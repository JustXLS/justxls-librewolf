# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: Exp $

WANT_AUTOCONF="2.1"
inherit flag-o-matic toolchain-funcs eutils mozconfig-minefield makeedit multilib java-pkg-opt-2 python autotools

DESCRIPTION="Mozilla runtime package that can be used to bootstrap XUL+XPCOM applications"
HOMEPAGE="http://developer.mozilla.org/en/docs/XULRunner"
SRC_URI="http://dev.gentooexperimental.org/~armin76/dist/${P}.tar.bz2"

KEYWORDS="~amd64 ~x86"
SLOT="0"
LICENSE="MPL-1.1 GPL-2 LGPL-2.1"
IUSE="python offline glitz"

RDEPEND="java? ( >=virtual/jre-1.4 )
	glitz? ( >=media-libs/glitz-0.5.6 )
	>=sys-devel/binutils-2.16.1
	>=dev-libs/nss-3.12_alpha2_p1
	>=dev-libs/nspr-4.7.0_pre20071016
	>=app-text/hunspell-1.1.9
	>=media-libs/lcms-1.17"
#	>=dev-db/sqlite-3.3.17"

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

pkg_setup() {
	if use glitz; then
		if ! built_with_use x11-libs/cairo glitz; then
			ewarn "You need cairo built with the glitz USE-flag."
			ewarn "Enable the glitz USE-flag and re-emerge cairo."
			die "re-emerge cairo with the glitz USE-flag set"
		fi
	fi
}

src_unpack() {
	unpack ${A}

	# Apply our patches
	cd "${S}" || die "cd failed"
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
#	epatch "${WORKDIR}"/patch

	#correct the pkg-config files and xulrunner-config
	epatch "${FILESDIR}"/008_xulrunner-gentoo-pkgconfig-3.patch
	#use so-names
	epatch "${FILESDIR}"/181_sonames-v3.patch
	#xpcomglue as a shared library
	#epatch "${FILESDIR}"/185_xpcomglue-v2.patch
	#epatch "${FILESDIR}"/186_wallet.patch
	#correct the cairo/glitz mess, if using system libs
	epatch "${FILESDIR}"/666_mozilla-glitz-cairo.patch
	#add the standard gentoo plugins dir
	epatch "${FILESDIR}"/064_firefox-nsplugins-v3.patch
	#make it use the system iconv
	epatch "${FILESDIR}"/165_native_uconv.patch
	#make it use system hunspell and correct the loading of dicts
	epatch "${FILESDIR}"/100_system_myspell-v2.patch
	#fix the mouse selection in the embedders (thanks amd)
	epatch "${FILESDIR}"/200_fix-mouse-selection-373196.patch
	#make loading certs behave with system nss
	epatch "${FILESDIR}"/068_firefox-nss-gentoo-fix.patch
	#correct the mozilla ini mess
	epatch "${FILESDIR}"/667_383167_borkage.patch
	#correct the mozilla system headers mess
	#epatch "${FILESDIR}"/668_system-headers.patch
	#install them in one place, in order for make install to 
	#really install them - it is simply piteous
	epatch "${FILESDIR}"/888_install_needed.patch
	#try to depackage, what should never be packaged in the first place
	epatch "${FILESDIR}"/989_repackager.patch
	epatch "${FILESDIR}"/898_fake_pkgconfig.patch
	#some more patching
	epatch "${FILESDIR}"/188_fix_includes.patch


	####################################
	#
	# behavioral fixes
	#
	####################################

	#rpath patch
	epatch "${FILESDIR}"/063_firefox-rpath-3.patch
	eautoreconf || die "failed  running eautoreconf"
}

src_compile() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"
	MEXTENSIONS="default,wallet"
	#if use python ; then
	#	MEXTENSIONS="${MEXTENSIONS},python/xpcom"
	#fi

	#if use xforms; then
	#	MEXTENSIONS="${MEXTENSIONS},xforms"
	#fi
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
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"
	#fake install some small portions, the other parts of
	#this abomination are patched away in oblivion
	emake DESTDIR="${D}" install || die "emake install failed"

	#install the sdk and the xulrunner in one - our way
	dodir "${MOZILLA_FIVE_HOME}"
	cp -a "${S}"/dist/bin/* "${D}"/"${MOZILLA_FIVE_HOME}"/ || die "cp failed"

	#install the includes and the idls
	dodir /usr/include/"${PN}"/stable
	cp -a "${S}"/dist/include/stable "${D}"/usr/include/"${PN}" || die "cp failed"
	dodir /usr/include/"${PN}"/unstable
	cp -a "${S}"/dist/include/unstable "${D}"/usr/include/"${PN}" || die "cp failed"
	cp -a "${S}"/dist/include/mozilla-config.h "${D}"/usr/include/"${PN}"/unstable || die "cp failed"
	cp -a "${S}"/dist/include/mozilla-config.h "${D}"/usr/include/"${PN}"/stable || die "cp failed"
	cp -a "${S}"/dist/include/nsStaticComponents.h "${D}"/usr/include/"${PN}"/unstable || die "cp failed"
	cp -a "${S}"/dist/include/nsStaticComponents.h "${D}"/usr/include/"${PN}"/stable || die "cp failed"

	dodir /usr/include/"${PN}"/idl
	cp -a "${S}"/dist/idl "${D}"/usr/include/"${PN}" || die "cp failed"

	dodir /usr/bin
	dosym ${D}${MOZILLA_FIVE_HOME}/xulrunner-bin /usr/bin/xulrunner

	X_DATE=`date +%Y%m%d`

	# Add Gentoo package version to preferences - copied from debian rules
	echo // Gentoo package version \
		> ${D}/usr/$(get_libdir)/xulrunner/defaults/pref/vendor.js
	echo "pref(\"general.useragent.product\",\"Gecko\");" \
		>> ${D}/usr/$(get_libdir)/xulrunner/defaults/pref/vendor.js
	echo "pref(\"general.useragent.productSub\",\"${X_DATE}\");" \
		>> ${D}/usr/$(get_libdir)/xulrunner/defaults/pref/vendor.js
	echo "pref(\"general.useragent.productComment\",\"Gentoo\");" \
		>> ${D}/usr/$(get_libdir)/xulrunner/defaults/pref/vendor.js

	if use java ; then
	    java-pkg_dojar ${D}${MOZILLA_FIVE_HOME}/javaxpcom.jar
	    rm -f ${D}${MOZILLA_FIVE_HOME}/javaxpcom.jar
	fi

	# xulrunner registration, the gentoo way
#	insinto /etc/gre.d
#	newins ${FILESDIR}/${PN}.conf ${PV}.conf
#	sed -i -e \
#		"s|version|${PV}|
#			s|instpath|${MOZILLA_FIVE_HOME}|" \
#		${D}/etc/gre.d/${PV}.conf
}

pkg_postinst() {
	if use python ; then
		python_version
		python_mod_optimize	${ROOT}/usr/$(get_libdir)/python${PYVER}/site-packages/xpcom
	fi
}

pkg_postrm() {
	if use python ; then
		python_version
		python_mod_cleanup
	fi
}
