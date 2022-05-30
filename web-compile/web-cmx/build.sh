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

############ Start of default variable definition ############
SCRIPTPATH=`cd $(dirname $0) ; pwd -P`
ROOT_PROJECT_PATH=`cd ${SCRIPTPATH}/../.. ; pwd -P`
PROJECT_NAME=`basename ${SCRIPTPATH}`
PROJECT_PATH=${SCRIPTPATH}
############  End of default variable definition  ############

############ Start of loading common script ############
. ${ROOT_PROJECT_PATH}/web-compile/bin/web-common.sh ${ROOT_PROJECT_PATH}
############  End of loading common script  ############

############ Start of setting default path ############
info_emphasized "${PROJECT_NAME} : setting default path..."
WEB_ENGINE_TARGET_PATH=${1}
if [ -z "${WEB_ENGINE_TARGET_PATH}" ]; then
	info_emphasized "WEB_ENGINE_TARGET_PATH is not valid."
	end_fail
fi

CONNECTOR_SRC_PATH=${2}
if [ -z "${CONNECTOR_SRC_PATH}" ]; then
	info_emphasized "CONNECTOR_SRC_PATH is not valid."
	end_fail
fi

PROJECT_SRC_PATH=${ROOT_PROJECT_PATH}/web-core/${PROJECT_NAME}/src
PROJECT_TARGET_PATH=${PROJECT_PATH}/target
PROJECT_WORK_SRC_PATH=${PROJECT_TARGET_PATH}/work-src
############  End of setting default path  ############

############ Start of generating src files ############
info_emphasized "${PROJECT_NAME} : generating src files..."
gen_web_cmx_src ${PROJECT_SRC_PATH} ${PROJECT_WORK_SRC_PATH}
############  End of generating src files  ############


############ Start of compile ############
info_emphasized "${PROJECT_NAME} : compile..."
compile_web_cmx ${PROJECT_WORK_SRC_PATH} ${WEB_ENGINE_TARGET_PATH} ${CONNECTOR_SRC_PATH}
check_exit_code $?
############  End of compile  ############

cp -rf ${WEB_ENGINE_TARGET_PATH}/modules/mod_cmx.so ${PROJECT_PATH}/mod

info_emphasized "${PROJECT_NAME} : build is completed..."
exit 0;
