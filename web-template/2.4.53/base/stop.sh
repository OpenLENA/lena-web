#!/bin/sh

SCRIPTPATH=`cd $(dirname $0) ; pwd -P`

. ${SCRIPTPATH}/env.sh

${OPENLENA_HOME}/latctl.sh stop apache ${INSTANCE_ID}

