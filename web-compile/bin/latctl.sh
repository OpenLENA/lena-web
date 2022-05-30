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

#!/bin/sh

echo "*******************************"
echo "*  LA:T Server Management !      *"
echo "*******************************"

RUNDIR=$(dirname "$0")
LAT_HOME=$(
  cd "$RUNDIR/.."
  pwd -P
)
RUN_USER=$(whoami)
HOSTNAME=$(hostname)
COMMAND="$1"
SERVER_TYPE="$2"
IS_DEBUG_ENABLED="false"
LAT_LOG_HOME=${LAT_HOME}/logs
LOG_HOME=${LAT_LOG_HOME}/lat-installer

debug() {
  if [ "${IS_DEBUG_ENABLED}" = "true" ]; then
    echo "$*"
  fi
}

info() {
  echo "$*"
}

end_success() {
  info "Execution is completed.!!"
  exit 0
}

end_fail() {
  info "Execution is failed.!!"
  exit 1
}

end_abort() {
  info "Execution is aborted.!!"
  exit 2
}

check_process() {
  if [ "$(uname -s)" = "HP-UX" ]; then
    local is_alive=$(ps -efx | grep "lat.home=${LAT_HOME}" | grep "argo.install" | wc -l)
  else
    local is_alive=$(ps -ef | grep "lat.home=${LAT_HOME}" | grep "argo.install" | wc -l)
  fi

  if [ ${is_alive} -ne 0 ]; then
    info "Another install process is already running."
    end_fail
  fi
}

is_valid_javahome() {
  local _javahome=$1

  if [ -z "${_javahome}" ]; then
    return 1
  fi

  if [ ! -r "${_javahome}/bin/java" ]; then
    return 1
  fi

  if [ ! -r "${_javahome}/lib/tools.jar" ]; then
    if [ ! -r "${_javahome}/lib/jrt-fs.jar" ]; then
      return 1
    fi
  fi

  return 0
}

save_javahome_info() {
  local _javahome=$1
  if is_valid_javahome ${_javahome}; then
    echo ${_javahome} >${LAT_HOME}/etc/info/java-home.info
  else
    echo "JAVA_HOME is invalid. Please check if jdk is installed."
    end_fail
  fi
}

check_javahome() {
  if [ -r "${LAT_HOME}/etc/info/java-home.info" ]; then
    info_java_path=$(cat "${LAT_HOME}/etc/info/java-home.info")
    if is_valid_javahome ${info_java_path}; then
      export JAVA_HOME=${info_java_path}
      return
    else
      echo "JAVA_HOME is invalid. Please check if jdk is installed."
    fi
  fi

  while true; do
    echo "Input JAVA_HOME path for LA:T. ( q: quit )"
    echo "JAVA_HOME PATH : "
    read input_java_path
    if [ "${input_java_path}" = "q" -o "${input_java_path}" = "Q" ]; then
      end_abort
    fi
    if is_valid_javahome ${input_java_path}; then
      echo "JAVA_HOME is valid."
      export JAVA_HOME=${input_java_path}
      echo "${input_java_path}" >> ${LAT_HOME}/etc/info/java-home.info
      return
    else
      echo "JAVA_HOME is invalid. Please check if jdk is installed."
    fi
  done
}

RESULT_FORMAT=text
#check arguments
for current_argument in $@; do
  if is_valid_javahome ${current_argument}; then
    save_javahome_info ${current_argument}
  elif [ "${current_argument}" = "--json" ]; then
    RESULT_FORMAT=json
  else
    ARGUMENTS="$ARGUMENTS $current_argument"
  fi
done

#check javahome path
check_javahome

# set installer lib path
INSTALLER_LIB_PATH=${LAT_HOME}/modules/lat-ctl/lib
list=$(ls ${INSTALLER_LIB_PATH}/*.jar)
for i in $(echo $list); do
  INSTALLER_LIB_PATH=$INSTALLER_LIB_PATH:$i
done

debug "RUNDIR : ${RUNDIR}"
debug "LAT_HOME : ${LAT_HOME}"
debug "COMMAND : ${COMMAND}"
debug "SERVER_TYPE : ${SERVER_TYPE}"
debug "JAVA_HOME : ${JAVA_HOME}"
debug "INSTALLER_LIB_PATH : ${INSTALLER_LIB_PATH}"
debug "ARGUMENTS : ${ARGUMENTS}"

_CLASSPATH="-cp ${INSTALLER_LIB_PATH}"
_JAVA_OPTS="-Duser_java.home=${JAVA_HOME} -Dlat.home=${LAT_HOME} -Dhostname=${HOSTNAME} -Drun_user=${RUN_USER} -Dis_debug_enabled=${IS_DEBUG_ENABLED} -Dlog.home=${LOG_HOME} -Dresult.format=${RESULT_FORMAT}"

case ${COMMAND} in
compile)
  if [ "${SERVER_TYPE}" = "apache-server" ] || [ "${SERVER_TYPE}" = "lat-web" ]; then
    ${LAT_HOME}/bin/web-compile.sh ${ARGUMENTS}
  else
    ${JAVA_HOME}/bin/java ${_CLASSPATH} ${_JAVA_OPTS} "argo.install.Main"
    end_fail
  fi
  ;;
modify)
  debug ${JAVA_HOME}/bin/java ${_CLASSPATH} ${_JAVA_OPTS} "argo.install.Modify" ${ARGUMENTS}
  check_process
  ${JAVA_HOME}/bin/java ${_CLASSPATH} ${_JAVA_OPTS} "argo.install.Modify" ${ARGUMENTS}
  ;;
*)
  debug ${JAVA_HOME}/bin/java ${_CLASSPATH} ${_JAVA_OPTS} "io.lat.ctl.Main" ${ARGUMENTS}
  check_process
  ${JAVA_HOME}/bin/java ${_CLASSPATH} ${_JAVA_OPTS} "io.lat.ctl.Main" ${ARGUMENTS}
  ;;
esac

EXIT_CODE=$?
if [ ${EXIT_CODE} -eq 0 ]; then
  end_success
elif [ ${EXIT_CODE} -eq 2 ]; then
  end_abort
else
  end_fail
fi

exit 0
