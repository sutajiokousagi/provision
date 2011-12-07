#!/bin/sh
PKG_NAME=$1
PKG_HASH=$2
PKG_REPO=$3

if [ -z ${PKG_NAME} ] || [ -z ${PKG_HASH} ]
then
    echo "Usage: $0 <package.ipk> <package-sha256-hash> [<repo-url>]"
    exit 0
fi

function die() {
	echo $1
	logger -t provision "$1"
	exit 1
}

function install_package() {
    PKG=$1
    HSH=$2
    if [ $# -lt 4 ]
    then
        ERR=$3
    else
        ERR=$4
        URL=$3
    fi

    MY_HSH="$(sha256sum ${PKG} | cut -d' ' -f1)"
    if [ "x${MY_HSH}" != "x${HSH}" ]
    then
        die "${ERR}: Hash doesn't match (wanted ${HSH}, got ${MY_HSH})"
    fi

    mount -oremount,rw /

    # Ensure the arch is set up and valid
    ARCH=$(ar -p "${PKG}" control.tar.gz | tar Oxz ./control | grep ^Architecture: | cut -d' ' -f2)
    grep -q ${ARCH} /etc/opkg/arch.conf || echo "arch ${ARCH} 15" >> /etc/opkg/arch.conf
    [ -z ${URL} ] || echo "src/gz ${ARCH} ${URL}" > /etc/opkg/${ARCH}.conf

    opkg install "${PKG}"
    mount -oremount,ro /
}

install_package "${PKG_NAME}" "${PKG_HASH}" "${PKG_REPO}" "Unable to install package"
rm -f "${PKG_NAME}"
reboot
