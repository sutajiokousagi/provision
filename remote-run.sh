#!/bin/sh
#
# Deploy provisioning documents onto an unconfigured device.
# This actually turns it into a "provisioning bomb".

if [ $# -lt 1 ]
then
    echo "Usage: $0 [command]"
    exit 1
fi

curl --data-urlencode "cmd=NeCommand" --data-urlencode "data=<value>$*</value>" \
         http://192.168.100.1/bridge
