/* Copyright 2021 LENA Development Team.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 /*
 * mod_cmx.c: LENA Monitoring Extension Module
 *
 */
#define CMX_HANDLER "cmx-status"

#include "httpd.h"
#include "http_config.h"
#include "http_core.h"
#include "http_log.h"
#include "http_protocol.h"
#include "http_main.h"
#include "apr_version.h"
#if APR_MAJOR_VERSION < 2
#include "apu_version.h"
#endif
#include "ap_mpm.h"

#include "util_script.h"
#include <time.h>
#include "scoreboard.h"
#if APR_HAVE_UNISTD_H
#include <unistd.h>
#endif
#define APR_WANT_STRFUNC
#include "apr_want.h"
#include "apr_strings.h"

#define CMX_STATUS_MAXLINE 64

#define CMX_KBYTE 1024
#define CMX_MBYTE 1048576L
#define CMX_GBYTE 1073741824L

#ifndef CMX_DEFAULT_TIME_FORMAT
#define CMX_DEFAULT_TIME_FORMAT "%A, %d-%b-%Y %H:%M:%S %Z"
#endif

#define CMX_SERVER_DISABLED SERVER_NUM_STATUS
#define CMX_MOD_STATUS_NUM_STATUS (SERVER_NUM_STATUS+1)

#ifdef HAVE_TIMES
/* ugh... need to know if we're running with a pthread implementation
 * such as linuxthreads that treats individual threads as distinct
 * processes; that affects how we add up CPU time in a process
 */
#endif

static pid_t child_pid;
static char cmx_status_flags[CMX_MOD_STATUS_NUM_STATUS];
static int cmx_server_limit, cmx_thread_limit, cmx_threads_per_child, cmx_max_servers, cmx_is_async;

#include "jk_worker.h"
#include "jk_ajp_common.h"
#include "jk_lb_worker.h"
static jk_map_t *cmx_jk_map = NULL;
static char *cmx_jk_worker_file = NULL;

struct cmx_server_info
{
	apr_time_t		current_time;
	apr_time_t		restart_time;
	double			system_cpu_usage;
	double			user_cpu_usage;
	unsigned long	total_access;
	apr_off_t		total_traffic;
    unsigned int	max_threads;
    unsigned int	active_threads;
    unsigned int	idle_threads;
};
typedef struct cmx_server_info cmx_monitor_info_t;

struct cmx_was_info
{
	char			*jvm_route;
	unsigned int	state;
	unsigned int	active_connections;
	unsigned int	max_connections;
	unsigned int	idle_connections;
	apr_off_t		total_access;
	apr_off_t		total_error;
};
typedef struct cmx_was_info cmx_was_info_t;

/* Format the number of bytes nicely */
static void cmx_format_byte_out(request_rec *r, apr_off_t bytes)
{
    if (bytes < (5 * CMX_KBYTE))
        ap_rprintf(r, "%d B", (int) bytes);
    else if (bytes < (CMX_MBYTE / 2))
        ap_rprintf(r, "%.1f kB", (float) bytes / CMX_KBYTE);
    else if (bytes < (CMX_GBYTE / 2))
        ap_rprintf(r, "%.1f MB", (float) bytes / CMX_MBYTE);
    else
        ap_rprintf(r, "%.1f GB", (float) bytes / CMX_GBYTE);
}

static int cmx_cmp_module_name(const void *a_, const void *b_)
{
    const module * const *a = a_;
    const module * const *b = b_;
    return strcmp((*a)->name, (*b)->name);
}

static apr_array_header_t *cmx_get_sorted_modules(apr_pool_t *p)
{
    apr_array_header_t *arr = apr_array_make(p, 64, sizeof(module *));
    module *modp, **entry;
    for (modp = ap_top_module; modp; modp = modp->next) {
        entry = &APR_ARRAY_PUSH(arr, module *);
        *entry = modp;
    }
    qsort(arr->elts, arr->nelts, sizeof(module *), cmx_cmp_module_name);
    return arr;
}

static void cmx_show_time(request_rec *r, apr_uint32_t tsecs)
{
    int days, hrs, mins, secs;

    secs = (int)(tsecs % 60);
    tsecs /= 60;
    mins = (int)(tsecs % 60);
    tsecs /= 60;
    hrs = (int)(tsecs % 24);
    days = (int)(tsecs / 24);

    if (days)
        ap_rprintf(r, " %d day%s", days, days == 1 ? "" : "s");

    if (hrs)
        ap_rprintf(r, " %d hour%s", hrs, hrs == 1 ? "" : "s");

    if (mins)
        ap_rprintf(r, " %d minute%s", mins, mins == 1 ? "" : "s");

    if (secs)
        ap_rprintf(r, " %d second%s", secs, secs == 1 ? "" : "s");
}

static void cmx_show_header_html(request_rec *r)
{
    ap_set_content_type(r, "text/html; charset=ISO-8859-1");
    ap_rputs(DOCTYPE_XHTML_1_0T
             "<html xmlns=\"http://www.w3.org/1999/xhtml\">\n"
             "<head>\n"
             "  <title>LENA Web Monitoring Extension</title>\n" "</head>\n", r);
    ap_rputs("<body><h1 style=\"text-align: center\">"
             "LENA Web Information</h1>\n", r);
}

static void cmx_show_summary_html(request_rec *r)
{
	server_rec *serv = r->server;
	int max_daemons, forked, threaded;
	ap_mpm_query(AP_MPMQ_MAX_DAEMON_USED, &max_daemons);
	ap_mpm_query(AP_MPMQ_IS_THREADED, &threaded);
	ap_mpm_query(AP_MPMQ_IS_FORKED, &forked);

	ap_rputs("<h2><a name=\"info\">Server Information</a></h2>", r);
	ap_rprintf(r,
			   "<dl><dt><strong>Version:</strong> "
			   "<font size=\"+1\"><tt>%s</tt></font></dt>\n",
			   ap_get_server_description());
	ap_rprintf(r,
			   "<dt><strong>Built:</strong> "
			   "<font size=\"+1\"><tt>%s</tt></font></dt>\n",
			   ap_get_server_built());
	ap_rprintf(r,
			   "<dt><strong>Hostname/port:</strong> "
			   "<tt>%s:%u</tt></dt>\n",
			   ap_escape_html(r->pool, ap_get_server_name(r)),
			   ap_get_server_port(r));
	ap_rprintf(r,
			   "<dt><strong>Timeouts:</strong> "
			   "<tt>connection: %d &nbsp;&nbsp; "
			   "keep-alive: %d</tt></dt>",
			   (int) (apr_time_sec(serv->timeout)),
			   (int) (apr_time_sec(serv->keep_alive_timeout)));

	ap_rprintf(r, "<dt><strong>MPM Name:</strong> <tt>%s</tt></dt>\n",
			   ap_show_mpm());

	ap_rprintf(r,
			   "<dt><strong>MPM Information:</strong> "
			   "<tt>Max Daemons: %d Threaded: %s Forked: %s</tt></dt>\n",
			   max_daemons, threaded ? "yes" : "no", forked ? "yes" : "no");

	ap_rprintf(r,
			   "<dt><strong>Architecture:</strong> "
			   "<tt>%ld-bit</tt></dt>\n", 8 * (long) sizeof(void *));
	ap_rprintf(r,
			   "<dt><strong>Engine Root:</strong> "
			   "<tt>%s</tt></dt>\n", ap_server_root);
	ap_rprintf(r,
			   "<dt><strong>Config File:</strong> "
			   "<tt>%s</tt></dt>\n", ap_conftree->filename);
}

