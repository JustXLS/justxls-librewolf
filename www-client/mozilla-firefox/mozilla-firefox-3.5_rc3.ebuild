# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/www-client/mozilla-firefox/mozilla-firefox-3.0.1.ebuild,v 1.7 2008/09/03 08:47:51 armin76 Exp $
EAPI="2"
WANT_AUTOCONF="2.1"

inherit flag-o-matic toolchain-funcs eutils mozconfig-3 makeedit multilib fdo-mime autotools mozextension
PATCH="${P}-patches-0.1"

LANGS="af ar as be bg bn-BD bn-IN ca cs cy da de el en-GB en-US eo es-AR es-CL
es-ES es-MX et eu fa fi fr fy-NL ga-IE gl gu-IN he hi-IN hr hu id is it ja ka kk
kn ko ku lt lv mk ml mr nb-NO nl nn-NO oc or pa-IN pl pt-BR pt-PT ro ru si sk sl
sq sr sv-SE ta-LK ta te th uk vi zh-CN zh-TW"
NOSHORTLANGS="en-GB es-AR pt-BR zh-CN"

XUL_PV="1.9.1"
MY_PV="${PV/_beta/b}" # Handle betas
MY_PV="${PV/_/}" # Handle rc1, rc2 etc
MAJ_PV="${PV/_*/}"

DESCRIPTION="Firefox Web Browser"
HOMEPAGE="http://www.mozilla.com/firefox"

KEYWORDS="~alpha ~amd64 ~hppa ~ia64 ~ppc ~ppc64 ~sparc ~x86"
SLOT="0"
LICENSE="|| ( MPL-1.1 GPL-2 LGPL-2.1 )"
IUSE="bindist debug iceweasel java mozdevelop qt-experimental restrict-javascript"

