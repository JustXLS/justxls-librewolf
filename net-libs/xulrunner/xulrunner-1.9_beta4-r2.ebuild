# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: Exp $

WANT_AUTOCONF="2.1"
inherit flag-o-matic toolchain-funcs eutils mozconfig-minefield makeedit multilib java-pkg-opt-2 python autotools

DESCRIPTION="Mozilla runtime package that can be used to bootstrap XUL+XPCOM applications"
HOMEPAGE="http://developer.mozilla.org/en/docs/XULRunner"
SRC_URI="http://dev.gentooexperimental.org/~armin76/dist/${P}.tar.bz2"

KEYWORDS="~alpha ~amd64 ~hppa ~ia64 ~ppc ~ppc64 ~sparc ~x86"
SLOT="1.9"
LICENSE="MPL-1.1 GPL-2 LGPL-2.1"
IUSE="glitz elibc_FreeBSD"

RDEPEND="java? ( >=virtual/jre-1.4 )
	glitz? ( >=media-libs/glitz-0.5.6 )
	>=sys-devel/binutils-2.16.1
	>=dev-libs/nss-3.12_beta1
	>=dev-libs/nspr-4.7
	>=app-text/hunspell-1.1.9
	>=media-libs/lcms-1.17
	>=dev-db/sqlite-3.5"

DEPEND="java? ( >=virtual/jdk-1.4 )
	${RDEPEND}
	dev-util/pkgconfig"

S="${WORKDIR}/mozilla"

# Needed by src_compile() and src_install().
# Would do in pkg_setup but that loses the export attribute, they
# become pure shell variables.
export MOZ_CO_PROJECT=xulrunner
export BUILD_OFFICIAL=1
export MOZILLA_OFFICIAL=1

src_unpack() {
	unpack ${A}

	# Apply our patches
	cd "${S}" || die "cd failed"
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
#	epatch "${WORKDIR}"/patch

	#Install in just one directory
	epatch "${FILESDIR}"/001-xul_gentoo_install_dirs.patch
	#Use system nspr/nss
	epatch "${FILESDIR}"/002-bzXXX_pc_honour_system_nspr_nss.patch
	#use so-names
	epatch "${FILESDIR}"/181_sonames-v4.patch
	#add the standard gentoo plugins dir
	epatch "${FILESDIR}"/064_firefox-nsplugins-v3.patch
	#make it use the system iconv
	epatch "${FILESDIR}"/165_native_uconv.patch
	#Fix when using system hunspell
	epatch "${FILESDIR}"/100-system-hunspell-corrections.patch
	#make loading certs behave with system nss
	epatch "${FILESDIR}"/068_firefox-nss-gentoo-fix.patch
	#correct the cairo/glitz mess, if using system libs
	epatch "${FILESDIR}"/666_mozilla-glitz-cairo-v2.patch


	####################################
	#
	# behavioral fixes
	#
	####################################

	#rpath patch
	epatch "${FILESDIR}"/063_firefox-rpath-3.patch

	#gfbsd stuff
	epatch "${FILESDIR}"/055_firefox-2.0_gfbsd-pthreads.patch
	epatch "${FILESDIR}"/bsd_include.patch
	#This breaks linux, so make it only if gfbsd
	use elibc_FreeBSD && epatch "${FILESDIR}"/iconvconst.patch

	eautoreconf || die "failed  running eautoreconf"
}

pkg_setup() {
	if use glitz; then
		if ! built_with_use x11-libs/cairo glitz; then
			ewarn "You need cairo built with the glitz USE-flag."
			ewarn "Enable the glitz USE-flag and re-emerge cairo."
			die "re-emerge cairo with the glitz USE-flag set"
		fi
	fi
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

	mozconfig_annotate '' --enable-extensions="${MEXTENSIONS}"
	mozconfig_annotate '' --disable-mailnews
	mozconfig_annotate 'broken' --disable-mochitest
	mozconfig_annotate 'broken' --disable-crashreporter
	mozconfig_annotate '' --enable-native-uconv
	mozconfig_annotate '' --enable-system-hunspell
	mozconfig_annotate '' --enable-system-sqlite
	mozconfig_annotate '' --enable-image-encoder=all
	mozconfig_annotate '' --enable-canvas
	#mozconfig_annotate '' --enable-js-binary
	mozconfig_annotate '' --enable-embedding-tests
	mozconfig_annotate '' --with-system-nspr
	mozconfig_annotate '' --with-system-nss
	mozconfig_annotate '' --enable-system-lcms
	#mozconfig_annotate '' --with-system-bz2
	# Bug 60668: Galeon doesn't build without oji enabled, so enable it
	# regardless of java setting.
	mozconfig_annotate '' --enable-oji --enable-mathml
	mozconfig_annotate 'places' --enable-storage --enable-places --enable-places_bookmarks

	# Other ff-specific settings
	mozconfig_annotate '' --enable-jsd
	mozconfig_annotate '' --enable-xpctools
	mozconfig_annotate '' --disable-libxul
	mozconfig_annotate '' --with-default-mozilla-five-home=${MOZILLA_FIVE_HOME}

	#use enable glitz
	if use glitz; then
		mozconfig_annotate thebes --enable-glitz
	fi

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
		${S}/config/autoconf.mk \
		${S}/toolkit/content/buildconfig.html

	# This removes extraneous CFLAGS from the Makefiles to reduce RAM
	# requirements while compiling
	edit_makefiles

	emake || die "emake failed"
}

src_install() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}-1.9"

	emake DESTDIR="${D}" install || die "emake install failed"

	rm "${D}"/usr/bin/xulrunner

	dodir /usr/bin
	dosym ${D}${MOZILLA_FIVE_HOME}/xulrunner-bin /usr/bin/xulrunner-1.9

	X_DATE=`date +%Y%m%d`

	# Add Gentoo package version to preferences - copied from debian rules
	echo // Gentoo package version \
		> "${D}"${MOZILLA_FIVE_HOME}/defaults/pref/vendor.js
	echo "pref(\"general.useragent.product\",\"Gecko\");" \
		>> "${D}"${MOZILLA_FIVE_HOME}/defaults/pref/vendor.js
	echo "pref(\"general.useragent.productSub\",\"${X_DATE}\");" \
		>> "${D}"${MOZILLA_FIVE_HOME}/defaults/pref/vendor.js
	echo "pref(\"general.useragent.productComment\",\"Gentoo\");" \
		>> "${D}"${MOZILLA_FIVE_HOME}/defaults/pref/vendor.js

	if use java ; then
	    java-pkg_dojar ${D}${MOZILLA_FIVE_HOME}/javaxpcom.jar
	    rm -f ${D}${MOZILLA_FIVE_HOME}/javaxpcom.jar
	fi
}