static void cmx_show_tail_html(request_rec *r)
{
    ap_rputs(ap_psignature("", r), r);
    ap_rputs("</body></html>\n", r);
}

static void cmx_show_modules_html(request_rec *r){
    apr_array_header_t *modules = NULL;
    int i;
    module *modp = NULL;
    modules = cmx_get_sorted_modules(r->pool);
	ap_rputs("<h2><a name=\"modules\">Loaded Modules</a></h2>", r);
    for (i = 0; i < modules->nelts; i++) {
        modp = APR_ARRAY_IDX(modules, i, module *);
        ap_rprintf(r, "<a>%s</a>", modp->name, modp->name);
        if (i < modules->nelts) {
            ap_rputs(", ", r);
        }
    }
}

static void cmx_show_server_status_html(request_rec *r){

    const char *loc;
    apr_time_t nowtime;
    apr_uint32_t up_time;
    ap_loadavg_t t;
    int j, i, res, written;
    int ready;
    int busy;
    unsigned long count;
    unsigned long lres, my_lres, conn_lres;
    apr_off_t bytes, my_bytes, conn_bytes;
    apr_off_t bcount, kbcount;
    long req_time;
    int no_table_report;
    worker_score *ws_record = apr_palloc(r->pool, sizeof *ws_record);
    process_score *ps_record;
    char *stat_buffer;
    pid_t *pid_buffer, worker_pid;
    int *thread_idle_buffer = NULL;
    int *thread_busy_buffer = NULL;
    clock_t tu, ts, tcu, tcs;
    ap_generation_t mpm_generation, worker_generation;
#ifdef HAVE_TIMES
    float tick;
    int times_per_thread;
#endif


#ifdef HAVE_TIMES
    times_per_thread = getpid() != child_pid;
#endif

    ap_mpm_query(AP_MPMQ_GENERATION, &mpm_generation);

#ifdef HAVE_TIMES
#ifdef _SC_CLK_TCK
    tick = sysconf(_SC_CLK_TCK);
#else
    tick = HZ;
#endif
#endif

    ready = 0;
    busy = 0;
    count = 0;
    bcount = 0;
    kbcount = 0;
    no_table_report = 0;

    pid_buffer = apr_palloc(r->pool, cmx_server_limit * sizeof(pid_t));
    stat_buffer = apr_palloc(r->pool, cmx_server_limit * cmx_thread_limit * sizeof(char));
    if (cmx_is_async) {
        thread_idle_buffer = apr_palloc(r->pool, cmx_server_limit * sizeof(int));
        thread_busy_buffer = apr_palloc(r->pool, cmx_server_limit * sizeof(int));
    }

    nowtime = apr_time_now();
    tu = ts = tcu = tcs = 0;

    if (!ap_exists_scoreboard_image()) {
        ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, APLOGNO(01237)
                      "Server status unavailable in inetd mode");
        return;
    }

    for (i = 0; i < cmx_server_limit; ++i) {
#ifdef HAVE_TIMES
        clock_t proc_tu = 0, proc_ts = 0, proc_tcu = 0, proc_tcs = 0;
        clock_t tmp_tu, tmp_ts, tmp_tcu, tmp_tcs;
#endif

        ps_record = ap_get_scoreboard_process(i);
        if (cmx_is_async) {
            thread_idle_buffer[i] = 0;
            thread_busy_buffer[i] = 0;
        }
        for (j = 0; j < cmx_thread_limit; ++j) {
            int indx = (i * cmx_thread_limit) + j;

            ap_copy_scoreboard_worker(ws_record, i, j);
            res = ws_record->status;

            if ((i >= cmx_max_servers || j >= cmx_threads_per_child)
                && (res == SERVER_DEAD))
                stat_buffer[indx] = cmx_status_flags[CMX_SERVER_DISABLED];
            else
                stat_buffer[indx] = cmx_status_flags[res];

            if (!ps_record->quiescing
                && ps_record->pid) {
                if (res == SERVER_READY) {
                    if (ps_record->generation == mpm_generation)
                        ready++;
                    if (cmx_is_async)
                        thread_idle_buffer[i]++;
                }
                else if (res != SERVER_DEAD &&
                         res != SERVER_STARTING &&
                         res != SERVER_IDLE_KILL) {
                    busy++;
                    if (cmx_is_async) {
                        if (res == SERVER_GRACEFUL)
                            thread_idle_buffer[i]++;
                        else
                            thread_busy_buffer[i]++;
                    }
                }
            }

            /* XXX what about the counters for quiescing/seg faulted
             * processes?  should they be counted or not?  GLA
             */
            if (ap_extended_status) {
                lres = ws_record->access_count;
                bytes = ws_record->bytes_served;

                if (lres != 0 || (res != SERVER_READY && res != SERVER_DEAD)) {
#ifdef HAVE_TIMES
                    tmp_tu = ws_record->times.tms_utime;
                    tmp_ts = ws_record->times.tms_stime;
                    tmp_tcu = ws_record->times.tms_cutime;
                    tmp_tcs = ws_record->times.tms_cstime;

                    if (times_per_thread) {
                        proc_tu += tmp_tu;
                        proc_ts += tmp_ts;
                        proc_tcu += tmp_tcu;
                        proc_tcs += tmp_tcs;
                    }
                    else {
                        if (tmp_tu > proc_tu ||
                            tmp_ts > proc_ts ||
                            tmp_tcu > proc_tcu ||
                            tmp_tcs > proc_tcs) {
                            proc_tu = tmp_tu;
                            proc_ts = tmp_ts;
                            proc_tcu = tmp_tcu;
                            proc_tcs = tmp_tcs;
                        }
                    }
#endif /* HAVE_TIMES */

                    count += lres;
                    bcount += bytes;

                    if (bcount >= CMX_KBYTE) {
                        kbcount += (bcount >> 10);
                        bcount = bcount & 0x3ff;
                    }
                }
            }
        }
#ifdef HAVE_TIMES
        tu += proc_tu;
        ts += proc_ts;
        tcu += proc_tcu;
        tcs += proc_tcs;
#endif
        pid_buffer[i] = ps_record->pid;
    }

    ap_rputs("<h2><a name=\"status\">Server Status</a></h2>", r);
    /* up_time in seconds */
    up_time = (apr_uint32_t) apr_time_sec(nowtime -
                               ap_scoreboard_image->global->restart_time);
    ap_get_loadavg(&t);

	ap_rvputs(r, "<dt>Current Time: ",
			  ap_ht_time(r->pool, nowtime, CMX_DEFAULT_TIME_FORMAT, 0),
						 "</dt>\n", NULL);
	ap_rvputs(r, "<dt>Restart Time: ",
			  ap_ht_time(r->pool,
						 ap_scoreboard_image->global->restart_time,
						 CMX_DEFAULT_TIME_FORMAT, 0),
			  "</dt>\n", NULL);
	ap_rprintf(r, "<dt>Parent Server Config. Generation: %d</dt>\n",
			   ap_state_query(AP_SQ_CONFIG_GEN));
	ap_rprintf(r, "<dt>Parent Server MPM Generation: %d</dt>\n",
			   (int)mpm_generation);
	ap_rputs("<dt>Server uptime: ", r);
	cmx_show_time(r, up_time);
	ap_rputs("</dt>\n", r);
	ap_rprintf(r, "<dt>Server load: %.2f %.2f %.2f</dt>\n",
			   t.loadavg, t.loadavg5, t.loadavg15);

    if (ap_extended_status) {
		ap_rprintf(r, "<dt>Total accesses: %lu ", count);
		ap_rprintf(r, " - Total traffic: %lu", kbcount);

		ap_rputs("</dt>\n", r);

#ifdef HAVE_TIMES
		/* Allow for OS/2 not having CPU stats */
		ap_rprintf(r, "<dt>CPU Usage: u%g s%g cu%g cs%g",
				   tu / tick, ts / tick, tcu / tick, tcs / tick);

		if (ts || tu || tcu || tcs)
			ap_rprintf(r, " - %.3g%% CPU load</dt>\n",
					   (tu + ts + tcu + tcs) / tick / up_time * 100.);
#endif

		if (up_time > 0) {
			ap_rprintf(r, "<dt>%.3g requests/sec - ",
					   (float) count / (float) up_time);

			cmx_format_byte_out(r, (unsigned long)(CMX_KBYTE * (float) kbcount
											   / (float) up_time));
			ap_rputs("/second - ", r);
		}

		if (count > 0) {
			cmx_format_byte_out(r, (unsigned long)(CMX_KBYTE * (float) kbcount
											   / (float) count));
			ap_rputs("/request", r);
		}

		ap_rputs("</dt>\n", r);
    } /* ap_extended_status */

	ap_rprintf(r, "<dt>%d requests currently being processed, "
				  "%d idle workers</dt>\n", busy, ready);

	ap_rputs("</dl>", r);

    if (cmx_is_async) {
        int write_completion = 0, lingering_close = 0, keep_alive = 0,
            connections = 0;
        /*
         * These differ from 'busy' and 'ready' in how gracefully finishing
         * threads are counted. XXX: How to make this clear in the html?
         */
        int busy_workers = 0, idle_workers = 0;
		ap_rputs("\n\n<table rules=\"all\" cellpadding=\"1%\">\n"
				 "<tr><th rowspan=\"2\">PID</th>"
					 "<th colspan=\"2\">Connections</th>\n"
					 "<th colspan=\"2\">Threads</th>"
					 "<th colspan=\"4\">Async connections</th></tr>\n"
				 "<tr><th>total</th><th>accepting</th>"
					 "<th>busy</th><th>idle</th><th>writing</th>"
					 "<th>keep-alive</th><th>closing</th></tr>\n", r);
        for (i = 0; i < cmx_server_limit; ++i) {
            ps_record = ap_get_scoreboard_process(i);
            if (ps_record->pid) {
                connections      += ps_record->connections;
                write_completion += ps_record->write_completion;
                keep_alive       += ps_record->keep_alive;
                lingering_close  += ps_record->lingering_close;
                busy_workers     += thread_busy_buffer[i];
                idle_workers     += thread_idle_buffer[i];
				ap_rprintf(r, "<tr><td>%" APR_PID_T_FMT "</td><td>%u</td>"
								  "<td>%s</td><td>%u</td><td>%u</td>"
								  "<td>%u</td><td>%u</td><td>%u</td>"
								  "</tr>\n",
						   ps_record->pid, ps_record->connections,
						   ps_record->not_accepting ? "no" : "yes",
						   thread_busy_buffer[i], thread_idle_buffer[i],
						   ps_record->write_completion,
						   ps_record->keep_alive,
						   ps_record->lingering_close);
            }
        }
		ap_rprintf(r, "<tr><td>Sum</td><td>%d</td><td>&nbsp;</td><td>%d</td>"
					  "<td>%d</td><td>%d</td><td>%d</td><td>%d</td>"
					  "</tr>\n</table>\n",
					  connections, busy_workers, idle_workers,
					  write_completion, keep_alive, lingering_close);
    }

    /* send the scoreboard 'table' out */
	ap_rputs("<pre>", r);

    written = 0;
    for (i = 0; i < cmx_server_limit; ++i) {
        for (j = 0; j < cmx_thread_limit; ++j) {
            int indx = (i * cmx_thread_limit) + j;
            if (stat_buffer[indx] != cmx_status_flags[CMX_SERVER_DISABLED]) {
                ap_rputc(stat_buffer[indx], r);
                if ((written % CMX_STATUS_MAXLINE == (CMX_STATUS_MAXLINE - 1)))
                    ap_rputs("\n", r);
                written++;
            }
        }
    }


	ap_rputs("</pre>\n"
			 "<p>Scoreboard Key:<br />\n"
			 "\"<b><code>_</code></b>\" Waiting for Connection, \n"
			 "\"<b><code>S</code></b>\" Starting up, \n"
			 "\"<b><code>R</code></b>\" Reading Request,<br />\n"
			 "\"<b><code>W</code></b>\" Sending Reply, \n"
			 "\"<b><code>K</code></b>\" Keepalive (read), \n"
			 "\"<b><code>D</code></b>\" DNS Lookup,<br />\n"
			 "\"<b><code>C</code></b>\" Closing connection, \n"
			 "\"<b><code>L</code></b>\" Logging, \n"
			 "\"<b><code>G</code></b>\" Gracefully finishing,<br /> \n"
			 "\"<b><code>I</code></b>\" Idle cleanup of worker, \n"
			 "\"<b><code>.</code></b>\" Open slot with no current process<br />\n"
			 "<p />\n", r);
	if (!ap_extended_status) {
		int j;
		int k = 0;
		ap_rputs("PID Key: <br />\n"
				 "<pre>\n", r);
		for (i = 0; i < cmx_server_limit; ++i) {
			for (j = 0; j < cmx_thread_limit; ++j) {
				int indx = (i * cmx_thread_limit) + j;

				if (stat_buffer[indx] != '.') {
					ap_rprintf(r, "   %" APR_PID_T_FMT
							   " in state: %c ", pid_buffer[i],
							   stat_buffer[indx]);

					if (++k >= 3) {
						ap_rputs("\n", r);
						k = 0;
					} else
						ap_rputs(",", r);
				}
			}
		}

		ap_rputs("\n"
				 "</pre>\n", r);
	}

    if (ap_extended_status) {
        if (no_table_report)
            ap_rputs("<hr /><h2>Server Details</h2>\n\n", r);
        else
            ap_rputs("\n\n<table border=\"0\"><tr>"
                     "<th>Srv</th><th>PID</th><th>Acc</th>"
                     "<th>M</th>"
#ifdef HAVE_TIMES
                     "<th>CPU\n</th>"
#endif
                     "<th>SS</th><th>Req</th>"
                     "<th>Conn</th><th>Child</th><th>Slot</th>"
                     "<th>Client</th><th>VHost</th>"
                     "<th>Request</th></tr>\n\n", r);

        for (i = 0; i < cmx_server_limit; ++i) {
            for (j = 0; j < cmx_thread_limit; ++j) {
                ap_copy_scoreboard_worker(ws_record, i, j);

                if (ws_record->access_count == 0 &&
                    (ws_record->status == SERVER_READY ||
                     ws_record->status == SERVER_DEAD)) {
                    continue;
                }

                ps_record = ap_get_scoreboard_process(i);

                if (ws_record->start_time == 0L)
                    req_time = 0L;
                else
                    req_time = (long)
                        ((ws_record->stop_time -
                          ws_record->start_time) / 1000);
                if (req_time < 0L)
                    req_time = 0L;

                lres = ws_record->access_count;
                my_lres = ws_record->my_access_count;
                conn_lres = ws_record->conn_count;
                bytes = ws_record->bytes_served;
                my_bytes = ws_record->my_bytes_served;
                conn_bytes = ws_record->conn_bytes;
                if (ws_record->pid) { /* MPM sets per-worker pid and generation */
                    worker_pid = ws_record->pid;
                    worker_generation = ws_record->generation;
                }
                else {
                    worker_pid = ps_record->pid;
                    worker_generation = ps_record->generation;
                }

                if (no_table_report) {
                    if (ws_record->status == SERVER_DEAD)
                        ap_rprintf(r,
                                   "<b>Server %d-%d</b> (-): %d|%lu|%lu [",
                                   i, (int)worker_generation,
                                   (int)conn_lres, my_lres, lres);
                    else
                        ap_rprintf(r,
                                   "<b>Server %d-%d</b> (%"
                                   APR_PID_T_FMT "): %d|%lu|%lu [",
                                   i, (int) worker_generation,
                                   worker_pid,
                                   (int)conn_lres, my_lres, lres);

                    switch (ws_record->status) {
                    case SERVER_READY:
                        ap_rputs("Ready", r);
                        break;
                    case SERVER_STARTING:
                        ap_rputs("Starting", r);
                        break;
                    case SERVER_BUSY_READ:
                        ap_rputs("<b>Read</b>", r);
                        break;
                    case SERVER_BUSY_WRITE:
                        ap_rputs("<b>Write</b>", r);
                        break;
                    case SERVER_BUSY_KEEPALIVE:
                        ap_rputs("<b>Keepalive</b>", r);
                        break;
                    case SERVER_BUSY_LOG:
                        ap_rputs("<b>Logging</b>", r);
                        break;
                    case SERVER_BUSY_DNS:
                        ap_rputs("<b>DNS lookup</b>", r);
                        break;
                    case SERVER_CLOSING:
                        ap_rputs("<b>Closing</b>", r);
                        break;
                    case SERVER_DEAD:
                        ap_rputs("Dead", r);
                        break;
                    case SERVER_GRACEFUL:
                        ap_rputs("Graceful", r);
                        break;
                    case SERVER_IDLE_KILL:
                        ap_rputs("Dying", r);
                        break;
                    default:
                        ap_rputs("?STATE?", r);
                        break;
                    }

                    ap_rprintf(r, "] "
#ifdef HAVE_TIMES
                               "u%g s%g cu%g cs%g"
#endif
                               "\n %ld %ld (",
#ifdef HAVE_TIMES
                               ws_record->times.tms_utime / tick,
                               ws_record->times.tms_stime / tick,
                               ws_record->times.tms_cutime / tick,
                               ws_record->times.tms_cstime / tick,
#endif
                               (long)apr_time_sec(nowtime -
                                                  ws_record->last_used),
                               (long) req_time);

                    cmx_format_byte_out(r, conn_bytes);
                    ap_rputs("|", r);
                    cmx_format_byte_out(r, my_bytes);
                    ap_rputs("|", r);
                    cmx_format_byte_out(r, bytes);
                    ap_rputs(")\n", r);
                    ap_rprintf(r,
                               " <i>%s {%s}</i> <b>[%s]</b><br />\n\n",
                               ap_escape_html(r->pool,
                                              ws_record->client),
                               ap_escape_html(r->pool,
                                              ap_escape_logitem(r->pool,
                                                                ws_record->request)),
                               ap_escape_html(r->pool,
                                              ws_record->vhost));
                }
                else { /* !no_table_report */
                    if (ws_record->status == SERVER_DEAD)
                        ap_rprintf(r,
                                   "<tr><td><b>%d-%d</b></td><td>-</td><td>%d/%lu/%lu",
                                   i, (int)worker_generation,
                                   (int)conn_lres, my_lres, lres);
                    else
                        ap_rprintf(r,
                                   "<tr><td><b>%d-%d</b></td><td>%"
                                   APR_PID_T_FMT
                                   "</td><td>%d/%lu/%lu",
                                   i, (int)worker_generation,
                                   worker_pid,
                                   (int)conn_lres,
                                   my_lres, lres);

                    switch (ws_record->status) {
                    case SERVER_READY:
                        ap_rputs("</td><td>_", r);
                        break;
                    case SERVER_STARTING:
                        ap_rputs("</td><td><b>S</b>", r);
                        break;
                    case SERVER_BUSY_READ:
                        ap_rputs("</td><td><b>R</b>", r);
                        break;
                    case SERVER_BUSY_WRITE:
                        ap_rputs("</td><td><b>W</b>", r);
                        break;
                    case SERVER_BUSY_KEEPALIVE:
                        ap_rputs("</td><td><b>K</b>", r);
                        break;
                    case SERVER_BUSY_LOG:
                        ap_rputs("</td><td><b>L</b>", r);
                        break;
                    case SERVER_BUSY_DNS:
                        ap_rputs("</td><td><b>D</b>", r);
                        break;
                    case SERVER_CLOSING:
                        ap_rputs("</td><td><b>C</b>", r);
                        break;
                    case SERVER_DEAD:
                        ap_rputs("</td><td>.", r);
                        break;
                    case SERVER_GRACEFUL:
                        ap_rputs("</td><td>G", r);
                        break;
                    case SERVER_IDLE_KILL:
                        ap_rputs("</td><td>I", r);
                        break;
                    default:
                        ap_rputs("</td><td>?", r);
                        break;
                    }

                    ap_rprintf(r,
                               "\n</td>"
#ifdef HAVE_TIMES
                               "<td>%.2f</td>"
#endif
                               "<td>%ld</td><td>%ld",
#ifdef HAVE_TIMES
                               (ws_record->times.tms_utime +
                                ws_record->times.tms_stime +
                                ws_record->times.tms_cutime +
                                ws_record->times.tms_cstime) / tick,
#endif
                               (long)apr_time_sec(nowtime -
                                                  ws_record->last_used),
                               (long)req_time);

                    ap_rprintf(r, "</td><td>%-1.1f</td><td>%-2.2f</td><td>%-2.2f\n",
                               (float)conn_bytes / CMX_KBYTE, (float) my_bytes / CMX_MBYTE,
                               (float)bytes / CMX_MBYTE);

                    ap_rprintf(r, "</td><td>%s</td><td nowrap>%s</td>"
                                  "<td nowrap>%s</td></tr>\n\n",
                               ap_escape_html(r->pool,
                                              ws_record->client),
                               ap_escape_html(r->pool,
                                              ws_record->vhost),
                               ap_escape_html(r->pool,
                                              ap_escape_logitem(r->pool,
                                                      ws_record->request)));
                } /* no_table_report */
            } /* for (j...) */
        } /* for (i...) */

        if (!no_table_report) {
            ap_rputs("</table>\n \
						<hr /> \
						<table>\n \
						<tr><th>Srv</th><td>Child Server number - generation</td></tr>\n \
						<tr><th>PID</th><td>OS process ID</td></tr>\n \
						<tr><th>Acc</th><td>Number of accesses this connection / this child / this slot</td></tr>\n \
						<tr><th>M</th><td>Mode of operation</td></tr>\n"

						#ifdef HAVE_TIMES
						"<tr><th>CPU</th><td>CPU usage, number of seconds</td></tr>\n"
						#endif

						"<tr><th>SS</th><td>Seconds since beginning of most recent request</td></tr>\n \
						<tr><th>Req</th><td>Milliseconds required to process most recent request</td></tr>\n \
						<tr><th>Conn</th><td>Kilobytes transferred this connection</td></tr>\n \
						<tr><th>Child</th><td>Megabytes transferred this child</td></tr>\n \
						<tr><th>Slot</th><td>Total megabytes transferred this slot</td></tr>\n \
						</table>\n", r);
		}
    } /* if (ap_extended_status) */
    else {

		ap_rputs("<hr />To obtain a full report with current status "
				 "information you need to use the "
				 "<code>ExtendedStatus On</code> directive.\n", r);
    }
}

