#!/bin/sh

# Copyright 2021 LENA Development Team.
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
# web-server clean script for build
# ---------------------------------------------------------------------------

############ Start of default variable definition ############
SCRIPTPATH=`cd $(dirname $0) ; pwd -P`
ROOT_PROJECT_PATH=`cd ${SCRIPTPATH}/../.. ; pwd -P`
PROJECT_NAME=`basename ${ROOT_PROJECT_PATH}`
############  End of default variable definition  ############


############ Start of setting default path ############
echo "${PROJECT_NAME} : setting default path..."

BUILD_TARGET=${1}
if [ -z "${BUILD_TARGET}" ]; then
	BUILD_TARGET="all"
fi
############  End of setting default path  ############


############ Start of loading common script ############
. ${ROOT_PROJECT_PATH}/web-compile/bin/web-common.sh ${ROOT_PROJECT_PATH}
############  End of loading common script  ############

############ Start of build process ############
echo "${PROJECT_NAME} : executing web-clean process..."
if [ ${BUILD_TARGET} = "all" ]; then
	for _build_target in ${BUILD_PROJECTS}; do
		echo "${PROJECT_NAME} : cleaning for ${_build_target}"
		rm -rf ${ROOT_PROJECT_PATH}/web-compile/${_build_target}/target/*
	done
	rm -rf ${ROOT_PROJECT_PATH}/target/*
else
	rm -rf ${ROOT_PROJECT_PATH}/web-compile/${BUILD_TARGET}/target/*
fi
############  End of build process  ############

echo "${PROJECT_NAME} : web-clean is completed..."
exit 0;
