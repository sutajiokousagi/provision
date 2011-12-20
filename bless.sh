#!/bin/sh
#
# Deploy provisioning documents onto an unconfigured device.
# This actually turns it into a "provisioning bomb".

DEST=/tmp

# We must be connected to them via the NeTV access point.
function remote_send() {
    local FILENAME=$1
    local DESTINATION=$2
    curl --form filedata=@${FILENAME} \
         --form path=${DESTINATION} \
         --form cmd=uploadfile \
         http://192.168.100.1/bridge
}

function remote_run() {
    curl --data-urlencode "cmd=NeCommand" --data-urlencode "data=<value>$*</value>" \
         http://192.168.100.1/bridge
}

function die() {
    echo $1
    logger -t provision "$1"
    exit 1
}



# Copy required files
remote_send provisioning-server.sh /tmp/provisioning-server.sh
echo
remote_send provision.sh /tmp/provision.sh
echo
remote_send kousagi.ipk /tmp/package.ipk
echo
remote_send prepare-provision.sh /tmp/prepare-provision.sh
echo

# Copy optional files
# XXX

# Mark the prep script as executable and run it
remote_run /bin/chmod 775 /tmp/prepare-provision.sh
remote_run /tmp/prepare-provision.sh
