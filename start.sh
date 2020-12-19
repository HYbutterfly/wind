#!/bin/bash

pid=$(ps -ef | grep wind_conf |grep skynet |cut -c10-16);

if [[ $pid != "" ]]; then
   	kill -2 $pid
	while kill -0 "$pid" 2>/dev/null; do
	    sleep 0.1
	done
else
    echo "no wind skynet process" 
fi;

# start
export ROOT=$(cd `dirname $0`;pwd)

export DAEMON=false

echo $ROOT

cd `dirname $0`
./skynet/skynet wind_conf