REL_URI="http://releases.mozilla.org/pub/mozilla.org/firefox/releases"
SRC_URI="${REL_URI}/${MY_PV}/source/firefox-${MY_PV}-source.tar.bz2
	iceweasel? ( mirror://gentoo/iceweasel-icons-3.0.tar.bz2 )"

for X in ${LANGS} ; do
	if [ "${X}" != "en" ] && [ "${X}" != "en-US" ]; then
		SRC_URI="${SRC_URI}
			linguas_${X/-/_}? ( ${REL_URI}/${MY_PV}/linux-i686/xpi/${X}.xpi -> ${P}-${X}.xpi )"
	fi
	IUSE="${IUSE} linguas_${X/-/_}"
	# english is handled internally
	if [ "${#X}" == 5 ] && ! has ${X} ${NOSHORTLANGS}; then
		if [ "${X}" != "en-US" ]; then
			SRC_URI="${SRC_URI}
				linguas_${X%%-*}? ( ${REL_URI}/${PV}/linux-i686/xpi/${X}.xpi -> ${P}-${X}.xpi )"
		fi
		IUSE="${IUSE} linguas_${X%%-*}"
	fi
done

RDEPEND="
	qt-experimental? (
		x11-libs/qt-gui
		x11-libs/qt-core )

	>=sys-devel/binutils-2.16.1
	>=dev-libs/nss-3.12.2
	>=dev-libs/nspr-4.7.3
	>=dev-db/sqlite-3.6.7
	>=app-text/hunspell-1.2

	=net-libs/xulrunner-${XUL_PV}_${PV/*_/}*[debug=,java=,qt-experimental=]

	>=x11-libs/cairo-1.8.8[X]
	x11-libs/pango[X]"

DEPEND="${RDEPEND}
	dev-util/pkgconfig"

PDEPEND="restrict-javascript? ( x11-plugins/noscript )"

S="${WORKDIR}/mozilla-${XUL_PV}"

# Needed by src_compile() and src_install().
# Would do in pkg_setup but that loses the export attribute, they
# become pure shell variables.
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
		ewarn "Sorry, but ${PN} does not support the ${LANG} LINGUA"
	done
}

pkg_setup(){
	if ! use bindist && ! use iceweasel; then
		elog "You are enabling official branding. You may not redistribute this build"
		elog "to any users on your network or the internet. Doing so puts yourself into"
		elog "a legal problem with Mozilla Foundation"
		elog "You can disable it by emerging ${PN} _with_ the bindist USE-flag"
	fi

	elog ""
	elog "There is now support for libgnomebreakpad; if you do not have bug-buddy installed don't"
	elog "worry about gtk-warning on startup. If you wish to be able to debug crashes in firefox, please"
	elog "install bug-buddy. Thank you the mozilla herd."
}

src_unpack() {
	unpack ${A}

	if use iceweasel; then
		unpack iceweasel-icons-3.0.tar.bz2

		cp -r iceweaselicons/browser "${WORKDIR}"
	fi

	linguas
	for X in ${linguas}; do
		# FIXME: Add support for unpacking xpis to portage
		[[ ${X} != "en" ]] && xpi_unpack "${P}-${X}.xpi"
	done
	if [[ ${linguas} != "" && ${linguas} != "en" ]]; then
		einfo "Selected language packs (first will be default): ${linguas}"
	fi
}

src_prepare() {
	# Apply our patches
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
	epatch "${FILESDIR}"/${PV}

	if use iceweasel; then
		sed -i -e "s|Minefield|Iceweasel|" browser/locales/en-US/chrome/branding/brand.* \
			browser/branding/nightly/configure.sh
	fi

	eautoreconf

	cd js/src
	eautoreconf

	# We need to re-patch this because autoreconf overwrites it
#	epatch "${WORKDIR}"/patch/000_flex-configure-LANG.patch
}

src_configure() {
	MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"
	MEXTENSIONS="default"

	####################################
	#
	# mozconfig, CFLAGS and CXXFLAGS setup
	#
	####################################

	mozconfig_init
	mozconfig_config

	# It doesn't compile on alpha without this LDFLAGS
	use alpha && append-ldflags "-Wl,--no-relax"

	mozconfig_annotate '' --enable-extensions="${MEXTENSIONS}"
	mozconfig_annotate '' --enable-application=browser
	mozconfig_annotate '' --disable-mailnews
	mozconfig_annotate 'broken' --disable-crashreporter
	mozconfig_annotate '' --enable-image-encoder=all
	mozconfig_annotate '' --enable-canvas
	# Bug 60668: Galeon doesn't build without oji enabled, so enable it
	# regardless of java setting.
	mozconfig_annotate '' --enable-oji --enable-mathml
	mozconfig_annotate 'places' --enable-storage --enable-places
	mozconfig_annotate '' --enable-safe-browsing

	# System-wide install specs
	mozconfig_annotate '' --disable-installer
	mozconfig_annotate '' --disable-updater
	mozconfig_annotate '' --disable-strip
	mozconfig_annotate '' --disable-install-strip

	# Use system libraries
	mozconfig_annotate '' --enable-system-cairo
	mozconfig_annotate '' --enable-system-hunspell
	mozconfig_annotate '' --enable-system-sqlite
	mozconfig_annotate '' --with-system-nspr
	mozconfig_annotate '' --with-system-nss
	mozconfig_annotate '' --enable-system-lcms
	mozconfig_annotate '' --with-system-bz2
	mozconfig_annotate '' --with-system-libxul
	mozconfig_annotate '' --with-libxul-sdk=/usr/$(get_libdir)/xulrunner-devel-${XUL_PV}

	# IUSE mozdevelop
	mozconfig_use_enable mozdevelop jsd
	mozconfig_use_enable mozdevelop xpctools
	#mozconfig_use_extension mozdevelop venkman

	# IUSE qt-experimental
	if use qt-experimental; then
		ewarn "You are enabling the EXPERIMENTAL qt toolkit"
		ewarn "Usage is at your own risk"
		ewarn "Known to be broken. DO NOT file bugs."
		mozconfig_annotate '' --disable-system-cairo
		mozconfig_annotate 'qt-experimental' --enable-default-toolkit=cairo-qt
	else
		mozconfig_annotate 'gtk' --enable-default-toolkit=cairo-gtk2
	fi

	# Other ff-specific settings
	mozconfig_annotate '' --with-default-mozilla-five-home=${MOZILLA_FIVE_HOME}

	if ! use bindist && ! use iceweasel; then
		mozconfig_annotate '' --enable-official-branding
	fi

	# Debug
	if use debug; then
		mozconfig_annotate 'debug' --disable-optimize
		mozconfig_annotate 'debug' --enable-debug=-ggdb
		mozconfig_annotate 'debug' --enable-debug-modules=all
		mozconfig_annotate 'debug' --enable-debugger-info-modules
	fi

	# Finalize and report settings
	mozconfig_final

	if [[ $(gcc-major-version) -lt 4 ]]; then
		append-cxxflags -fno-stack-protector
	fi

	####################################
	#
	#  Configure and build
	#
	####################################

	CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" \
	econf || die
}

src_compile() {
	# Should the build use multiprocessing? Not enabled by default, as it tends to break
	[ "${WANT_MP}" = "true" ] && jobs=${MAKEOPTS} || jobs="-j1"
	emake ${jobs} || die
}

src_install() {
	emake DESTDIR="${D}" install || die "emake install failed"
	rm "${D}"/usr/bin/firefox

	linguas
	for X in ${linguas}; do
		[[ ${X} != "en" ]] && xpi_install "${WORKDIR}"/"${P}-${X}"
	done

	cp "${FILESDIR}"/gentoo-default-prefs.js \
		"${D}"${MOZILLA_FIVE_HOME}/defaults/preferences/all-gentoo.js

	local LANG=${linguas%% *}
	if [[ -n ${LANG} && ${LANG} != "en" ]]; then
		elog "Setting default locale to ${LANG}"
		dosed -e "s:general.useragent.locale\", \"en-US\":general.useragent.locale\", \"${LANG}\":" \
			${MOZILLA_FIVE_HOME}/defaults/preferences/firefox.js \
			${MOZILLA_FIVE_HOME}/defaults/preferences/firefox-l10n.js || \
			die "sed failed to change locale"
	fi

	# Install icon and .desktop for menu entry
	if use iceweasel; then
		newicon "${S}"/browser/base/branding/icon48.png iceweasel-icon.png
		newmenu "${FILESDIR}"/icon/iceweasel.desktop \
			${PN}-${MAJ_PV}.desktop
	elif ! use bindist; then
		newicon "${S}"/other-licenses/branding/firefox/content/icon48.png firefox-icon.png
		newmenu "${FILESDIR}"/icon/mozilla-firefox-1.5.desktop \
			${PN}-${MAJ_PV}.desktop
	else
		newicon "${S}"/browser/base/branding/icon48.png firefox-icon-unbranded.png
		newmenu "${FILESDIR}"/icon/mozilla-firefox-1.5-unbranded.desktop \
			${PN}-${MAJ_PV}.desktop
		sed -e "s/Bon Echo/Minefield/" \
			-i "${D}"/usr/share/applications/${PN}-${MAJ_PV}.desktop
	fi

	# Create /usr/bin/firefox
	cat <<EOF >"${D}"/usr/bin/firefox
#!/bin/sh
export LD_LIBRARY_PATH="${MOZILLA_FIVE_HOME}"
exec "${MOZILLA_FIVE_HOME}"/firefox "\$@"
EOF

	fperms 0755 /usr/bin/firefox

	# Plugins dir
	ln -s "${D}"/usr/$(get_libdir)/{nsbrowser,mozilla-firefox}/plugins
}

pkg_postinst() {
	ewarn "All the packages built against ${PN} won't compile,"
	ewarn "if after installing firefox 3.0 you get some blockers,"
	ewarn "please add 'xulrunner' to your USE-flags."
	elog

	# Update mimedb for the new .desktop file
	fdo-mime_desktop_database_update
}
