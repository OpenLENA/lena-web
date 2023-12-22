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
LAT_MANAGEMENT_HOME=$(
  cd "$RUNDIR/../../../../management/latctl"
  pwd -P
)
LAT_HOME=$(
  cd "$RUNDIR/../../../.."
  pwd -P
)
LAT_ENGINE_HOME=$(
  cd "$RUNDIR/../../.."
  pwd -P
)

ENGN_NAME=Apache
ENGN_VERSION=2.4.53
RUN_USER=$(whoami)
INSTANCE_TYPE="$1"
INSTANCE_NAME="$2"
INSTANCE_PATH="${LAT_HOME}/instances/${INSTANCE_TYPE}/${INSTANCE_NAME}"
LOG_LEVEL=info
LOG_DATE=`date +%Y%m%d`
IS_DEBUG_ENABLED="false"

debug() {
  if [ "${IS_DEBUG_ENABLED}" = "true" ]; then
    echo "$*"
    echo "| Instance Path : [$INSTANCE_PATH]"
  fi
}

info() {
  echo "| $*"
}

error() {
  echo "| $*" 1>&2
}

end_success() {
  info "[${ENGN_NAME}-${ENGN_VERSION}] Validation Pass.!!"
  exit 0
}

end_fail() {
  error "[${ENGN_NAME}-${ENGN_VERSION}] Validation failed.!! "
  exit 1

}

end_success
#end_fail