static apr_table_t* cmx_get_request_params(request_rec *r){
	apr_table_t *params = apr_table_make(r->pool, 10);

    char *args = apr_pstrdup(r->pool, r->args);
    char *tok, *val;
    while (args && *args) {
        if ((val = ap_strchr(args, '='))) {
            *val++ = '\0';
            if ((tok = ap_strchr(val, '&')))
                *tok++ = '\0';

            apr_table_setn(params, args, val);
            args = tok;
        }
    }

	return params;
}

static int cmx_get_was_count(request_rec *r){
	char **worker_list;
	unsigned int num_of_workers=0;
	int i;
	int was_count_sum = 0;

	//copy cmx_jk_map to cmx_jk_map_temp
	jk_map_t *cmx_jk_map_temp;
	jk_map_alloc(&cmx_jk_map_temp);
	jk_map_copy(cmx_jk_map, cmx_jk_map_temp);
	
	jk_get_worker_list(cmx_jk_map_temp, &worker_list, &num_of_workers);

	for (i = 0; i < num_of_workers; i++) {
		const char *type = jk_get_worker_type(cmx_jk_map_temp, worker_list[i]);
		if (!strcmp(type, "lb")) {
			jk_worker_t  *w = wc_get_worker_for_name(worker_list[i], NULL);
			lb_worker_t *worker= (lb_worker_t *) w->worker_private;

			if (worker->lb_workers) {
				was_count_sum += worker->num_of_workers;
			}
		}
	}

	//free cmx_jk_map_temp
	jk_map_free(&cmx_jk_map_temp);

	return was_count_sum;
}

