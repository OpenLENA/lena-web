#!/bin/bash

echo "file list"

# shell execute on
chmod -R 755 ./web-compile

# clean build result
cd ./web-compile/bin
./web-clean.sh

# build apache httpd
./web-build-ubuntu.sh

echo "action test"