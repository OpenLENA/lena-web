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

PROJECT_TARGET_PATH=${PROJECT_PATH}/target
############  End of setting default path  ############

DIST_TARGET_PATH=${PROJECT_TARGET_PATH}/${WEB_SERVER_NAME}
DIST_TARGET_DEPOT_PATH=${DIST_TARGET_PATH}/depot/${WEB_SERVER_DEPOT_NAME}/${WEB_SERVER_VERSION}
DIST_TOMCAT_CONNECTORS_DEPOT_PATH=${DIST_TARGET_PATH}/depot/${TOMCAT_CONNECTORS_DEPOT_NAME}/${TOMCAT_CONNECTORS_VERSION}

############ Start of generating web-server depot files ############
info_emphasized "${PROJECT_NAME} : generating dist files..."

gen_web_engine_src ${ROOT_PROJECT_PATH}/web-core/web-engine/src ${DIST_TARGET_DEPOT_PATH}/module/web-engine/src
gen_web_connectors_src ${ROOT_PROJECT_PATH}/web-core/web-connectors/src ${DIST_TARGET_DEPOT_PATH}/module/web-connectors/src ${PROJECT_PATH}/target/tmp

############  End of generating web-server depot files  ############

############ Start of generating web-server other files ############
if [ ! -d ${DIST_TARGET_PATH}/bin ]; then
	mkdir -p ${DIST_TARGET_PATH}/bin
fi

if [ ! -d ${DIST_TARGET_PATH}/etc ]; then
	mkdir -p ${DIST_TARGET_PATH}/etc
fi

if [ ! -d ${DIST_TARGET_DEPOT_PATH}/template ]; then
	mkdir -p ${DIST_TARGET_DEPOT_PATH}/template
fi
cp -rf ${ROOT_PROJECT_PATH}/web-compile/bin/latctl.sh ${DIST_TARGET_PATH}/bin
cp -rf ${ROOT_PROJECT_PATH}/web-compile/bin/web-common.sh ${DIST_TARGET_PATH}/bin
cp -rf ${ROOT_PROJECT_PATH}/web-compile/bin/web-compile.sh ${DIST_TARGET_PATH}/bin
cp -rf ${ROOT_PROJECT_PATH}/web-compile/bin/web-package-install.sh ${DIST_TARGET_PATH}/bin
cp -rf ${ROOT_PROJECT_PATH}/web-compile/etc/* ${DIST_TARGET_PATH}/etc

cp -rf ${ROOT_PROJECT_PATH}/web-template/${TEMPLATE_NAME} ${DIST_TARGET_DEPOT_PATH}/template/
chmod -R 755 ${DIST_TARGET_PATH}

cd ${DIST_TARGET_PATH}/..
find ${DIST_TARGET_PATH} -name "\.ptp-sync-folder" | xargs rm
tar -zcf ${WEB_SERVER_NAME}-${WEB_SERVER_VERSION}.tar.gz `basename ${DIST_TARGET_PATH}`
jar -cf ${WEB_SERVER_NAME}-${WEB_SERVER_VERSION}.zip `basename ${DIST_TARGET_PATH}`


if [ -d ${WEB_ENGINE_TARGET_PATH} ]; then
	cd ${WEB_ENGINE_TARGET_PATH}/..
	find ${WEB_ENGINE_TARGET_PATH} -name "\.ptp-sync-folder" | xargs rm
	tar -zcf ${PROJECT_TARGET_PATH}/${WEB_SERVER_NAME}-${WEB_SERVER_VERSION}-x86_64-linux.tar.gz `basename ${WEB_ENGINE_TARGET_PATH}`
fi
############  End of generating web-server other files  ############


############# Start of generating rpm files ############
#AIX_RPMFILES_DIR_NAME=${PROJECT_TARGET_PATH}/${WEB_SERVER_DEPOT_NAME}-rpm-aix6.1
#
#if [ ! -d ${AIX_RPMFILES_DIR_NAME} ]; then
#	mkdir -p ${AIX_RPMFILES_DIR_NAME}
#fi
##cp -rf ${ROOT_PROJECT_PATH}/web-rpm/aix6.1/* ${AIX_RPMFILES_DIR_NAME}
#find ${AIX_RPMFILES_DIR_NAME} -name "\.ptp-sync-folder" | xargs rm
#cd ${AIX_RPMFILES_DIR_NAME}/..
#tar -zcf  ${AIX_RPMFILES_DIR_NAME}.tar.gz `basename ${AIX_RPMFILES_DIR_NAME}`
#############  End of generating rpm files  ############


info_emphasized "${PROJECT_NAME} : build is completed..."
exit 0;
