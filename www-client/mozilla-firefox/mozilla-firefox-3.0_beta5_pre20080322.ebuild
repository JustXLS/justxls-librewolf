# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/www-client/mozilla-firefox/mozilla-firefox-2.0.0.9.ebuild,v 1.7 2007/11/12 16:57:25 drac Exp $
EAPI="1"
WANT_AUTOCONF="2.1"

inherit flag-o-matic toolchain-funcs eutils mozconfig-minefield makeedit multilib fdo-mime autotools mozilla-launcher

#PATCH="${PN}-2.0.0.8-patches-0.2"
#LANGS="be ca cs de el es-AR es-ES eu fi fr fy-NL gu-IN ja ko nb-NO nl pa-IN  pl pt-PT ro ru sk sv-SE tr uk zh-CN"
#NOSHORTLANGS="es-AR"

MY_PV=${PV/_beta/b}
MY_P="${PN}-${MY_PV}"

DESCRIPTION="Firefox Web Browser"
HOMEPAGE="http://www.mozilla.org/projects/firefox/"

KEYWORDS="~alpha ~amd64 ~hppa ~ia64 ~ppc ~ppc64 ~sparc ~x86"
SLOT="0"
LICENSE="MPL-1.1 GPL-2 LGPL-2.1"
IUSE="java mozdevelop bindist restrict-javascript +xulrunner"

#MOZ_URI="http://releases.mozilla.org/pub/mozilla.org/firefox/releases/${MY_PV}"
#SRC_URI="${MOZ_URI}/source/firefox-${MY_PV}-source.tar.bz2"
#	mirror://gentoo/${PATCH}.tar.bz2"
SRC_URI="http://dev.gentooexperimental.org/~armin76/dist/${P}.tar.bz2"

