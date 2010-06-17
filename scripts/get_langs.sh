#!/bin/sh

if test -z "${2}"; then
	echo "Usage: ${0} <product> <version>"
	exit 1
fi

INBUILT_LANGS="en en-US"
PRODUCT="${1}"
VER="${2}"
MIRROR_URI="http://releases.mozilla.org/pub/mozilla.org/${PRODUCT}/releases/${VER}/linux-i686/xpi/"
XPI_LANGS=$(wget -q "${MIRROR_URI}" -O - | grep -o '[a-zA-Z-]\+\.xpi' | uniq | sed 's/\.xpi//')
LANGS=$(echo ${INBUILT_LANGS} ${XPI_LANGS} | tr " " "\n" | sort -d)
echo ${LANGS}
