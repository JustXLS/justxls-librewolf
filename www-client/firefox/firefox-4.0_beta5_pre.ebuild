# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="3"
WANT_AUTOCONF="2.1"

inherit flag-o-matic toolchain-funcs eutils mozconfig-3 makeedit multilib pax-utils fdo-mime autotools mozextension versionator python

MAJ_XUL_PV="2.0"
MAJ_FF_PV="$(get_version_component_range 1-2)" # 3.5, 3.6, 4.0, etc.
XUL_PV="${MAJ_XUL_PV}${PV/${MAJ_FF_PV}/}" # 1.9.3_alpha6, 1.9.2.3, etc.
FF_PV="${PV/_alpha/a}" # Handle alpha for SRC_URI
FF_PV="${FF_PV/_beta/b}" # Handle beta for SRC_URI
CHANGESET="137f0ce0e0ca"
PATCH="${PN}-4.0-patches-0.3"

DESCRIPTION="Firefox Web Browser"
HOMEPAGE="http://www.mozilla.com/firefox"

KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~ppc ~ppc64 ~sparc ~x86 ~amd64-linux ~ia64-linux ~x86-linux ~sparc-solaris ~x64-solaris ~x86-solaris"
SLOT="0"
LICENSE="|| ( MPL-1.1 GPL-2 LGPL-2.1 )"
IUSE="+alsa bindist +cups +ipc libnotify system-sqlite +webm wifi"

REL_URI="http://releases.mozilla.org/pub/mozilla.org/firefox/releases"
# More URIs appended below...
SRC_URI="http://dev.gentoo.org/~anarchy/mozilla/patchsets/${PATCH}.tar.bz2"

RDEPEND="
	>=sys-devel/binutils-2.16.1
	>=dev-libs/nss-3.12.8_beta1
	>=dev-libs/nspr-4.8.5
	>=app-text/hunspell-1.2
	>=x11-libs/cairo-1.8.8[X]
	x11-libs/pango[X]
	alsa? ( media-libs/alsa-lib )
	libnotify? ( >=x11-libs/libnotify-0.4 )
	system-sqlite? ( >=dev-db/sqlite-3.7.0.1[fts3,secure-delete,unlock-notify] )
	wifi? ( net-wireless/wireless-tools )
	cups? ( net-print/cups[gnutls] )
	~net-libs/xulrunner-${XUL_PV}[wifi=,libnotify=,system-sqlite=,webm=]"

DEPEND="${RDEPEND}
	dev-util/pkgconfig"

# No source releases for alpha|beta
if [[ ${PV} =~ alpha|beta ]]; then
	SRC_URI="${SRC_URI}
		http://dev.gentoo.org/~anarchy/mozilla/firefox/firefox-${FF_PV}_${CHANGESET}.source.tar.bz2"
	S="${WORKDIR}/mozilla-central"
else
	SRC_URI="${SRC_URI}
		${REL_URI}/${FF_PV}/source/firefox-${FF_PV}.source.tar.bz2"
	S="${WORKDIR}/mozilla-${MAJ_XUL_PV}"
fi

# No language packs for alphas
if ! [[ ${PV} =~ alpha|beta ]]; then
	# This list can be updated with scripts/get_langs.sh from mozilla overlay
	LANGS="af ar as be bg bn-BD bn-IN ca cs cy da de el en en-GB en-US eo es-AR
	es-CL es-ES es-MX et eu fa fi fr fy-NL ga-IE gl gu-IN he hi-IN hr hu id is
	it ja ka kk kn ko ku lt lv mk ml mr nb-NO nl nn-NO oc or pa-IN pl pt-BR
	pt-PT rm ro ru si sk sl sq sr sv-SE ta ta-LK te th tr uk vi zh-CN zh-TW"
	NOSHORTLANGS="en-GB es-AR es-CL es-MX pt-BR zh-CN zh-TW"

	for X in ${LANGS} ; do
		if [ "${X}" != "en" ] && [ "${X}" != "en-US" ]; then
			SRC_URI="${SRC_URI}
				linguas_${X/-/_}? ( ${REL_URI}/${FF_PV}/linux-i686/xpi/${X}.xpi -> ${P}-${X}.xpi )"
		fi
		IUSE="${IUSE} linguas_${X/-/_}"
		# english is handled internally
		if [ "${#X}" == 5 ] && ! has ${X} ${NOSHORTLANGS}; then
			if [ "${X}" != "en-US" ]; then
				SRC_URI="${SRC_URI}
					linguas_${X%%-*}? ( ${REL_URI}/${FF_PV}/linux-i686/xpi/${X}.xpi -> ${P}-${X}.xpi )"
			fi
			IUSE="${IUSE} linguas_${X%%-*}"
		fi
	done
fi

QA_PRESTRIPPED="usr/$(get_libdir)/${PN}/firefox"

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
		ewarn "Sorry, but ${P} does not support the ${LANG} LINGUA"
	done
}

pkg_setup() {
	# Ensure we always build with C locale.
	export LANG="C"
	export LC_ALL="C"
	export LC_MESSAGES="C"
	export LC_CTYPE="C"

	if ! use bindist ; then
		einfo
		elog "You are enabling official branding. You may not redistribute this build"
		elog "to any users on your network or the internet. Doing so puts yourself into"
		elog "a legal problem with Mozilla Foundation"
		elog "You can disable it by emerging ${PN} _with_ the bindist USE-flag"
	fi

	python_set_active_version 2
}

