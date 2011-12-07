#!/bin/sh
#
# Deploy provisioning documents onto an unconfigured device.
# This actually turns it into a "provisioning bomb".

# We must be connected to them via the NeTV access point.
FILENAME=$1
DESTINATION=$2

if [ -z ${FILENAME} ] || [ -z ${DESTINATION} ]
then
    echo "Usage: $0 [filename] [destination-directory]"
    exit 1
fi

curl --form filedata=@${FILENAME} \
     --form path=${DESTINATION} \
     --form cmd=uploadfile \
     http://192.168.100.1/bridge
