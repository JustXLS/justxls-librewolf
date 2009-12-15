# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/www-client/seamonkey/seamonkey-2.0_rc2-r1.ebuild,v 1.1 2009/10/26 00:35:30 anarchy Exp $

EAPI="2"
WANT_AUTOCONF="2.1"

inherit flag-o-matic toolchain-funcs eutils mozconfig-3 makeedit multilib fdo-mime autotools mozextension java-pkg-opt-2

PATCH="${PN}-2.0-patches-0.1"
EMVER="0.97a0"

LANGS="be ca cs de en-US es-AR es-ES fr gl hu it ka lt nb-NO nl pl pt-PT ru sk sv-SE tr"
NOSHORTLANGS="es-AR es-ES nb-NO pt-PT sv-SE"

MY_PV="${PV/_rc/rc}"
MY_P="${PN}-${MY_PV}"

DESCRIPTION="Seamonkey Web Browser"
HOMEPAGE="http://www.seamonkey-project.org"

KEYWORDS="~alpha ~amd64 ~hppa ~ia64 ~ppc ~ppc64 ~sparc ~x86"
SLOT="0"
LICENSE="|| ( MPL-1.1 GPL-2 LGPL-2.1 )"
IUSE="+alsa +crypt java ldap mozdevelop moznocompose moznoirc moznomail moznoroaming sqlite restrict-javascript"

