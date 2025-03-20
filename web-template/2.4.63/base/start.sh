#!/bin/sh

SCRIPTPATH=`cd $(dirname $0) ; pwd -P`

. ${SCRIPTPATH}/env.sh

${OPENLENA_HOME}/latctl.sh start apache ${INSTANCE_ID}