# These are in
#
#  http://releases.mozilla.org/pub/mozilla.org/firefox/releases/${PV}/linux-i686/xpi/
#
# for i in $LANGS $SHORTLANGS; do wget $i.xpi -O ${P}-$i.xpi; done
for X in ${LANGS} ; do
	SRC_URI="${SRC_URI}
		linguas_${X/-/_}? ( http://dev.gentooexperimental.org/~armin76/dist/${MY_P}-xpi/${MY_P}-${X}.xpi )"
	IUSE="${IUSE} linguas_${X/-/_}"
	# english is handled internally
	if [ "${#X}" == 5 ] && ! has ${X} ${NOSHORTLANGS}; then
		SRC_URI="${SRC_URI}
			linguas_${X%%-*}? ( http://dev.gentooexperimental.org/~armin76/dist/${MY_P}-xpi/${MY_P}-${X}.xpi )"
		IUSE="${IUSE} linguas_${X%%-*}"
	fi
done

RDEPEND="java? ( virtual/jre )
	>=www-client/mozilla-launcher-1.58
	>=sys-devel/binutils-2.16.1
	>=dev-libs/nss-3.12_beta2
	>=dev-libs/nspr-4.7
	>=media-libs/lcms-1.17
	>=app-text/hunspell-1.1.9
	>=dev-db/sqlite-3.3.17
	xulrunner? ( >=net-libs/xulrunner-1.9_beta5_alpha )"


DEPEND="${RDEPEND}
	java? ( >=dev-java/java-config-0.2.0 )"

PDEPEND="restrict-javascript? ( x11-plugins/noscript )"

S="${WORKDIR}/mozilla"

# Needed by src_compile() and src_install().
# Would do in pkg_setup but that loses the export attribute, they
# become pure shell variables.
export MOZ_CO_PROJECT=browser
export BUILD_OFFICIAL=1
export MOZILLA_OFFICIAL=1

linguas() {
	local LANG SLANG
	for LANG in ${LINGUAS}; do
		if has ${LANG} en en_US; then
			has en ${linguas} || linguas="${linguas:+"${linguas} "}en"
			continue
		elif has ${LANG} ${LANGS//-/_}; then
			has ${LANG//_/-} ${linguas} || linguas="${linguas:+"${linguas} "}${LANG//_/-}"
			continue
		elif [[ " ${LANGS} " == *" ${LANG}-"* ]]; then
			for X in ${LANGS}; do
				if [[ "${X}" == "${LANG}-"* ]] && \
					[[ " ${NOSHORTLANGS} " != *" ${X} "* ]]; then
					has ${X} ${linguas} || linguas="${linguas:+"${linguas} "}${X}"
					continue 2
				fi
			done
		fi
		ewarn "Sorry, but mozilla-firefox does not support the ${LANG} LINGUA"
	done
}

pkg_setup(){
	if ! built_with_use x11-libs/cairo X; then
		eerror "Cairo is not built with X useflag."
		eerror "Please add 'X' to your USE flags, and re-emerge cairo."
		die "Cairo needs X"
	fi

	if ! use bindist; then
		elog "You are enabling official branding. You may not redistribute this build"
		elog "to any users on your network or the internet. Doing so puts yourself into"
		elog "a legal problem with Mozilla Foundation"
		elog "You can disable it by emerging ${PN} _with_ the bindist USE-flag"

	fi

	use moznopango && warn_mozilla_launcher_stub
}

src_unpack() {
	unpack ${A}
# ${PATCH}.tar.bz2

#	linguas
#	for X in ${linguas}; do
#		[[ ${X} != "en" ]] && xpi_unpack "${MY_P}-${X}.xpi"
#	done
#	if [[ ${linguas} != "" ]]; then
#		einfo "Selected language packs (first will be default): ${linguas}"
#	fi

	# Apply our patches
	cd "${S}" || die "cd failed"
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
#	epatch "${WORKDIR}"/patch

	#add the standard gentoo plugins dir
	epatch "${FILESDIR}"/064_firefox-nsplugins-v3.patch
	#Fix when using system hunspell
	epatch "${FILESDIR}"/100-system-hunspell-corrections.patch
	#make loading certs behave with system nss
	epatch "${FILESDIR}"/068_firefox-nss-gentoo-fix.patch
	#Fix typeahead
	epatch "${FILESDIR}"/667_typeahead-broken-v4.patch

	epatch "${FILESDIR}"/001-firefox_gentoo_install_dirs.patch
	epatch "${FILESDIR}"/bz386904_config_rules_install_dist_files.patch
	epatch "${FILESDIR}"/installer_shouldnt_copy_xulrunner.patch

	if use xulrunner; then
		epatch "${FILESDIR}"/002-dont_depend_on_nspr_sources.patch
		epatch "${FILESDIR}"/003-nspr_flags_by_pkg_config_hack.patch
	fi

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

	eautoreconf || die "failed  running eautoreconf"
}

src_compile() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"
	MEXTENSIONS="default,typeaheadfind"

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
	mozconfig_annotate '' --enable-system-hunspell
#	mozconfig_annotate '' --enable-system-sqlite
	mozconfig_annotate '' --enable-image-encoder=all
	mozconfig_annotate '' --enable-canvas
#	mozconfig_annotate '' --with-system-nspr
#	mozconfig_annotate '' --with-system-nss
	mozconfig_annotate '' --enable-system-lcms
	mozconfig_annotate '' --enable-oji --enable-mathml
	mozconfig_annotate 'places' --enable-storage --enable-places --enable-places_bookmarks

	# Other ff-specific settings
	#mozconfig_use_enable mozdevelop jsd
	#mozconfig_use_enable mozdevelop xpctools
	mozconfig_use_extension mozdevelop venkman
	mozconfig_annotate '' --with-default-mozilla-five-home=${MOZILLA_FIVE_HOME}
	if use xulrunner; then
		# Add xulrunner variable
		mozconfig_annotate '' --with-libxul-sdk=/usr/$(get_libdir)/xulrunner-1.9
	fi

	if ! use bindist; then
		mozconfig_annotate '' --enable-official-branding
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

	# This removes extraneous CFLAGS from the Makefiles to reduce RAM
	# requirements while compiling
	edit_makefiles

	# Should the build use multiprocessing? Not enabled by default, as it tends to break
	[ "${WANT_MP}" = "true" ] && jobs=${MAKEOPTS} || jobs="-j1"
	emake ${jobs} || die
}

src_install() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"
	if use xulrunner; then
		PKG_CONFIG=`which pkg-config`
		X_DATE=`date +%Y%m%d`
		XULRUNNER_VERSION=`${PKG_CONFIG} --modversion libxul`
	fi

	emake DESTDIR="${D}" install || die "emake install failed"
	rm "${D}"/usr/bin/firefox

	linguas
	for X in ${linguas}; do
		[[ ${X} != "en" ]] && xpi_install "${WORKDIR}"/"${MY_P}-${X}"
	done

	local LANG=${linguas%% *}
	if [[ -n ${LANG} && ${LANG} != "en" ]]; then
		elog "Setting default locale to ${LANG}"
		dosed -e "s:general.useragent.locale\", \"en-US\":general.useragent.locale\", \"${LANG}\":" \
			${MOZILLA_FIVE_HOME}/defaults/preferences/firefox.js \
			${MOZILLA_FIVE_HOME}/defaults/preferences/firefox-l10n.js || \
			die "sed failed to change locale"
	fi

	# Install icon and .desktop for menu entry
	if ! use bindist; then
		 newicon "${S}"/other-licenses/branding/firefox/content/icon48.png firefox-icon.png
		newmenu "${FILESDIR}"/icon/mozilla-firefox-1.5.desktop \
			mozilla-firefox-3.0.desktop
	else
		newicon "${S}"/browser/base/branding/firefox/content/icon48.png firefox-icon-unbranded.png
		newmenu "${FILESDIR}"/icon/mozilla-firefox-1.5-unbranded.desktop \
			mozilla-firefox-3.0.desktop
	fi

	dodir ${MOZILLA_FIVE_HOME}/defaults/preferences
	cp "${FILESDIR}"/gentoo-default-prefs.js "${D}"${MOZILLA_FIVE_HOME}/defaults/preferences/all-gentoo.js

	if use xulrunner; then
		#set the application.ini
		sed -i -e "s|BuildID=.*$|BuildID=${X_DATE}GentooMozillaFirefox|"	"${D}"${MOZILLA_FIVE_HOME}/application.ini
		sed -i -e "s|MinVersion=.*$|MinVersion=${XULRUNNER_VERSION}|" "${D}"${MOZILLA_FIVE_HOME}/application.ini
		sed -i -e "s|MaxVersion=.*$|MaxVersion=${XULRUNNER_VERSION}|" "${D}"${MOZILLA_FIVE_HOME}/application.ini
		# Create /usr/bin/firefox
		install_mozilla_launcher_stub firefoxxul ${MOZILLA_FIVE_HOME}
	else
		# Create /usr/bin/firefox
		install_mozilla_launcher_stub firefox ${MOZILLA_FIVE_HOME}
	fi
}

pkg_postinst() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	ewarn "All the packages built against ${PN} won't compile,"
	ewarn "since they should be built against net-libs/xulrunner,"
	ewarn "therefore you should check if your package builds against"
	ewarn "xulrunner and if it doesn't, file a bug, thanks."

	# This should be called in the postinst and postrm of all the
	# mozilla, mozilla-bin, firefox, firefox-bin, thunderbird and
	# thunderbird-bin ebuilds.
	update_mozilla_launcher_symlinks

	# Update mimedb for the new .desktop file
	fdo-mime_desktop_database_update
}

pkg_postrm() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	update_mozilla_launcher_symlinks
}


