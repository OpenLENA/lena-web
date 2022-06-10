#!/bin/bash

# set
INSTALL_FILE_PATH=`ls ${LAT_HOME}/*.tar.gz`

# install jdk
if `cat /etc/*-release | grep -q "Ubuntu"`; then
  apt-get update
  apt-get install -y openjdk-8-jdk
  JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
elif `cat /etc/*-release | grep -q "Amazon Linux 2"`; then
  yum update -y
  yum install -y tar procps hostname
  yum install -y java-1.8.0-openjdk-devel.x86_64
  JAVA_HOME=/usr/lib/jvm/java
else
  yum update -y
  yum install -y tar
  yum install -y java-1.8.0-openjdk-devel.x86_64
  JAVA_HOME=/usr/lib/jvm/java
fi

# Extract install file
tar -zxf ${INSTALL_FILE_PATH} -C ${LAT_HOME} --strip-components=1

# Clear install file
rm -rf ${INSTALL_FILE_PATH}

# Install apache
### create argument text file
INSTALL_ARG_FILE=${LAT_HOME}/arg.txt
echo ${JAVA_HOME} >> ${INSTALL_ARG_FILE}      # java home
echo ${SERVER_NAME} >> ${INSTALL_ARG_FILE}    # server name
echo ${SERVICE_PORT} >> ${INSTALL_ARG_FILE}   # service port
echo "" >> ${INSTALL_ARG_FILE}                # run user - use default, don't need to input
echo "" >> ${INSTALL_ARG_FILE}                # apache engine path - use default, don't need to input
echo "" >> ${INSTALL_ARG_FILE}                # install root path - use default, don't need to input
echo "" >> ${INSTALL_ARG_FILE}                # log home - use default, don't need to input
echo "" >> ${INSTALL_ARG_FILE}                # document root path - use default, don't need to input

### install
cat ${INSTALL_ARG_FILE}

echo ${LAT_HOME}
echo "COMMAND: create"
echo "SERVER_TYPE: apache"
/bin/bash ${LAT_HOME}/bin/latctl.sh create apache < ${INSTALL_ARG_FILE}

# create image build info
IMAGE_BUILD_INFO_FILE=${LAT_HOME}/etc/info/image-build.info
echo IMAGE BUILD TIME : `date` >> ${IMAGE_BUILD_INFO_FILE}
echo JAVA_HOME : ${JAVA_HOME} >> ${IMAGE_BUILD_INFO_FILE}
echo SERVER_NAME : ${SERVER_NAME} >> ${IMAGE_BUILD_INFO_FILE}
echo SERVICE_PORT : ${SERVICE_PORT} >> ${IMAGE_BUILD_INFO_FILE}
echo INSTALL_FILE_PATH : ${INSTALL_FILE_PATH} >> ${IMAGE_BUILD_INFO_FILE}