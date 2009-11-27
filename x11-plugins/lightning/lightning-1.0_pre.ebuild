# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

WANT_AUTOCONF="2.1"
EAPI="2"

inherit flag-o-matic toolchain-funcs eutils mozconfig-3 makeedit multilib mozextension autotools

TBVER="3.0rc1"
PATCH="mozilla-thunderbird-3.0-patches-0.1"

DESCRIPTION="Calendar extension for Mozilla Thunderbird."
HOMEPAGE="http://www.mozilla.org/projects/calendar/lightning/"
SRC_URI="http://releases.mozilla.org/pub/mozilla.org/thunderbird/releases/${TBVER}/source/thunderbird-${TBVER}.source.tar.bz2
	http://dev.gentoo.org/~anarchy/dist/${PATCH}.tar.bz2"

KEYWORDS="~alpha ~amd64 ~ia64 ~ppc ~ppc64 ~sparc ~x86 ~x86-fbsd"
SLOT="0"
LICENSE="MPL-1.1 GPL-2"
IUSE=""

RDEPEND=">=mail-client/mozilla-thunderbird-3.0_beta4"

S="${WORKDIR}"/comm-1.9.1

src_unpack() {
	unpack thunderbird-${TBVER}.source.tar.bz2 ${PATCH}.tar.bz2 || die "unpack failed"
}

src_prepare(){
	# Apply our patches
	EPATCH_EXCLUDE="104-fix_licence_file_preprocessor.patch" \
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
	epatch "${WORKDIR}"

	# Don't strip
	sed -i -e 's/STRIP_/#STRIP_/g' calendar/lightning/Makefile.in

	cd mozilla
	eautoreconf
	cd js/src
	eautoreconf
}

src_configure() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/mozilla-thunderbird"

	####################################
	#
	# mozconfig, CFLAGS and CXXFLAGS setup
	#
	####################################

	touch mail/config/mozconfig
	mozconfig_init
	mozconfig_config

	# lightning-specific settings
	mozconfig_annotate '' \
		--with-system-nspr \
		--with-system-nss \
		--with-default-mozilla-five-home=${MOZILLA_FIVE_HOME} \
		--enable-application=calendar

	# Finalize and report settings
	mozconfig_final

	# Disable no-print-directory
	MAKEOPTS=${MAKEOPTS/--no-print-directory/}

	if [[ $(gcc-major-version) -lt 4 ]]; then
		append-cxxflags -fno-stack-protector
	fi

	####################################
	#
	#  Configure and build Thunderbird
	#
	####################################
	CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" \
	econf || die

	# This removes extraneous CFLAGS from the Makefiles to reduce RAM
	# requirements while compiling
	edit_makefiles
}

src_compile() {
	# Only build the parts necessary to support minimial build requirements for additional
	# extensions
	emake -j1 export || die "make export failed"
	emake -C mozilla/xpcom || die "make xpcom failed"
	emake -C mozilla/js/src || die "make js failed"

	# Build the lightning plugin
	einfo "Building Lightning plugin..."
	emake -C "${S}"/calendar/lightning/ || die "make lightning failed"
}

src_install() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/mozilla-thunderbird"
	# Declare emid as sed fails to detect thunderbird emid and tries to use seamonkeys.
	declare emid="{3550f703-e582-4d05-9a08-453d09bdfdc6}"

	dodir ${MOZILLA_FIVE_HOME}/extensions/${emid}
	cd "${D}"${MOZILLA_FIVE_HOME}/extensions/${emid}
	unzip "${S}"/mozilla/dist/xpi-stage/${PN}.xpi
}
