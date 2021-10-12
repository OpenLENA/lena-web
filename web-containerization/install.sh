#!/bin/bash

# set
INSTALL_FILE_PATH=`ls ${LENA_HOME}/*.tar.gz`

# install jdk
yum install -y java-1.8.0-openjdk-devel.x86_64

# Extract install file
tar -zxvf ${INSTALL_FILE_PATH} -C ${LENA_HOME} --strip-components=1

# Clear install file
rm -rf ${INSTALL_FILE_PATH}

# Install lena-web
### create argument text file
INSTALL_ARG_FILE=${LENA_HOME}/arg.txt
echo ${JAVA_HOME} >> ${INSTALL_ARG_FILE} # java home
echo ${SERVER_NAME} >> ${INSTALL_ARG_FILE} # server name
echo ${SERVICE_PORT} >> ${INSTALL_ARG_FILE} # service port
echo "" >> ${INSTALL_ARG_FILE} # run user - use default, don't need to input
echo "" >> ${INSTALL_ARG_FILE} # apache engine path - use default, don't need to input
echo "" >> ${INSTALL_ARG_FILE} # install root path - use default, don't need to input
echo "" >> ${INSTALL_ARG_FILE} # log home - use default, don't need to input
echo "" >> ${INSTALL_ARG_FILE} # document root path - use default, don't need to input

### install
/bin/bash ${LENA_HOME}/bin/lenactl.sh create lena-web < ${INSTALL_ARG_FILE}

# create image build info
IMAGE_BUILD_INFO_FILE=${LENA_HOME}/etc/info/image-build.info
echo IMAGE BUILD TIME : `date` >> ${IMAGE_BUILD_INFO_FILE}
echo JAVA_HOME : ${JAVA_HOME} >> ${IMAGE_BUILD_INFO_FILE}
echo SERVER_NAME : ${SERVER_NAME} >> ${IMAGE_BUILD_INFO_FILE}
echo SERVICE_PORT : ${SERVICE_PORT} >> ${IMAGE_BUILD_INFO_FILE}
echo INSTALL_FILE_PATH : ${INSTALL_FILE_PATH} >> ${IMAGE_BUILD_INFO_FILE}