static cmx_was_info_t* cmx_get_was_infos(request_rec *r, int was_count)
{
	char **worker_list;
	unsigned int num_of_workers=0;
	int worker_idx = 0;
	int i;
	int idle_connections;
	unsigned int ep_cache_sz;

	cmx_was_info_t *was_infos = (cmx_was_info_t *)apr_palloc(r->pool, sizeof(cmx_was_info_t) * was_count );

	//copy cmx_jk_map to cmx_jk_map_temp
	jk_map_t *cmx_jk_map_temp;
	jk_map_alloc(&cmx_jk_map_temp);
	jk_map_copy(cmx_jk_map, cmx_jk_map_temp);
	
	jk_get_worker_list(cmx_jk_map_temp, &worker_list, &num_of_workers);

	for (i = 0; i < num_of_workers; i++) {
		const char *type = jk_get_worker_type(cmx_jk_map_temp, worker_list[i]);
		if (!strcmp(type, "lb")) {
			jk_worker_t  *w = wc_get_worker_for_name(worker_list[i], NULL);
			lb_worker_t *worker= (lb_worker_t *) w->worker_private;

			if (worker->lb_workers) {
				int idx;
				int state;
				lb_sub_worker_t *lb_sub_worker;
				ajp_worker_t *ajp_worker;

				for (idx = 0; idx < worker->num_of_workers; idx++) {
					lb_sub_worker = NULL;
					ajp_worker = NULL;
					state = -1;
					lb_sub_worker = &worker->lb_workers[idx];
					ajp_worker = (ajp_worker_t *) lb_sub_worker->worker->worker_private;

					if (lb_sub_worker == NULL)
						continue;
					if (ajp_worker == NULL)
						continue;

					was_infos[worker_idx].jvm_route = lb_sub_worker->name;
					was_infos[worker_idx].state = lb_sub_worker->s->state;
					was_infos[worker_idx].total_access = ajp_worker->s->used;
					was_infos[worker_idx].total_error = ajp_worker->s->errors;
					was_infos[worker_idx].active_connections = ajp_worker->s->busy;
					idle_connections = ajp_worker->s->connected - ajp_worker->s->busy;
					idle_connections = idle_connections <= 0 ? 0 : idle_connections;

					was_infos[worker_idx].idle_connections = idle_connections;
					ep_cache_sz = ajp_worker->ep_cache_sz;
					ep_cache_sz = ep_cache_sz <= 0 ? 128 : ep_cache_sz;

					was_infos[worker_idx].max_connections = ep_cache_sz * cmx_max_servers;

					worker_idx++;
				}
			}
		}
	}

	//free cmx_jk_map_temp
	jk_map_free(&cmx_jk_map_temp);

	return was_infos;
}

