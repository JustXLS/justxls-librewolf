# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/www-client/seamonkey/seamonkey-2.0.4-r1.ebuild,v 1.1 2010/04/09 03:56:59 polynomial-c Exp $

EAPI="2"
WANT_AUTOCONF="2.1"

inherit flag-o-matic toolchain-funcs eutils mozconfig-3 makeedit multilib fdo-mime autotools mozextension python

PATCH="${PN}-2.0.5-patches-01"
EMVER="1.1.2"

LANGS="be cs de en en-US es-AR es-ES fr lt nl pl pt-PT ru sk"
NOSHORTLANGS="es-AR es-ES"

MY_PV="${PV/_pre*}"
MY_PV="${MY_PV/_alpha/a}"
MY_PV="${MY_PV/_beta/b}"
MY_PV="${MY_PV/_rc/rc}"
MY_P="${PN}-${MY_PV}"

[[ ${MY_PV} == 2.1b3 ]] && MY_PV="${MY_PV}-real"

# release versions usually have language packs. So be careful with changing this.
HAS_LANGS="true"
if [[ ${PV} == *_pre* ]] ; then
	# pre-releases. No need for arch teams to change KEYWORDS here.

	REL_URI="ftp://ftp.mozilla.org/pub/mozilla.org/${PN}/nightly/${MY_PV}-candidates/build${PV##*_pre}"
	#KEYWORDS=""
	KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~ppc ~ppc64 ~sparc ~x86"
	#HAS_LANGS="false"
else
	# This is where arch teams should change the KEYWORDS.

	REL_URI="http://releases.mozilla.org/pub/mozilla.org/${PN}/releases/${MY_PV}"
	KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~ppc ~ppc64 ~sparc ~x86"
	[[ ${PV} == *alpha* ]] && HAS_LANGS="false"
fi

DESCRIPTION="Seamonkey Web Browser"
HOMEPAGE="http://www.seamonkey-project.org"

SLOT="0"
LICENSE="|| ( MPL-1.1 GPL-2 LGPL-2.1 )"
IUSE="+alsa +chatzilla +composer +crypt gconf ldap +mailclient +roaming +webm"

