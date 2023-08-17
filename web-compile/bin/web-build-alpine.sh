#!/bin/bash
SCRIPTPATH=`cd $(dirname $0) ; pwd -P`

if [ ! -f /usr/include/sys/socketvar.h ]; then
  mkdir -p /usr/include/sys
  echo "#include <sys/socket.h>" > /usr/include/sys/socketvar.h
fi

cat /usr/include/sys/socketvar.h

${SCRIPTPATH}/web-build.sh
