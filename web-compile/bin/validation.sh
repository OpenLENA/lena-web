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

ENGN_NAME=Apache
ENGN_VERSION=2.4.53
RUN_USER=$(whoami)


info() {
  echo "$*"
}

end_success() {
  info "Validation Pass.!! [${ENGN_NAME}-${ENGN_VERSION}]"
  exit 0
}

end_fail() {
  info "Validation failed.!! [${ENGN_NAME}-${ENGN_VERSION}]"
  exit 1
}

end_success



