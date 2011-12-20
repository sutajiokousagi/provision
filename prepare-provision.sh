#!/bin/sh
#
# This file gets uploaded to an unconfigured device.  It performs the
# following steps, then removes itself:
#   - Decrypts the ipk (if necessary)
#   - Verifies the SHA256 sum
#   - Copes the ipk to /psp/provisioning/
#   - Copies the provision script to /psp/provisioning/
#   - Copes the driver script to /psp/provisioning/
#   - Deploys a new index file under /psp/provisioning/
#   - Writes the new docroot path to /psp/homepage
#   - Writes the status as "Initializing" to /psp/provisioning/status
#   - Writes the device count of 0 to /psp/provisioning/grand-total
#   - Writes the device count of 0 to /psp/provisioning/total
#   - Reboots the device
#
# This script should be installed under /tmp/ so that it will get removed
# when the device is rebooted.
#
# Before the script is run, the following files must be present:
#   /tmp/package.ipk - The provisioning package
#   /tmp/provision.sh - The script that gets deployed to devices
#   /tmp/provisioning-server.sh - The actual script that performs provisioning
#
# Optionally, the following files may exist:
#   /tmp/package.key - The passphrase used to encrypt /tmp/package.ipk
#   /tmp/package.asc - The signature file used to sign /tmp/package.ipk
#   /tmp/package.sha - A SHA-256 sum of the uncompressed package

PROV_ROOT=/psp/provisioning

PKG=/tmp/package.ipk
SCR=/tmp/provision.sh
SRV=/tmp/provisioning-server.sh

KEY=/tmp/package.key
ASC=/tmp/package.asc
SHA=/tmp/package.sha
URL=/tmp/package.url



function die() {
	echo $1
    echo $1 > /tmp/provision.$$.log
	logger -t provision "$1"
	exit 1
}

function fetch() {
    curl --stderr /dev/null -f -o "$1" "$2" || die "$3"
}

function verify_signature() {
    gpg --lock-never --no-options --no-default-keyring \
        --keyring /etc/opkg/trusted.gpg \
        --secret-keyring /etc/opkg/secring.gpg \
        --trustdb-name /etc/opkg/trustdb.gpg \
        --quiet --batch --verify "$2" "$1" || die "$3"
}

function verify_sum() {
    if [ "x$(cat $2)" != "x$(sha256sum $1 | cut -d' ' -f1)" ]
    then
        die "$3"
    fi
}

function decrypt_package() {
    # If there's no "die" message, then it's because there is no key
    if [ $# -lt 3 ]
    then
        return
    fi

    gpg --lock-never --no-options --no-default-keyrung
        --passphrase-file "$2" \
        --output "/tmp/pkg.tmp" \
        --decrypt "$1" || die "$3"
    mv /tmp/pkg.tmp $1
}


# Ensure the scripts we need are present
[ ! -e ${PKG} ] && die "Missing ipk file ${PKG}"
[ ! -e ${SCR} ] && die "Missing deployable provisioning script ${SCR}"
[ ! -e ${SRV} ] && die "Missing provisioning server script ${SRV}"

# Decrypt the package, if necessary
[ -e ${KEY} ] &&  decrypt_package ${PKG} ${KEY} "Unable to decrypt package"

# If a signature file is present, verify the signature
[ -e ${ASC} ] && verify_signature ${PKG} ${ASC} "Unable to verify signature"

# If a sumfile is present, verify the sum
[ -e ${SHA} ] &&       verify_sum ${PKG} ${SHA} "Unable to verify file sum"

mkdir -p "${PROV_ROOT}"
echo "${PROV_ROOT}" > /psp/homepage
/etc/init.d/chumby-netvserver restart
/etc/init.d/chumby-netvbrowser restart
echo '<html><head><script>fCheckAlive() { return true; } </script><meta http-equiv="refresh" content="5"></head><body bgcolor="yellow"><table style="background:purple; width:1280px; height:720px;"><tr><td style="vertical-align:middle; font: 36pt sans-serif; text-align: center;">Preparing...</td></tr></table></body></html>' > "${PROV_ROOT}/index.html"

# Copy necessary files to the provisioning root
cp "${PKG}" "${PROV_ROOT}"
cp "${SCR}" "${PROV_ROOT}"
cp "${SRV}" "${PROV_ROOT}"
[ -e "${URL}" ] && cp "${URL}" "${PROV_ROOT}"

# Set up userhook0 to run on startup
mkdir -p /psp/rfs1
mount -oremount,rw /
/usr/sbin/update-rc.d userhook0.sh defaults 80 20
mount -oremount,ro /
cp "${SRV}" /psp/rfs1/userhook0
chmod a+x /psp/rfs1/userhook0


echo "Initializing" > "${PROV_ROOT}/status"
echo "0" > "${PROV_ROOT}/grand-total"
echo "0" > "${PROV_ROOT}/total"
echo '<html><head><script>fCheckAlive() { return true; } </script><meta http-equiv="refresh" content="5"></head><body bgcolor="yellow"><table style="background:purple; width:1280px; height:720px;"><tr><td style="vertical-align:middle; font: 36pt sans-serif; text-align: center;"> Initializing...</td></tr></table></body></html>' > "${PROV_ROOT}/index.html"


reboot
