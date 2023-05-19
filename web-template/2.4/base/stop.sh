#!/bin/sh

SCRIPTPATH=`cd $(dirname $0) ; pwd -P`

. ${SCRIPTPATH}/env.sh

${LAT_HOME}/management/latctl/bin/latctl.sh stop apache ${INSTANCE_ID}

