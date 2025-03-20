#!/bin/sh

# Copyright 2022 OpenLENA Development Team.
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

# ---------------------------------------------------------------------------
# web-server compile script
# ---------------------------------------------------------------------------

SCRIPTPATH=`cd $(dirname $0) ; pwd -P`
OPENLENA_HOME=`cd ${SCRIPTPATH}/.. ; pwd -P`

. ${OPENLENA_HOME}/bin/web-common.sh ${OPENLENA_HOME}

setup_environment() {
	WEB_ENGINE_TARGET_PATH=${OPENLENA_HOME}/modules/${WEB_SERVER_DEPOT_NAME}
	
	if [ -r "${OPENLENA_HOME}/etc/info/web-server-engine-path.info" ]; then
		WEB_ENGINE_TARGET_PATH=`cat ${OPENLENA_HOME}/etc/info/web-server-engine-path.info`
		info "web-server engine is already compiled!!"
		end_fail
	else
		info "Input Web Server engine install path. ( q: quit )"
		info "Default install path : $WEB_ENGINE_TARGET_PATH "
		read input_web_server_engine_path
		if [ "$input_web_server_engine_path" = "q" -o "$input_web_server_engine_path" = "Q" ] ; then
			end_abort
		fi
		if [ "$input_web_server_engine_path" != "" ] ; then
			WEB_ENGINE_TARGET_PATH=$input_web_server_engine_path
		fi
	fi
}

compile_lat_web_server_all() {
	if [ "${_OS_NAME}" = "AIX" ]; then
		load_environment_vairable_for_aix xlc
		compile_web_engine ${WEB_SERVER_DEPOT_PATH}/module/web-engine/src ${WEB_ENGINE_TARGET_PATH}
		check_exit_code $?
		
		compile_web_connectors ${WEB_SERVER_DEPOT_PATH}/module/web-connectors/src ${WEB_ENGINE_TARGET_PATH}
		check_exit_code $?
		
		#setup_security ${WEB_ENGINE_TARGET_PATH}
		#check_exit_code $?
	else
		install_default_package ${SERVER_TYPE}
		
		compile_web_engine ${WEB_SERVER_DEPOT_PATH}/module/web-engine/src ${WEB_ENGINE_TARGET_PATH}
		check_exit_code $?
		
		compile_web_connectors ${WEB_SERVER_DEPOT_PATH}/module/web-connectors/src ${WEB_ENGINE_TARGET_PATH}
		check_exit_code $?
		
		#setup_security ${WEB_ENGINE_TARGET_PATH}
		#check_exit_code $?
	fi
	
	if [ -f "${OPENLENA_HOME}/modules/openLena-web-pe/modules/mod_cmx.so" ]; then
		cp -f ${OPENLENA_HOME}/modules/openLena-web-pe/modules/mod_cmx.so ${WEB_ENGINE_TARGET_PATH}/modules
	fi
}

compile_apache_web_server_all() {
	install_default_package ${SERVER_TYPE}

	compile_apache_server ${WEB_SERVER_DEPOT_PATH}/module ${WEB_ENGINE_TARGET_PATH}
	check_exit_code $?
	
	compile_tomcat_connectors ${CONNECTOR_DEPOT_PATH}/module/src ${WEB_ENGINE_TARGET_PATH}
	check_exit_code $?
}


COMMAND=${1}
SERVER_TYPE=${2}
WEB_ENGINE_TARGET_PATH=${3}
if [ -z "${COMMAND}" ]; then
	COMMAND="compile"
fi

if [ -z "${SERVER_TYPE}" ]; then
	SERVER_TYPE="apache"
fi
setup_environment

WEB_SERVER_DEPOT_PATH=${OPENLENA_HOME}/depot/${WEB_SERVER_DEPOT_NAME}/${WEB_SERVER_VERSION}
chmod -R 755 ${WEB_SERVER_DEPOT_PATH}
compile_lat_web_server_all


echo ${WEB_ENGINE_TARGET_PATH} > ${OPENLENA_HOME}/etc/info/web-server-engine-path.info

info_emphasized "Compile is completed."
exit 0;