SRC_URI="${REL_URI}/source/${MY_P}.source.tar.bz2
	http://dev.gentoo.org/~polynomial-c/mozilla/patchsets/${PATCH}.tar.bz2
	crypt? ( mailclient? ( http://dev.gentoo.org/~polynomial-c/mozilla/enigmail-${EMVER}-20110124.tar.bz2 ) )"

if ${HAS_LANGS} ; then
	for X in ${LANGS} ; do
		if [ "${X}" != "en" ] ; then
			SRC_URI="${SRC_URI}
				linguas_${X/-/_}? ( ${REL_URI}/langpack/${MY_P}.${X}.langpack.xpi -> ${MY_P}-${X}.xpi )"
		fi
		IUSE="${IUSE} linguas_${X/-/_}"
		# english is handled internally
		if [ "${#X}" == 5 ] && ! has ${X} ${NOSHORTLANGS}; then
			#if [ "${X}" != "en-US" ]; then
				SRC_URI="${SRC_URI}
					linguas_${X%%-*}? ( ${REL_URI}/langpack/${MY_P}.${X}.langpack.xpi -> ${MY_P}-${X}.xpi )"
			#fi
			IUSE="${IUSE} linguas_${X%%-*}"
		fi
	done
fi

RDEPEND=">=sys-devel/binutils-2.16.1
	>=dev-libs/nss-3.12.9
	>=dev-libs/nspr-4.8.7
	>=media-libs/libpng-1.4.1[apng]
	>=x11-libs/pango-1.14.0[X]
	gconf? ( >=gnome-base/gconf-1.2.1:2 )
	crypt? ( mailclient? ( >=app-crypt/gnupg-1.4 ) )
	webm? ( media-libs/libvpx
		media-libs/alsa-lib )"

DEPEND="${RDEPEND}
	dev-util/pkgconfig
	dev-lang/yasm"

S="${WORKDIR}/comm-central"

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

src_unpack() {
	unpack ${A}

	if ${HAS_LANGS} ; then
		linguas
		for X in ${linguas}; do
			# FIXME: Add support for unpacking xpis to portage
			[[ ${X} != "en" ]] && xpi_unpack "${MY_P}-${X}.xpi"
		done
		if [[ ${linguas} != "" && ${linguas} != "en" ]]; then
			einfo "Selected language packs (first will be default): ${linguas}"
		fi
	fi
}

pkg_setup() {
	if [[ ${PV} == *_pre* ]] ; then
		ewarn "You're using an unofficial release of ${PN}. Don't file any bug in"
		ewarn "Gentoo's Bugtracker against this package in case it breaks for you."
		ewarn "Those belong to upstream: https://bugzilla.mozilla.org"
	fi

	moz_pkgsetup
}

src_prepare() {
	# Apply our patches
	EPATCH_EXCLUDE="1002_fix-system-hunspell-dict-detections.patch
			104-no_dynamic_nss_softokn.patch
			118-bz467766_att351173-dont-reset-user-prefs-on-upgrade.patch
			310-gecko-1.9.1-cairo-1.8.10-crash-fix.patch" \
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
	epatch "${WORKDIR}"

	epatch "${FILESDIR}"/2.1/${PN}-2.1b1-configure-fix.patch
	if has_version \>=media-libs/libpng-1.5.0 ; then
		epatch "${FILESDIR}"/2.1/xulrunner-libpng15.diff
	fi
	epatch "${FILESDIR}"/2.1/${PN}-2.1b2-gconf-config-update.patch

	EPATCH_OPTS="-R" \
	epatch "${FILESDIR}"/2.1/${PN}-2.1b3-restore-tabbar-scrolling-from-b2.diff

	if use crypt && use mailclient ; then
		mv "${WORKDIR}"/enigmail "${S}"/mailnews/extensions/enigmail
		cd "${S}"/mailnews/extensions/enigmail || die
		epatch "${FILESDIR}"/enigmail/enigmail-1.1.2-seamonkey-2.1b3-versionfix.patch
		epatch "${FILESDIR}"/enigmail/enigmail-1.1.2-20110124-makefile.diff
		eautomake
		makemake2
		sed -e 's:@srcdir@:${S}/mailnews/extensions/enigmail:' \
			-i Makefile.in || die
		cd "${S}"
	fi

	#pushd "${S}"/mozilla &>/dev/null || die pushd
	#popd &>/dev/null || die popd

	#Ensure we disable javaxpcom by default to prevent configure breakage
	sed -i -e s:MOZ_JAVAXPCOM\=1::g ${S}/mozilla/xulrunner/confvars.sh \
		|| die "sed javaxpcom"

	# Disable gnomevfs extension
	sed -i -e "s:gnomevfs::" "${S}/"suite/confvars.sh \
		|| die "Failed to remove gnomevfs extension"

	eautoreconf
	cd "${S}"/mozilla || die
	eautoreconf
	cd "${S}"/mozilla/js/src || die
	eautoreconf
}

src_configure() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"
	MEXTENSIONS=""

	####################################
	#
	# mozconfig, CFLAGS and CXXFLAGS setup
	#
	####################################

	mozconfig_init
	mozconfig_config

	# It doesn't compile on alpha without this LDFLAGS
	use alpha && append-ldflags "-Wl,--no-relax"

	if ! use chatzilla ; then
		MEXTENSIONS="${MEXTENSIONS},-irc"
	fi
	if ! use roaming ; then
		MEXTENSIONS="${MEXTENSIONS},-sroaming"
	fi

	if ! use composer ; then
		if ! use chatzilla && ! use mailclient ; then
			mozconfig_annotate '-composer' --disable-composer
		fi
	fi

	mozconfig_annotate '' --enable-extensions="${MEXTENSIONS}"
	mozconfig_annotate '' --enable-jsd
	mozconfig_annotate '' --enable-canvas
	mozconfig_annotate '' --with-default-mozilla-five-home=${MOZILLA_FIVE_HOME}

	mozconfig_use_enable gconf
	mozconfig_use_enable ldap
	mozconfig_use_enable ldap ldap-experimental
	mozconfig_use_enable mailclient mailnews

	if use mailclient && use crypt ; then
		mozconfig_annotate "mail crypt" --enable-chrome-format=jar
	fi

        # ZOMG! Mozilla guys wanna have APNG in libpng if building with
        # system-libpng. Kids, leave your fingers from drugs that make you
        # do such nasty "extensions"!!!
        # See https://bugs.gentoo.org/183370 for details.
        mozconfig_annotate '' --with-system-png

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

	# Work around breakage in makeopts with --no-print-directory
	MAKEOPTS="${MAKEOPTS/--no-print-directory/}"

	CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" PYTHON="$(PYTHON)" econf
}

src_compile() {
	# Should the build use multiprocessing? Not enabled by default, as it tends to break.
	[ "${WANT_MP}" = "true" ] && jobs=${MAKEOPTS} || jobs="-j1"
	emake ${jobs} || die

	# Only build enigmail extension if conditions are met.
	if use crypt && use mailclient ; then
		emake -C "${S}"/mailnews/extensions/enigmail || die "make enigmail failed"
		emake -j1 -C "${S}"/mailnews/extensions/enigmail xpi || die "make enigmail xpi failed"
	fi
}

src_install() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"
	declare emid

	emake DESTDIR="${D}" install || die "emake install failed"
	cp -f "${FILESDIR}"/icon/seamonkey.desktop "${T}" || die

	if use crypt && use mailclient ; then
		cd "${T}" || die
		unzip "${S}"/mozilla/dist/bin/enigmail*.xpi install.rdf || die
		emid=$(sed -n '/<em:id>/!d; s/.*\({.*}\).*/\1/; p; q' install.rdf)

		dodir ${MOZILLA_FIVE_HOME}/extensions/${emid} || die
		cd "${D}"${MOZILLA_FIVE_HOME}/extensions/${emid} || die
		unzip "${S}"/mozilla/dist/bin/enigmail*.xpi || die

		sed 's|^\(MimeType=.*\)$|\1MimeType=text/x-vcard;text/directory;application/mbox;message/rfc822;x-scheme-handler/mailto;|' \
			-i "${T}"/${PN}.desktop || die
		sed 's|^\(Categories=.*\)$|\1Email;|' -i "${T}"/${PN}.desktop \
			|| die
	fi

	if ${HAS_LANGS} ; then
		linguas
		for X in ${linguas}; do
			[[ ${X} != "en" ]] && xpi_install "${WORKDIR}"/"${MY_P}-${X}"
		done
	fi

	# Install icon and .desktop for menu entry
	newicon "${S}"/suite/branding/nightly/content/icon64.png seamonkey.png \
		|| die
	domenu "${T}"/seamonkey.desktop || die

	# Add StartupNotify=true bug 290401
	if use startup-notification ; then
		echo "StartupNotify=true" >> "${D}"/usr/share/applications/seamonkey.desktop
	fi

	# Add our default prefs
	sed "s|SEAMONKEY_PVR|${PVR}|" "${FILESDIR}"/all-gentoo.js \
		> "${D}"${MOZILLA_FIVE_HOME}/defaults/pref/all-gentoo.js \
			|| die

	# Plugins dir
	rm -rf "${D}"${MOZILLA_FIVE_HOME}/plugins || die "failed to remove existing plugins dir"
	dosym ../nsbrowser/plugins "${MOZILLA_FIVE_HOME}"/plugins || die

	doman "${S}"/suite/app/${PN}.1 || die
}

pkg_preinst() {
	declare MOZILLA_FIVE_HOME="${ROOT}/usr/$(get_libdir)/${PN}"

	if [ -d ${MOZILLA_FIVE_HOME}/plugins ] ; then
		rm ${MOZILLA_FIVE_HOME}/plugins -rf
	fi
}

pkg_postinst() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	# Update mimedb for the new .desktop file
	fdo-mime_desktop_database_update

	if use chatzilla ; then
		elog "chatzilla is now an extension which can be en-/disabled and configured via"
		elog "the Add-on manager."
	fi
}
