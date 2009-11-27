# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

WANT_AUTOCONF="2.1"
EAPI="2"

inherit flag-o-matic toolchain-funcs eutils mozconfig-3 makeedit multilib mozextension autotools
MY_P="${P/_beta/b}"
EMVER="${PV}"
TBVER="3.0rc1"
PATCH="mozilla-thunderbird-3.0-patches-0.1"

DESCRIPTION="GnuPG encryption plugin for thunderbird."
HOMEPAGE="http://enigmail.mozdev.org"
SRC_URI="http://releases.mozilla.org/pub/mozilla.org/thunderbird/releases/${TBVER}/source/thunderbird-${TBVER}.source.tar.bz2
	http://dev.gentoo.org/~anarchy/dist/enigmail-${EMVER}.tar.gz
	http://dev.gentoo.org/~anarchy/dist/${PATCH}.tar.bz2"

KEYWORDS="~alpha ~amd64 ~ia64 ~ppc ~ppc64 ~sparc ~x86 ~x86-fbsd"
SLOT="0"
LICENSE="MPL-1.1 GPL-2"
IUSE=""

DEPEND=">=mail-client/mozilla-thunderbird-3.0_beta3"
RDEPEND="${DEPEND}
	|| (
		(
			>=app-crypt/gnupg-2.0
			|| (
				app-crypt/pinentry[gtk]
				app-crypt/pinentry[qt4]
				app-crypt/pinentry[qt3]
			)
		)
		=app-crypt/gnupg-1.4*
	)"

S="${WORKDIR}"/comm-1.9.1

pkg_setup() {
	# EAPI=2 ensures they are set properly.
	export BUILD_OFFICIAL=1
	export MOZILLA_OFFICIAL=1
	export MOZ_CO_PROJECT=mail

	elog "This is alphaware, do not expect themes to work properly with this release."
	elog "If you need a working theme please visit the addons page and install one,"
	elog "one known theme includes the iLeopard Mail theme."
	elog "https://addons.mozilla.org/en-US/thunderbird/addon/9552"
}


src_unpack() {
	unpack thunderbird-${TBVER}.source.tar.bz2 ${PATCH}.tar.bz2 || die "unpack failed"
}

src_prepare(){
	# Apply our patches
	EPATCH_EXCLUDE="104-fix_licence_file_preprocessor.patch" \
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
	epatch "${WORKDIR}"

	cd mozilla
	eautoreconf
	cd js/src
	eautoreconf

	# Unpack the enigmail plugin
	cd "${S}"/mailnews/extensions || die
	unpack enigmail-${EMVER}.tar.gz
	cd "${S}"/mailnews/extensions/enigmail || die "cd failed"
	makemake2

	cd "${S}"

	# Use the right theme for thunderbird #45609
	sed -i -ne '/^enigmail-skin.jar:$/ { :x; n; /^\t/bx; }; p' mailnews/extensions/enigmail/ui/jar.mn

	# Fix installation of enigmail.js
	epatch "${FILESDIR}"/70_enigmail-fix.patch

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

	# tb-specific settings
	mozconfig_annotate '' \
		--with-system-nspr \
		--with-system-nss \
		--with-default-mozilla-five-home=${MOZILLA_FIVE_HOME} \
		--with-user-appdir=.thunderbird \
		--enable-application=mail

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
	# Only build the parts necessary to support building enigmail
	emake -j1 export || die "make export failed"
	emake -C mozilla/modules/libreg || die "make modules/libreg failed"
	emake -C mozilla/xpcom/string || die "make xpcom/string failed"
	emake -C mozilla/xpcom || die "make xpcom failed"
	emake -C mozilla/xpcom/obsolete || die "make xpcom/obsolete failed"

	# Build the enigmail plugin
	einfo "Building Enigmail plugin..."
	emake -C "${S}"/mailnews/extensions/enigmail || die "make enigmail failed"

	# Package the enigmail plugin; this may be the easiest way to collect the
	# necessary files
	emake -j1 -C "${S}"/mailnews/extensions/enigmail xpi || die "make xpi failed"
}

src_install() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/mozilla-thunderbird"
	declare emid

	cd "${T}"
	unzip "${S}"/mozilla/dist/bin/*.xpi install.rdf
	emid=$(sed -n '/<em:id>/!d; s/.*\({.*}\).*/\1/; p; q' install.rdf)

	dodir ${MOZILLA_FIVE_HOME}/extensions/${emid}
	cd "${D}"${MOZILLA_FIVE_HOME}/extensions/${emid}
	unzip "${S}"/mozilla/dist/bin/*.xpi
}
