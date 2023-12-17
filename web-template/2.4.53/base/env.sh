#!/bin/sh

# Copyright 2022 LA:T Development Team.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SCRIPTPATH=`cd $(dirname $0) ; pwd -P`

export LAT_HOME=/apps/lat/1.0.0
export ENGN_VERSION=2.4.53
export ENGN_HOME=${LAT_HOME}/engines/runtime/apache/${ENGN_VERSION}
export INSTANCE_ID=lat-apache
export SERVICE_PORT=8580
export RUN_USER=`whoami`
#export HTTPS_SERVICE_PORT=`expr ${SERVICE_PORT} + 363`
export INSTALL_PATH=${SCRIPTPATH}
export DOC_ROOT=${INSTALL_PATH}/htdocs
export LOG_HOME=${INSTALL_PATH}/logs
export LOG_MAX_DAYS=0
export STAGING_SERVICE_PORT=`expr ${SERVICE_PORT} + 10000`
export STAGING_HTTPS_SERVICE_PORT=`expr ${HTTPS_SERVICE_PORT} + 10000`
export MPM_TYPE=MPM_EVENT
export SHUTDOWN_GRACEFUL=false
export GRACEFUL_SHUTDOWN_TIMEOUT=0
export INST_NAME=${INSTANCE_ID}_`hostname`
export TRACE_DTM=5000000
export EXT_MODULE_NAMES=
export EXT_MODULE_DEFINES=

if [ ! -r ${ENGN_HOME}/modules/mod_mpm_event.so ]; then
	export MPM_TYPE=MPM_WORKER
fi
## ROOT SWITCH USER / GROUP
export ROOT_SWITCH_USER=nobody
if `cat /etc/*-release | grep -q "Ubuntu"`; then
  export ROOT_SWITCH_GROUP=nogroup
else
  export ROOT_SWITCH_GROUP=nobody
fi

## LIBPATH
export LD_LIBRARY_PATH="${ENGN_HOME}/lib:${LD_LIBRARY_PATH}"
