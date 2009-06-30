#!/bin/sh

if test -z "${1}"; then
	echo "Usage: ${0} FF_VER"
	exit 1
fi

VER="${1}"
MIRROR_URI="http://releases.mozilla.org/pub/mozilla.org/firefox/releases/${VER}/linux-i686/xpi/"
echo $(wget -q "${MIRROR_URI}" -O - | grep -o '[a-zA-Z-]\+\.xpi' | uniq | sed 's/\.xpi//')
