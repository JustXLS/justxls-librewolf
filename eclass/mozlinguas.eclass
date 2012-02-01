# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

# @ECLASS: mozlinguas.eclass
# @MAINTAINER: mozilla@gentoo.org
# @AUTHOR: Nirbheek Chauhan <nirbheek@gentoo.org>
# @BLURB: Handle language packs for mozilla products
# @DESCRIPTION:
# Sets IUSE according to LANGS (language packs available). Also exports
# src_unpack and src_install for use in ebuilds.

inherit mozextension

case "${EAPI:-0}" in
	0|1)
		die "EAPI ${EAPI:-0} does not support the '->' SRC_URI operator";;
	2|3|4)
		EXPORT_FUNCTIONS src_unpack src_install;;
	*)
		die "EAPI ${EAPI} is not supported, contact eclass maintainers";;
esac

# @ECLASS-VARIABLE: LANGS
# @DEFAULT-UNSET
# @DESCRIPTION: Array containing the list of language pack xpis available for
# this release. The list can be updated with scripts/get_langs.sh from the
# mozilla overlay.
: ${LANGS:=""}

# @ECLASS-VARIABLE: MOZ_PV
# @DESCRIPTION: Ebuild package version converted to equivalent upstream version.
# Defaults to ${PV}, and should be overridden for alphas, betas, and RCs
: ${MOZ_PV:="${PV}"}

# @ECLASS-VARIABLE: MOZ_PN
# @DESCRIPTION: Ebuild package name converted to equivalent upstream name.
# Defaults to ${PN}, and should be overridden for binary ebuilds.
: ${MOZ_PN:="${PN}"}

# @ECLASS-VARIABLE: MOZ_P
# @DESCRIPTION: Ebuild package name + version converted to upstream equivalent.
# Defaults to ${MOZ_PN}-${MOZ_PV}
: ${MOZ_P:="${MOZ_PN}-${MOZ_PV}"}

# @ECLASS-VARIABLE: FTP_URI
# @DEFAULT-UNSET
# @DESCRIPTION: The ftp URI prefix for the release tarballs and language packs.
: ${FTP_URI:=""}

# @ECLASS-VARIABLE: LANGPACK_PREFIX
# @DESCRIPTION: The relative path till the lang code in the langpack file URI.
# Defaults to ${MOZ_PV}/linux-i686/xpi/
: ${LANGPACK_PREFIX:="${MOZ_PV}/linux-i686/xpi/"}

# @ECLASS-VARIABLE: LANGPACK_SUFFIX
# @DESCRIPTION: The suffix after the lang code in the langpack file URI.
# Defaults to '.xpi'
: ${LANGPACK_SUFFIX:=".xpi"}

# Add linguas_* to IUSE according to available language packs
# No language packs for alphas and betas
if ! [[ ${PV} =~ alpha|beta ]]; then
	for x in "${LANGS[@]}" ; do
		# en and en_US are handled internally
		if [[ ${x} = en ]] || [[ ${x} = en-US ]]; then
			continue
		fi
		SRC_URI="${SRC_URI}
			linguas_${x/-/_}?
				( ${FTP_URI}/${LANGPACK_PREFIX}${x}${LANGPACK_SUFFIX} -> ${MOZ_P}-${x}.xpi )"
		IUSE="${IUSE} linguas_${x/-/_}"
		# We used to do some magic if specific/generic locales were missing, but
		# we stopped doing that due to bug 325195.
	done
fi

mozlinguas() {
	[[ ${PV} =~ alpha|beta ]] && return
	# Generate the list of language packs called "linguas"
	# This list is used to unpack and install the xpi language packs
	local lingua
	for lingua in ${LINGUAS}; do
		if has ${lingua} en en_US; then
			# For mozilla products, en and en_US are handled internally
			continue
		# If this language is supported by ${P},
		elif has ${lingua} "${LANGS[@]//-/_}"; then
			# Add the language to linguas, if it isn't already there
			has ${lingua//_/-} "${linguas[@]}" || linguas+=(${lingua//_/-})
			continue
		# For each short lingua that isn't in LANGS,
		# We used to add *all* long LANGS to the linguas list,
		# but we stopped doing that due to bug 325195.
		fi
		ewarn "Sorry, but ${P} does not support the ${lingua} locale"
	done
}

# @FUNCTION: mozlinguas_src_unpack
# @DESCRIPTION:
# Unpack xpi language packs according to the user's LINGUAS settings
mozlinguas_src_unpack() {
	local x
	mozlinguas
	for x in "${linguas[@]}"; do
		# FIXME: Add support for unpacking xpis to portage
		xpi_unpack "${MOZ_P}-${x}.xpi"
	done
	if [[ "${linguas[*]}" != "" && "${linguas[*]}" != "en" ]]; then
		einfo "Selected language packs (first will be default): ${linguas[*]}"
	fi
}

# @FUNCTION: mozlinguas_src_install
# @DESCRIPTION:
# Install xpi language packs according to the user's LINGUAS settings
mozlinguas_src_install() {
	local x
	mozlinguas
	for x in "${linguas[@]}"; do
		xpi_install "${WORKDIR}/${MOZ_P}-${x}"
	done
}
