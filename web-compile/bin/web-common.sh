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
# OpenLENA build common script
# ---------------------------------------------------------------------------
SCRIPTPATH=`cd $(dirname $0) ; pwd -P`

ROOT_PROJECT_PATH=${1}
. ${ROOT_PROJECT_PATH}/web-compile/etc/info/web-server-compile.info

IS_DEBUG_ENABLED="false"

TRUE_VAL=0
FALSE_VAL=1
ABORT_VAL=2

_OS_NAME=`uname -s`

# print debug message
debug(){
	if [ "${IS_DEBUG_ENABLED}" = "true" ]; then
		echo "$*"
	fi
}

# print info message
info(){
	echo "$*"
}

info_emphasized ( ) {
    echo ""
    echo "-----------------------------------------------------------------"
    echo "- $*"
    echo "-----------------------------------------------------------------"
}

# exit with success code
end_success(){
	info "Execution is succeeded."
	exit ${TRUE_VAL}
}

# exit with fail code
end_fail(){
	info "Execution is failed."
	exit ${FALSE_VAL}
}

# exit with abort code
end_abort(){
	info "Execution is aborted."
	exit ${ABORT_VAL}
}

# if exit code is not 0, then exit with fail code.
check_exit_code(){
	local _exit_code=$1
	local _error_msg=$2
	
	if [ ${_exit_code} -ne ${TRUE_VAL} ]; then
		info ${_error_msg}
		end_fail
	fi
}

is_package_installed() {
	local _package_name=$1
	local _package_check_cmd="rpm -qa"
	if `cat /etc/*-release | grep -q "Ubuntu"`; then
    _package_check_cmd="dpkg -l"
  fi

	info Checking package : ${_package_name}
	if ! ${_package_check_cmd} | grep ${_package_name}; then
		return ${FALSE_VAL}
	else
		return ${TRUE_VAL}
	fi
}

is_default_package_installed() {
	local _web_server_type=$1
	local _check_packages=${DEFAULT_OS_PACKAGES_24}

	if `cat /etc/*-release | grep -q "Ubuntu"`; then
    _check_packages=${DEFAULT_OS_PACKAGES_24_UBUNTU}
  fi
	
	for _package_name in ${_check_packages}; do
		if ! is_package_installed ${_package_name}; then
			return ${FALSE_VAL}
		fi
	done
	
	return ${TRUE_VAL}
}

install_package() {
	local _package_name=$1
	local _runner=`whoami`

	if [ ! ${_runner} = root ]; then
		info "Package installation is failed. Execute package install script as root user."
		end_fail
	fi

	local _package_install_cmd="yum install -y"
	if `cat /etc/*-release | grep -q "Ubuntu"`; then
    _package_install_cmd="apt-get install -y"
  elif `cat /etc/*-release | grep -q "Alpine"`; then
    _package_install_cmd="apk add"
  fi

  ${_package_install_cmd} ${_package_name}

#	if ! is_package_installed ${_package_name} ; then
#		${_package_install_cmd} install -y ${_package_name}
#		check_exit_code $? "Package installation is failed. Please check the environment."
#	else
#		info "${_package_name} package is already installed."
#	fi

	return ${TRUE_VAL}
}