REL_URI="http://releases.mozilla.org/pub/mozilla.org/${PN}/releases"
SRC_URI="${REL_URI}/${MY_PV}/source/${MY_P}.source.tar.bz2
	http://dev.gentoo.org/~anarchy/dist/${PATCH}.tar.bz2
	crypt? ( !moznomail? ( http://dev.gentoo.org/~anarchy/dist/enigmail-${EMVER}-20091011.tar.gz ) )"

for X in ${LANGS} ; do
	if [ "${X}" != "en" ] && [ "${X}" != "en-US" ]; then
		SRC_URI="${SRC_URI}
			linguas_${X/-/_}? ( ${REL_URI}/${MY_PV}/langpack/${MY_P}.${X}.langpack.xpi -> ${MY_P}-${X}.xpi )"
	fi
	IUSE="${IUSE} linguas_${X/-/_}"
	# english is handled internally
	if [ "${#X}" == 5 ] && ! has ${X} ${NOSHORTLANGS}; then
		if [ "${X}" != "en-US" ]; then
			SRC_URI="${SRC_URI}
				linguas_${X%%-*}? ( ${REL_URI}/${MY_PV}/langpack/${MY_P}.${X}.langpack.xpi -> ${MY_P}-${X}.xpi )"
		fi
		IUSE="${IUSE} linguas_${X%%-*}"
	fi
done

RDEPEND="java? ( virtual/jre )
	>=sys-devel/binutils-2.16.1
	>=dev-libs/nss-3.12.2
	>=dev-libs/nspr-4.8
	alsa? ( media-libs/alsa-lib )
	sqlite? ( >=dev-db/sqlite-3.6.10 )
	>=app-text/hunspell-1.2
	x11-libs/cairo[X]
	x11-libs/pango[X]
	crypt? ( !moznomail? ( >=app-crypt/gnupg-1.4 ) )"

DEPEND="${RDEPEND}
	dev-util/pkgconfig
	java? ( >=virtual/jdk-1.4 )"

PDEPEND="restrict-javascript? ( www-plugins/noscript )"

S="${WORKDIR}/comm-1.9.1"

# Needed by src_compile() and src_install().
# Would do in pkg_setup but that loses the export attribute,
# they become pure shell variables.
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

src_unpack() {
	unpack ${A}

	linguas
	for X in ${linguas}; do
		# FIXME: Add support for unpacking xpis to portage
		[[ ${X} != "en" ]] && xpi_unpack "${MY_P}-${X}.xpi"
	done
	if [[ ${linguas} != "" && ${linguas} != "en" ]]; then
		einfo "Selected language packs (first will be default): ${linguas}"
	fi
}

pkg_setup() {
	java-pkg-opt-2_pkg_setup

	if use sqlite ; then
		einfo
		elog "You are enabling system sqlite. Do not file a bug with gentoo if you have"
		elog "issues that arise from enabling system sqlite. All bugs will be concidered"
		elog  "invalid. All patches are welcomed to fix any issues that might be found with"
		elog "system sqlite. If you are starting with a fresh profile you can enable sqlite"
		elog  "without any major issues."
		epause 10
	fi
}

src_prepare() {
	java-pkg-opt-2_src_prepare

	# Apply our patches
	EPATCH_EXCLUDE="108-fix_ftbfs_with_cairo_fb.patch" \
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
	epatch "${WORKDIR}"

	if use crypt && ! use moznomail; then
		mv "${WORKDIR}"/enigmail "${S}"/mailnews/extensions/enigmail
		cd "${S}"/mailnews/extensions/enigmail || die
		epatch "${FILESDIR}"/enigmail/70_enigmail-fix.patch
		epatch "${FILESDIR}"/enigmail/0.95.0-replytolist.patch
		makemake2
		cd "${S}"
	fi

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

	if use moznoirc ; then
		MEXTENSIONS="${MEXTENSIONS},-irc"
	fi
	if use moznoroaming ; then
		MEXTENSIONS="${MEXTENSIONS},-sroaming"
	fi

	if ! use gnome ; then
		MEXTENSIONS="${MEXTENSIONS},-gnomevfs"
	fi

	if use moznomail ; then
		mozconfig_annotate '+moznomail' --disable-mailnews
	fi

	if use moznocompose ; then
		if use moznoirc && use moznomail ; then
			mozconfig_annotate '+moznocompose' --disable-composer
		fi
	fi

	mozconfig_annotate '' --enable-extensions="${MEXTENSIONS}"
	mozconfig_annotate '' --enable-application=suite
	mozconfig_annotate 'broken' --disable-mochitest
	mozconfig_annotate 'broken' --disable-crashreporter
	mozconfig_annotate '' --enable-system-hunspell
	mozconfig_annotate '' --enable-system-sqlite
	mozconfig_annotate '' --enable-image-encoder=all
	mozconfig_annotate '' --enable-canvas
	mozconfig_annotate '' --with-system-nspr
	mozconfig_annotate '' --with-system-nss
	mozconfig_annotate '' --enable-system-lcms
	mozconfig_annotate '' --enable-oji --enable-mathml
	mozconfig_annotate 'places' --enable-storage --enable-places --enable-places_bookmarks
	mozconfig_annotate '' --disable-installer
	mozconfig_annotate '' --with-default-mozilla-five-home=${MOZILLA_FIVE_HOME}

	# Enable/Disable based on USE flags
	mozconfig_use_enable alsa ogg
	mozconfig_use_enable alsa wave
	mozconfig_use_enable ldap
	mozconfig_use_enable ldap ldap-experimental
	mozconfig_use_enable sqlite system-sqlite
	mozconfig_use_enable java javaxpcom

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

	CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" econf
}

src_compile() {
	# Should the build use multiprocessing? Not enabled by default, as it tends to break.
	[ "${WANT_MP}" = "true" ] && jobs=${MAKEOPTS} || jobs="-j1"
	emake ${jobs} || die

	# Only build enigmail extension if conditions are met.
	if use crypt && ! use moznomail; then
		emake -C "${S}"/mailnews/extensions/enigmail || die "make enigmail failed"
		emake -j1 -C "${S}"/mailnews/extensions/enigmail xpi || die "make enigmail xpi failed"
	fi
}

src_install() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"
	declare emid

	emake DESTDIR="${D}" install || die "emake install failed"

	if use crypt && ! use moznomail; then
		cd "${T}"
		unzip "${S}"/mozilla/dist/bin/enigmail*.xpi install.rdf
		emid=$(sed -n '/<em:id>/!d; s/.*\({.*}\).*/\1/; p; q' install.rdf)

		dodir ${MOZILLA_FIVE_HOME}/extensions/${emid}
		cd "${D}"${MOZILLA_FIVE_HOME}/extensions/${emid}
		unzip "${S}"/mozilla/dist/bin/enigmail*.xpi
	fi

	linguas
	for X in ${linguas}; do
		[[ ${X} != "en" ]] && xpi_install "${WORKDIR}"/"${MY_P}-${X}"
	done

	local LANG=${linguas%% *}
	if [[ -n ${LANG} && ${LANG} != "en" ]]; then
		elog "Setting default locale to ${LANG}"
		dosed -e "s:general.useragent.locale\", \"en-US\":general.useragent.locale\", \"${LANG}\":" \
			${MOZILLA_FIVE_HOME}/defaults/pref/suite-l10n.js || \
			die "sed failed to change locale"
	fi

	# Install icon and .desktop for menu entry
	newicon "${S}"/suite/branding/content/icon64.png seamonkey.png
	domenu "${FILESDIR}"/icon/seamonkey.desktop

	# Add StartupNotify=true bug 290401
	if use startup-notification ; then
		echo "StartupNotify=true" >> "${D}"/usr/share/applications/seamonkey.desktop
	fi

	# Add vendor
	echo "pref(\"general.useragent.vendor\",\"Gentoo\");" \
		>> "${D}"${MOZILLA_FIVE_HOME}/defaults/pref/vendor.js

	# Plugins dir
	rm -rf "${D}"${MOZILLA_FIVE_HOME}/plugins || die "failed to remove existing plugins dir"
	dosym ../nsbrowser/plugins "${MOZILLA_FIVE_HOME}"/plugins

	# shiny new man page
	doman "${S}"/suite/app/${PN}.1
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

	if ! use moznoirc ; then
		elog "chatzilla is now an extension which can be en-/disabled and configured via"
		elog "the Add-on manager."
	fi
}