static cmx_monitor_info_t* cmx_get_monitor_info(request_rec *r) {
    const char *loc;
    apr_time_t nowtime;
    int j, i, res, written;
    int ready;
    int busy;
    unsigned long count;
    unsigned long lres, my_lres, conn_lres;
    apr_off_t bytes, my_bytes, conn_bytes;
    apr_off_t bcount, kbcount;
    long req_time;
    worker_score *ws_record = apr_palloc(r->pool, sizeof *ws_record);
    process_score *ps_record;
    char *stat_buffer;
    pid_t *pid_buffer, worker_pid;
    int *thread_idle_buffer = NULL;
    int *thread_busy_buffer = NULL;
    clock_t tu, ts, tcu, tcs;
    ap_generation_t mpm_generation, worker_generation;
	cmx_monitor_info_t *monitor_info;
#ifdef HAVE_TIMES
    float tick;
    int times_per_thread;
#endif


#ifdef HAVE_TIMES
    times_per_thread = getpid() != child_pid;
#endif

    ap_mpm_query(AP_MPMQ_GENERATION, &mpm_generation);

#ifdef HAVE_TIMES
#ifdef _SC_CLK_TCK
    tick = sysconf(_SC_CLK_TCK);
#else
    tick = HZ;
#endif
#endif

    ready = 0;
    busy = 0;
    count = 0;
    bcount = 0;
    kbcount = 0;

    pid_buffer = apr_palloc(r->pool, cmx_server_limit * sizeof(pid_t));
    stat_buffer = apr_palloc(r->pool, cmx_server_limit * cmx_thread_limit * sizeof(char));
    if (cmx_is_async) {
        thread_idle_buffer = apr_palloc(r->pool, cmx_server_limit * sizeof(int));
        thread_busy_buffer = apr_palloc(r->pool, cmx_server_limit * sizeof(int));
    }

    nowtime = apr_time_now();
    tu = ts = tcu = tcs = 0;

    if (!ap_exists_scoreboard_image()) {
        ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, APLOGNO(01237)
                      "Server status unavailable in inetd mode");
        return NULL;
    }

    for (i = 0; i < cmx_server_limit; ++i) {
#ifdef HAVE_TIMES
        clock_t proc_tu = 0, proc_ts = 0, proc_tcu = 0, proc_tcs = 0;
        clock_t tmp_tu, tmp_ts, tmp_tcu, tmp_tcs;
#endif

        ps_record = ap_get_scoreboard_process(i);
        if (cmx_is_async) {
            thread_idle_buffer[i] = 0;
            thread_busy_buffer[i] = 0;
        }
        for (j = 0; j < cmx_thread_limit; ++j) {
            int indx = (i * cmx_thread_limit) + j;

            ap_copy_scoreboard_worker(ws_record, i, j);
            res = ws_record->status;

            if ((i >= cmx_max_servers || j >= cmx_threads_per_child)
                && (res == SERVER_DEAD))
                stat_buffer[indx] = cmx_status_flags[CMX_SERVER_DISABLED];
            else
                stat_buffer[indx] = cmx_status_flags[res];

            if (!ps_record->quiescing && ps_record->pid) {
                if (res == SERVER_READY) {
                    if (ps_record->generation == mpm_generation)
                        ready++;
                    if (cmx_is_async)
                        thread_idle_buffer[i]++;
                }
                else if (res != SERVER_DEAD &&
                         res != SERVER_STARTING &&
                         res != SERVER_IDLE_KILL) {
                    busy++;
                    if (cmx_is_async) {
                        if (res == SERVER_GRACEFUL)
                            thread_idle_buffer[i]++;
                        else
                            thread_busy_buffer[i]++;
                    }
                }
            }

			lres = ws_record->access_count;
			bytes = ws_record->bytes_served;

			if (lres != 0 || (res != SERVER_READY && res != SERVER_DEAD)) {
#ifdef HAVE_TIMES
                    tmp_tu = ws_record->times.tms_utime;
                    tmp_ts = ws_record->times.tms_stime;
                    tmp_tcu = ws_record->times.tms_cutime;
                    tmp_tcs = ws_record->times.tms_cstime;

                    if (times_per_thread) {
                        proc_tu += tmp_tu;
                        proc_ts += tmp_ts;
                        proc_tcu += tmp_tcu;
                        proc_tcs += tmp_tcs;
                    }
                    else {
                        if (tmp_tu > proc_tu ||
                            tmp_ts > proc_ts ||
                            tmp_tcu > proc_tcu ||
                            tmp_tcs > proc_tcs) {
                            proc_tu = tmp_tu;
                            proc_ts = tmp_ts;
                            proc_tcu = tmp_tcu;
                            proc_tcs = tmp_tcs;
                        }
                    }
#endif /* HAVE_TIMES */

				count += lres;
				bcount += bytes;

				if (bcount >= CMX_KBYTE) {
					kbcount += (bcount >> 10);
					bcount = bcount & 0x3ff;
				}
			}
        }

#ifdef HAVE_TIMES
        tu += proc_tu;
        ts += proc_ts;
        tcu += proc_tcu;
        tcs += proc_tcs;
#endif
        pid_buffer[i] = ps_record->pid;
    }

	monitor_info = (cmx_monitor_info_t *) apr_palloc(r->pool, sizeof(cmx_monitor_info_t));

	monitor_info->current_time = nowtime / 1000;
	monitor_info->restart_time = ap_scoreboard_image->global->restart_time / 1000;
	monitor_info->total_access = count;
	monitor_info->total_traffic = kbcount;
	monitor_info->max_threads = cmx_max_servers * cmx_threads_per_child;
	monitor_info->active_threads = busy;
	monitor_info->idle_threads = ready;