install_default_package() {
	local _web_server_type=$1
	local _check_packages

	if `cat /etc/*-release | grep -q "Ubuntu"`; then
    _check_packages=${DEFAULT_OS_PACKAGES_24_UBUNTU}
  elif `cat /etc/*-release | grep -q "Alpine"`; then
    _check_packages=${DEFAULT_OS_PACKAGES_24_ALPINE}
  else
    _check_packages=${DEFAULT_OS_PACKAGES_24}
	  local _redhat_version=`cat /etc/redhat-release |awk '{print $4}' | cut -b1`
    # if redhat8 need to enable powertools for install lua-devel....etc...
    if [ "${_redhat_version}" = "8" ]; then
      # Enable Power Tools Rocky-PowerTools.repo or CentOS-Linux-PowerTools.repo
      sed -i "s/enabled=0/enabled=1/g" /etc/yum.repos.d/*-PowerTools.repo
    fi
  fi
	
#	if is_default_package_installed ${_web_server_type}; then
#		return ${TRUE_VAL}
#	fi
	
	for _package_name in ${_check_packages}; do
		install_package ${_package_name}
	done
}

compile_apache_server() {
	local _source_path=$1
	local _target_path=$2

	info_emphasized "Compile ${_target_path} apache-server .."
	
	if [ ! -d ${_source_path} ]; then
		info_emphasized "apache-server source path is not valid."
		end_fail
	fi
	
	cd ${_source_path}
	
	./configure \
	  --prefix=${_target_path} \
	  --enable-modules=all \
	  --enable-mods-shared=most \
	  --with-mpm=worker \
	  --enable-proxy \
	  --enable-proxy-http \
	  --enable-proxy-connect \
	  --enable-cache \
	  --enable-mem-cache \
	  --enable-disk-cache \
	  --enable-deflate \
	  --enable-ssl \
	  --with-ssl=/usr/include/openssl
	  
	check_exit_code $?
	
	info_emphasized "make web-engine..."
	
	make clean
	check_exit_code $?
	
	make
	check_exit_code $?
	
	info_emphasized "make install web-engine..."
	make install
	check_exit_code $?
}

compile_tomcat_connectors() {
	local _source_path=$1
	local _target_path=$2
	info_emphasized "Compile ${_target_path} tomcat-connectors .."
	
	if [ ! -d ${_source_path} ]; then
		info_emphasized "tomcat-connectors source path is not valid."
		end_fail
	fi	
	
	cd ${_source_path}
	touch ./*
	
	./configure \
		--with-apxs=${_target_path}/bin/apxs

	info_emphasized "make tomcat-connectors..."
	make clean
	check_exit_code $?
	
	make
	check_exit_code $?
	info_emphasized "make install tomcat-connectors..."
	
	make install
	check_exit_code $?
}

compile_web_engine() {
	local _source_path=$1
	local _target_path=$2
	info_emphasized "Compile ${_target_path} web-engine .."
	
	if [ ! -d ${_source_path} ]; then
		info_emphasized "web-engine source path is not valid."
		end_fail
	fi
	
	cd ${_source_path}

    ./configure \
        --prefix=${_target_path} \
        --enable-modules=all \
        --enable-proxy \
        --enable-proxy-http \
        --enable-proxy-connect \
        --enable-cache \
        --enable-disk-cache \
        --enable-deflate \
        --enable-ssl \
        --enable-mpms-shared=all \
        --enable-nonportable-atomics=yes \
        --enable-lua \
        --enable-sed \
        --enable-usertrack \
        --enable-mods-shared=most \
        --with-ssl=/usr/include/openssl \
        --with-included-apr \
        --enable-shared \
        --enable-load-all-modules
	
	check_exit_code $?
	
	info_emphasized "make web-engine..."
	
	make clean
	check_exit_code $?
	
	make
	check_exit_code $?
	
	info_emphasized "make install web-engine..."
	make install
	check_exit_code $?
}

compile_web_connectors() {
	local _source_path=$1
	local _target_path=$2
	info_emphasized "Compile ${_target_path} web-connectors .."
	
	if [ ! -d ${_source_path} ]; then
		info_emphasized "web-connectors source path is not valid."
		end_fail
	fi	
	
	cd ${_source_path}
	touch ./*
	
	./configure \
		--with-apxs=${_target_path}/bin/apxs

	info_emphasized "make web-connectors..."
	make clean
	check_exit_code $?
	
	make
	local _exit_code=$?
	
	# try again
	if [ ${_exit_code} -ne ${TRUE_VAL} ]; then
		make
		check_exit_code $?
	fi
	
	info_emphasized "make install web-connectors..."
	
	make install
	check_exit_code $?
}

compile_web_vela_server() {
	local _source_path=$1
	local _target_path=$2
	
    info_emphasized "Compile ${_target_path} web-vela-server .."
    cd ${_source_path}
	
  ./configure \
    --prefix=${_target_path}

	info_emphasized "make web-vela-server..."
	sleep 3
	make clean
	check_exit_code $?
	
	make
	check_exit_code $?
	info_emphasized "make install web-vela-server..."
	sleep 3
	
	make install
	check_exit_code $?
}

compile_web_fox() {
	local _source_path=$1
	local _target_path=$2
	local _connector_source_path=$3
	
	info_emphasized "Compile ${_target_path} web-fox .."
	
	if [ ! -d ${_source_path} ]; then
		info_emphasized "web-fox source path is not valid."
		end_fail
	fi	
	
	cd ${_source_path}
	
	info_emphasized "compile web-fox..."
	${_target_path}/bin/apxs -i -DHAVE_APR -I ${_connector_source_path}/common -n fox -c ${_source_path}/mod_fox.c
	check_exit_code $?
}

compile_web_cmx() {
	local _source_path=$1
	local _target_path=$2
	local _connector_source_path=$3
	
	info_emphasized "Compile ${_target_path} web-cmx .."
	
	if [ ! -d ${_source_path} ]; then
		info_emphasized "web-cmx source path is not valid."
		end_fail
	fi	
	
	cd ${_source_path}
	
	info_emphasized "compile web-cmx..."
	${_target_path}/bin/apxs -i -DHAVE_APR -I ${_connector_source_path}/common -n cmx -c ${_source_path}/mod_cmx.c
	check_exit_code $?
}

compile_web_lsc() {
	local _source_path=$1
	local _target_path=$2
	
	info_emphasized "Compile ${_target_path} web-lsc .."
	
	if [ ! -d ${_source_path} ]; then
		info_emphasized "web-lsc source path is not valid."
		end_fail
	fi	
	
	cd ${_source_path}
	
	info_emphasized "compile web-lsc..."
	${_target_path}/bin/apxs -i -DHAVE_APR -n lsc -c ${_source_path}/mod_lsc.c
	check_exit_code $?
}

gen_web_engine_src() {
	local _project_src_path=${1}
	local _gen_target_path=${2}
	
	if [ ! -d ${_gen_target_path} ]; then
		mkdir -p ${_gen_target_path} ${_gen_target_path}/srclib/apr ${_gen_target_path}/srclib/apr-util 
	fi
	
	tar -zxf ${ROOT_PROJECT_PATH}/web-oss/httpd/${HTTPD_VERSION}/${HTTPD_FILE_NAME} --strip-components=1 -C ${_gen_target_path}
	tar -zxf ${ROOT_PROJECT_PATH}/web-oss/apr/${APR_VERSION}/${APR_FILE_NAME} --strip-components=1 -C ${_gen_target_path}/srclib/apr
	tar -zxf ${ROOT_PROJECT_PATH}/web-oss/apr-util/${APR_UTIL_VERSION}/${APR_UTIL_FILE_NAME} --strip-components=1 -C ${_gen_target_path}/srclib/apr-util
	
	#overwrite web-engine source
	#cp -rf ${_project_src_path}/* ${_gen_target_path}
}

gen_web_connectors_src() {
	local _project_src_path=${1}
	local _gen_target_path=${2}
	local _gen_tmp_path=${3}
	
	if [ ! -d ${_gen_target_path} ]; then
		mkdir -p ${_gen_target_path}
	fi
	
	if [ ! -d ${_gen_tmp_path} ]; then
		mkdir -p ${_gen_tmp_path}
	fi
	
	tar -zxf ${ROOT_PROJECT_PATH}/web-oss/tomcat-connectors/${TOMCAT_CONNECTORS_VERSION}/${TOMCAT_CONNECTORS_FILE_NAME} --strip-components=1 -C ${_gen_tmp_path}
	cp -rf ${_gen_tmp_path}/native/* ${_gen_target_path}
	rm -rf ${_gen_tmp_path}
	
	#overwrite web-connectors source
	cp -rf ${_project_src_path}/* ${_gen_target_path}
}

gen_web_vela_server_src() {
	local _project_src_path=${1}
	local _gen_target_path=${2}
	
	if [ ! -d ${_gen_target_path} ]; then
		mkdir -p ${_gen_target_path}
	fi
	
	tar -zxf ${ROOT_PROJECT_PATH}/web-oss/hpnssh/${HPNSSH_VERSION}/${HPNSSH_FILE_NAME} --strip-components=1 -C ${_gen_target_path}
	cp -rf ${_project_src_path}/* ${_gen_target_path}
}

gen_web_fox_src() {
	local _project_src_path=${1}
	local _gen_target_path=${2}
	
	if [ ! -d ${_gen_target_path} ]; then
		mkdir -p ${_gen_target_path}
	fi
	
	cp -rf ${_project_src_path}/* ${_gen_target_path}
}

gen_web_cmx_src() {
	local _project_src_path=${1}
	local _gen_target_path=${2}
	
	if [ ! -d ${_gen_target_path} ]; then
		mkdir -p ${_gen_target_path}
	fi
	
	cp -rf ${_project_src_path}/* ${_gen_target_path}
}

gen_web_lsc_src() {
	local _project_src_path=${1}
	local _gen_target_path=${2}
	
	if [ ! -d ${_gen_target_path} ]; then
		mkdir -p ${_gen_target_path}
	fi
	
	cp -rf ${_project_src_path}/* ${_gen_target_path}
}

setup_security() {
	local _target_path=$1
	info "clean not using directory ..."

	rm -rf $_target_path/conf $_target_path/cgi-bin $_target_path/manual
	rm -rf $_target_path/build $_target_path/man $_target_path/logs
	rm -rf $_target_path/htdocs $_target_path/include
}

load_environment_vairable_for_aix() {
	local _compiler=${1}
	
	if [ "${_compiler}" = "gcc" ]; then
		export CC="gcc"
		export CFLAGS="-maix64"
		export CXX="g++"
		export CXXFLAGS="-maix64"
		export LDFLAGS="-maix64 -L/opt/freeware/lib64 -L/opt/freeware/lib -L/usr/linux/lib64"
	fi
	
	if [ "${_compiler}" = "xlc" ]; then
		export CC="xlc_r -q64"
		export CFLAGS="-q64"
		export CXX="xlc_r"
		export CXXFLAGS="-q64"
		export LDFLAGS="-b64 -L/opt/freeware/lib64 -L/opt/freeware/lib -L/usr/linux/lib64"
	fi
	
	export AR="ar -X64"
	export OBJECT_MODE=64
	export PATH=/opt/freeware/bin:$PATH
	
	#export CONFIG_SHELL=/usr/bin/bash
	export PKGCONFIG=/opt/freeware/bin/pkg-config_64
	export PKG_CONFIG_PATH=/opt/freeware/lib64/pkgconfig:$PKG_CONFIG_PATH
}