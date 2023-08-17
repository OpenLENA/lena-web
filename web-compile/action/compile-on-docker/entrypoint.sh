#!/bin/bash

# shell execute on
chmod -R 755 ./web-compile

# clean build result
./web-compile/bin/web-clean.sh

ls -al ./web-compile/bin/

# build apache httpd
if [ -z "${TARGET_OS##*ubuntu*}" ]; then
  echo ===ubuntu===
  ./web-compile/bin/web-build-ubuntu.sh
elif [ -z "${TARGET_OS##*alpine*}" ]; then
  echo ===alpine===
  sh ./web-compile/bin/web-build-alpine.sh
else
  echo ===other_os===
  ./web-compile/bin/web-build.sh
fi