#ifdef HAVE_TIMES
	monitor_info->system_cpu_usage = ts / tick;
	monitor_info->user_cpu_usage = tu / tick;
#endif

	return monitor_info;
}

static void cmx_show_monitor_json(request_rec *r){
	cmx_monitor_info_t *monitor_info = cmx_get_monitor_info(r);
	int was_count = cmx_get_was_count(r);
	process_score *ps_record;
	int process_infos_idx;
	int process_count=0;

	cmx_was_info_t* was_infos = cmx_get_was_infos(r, was_count);

	ap_set_content_type(r, "application/json; charset=ISO-8859-1");

	ap_rputs("{", r);	 /* start of json */

	ap_rprintf(r, "\"currentTime\":\"%"APR_TIME_T_FMT"\""
				",\"restartTime\":\"%"APR_TIME_T_FMT"\""
				",\"systemCpuUsage\":\"%g\""
				",\"userCpuUsage\":\"%g\""
				",\"totalAccess\":\"%lu\""
				",\"totalTraffic\":\"%lu\""
				",\"maxThreads\":\"%d\""
				",\"activeThreads\":\"%d\""
				",\"idleThreads\":\"%d\""
				, monitor_info->current_time
				, monitor_info->restart_time
				, monitor_info->system_cpu_usage
				, monitor_info->user_cpu_usage
				, monitor_info->total_access
				, monitor_info->total_traffic
				, monitor_info->max_threads
				, monitor_info->active_threads
				, monitor_info->idle_threads
			);

	ap_rputs(",\"wasInfos\":[", r);	 /* start of wasInfos */

	if(was_infos){
		int was_infos_idx;
		for(was_infos_idx=0; was_infos_idx < was_count; was_infos_idx++)
		{
			if(was_infos_idx > 0){
				ap_rputs(",", r);
			}
			ap_rprintf(r, "{"
						   "\"jvmRoute\":\"%s\""
							",\"state\":\"%d\""
							",\"maxConnections\":\"%d\""
							",\"activeConnections\":\"%d\""
							",\"idleConnections\":\"%d\""
							",\"totalAccess\":\"%lu\""
							",\"totalError\":\"%lu\""
							"}"
							,was_infos[was_infos_idx].jvm_route
							,was_infos[was_infos_idx].state
							,was_infos[was_infos_idx].max_connections
							,was_infos[was_infos_idx].active_connections
							,was_infos[was_infos_idx].idle_connections
							,was_infos[was_infos_idx].total_access
							,was_infos[was_infos_idx].total_error
						);
		}
	}

	ap_rputs("]", r);	/* end of wasInfos */

	ap_rputs(",\"processInfos\":[", r);	 /* start of processInfos */

    for (process_infos_idx = 0; process_infos_idx < cmx_server_limit; process_infos_idx++) {
        ps_record = ap_get_scoreboard_process(process_infos_idx);
        if (ps_record->pid) {
			if(process_count > 0){
				ap_rputs(",", r);
			}
			ap_rprintf(r, "{"
						   "\"pid\":\"%d\""
					/*
							",\"connections\":\"%d\""
							",\"writeCompletion\":\"%d\""
							",\"keepAlive\":\"%d\""
							",\"lingeringClose\":\"%d\""
					 */
							"}"
							,ps_record->pid
					/*
							,ps_record->connections
							,ps_record->write_completion
							,ps_record->keep_alive
							,ps_record->lingering_close
					 */
						);
			process_count++;
        }
    }
	ap_rputs("]", r);	/* end of processInfos */

	ap_rputs("}", r);	/* end of json */
}

