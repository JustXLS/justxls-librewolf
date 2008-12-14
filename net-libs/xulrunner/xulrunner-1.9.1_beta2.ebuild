# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-libs/xulrunner/xulrunner-1.9.0.1.ebuild,v 1.4 2008/07/30 10:42:58 armin76 Exp $

WANT_AUTOCONF="2.1"

inherit flag-o-matic toolchain-funcs eutils mozconfig-3 makeedit multilib java-pkg-opt-2 python autotools
PATCH="${P}-patches-0.1"
MY_PV="${PV/_beta/b}"
MY_PV="${MY_PV/1.9/3}"

DESCRIPTION="Mozilla runtime package that can be used to bootstrap XUL+XPCOM applications"
HOMEPAGE="http://developer.mozilla.org/en/docs/XULRunner"
SRC_URI="http://releases.mozilla.org/pub/mozilla.org/firefox/releases/${MY_PV}/source/firefox-${MY_PV}-source.tar.bz2"
#	mirror://gentoo/${PATCH}.tar.bz2"

KEYWORDS="~alpha ~amd64 ~hppa ~ia64 ~ppc ~ppc64 ~sparc ~x86"
SLOT="1.9"
LICENSE="|| ( MPL-1.1 GPL-2 LGPL-2.1 )"
IUSE="python"

RDEPEND="java? ( >=virtual/jre-1.4 )
	python? ( >=dev-lang/python-2.3 )
	>=sys-devel/binutils-2.16.1
	>=dev-libs/nss-3.12.2_rc1
	>=dev-libs/nspr-4.7.3
	media-libs/alsa-lib
	>=dev-db/sqlite-3.6.2
	>=app-text/hunspell-1.2"

DEPEND="java? ( >=virtual/jdk-1.4 )
	${RDEPEND}
	dev-util/pkgconfig"

S="${WORKDIR}/mozilla-central"

# Needed by src_compile() and src_install().
# Would do in pkg_setup but that loses the export attribute, they
# become pure shell variables.
export MOZ_CO_PROJECT=xulrunner
export BUILD_OFFICIAL=1
export MOZILLA_OFFICIAL=1

pkg_setup(){
	if ! built_with_use x11-libs/cairo X; then
		eerror "Cairo is not built with X useflag."
		eerror "Please add 'X' to your USE flags, and re-emerge cairo."
		die "Cairo needs X"
	fi

	if ! built_with_use --missing true x11-libs/pango X; then
		eerror "Pango is not built with X useflag."
		eerror "Please add 'X' to your USE flags, and re-emerge pango."
		die "Pango needs X"
	fi
	java-pkg-opt-2_pkg_setup
}

src_unpack() {
	unpack ${A}

	# Apply our patches
	cd "${S}" || die "cd failed"
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
	epatch "${FILESDIR}"/1.9.1_beta2

	eautoreconf

	cd js/src
	eautoreconf


	# We need to re-patch this because autoreconf overwrites it
#	epatch "${FILESDIR}"/patch/000_flex-configure-LANG.patch
}

src_compile() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}-1.9"

	####################################
	#
	# mozconfig, CFLAGS and CXXFLAGS setup
	#
	####################################

	mozconfig_init
	mozconfig_config

        MEXTENSIONS="default"
        if use python; then
                MEXTENSIONS="${MEXTENSIONS},python/xpcom"
        fi

	mozconfig_annotate '' --enable-extensions="${MEXTENSIONS}"
	mozconfig_annotate '' --disable-mailnews
	mozconfig_annotate 'broken' --disable-mochitest
	mozconfig_annotate 'broken' --disable-crashreporter
	mozconfig_annotate '' --enable-system-hunspell
	mozconfig_annotate '' --enable-system-sqlite
	mozconfig_annotate '' --enable-image-encoder=all
	mozconfig_annotate '' --enable-canvas
	#mozconfig_annotate '' --enable-js-binary
	mozconfig_annotate '' --enable-embedding-tests
	mozconfig_annotate '' --with-system-nspr
	mozconfig_annotate '' --with-system-nss
#	mozconfig_annotate '' --enable-system-lcms
	mozconfig_annotate '' --with-system-bz2
	# Bug 60668: Galeon doesn't build without oji enabled, so enable it
	# regardless of java setting.
	mozconfig_annotate '' --enable-oji --enable-mathml
	mozconfig_annotate 'places' --enable-storage --enable-places --enable-places_bookmarks
	mozconfig_annotate '' --enable-safe-browsing

	# Other ff-specific settings
	mozconfig_annotate '' --enable-jsd
	mozconfig_annotate '' --enable-xpctools
	mozconfig_annotate '' --with-default-mozilla-five-home=${MOZILLA_FIVE_HOME}

	#disable java
	if ! use java ; then
		mozconfig_annotate '-java' --disable-javaxpcom
	fi

	# Finalize and report settings
	mozconfig_final

	# -fstack-protector breaks us
	if gcc-version ge 4 1; then
		gcc-specs-ssp && append-flags -fno-stack-protector
	else
		gcc-specs-ssp && append-flags -fno-stack-protector-all
	fi
	filter-flags -fstack-protector -fstack-protector-all

	####################################
	#
	#  Configure and build
	#
	####################################

	CPPFLAGS="${CPPFLAGS} -DARON_WAS_HERE" \
	CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" \
	econf || die

	# It would be great if we could pass these in via CPPFLAGS or CFLAGS prior
	# to econf, but the quotes cause configure to fail.
	sed -i -e \
		's|-DARON_WAS_HERE|-DGENTOO_NSPLUGINS_DIR=\\\"/usr/'"$(get_libdir)"'/nsplugins\\\" -DGENTOO_NSBROWSER_PLUGINS_DIR=\\\"/usr/'"$(get_libdir)"'/nsbrowser/plugins\\\"|' \
		"${S}"/config/autoconf.mk \
		"${S}"/toolkit/content/buildconfig.html

	emake || die "emake failed"
}

src_install() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}-1.9"

	emake DESTDIR="${D}" install || die "emake install failed"

	rm "${D}"/usr/bin/xulrunner

	dodir /usr/bin
	dosym ${MOZILLA_FIVE_HOME}/xulrunner /usr/bin/xulrunner-1.9

	# Add vendor
	echo "pref(\"general.useragent.vendor\",\"Gentoo\");" \
		>> "${D}"${MOZILLA_FIVE_HOME}/defaults/pref/vendor.js

	if use java ; then
	    java-pkg_dojar "${D}"${MOZILLA_FIVE_HOME}/javaxpcom.jar
	    rm -f "${D}"${MOZILLA_FIVE_HOME}/javaxpcom.jar
	fi
}

pkg_postinst() {
	if use python; then
		python_version
		python_mod_optimize ${ROOT}/usr/$(get_libdir)/${PN}-1.9/python/xpcom
	fi
}

pkg_postrm() {
	if use python; then
		python_version
		python_mod_cleanup ${ROOT}/usr/$(get_libdir)/${PN}-1.9/python/xpcom
	fi
}