src_unpack() {
	unpack ${A}

	linguas
	for X in ${linguas}; do
		# FIXME: Add support for unpacking xpis to portage
		[[ ${X} != "en" ]] && xpi_unpack "${P}-${X}.xpi"
	done
}

src_prepare() {
	# Apply our patches
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
	epatch "${WORKDIR}"

	# Allow user to apply any additional patches without modifing ebuild
	epatch_user

	# Ensure we keep a sane enviroment
	sed -i -e "s:MOZ_SERVICES_SYNC\=:MOZ_SERVICES_SYNC\=1:g" \
		${S}/browser/confvars.sh || die "failed to enable sync services"

	eautoreconf

	cd js/src
	eautoreconf
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
	mozconfig_annotate '' --enable-crashreporter
	mozconfig_annotate '' --enable-image-encoder=all
	mozconfig_annotate '' --enable-canvas
	mozconfig_annotate 'gtk' --enable-default-toolkit=cairo-gtk2
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
	mozconfig_annotate '' --with-system-nspr --with-nspr-prefix="${EPREFIX}"/usr
	mozconfig_annotate '' --with-system-nss --with-nss-prefix="${EPREFIX}"/usr
	mozconfig_annotate '' --x-includes="${EPREFIX}"/usr/include	--x-libraries="${EPREFIX}"/usr/$(get_libdir)
	mozconfig_annotate '' --with-system-bz2
	mozconfig_annotate '' --with-system-libevent=/usr
	mozconfig_annotate '' --with-system-libxul
	mozconfig_annotate '' --with-libxul-sdk="${EPREFIX}"/usr/$(get_libdir)/xulrunner-devel-${MAJ_XUL_PV}

	mozconfig_use_enable ipc # +ipc, upstream default
	mozconfig_use_enable libnotify
	mozconfig_use_enable wifi necko-wifi
	mozconfig_use_enable alsa ogg
	mozconfig_use_enable alsa wave
	mozconfig_use_enable system-sqlite
	mozconfig_use_enable webm
	mozconfig_use_enable cups printing
	mozconfig_use_enable !bindist official-branding

	# NOTE: Uses internal copy of libvpx
	if use webm && ! use alsa; then
		ewarn "USE=webm needs USE=alsa, disabling WebM support."
		mozconfig_annotate '+webm -alsa' --disable-webm
	fi

	if use amd64 || use x86 || use arm || use sparc; then
		mozconfig_annotate '' --enable-tracejit
	fi

	# Other ff-specific settings
	mozconfig_annotate '' --with-default-mozilla-five-home=${MOZILLA_FIVE_HOME}

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

	CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" PYTHON="$(PYTHON)" econf
}

src_compile() {
	# Should the build use multiprocessing? Not enabled by default, as it tends to break
	[ "${WANT_MP}" = "true" ] && jobs=${MAKEOPTS} || jobs="-j1"
	emake ${jobs} || die
}

src_install() {
	MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	emake DESTDIR="${D}" install || die "emake install failed"

	linguas
	for X in ${linguas}; do
		[[ ${X} != "en" ]] && xpi_install "${WORKDIR}/${P}-${X}"
	done

	# Install icon and .desktop for menu entry
	if ! use bindist ; then
		newicon "${S}"/other-licenses/branding/firefox/content/icon48.png ${PN}-icon.png
		newmenu "${FILESDIR}"/icon/${PN}-1.5.desktop \
			${PN}-${MAJ_FF_PV}.desktop
	else
		newicon "${S}"/browser/base/branding/icon48.png ${PN}-icon-unbranded.png
		newmenu "${FILESDIR}"/icon/${PN}-1.5-unbranded.desktop \
			${PN}-${MAJ_FF_PV}.desktop
		sed -i -e "s:Bon Echo:Shiretoko:" \
			"${D}"/usr/share/applications/${PN}-${MAJ_FF_PV}.desktop || die "sed failed!"
	fi

	# Add StartupNotify=true bug 237317
	if use startup-notification ; then
		echo "StartupNotify=true" >> "${ED}"/usr/share/applications/${PN}-${MAJ_FF_PV}.desktop
	fi

	pax-mark m "${ED}"/${MOZILLA_FIVE_HOME}/firefox

	# Enable very specific settings not inherited from xulrunner
	cp "${FILESDIR}"/firefox-default-prefs.js \
		"${ED}/${MOZILLA_FIVE_HOME}/defaults/preferences/all-gentoo.js" || \
		die "failed to cp firefox-default-prefs.js"

	# Plugins dir
	dosym ../nsbrowser/plugins "${MOZILLA_FIVE_HOME}"/plugins \
		|| die "failed to symlink"

	# very ugly hack to make firefox not sigbus on sparc
	use sparc && { sed -e 's/Firefox/FirefoxGentoo/g' \
					 -i "${ED}/${MOZILLA_FIVE_HOME}/application.ini" || \
					 die "sparc sed failed"; }
}

pkg_postinst() {
	ewarn "All the packages built against ${PN} won't compile,"
	ewarn "any package that fails to build warrants a bug report."
	elog

	# Update mimedb for the new .desktop file
	fdo-mime_desktop_database_update
}