static void cmx_show_was_status_html(request_rec *r) {
	int was_count = cmx_get_was_count(r);
	int was_infos_idx;

	cmx_was_info_t* was_infos = cmx_get_was_infos(r, was_count);

	ap_rputs("<h2><a name=\"was-info\">Connected WAS Information</a></h2>", r);

	ap_rputs("<table cellpadding=\"1%\">", r);

	ap_rputs("<tr>"
			 "<th>JvmRoute</th>"
			 "<th>State</th>"
			 "<th>MaxConnections</th>"
			 "<th>activeConnections</th>"
			 "<th>idleConnections</th>"
			 "<th>totalAccess</th>"
			 "<th>totalError</th>"
			 "</tr>"
			, r);

	if(was_infos){
		for(was_infos_idx=0; was_infos_idx < was_count; was_infos_idx++)
		{
			ap_rprintf(r, "<tr>"
						 "<td>%s</td>"
						 "<td>%d</td>"
						 "<td>%d</td>"
						 "<td>%d</td>"
						 "<td>%d</td>"
						 "<td>%d</td>"
						 "<td>%d</td>"
						 "</tr>"
						,was_infos[was_infos_idx].jvm_route
						,was_infos[was_infos_idx].state
						,was_infos[was_infos_idx].max_connections
						,was_infos[was_infos_idx].active_connections
						,was_infos[was_infos_idx].idle_connections
						,was_infos[was_infos_idx].total_access
						,was_infos[was_infos_idx].total_error
					);
		}
	}
	ap_rputs("</table>", r);
}

