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
SCRIPT=$SCRIPTPATH/$(basename $0)

. ${SCRIPTPATH}/env.sh

echo "Start LA:T [web] ... ${SERVER_ID}"

RUNNER=`whoami`

COMMAND=${1}


# set command
case ${COMMAND} in
	staging)
		export SERVICE_PORT=${STAGING_SERVICE_PORT}
		export HTTPS_SERVICE_PORT=${STAGING_HTTPS_SERVICE_PORT}
	;;
	*)
		# do nothing
	;;
esac

if [ ${RUNNER} = ${RUN_USER} ] || [ ${RUNNER} = root ]; then
  LOG_DATE=`date +%Y%m%d`
  
  _log_dirs="access error jk"
  for _dir in `echo $_log_dirs`
  do
    if [ ! -d ${LOG_HOME}/${_dir} ]; then
      mkdir -p ${LOG_HOME}/${_dir}
      if [ $? -ne 0 ]; then
  	  echo >&2 "cannot create log directory '${LOG_HOME}/${_dir}'";
  	  echo >&2 "Startup failed."
  	  exit 1;
      fi
    fi
  done

  if [ 0 -ne `ls ${LOG_HOME} | grep "error_${INST_NAME}.*" | grep -v "${LOG_DATE}" | wc -l` ]; then
    cd ${LOG_HOME}
    for LOG_FILE in `ls error_${INST_NAME}*.log | grep -v "${LOG_DATE}"`
    do
      mv ${LOG_FILE} error/
    done
  fi
  
  if [ 0 -ne `ls ${LOG_HOME} | grep "access_${INST_NAME}.*" | grep -v "${LOG_DATE}" | wc -l` ]; then
    cd ${LOG_HOME}
    for LOG_FILE in `ls access_${INST_NAME}*.log | grep -v "${LOG_DATE}"`
    do
      mv ${LOG_FILE} access/
    done
  fi
  
  if [ 0 -ne `ls ${LOG_HOME} | grep "jk_${INST_NAME}.*" | grep -v "${LOG_DATE}" | wc -l` ]; then
    cd ${LOG_HOME}
    for LOG_FILE in `ls jk_${INST_NAME}*.log | grep -v "${LOG_DATE}"`
    do
      mv ${LOG_FILE} jk/
    done
  fi

  if [ "${_OS_NAME}" = "Linux" ] && [ ! -r /lib64/libpcre.so.0 ] && [ ! -r ${ENGN_HOME}/lib/libpcre.so.0 ]; then
    ln -s /lib64/libpcre.so.1 ${ENGN_HOME}/lib/libpcre.so.0
     echo "libpcre.so.0 link generated."
  fi

  
  if [ "${COMMAND}" = "foreground" ]; then
	  ${ENGN_HOME}/bin/apachectl -f ${INSTALL_PATH}/conf/httpd.conf -k start -D${MPM_TYPE} ${EXT_MODULE_DEFINES} -DFOREGROUND
  else
	  ${ENGN_HOME}/bin/apachectl -f ${INSTALL_PATH}/conf/httpd.conf -k start -D${MPM_TYPE} ${EXT_MODULE_DEFINES}
  fi
  
else
   >&2 echo "Deny Access : [ ${RUNNER} ]. Not ${RUN_USER}" ;
   exit 1 ;
fi
