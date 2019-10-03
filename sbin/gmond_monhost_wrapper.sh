#!/bin/bash

SOURCEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SOURCEDIR/../lib64

exec $SOURCEDIR/gmond --conf=${SOURCEDIR}/../etc/gmond_monhost.conf $@