static void cmx_show_not_support_html(request_rec *r) {
	cmx_show_header_html(r);
	ap_rputs("<h2><a name=\"notice\">Doesn't support this command and parameter.</a></h2>", r);
	cmx_show_tail_html(r);
}

static void cmx_show_info_html(request_rec *r) {
	cmx_show_header_html(r);
	cmx_show_summary_html(r);
	cmx_show_modules_html(r);
	cmx_show_server_status_html(r);
	cmx_show_was_status_html(r);
	cmx_show_tail_html(r);
}

static int cmx_handler(request_rec *r) {
	apr_table_t *params;
	const char *cmd;
	const char *format;

    /* Determine if we are the handler for this request. */
    if (r->handler && strcmp(r->handler, CMX_HANDLER)) {
        return DECLINED;
    }

    params = cmx_get_request_params(r);
    cmd = apr_table_get(params, "cmd") == NULL ? "info" : apr_table_get(params, "cmd");
    format = apr_table_get(params, "format") == NULL ? "html" : apr_table_get(params, "format");

    if (!strcmp(cmd, "monitor")){
    	if(!strcmp(format, "json")){
			cmx_show_monitor_json(r);
    	}
    	else if(!strcmp(format, "html")){
    		cmx_show_not_support_html(r);
    	}
    	else{
    		cmx_show_not_support_html(r);
    	}
    }
    else if (!strcmp(cmd, "info")){
    	if(!strcmp(format, "html")){
    		cmx_show_info_html(r);
    	}
    	else{
    		cmx_show_not_support_html(r);
    	}
    }

    return OK;
}

static void cmx_jk_init(apr_pool_t *p, server_rec *s) {
    if (cmx_jk_worker_file == NULL){
		fprintf(stderr,"[error:mod_cmx] worker file name invalid.\n");
    	return;
    }

    if(jk_file_exists(cmx_jk_worker_file) != JK_TRUE){
    	fprintf(stderr,"[error:mod_cmx] worker file doesn't exist.\n");
    	return;
    }

	if (!cmx_jk_map){
		jk_map_alloc(&cmx_jk_map);
		jk_map_read_properties(cmx_jk_map, NULL, cmx_jk_worker_file, NULL, JK_MAP_HANDLE_DUPLICATES, NULL);
	}
}

static void cmx_child_init(apr_pool_t *p, server_rec *s)
{
    child_pid = getpid();
    cmx_jk_init(p, s);
}

static int cmx_init(apr_pool_t *p, apr_pool_t *plog, apr_pool_t *ptemp, server_rec *s) {
    cmx_status_flags[SERVER_DEAD] = '.';  /* We don't want to assume these are in */
    cmx_status_flags[SERVER_READY] = '_'; /* any particular order in scoreboard.h */
    cmx_status_flags[SERVER_STARTING] = 'S';
    cmx_status_flags[SERVER_BUSY_READ] = 'R';
    cmx_status_flags[SERVER_BUSY_WRITE] = 'W';
    cmx_status_flags[SERVER_BUSY_KEEPALIVE] = 'K';
    cmx_status_flags[SERVER_BUSY_LOG] = 'L';
    cmx_status_flags[SERVER_BUSY_DNS] = 'D';
    cmx_status_flags[SERVER_CLOSING] = 'C';
    cmx_status_flags[SERVER_GRACEFUL] = 'G';
    cmx_status_flags[SERVER_IDLE_KILL] = 'I';
    cmx_status_flags[CMX_SERVER_DISABLED] = ' ';
    ap_mpm_query(AP_MPMQ_HARD_LIMIT_THREADS, &cmx_thread_limit);
    ap_mpm_query(AP_MPMQ_HARD_LIMIT_DAEMONS, &cmx_server_limit);
    ap_mpm_query(AP_MPMQ_MAX_THREADS, &cmx_threads_per_child);
    /* work around buggy MPMs */
    if (cmx_threads_per_child == 0)
        cmx_threads_per_child = 1;
    ap_mpm_query(AP_MPMQ_MAX_DAEMONS, &cmx_max_servers);
    ap_mpm_query(AP_MPMQ_IS_ASYNC, &cmx_is_async);
    return OK;
}

static int cmx_pre_config(apr_pool_t *p, apr_pool_t *plog, apr_pool_t *ptemp) {
    /* When mod_status is loaded, default our ExtendedStatus to 'on'
     * other modules which prefer verbose scoreboards may play a similar game.
     * If left to their own requirements, mpm modules can make do with simple
     * scoreboard entries.
     */
    ap_extended_status = 1;
    return OK;
}

static void cmx_register_hooks(apr_pool_t *p) {
    ap_hook_handler(cmx_handler, NULL, NULL, APR_HOOK_MIDDLE);
    ap_hook_pre_config(cmx_pre_config, NULL, NULL, APR_HOOK_LAST);
    ap_hook_post_config(cmx_init, NULL, NULL, APR_HOOK_MIDDLE);
    ap_hook_child_init(cmx_child_init, NULL, NULL, APR_HOOK_MIDDLE);
}

static const char *jk_set_worker_file(cmd_parms * cmd, void *dummy, const char *worker_file) {
    const char *err_string = ap_check_cmd_context(cmd, GLOBAL_ONLY);
    if (err_string != NULL) {
        return err_string;
    }

    cmx_jk_worker_file = ap_server_root_relative(cmd->pool, worker_file);

    if (cmx_jk_worker_file == NULL){
    	fprintf(stderr,"[info:mod_cmx] worker file name invalid.\n");
    }

    return NULL;
}

static const command_rec cmx_cmds[] = {
	AP_INIT_TAKE1("JkWorkersFile", jk_set_worker_file, NULL, RSRC_CONF,
				  "The name of a worker file for the Tomcat servlet containers"),
    {NULL}
};

module AP_MODULE_DECLARE_DATA cmx_module = {
    STANDARD20_MODULE_STUFF, 
    NULL,                   /* per-directory config creator */
    NULL,                   /* dir config merger */
    NULL,                   /* server config creator */
    NULL,                   /* server config merger */
	cmx_cmds,               /* command table */
    cmx_register_hooks      /* register hooks */
};

