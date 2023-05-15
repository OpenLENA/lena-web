#!/bin/sh

SCRIPTPATH=`cd $(dirname $0) ; pwd -P`

. ${SCRIPTPATH}/env.sh

${LAT_HOME}/management/*RELEASE/bin/latctl.sh start apache ${INSTANCE_ID}

