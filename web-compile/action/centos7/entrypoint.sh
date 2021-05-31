#!/bin/bash

echo "file list"

# shell execute on
chmod -R 755 ./web-compile

# clean build result
./web-compile/bin/web-clean.sh

# build apache httpd
./web-compile/bin/web-build.sh

echo "action test"