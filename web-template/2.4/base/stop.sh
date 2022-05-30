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

RUNNER=`whoami`

COMMAND=${1}

ps_check(){
	if [ "`uname -s`" = "HP-UX" ]; then
		ps -efx | grep ${ENGN_HOME}/bin/httpd|grep ${INSTALL_PATH}/conf/httpd.conf | wc -l
	else
		ps -ef | grep ${ENGN_HOME}/bin/httpd|grep ${INSTALL_PATH}/conf/httpd.conf | wc -l
	fi
}

[ `ps_check` -eq 0 ] && echo "##### ${SERVER_ID} is not running. There is nothing to stop.#######" && exit 1

echo "Stop LA:T [web] ... ${SERVER_ID}"

# set command
case ${COMMAND} in
	graceful)
		COMMAND=graceful-stop
	;;
	force)
		COMMAND=kill
	;;
	*)
		COMMAND=stop
		# check graceful option from env.sh
		if [ "$SHUTDOWN_GRACEFUL" = "true" ]; then
			COMMAND=graceful-stop
		fi
	;;
esac



if [ ${RUNNER} = ${RUN_USER} ] || [ ${RUNNER} = root ]; then
  # Stop Apache
  if [ "${COMMAND}" = "kill" ]; then
  	$SCRIPTPATH/kill.sh
  else
  	${ENGN_HOME}/bin/apachectl -f ${INSTALL_PATH}/conf/httpd.conf -k ${COMMAND} -D${MPM_TYPE} ${EXT_MODULE_DEFINES}
  fi
else
   echo "Deny Access : [ ${RUNNER} ]. Not ${RUN_USER}" ;
   exit 1 ;
fi