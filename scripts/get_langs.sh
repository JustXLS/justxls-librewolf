#!/bin/sh

if test -z "${1}"; then
	echo "Usage: ${0} FF_VER"
	exit 1
fi

INBUILT_LANGS="en en-US"
VER="${1}"
MIRROR_URI="http://releases.mozilla.org/pub/mozilla.org/firefox/releases/${VER}/linux-i686/xpi/"
XPI_LANGS=$(wget -q "${MIRROR_URI}" -O - | grep -o '[a-zA-Z-]\+\.xpi' | uniq | sed 's/\.xpi//')
LANGS=$(echo ${INBUILT_LANGS} ${XPI_LANGS} | tr " " "\n" | sort -d)
echo ${LANGS}
