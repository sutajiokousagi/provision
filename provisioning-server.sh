#!/bin/sh
#
# Creates a "provisioning bomb".  Will attempt to continuously connect
# to an unprovisioned device in AP mode and blast a configuration file
# to it, then wait for it to reboot.
#
# This assumes the provisioning ipk has already been decrypted (if necessary).

IPK=package.ipk
URL=package.url
PROV=provision.sh
SRC=/psp/provisioning
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

function exit_on_string() {
    TXT=
    while ! echo ${TXT} | grep -q $1
    do
        read TXT
        echo "Line: ${TXT}"
    done
    killall dbus-monitor
    exit 0
}

function wait_for_wifi_disconnect() {
    dbus-monitor --system interface=fi.epitest.hostap.WPASupplicant.Interface,member=StateChange | exit_on_string '"DISCONNECTED"'
}

function complete_provision() {
    TOTAL=0
    GRAND_TOTAL=0
    STATUS=$1
    if [ -e /psp/provisioning/grand-total ]
    then
        GRAND_TOTAL=$(($(cat /psp/provisioning/grand-total)+1))
    fi
    if [ -e /psp/provisioning/total ]
    then
        TOTAL=$(($(cat /psp/provisioning/total)+1))
    fi
    echo ${TOTAL} > /psp/provisioning/total
    echo ${GRAND_TOTAL} > /psp/provisioning/grand-total
}

function regen_provisioning_page() {
    TOTAL=0
    GRAND_TOTAL=0
    STATUS=$1
    if [ -e /psp/provisioning/grand-total ]
    then
        GRAND_TOTAL=$(cat /psp/provisioning/grand-total)
    fi
    if [ -e /psp/provisioning/total ]
    then
        TOTAL=$(cat /psp/provisioning/total)
    fi

    echo "<html><head><script>fCheckAlive() { return true; } </script><meta http-equiv='refresh' content='5'></head><body bgcolor='yellow'><table style='background:purple; width:1280px; height:720px;'><tr><td style='vertical-align:middle; font: 36pt sans-serif; text-align: center;'><div>Status: ${STATUS}</div><div>Completed: ${GRAND_TOTAL}</div><div>Completed since boot: ${TOTAL}</div></td></tr></table></body></html>" > /psp/provisioning/index.html.tmp

    mv -f /psp/provisioning/index.html.tmp /psp/provisioning/index.html
}

 

function main_loop() {
    local SRC="$1"
    local IPK="$2"
    local PROV="$3"
    local DEST="$4"
    local SHA="$5"
    local URL="$6"

    regen_provisioning_page "Idle"

    while true
    do

        # Ensure NetworkManager is running
        killall hostapd dnsmasq 2> /dev/null
        /etc/init.d/NetworkManager start 2> /dev/null

        # See if we can connect to a device.
        if ! start_network; then
            # No device found.  Try again in 5 seconds.
            sleep 5
            continue
        fi

        regen_provisioning_page "Provisioning..."

        # Upload the provision script and package file to remote device
        remote_send ${SRC}/${IPK} ${DEST}/provision.ipk
        remote_send ${SRC}/${PROV} ${DEST}/provision.sh

        # Execute provision.sh to install the package.
        # This script reboots at the end.
        remote_run /bin/chmod 755 ${DEST}/provision.sh
        remote_run ${DEST}/provision.sh ${DEST}/provision.ipk "${SHA}" "${URL}"

        # Wait for provision to complete, which will be indicated by
        # the access point going away.
        wait_for_wifi_disconnect

        # Let the UI know that we've provisioned another
        complete_provision
        regen_provisioning_page "Idle"
    done
}


if [ ! -e "${SRC}/${IPK}" ]
then
    die "Unable to find package file ${SRC}/${IPK}"
fi

if [ ! -e "${SRC}/${PROV}" ]
then
    die "Unable to find provision script ${SRC}/${PROV}"
fi


SHA="$(sha256sum "${SRC}/${IPK}" | cut -d' ' -f1)"
if [ -e ${URL} ]
then
    URL=$(cat ${URL})
else
    URL=
fi


echo "<configuration type='wlan' ssid='NeTV' allocation='dhcp' auth='OPEN' encryption='NONE'/>" > /psp/network_config

echo 0 > ${SRC}/total
main_loop "${SRC}" "${IPK}" "${PROV}" "${DEST}" "${SHA}" "${URL}" &
