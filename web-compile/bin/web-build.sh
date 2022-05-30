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

# ---------------------------------------------------------------------------
# web-server compile script for build
# ---------------------------------------------------------------------------

############ Start of default variable definition ############
SCRIPTPATH=`cd $(dirname $0) ; pwd -P`
ROOT_PROJECT_PATH=`cd ${SCRIPTPATH}/../.. ; pwd -P`
PROJECT_NAME=`basename ${ROOT_PROJECT_PATH}`
############  End of default variable definition  ############


############ Start of chmod 755 ############
if [ -z "${1}" ]; then
	chmod -R 755 ${ROOT_PROJECT_PATH}
fi
############  End of chmod 755  ############

############ Start of loading common script ############
. ${ROOT_PROJECT_PATH}/web-compile/bin/web-common.sh ${ROOT_PROJECT_PATH}
############  End of loading common script  ############

############ Start of setting default path ############
info_emphasized "${PROJECT_NAME} : setting default path..."

BUILD_TARGET=${1}
if [ -z "${BUILD_TARGET}" ]; then
	BUILD_TARGET="all"
fi

############  End of setting default path  ############

WEB_ENGINE_TARGET_PATH=${ROOT_PROJECT_PATH}/target/${WEB_SERVER_NAME}
CONNECTORS_SRC_PATH=${ROOT_PROJECT_PATH}/web-compile/web-connectors/target/work-src

############ Start of build process ############
info_emphasized "${PROJECT_NAME} : executing web-build process..."
if [ "${_OS_NAME}" = "AIX" ]; then
	load_environment_vairable_for_aix xlc
fi

if [ ${BUILD_TARGET} = "all" ]; then
	
	if [ "${_OS_NAME}" = "Linux" ]; then
		install_default_package
	fi
	for _build_target in ${BUILD_PROJECTS}; do
		${ROOT_PROJECT_PATH}/web-compile/${_build_target}/build.sh ${WEB_ENGINE_TARGET_PATH} ${CONNECTORS_SRC_PATH}
		check_exit_code $?
	done
	
	info_emphasized "${PROJECT_NAME} : copying template..."
	TEMPLATE_PATH=${ROOT_PROJECT_PATH}/web-template/${TEMPLATE_NAME}
	
	TARGET_SERVER_PATH=${WEB_ENGINE_TARGET_PATH}/servers/test_web
	
	if [ ! -d ${TARGET_SERVER_PATH} ]; then
	    mkdir -p ${TARGET_SERVER_PATH}
	    cp -Rf ${TEMPLATE_PATH}/* ${TARGET_SERVER_PATH}
	fi
else
	${ROOT_PROJECT_PATH}/web-core/${BUILD_TARGET}/build.sh ${WEB_ENGINE_TARGET_PATH} ${CONNECTORS_SRC_PATH}
fi
############  End of build process  ############

info_emphasized "${PROJECT_NAME} : web-build is completed..."
exit 0;
