# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-libs/xulrunner/xulrunner-1.9.2.ebuild,v 1.2 2010/01/22 13:43:38 anarchy Exp $

EAPI="2"
WANT_AUTOCONF="2.1"

inherit flag-o-matic toolchain-funcs eutils mozconfig-3 makeedit multilib autotools python versionator pax-utils

MAJ_XUL_PV="$(get_version_component_range 1-2)" # from mozilla-* branch name
MAJ_FF_PV="4.0"
FF_PV="${PV/${MAJ_XUL_PV}/${MAJ_FF_PV}}" # 3.7_alpha6, 3.6.3, etc.
FF_PV="${FF_PV/_alpha/a}" # Handle alpha for SRC_URI
FF_PV="${FF_PV/_beta/b}" # Handle beta for SRC_URI
CHANGESET="72ec4df3de76"
PATCH="${PN}-2.0-patches-0.2"

DESCRIPTION="Mozilla runtime package that can be used to bootstrap XUL+XPCOM applications"
HOMEPAGE="http://developer.mozilla.org/en/docs/XULRunner"

KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~ppc ~ppc64 ~sparc ~x86"
SLOT="1.9"
LICENSE="|| ( MPL-1.1 GPL-2 LGPL-2.1 )"
IUSE="+alsa debug +cups +ipc libnotify system-sqlite +webm wifi"

# More URIs appended below...
SRC_URI="http://dev.gentoo.org/~anarchy/mozilla/patchsets/${PATCH}.tar.bz2"

RDEPEND="
	>=sys-devel/binutils-2.16.1
	>=dev-libs/nss-3.12.8_beta1
	>=dev-libs/nspr-4.8.5
	>=app-text/hunspell-1.2
	>=x11-libs/cairo-1.8.8[X]
	>=dev-libs/libevent-1.4.7
	x11-libs/pango[X]
	x11-libs/libXt
	x11-libs/pixman
	alsa? ( media-libs/alsa-lib )
	libnotify? ( >=x11-libs/libnotify-0.4 )
	system-sqlite? ( >=dev-db/sqlite-3.7.0.1[fts3,secure-delete,unlock-notify] )
	wifi? ( net-wireless/wireless-tools )
	cups? ( net-print/cups[gnutls] )"

DEPEND="${RDEPEND}
	=dev-lang/python-2*[threads]
	dev-util/pkgconfig"

if [[ ${PV} =~ alpha|beta ]]; then
	# hg snapshot tarball
	SRC_URI="${SRC_URI}
		http://dev.gentoo.org/~anarchy/mozilla/firefox/firefox-${FF_PV}_${CHANGESET}.source.tar.bz2"
	S="${WORKDIR}/mozilla-central"
else
	REL_URI="http://releases.mozilla.org/pub/mozilla.org/firefox/releases"
	SRC_URI="${SRC_URI}
		${REL_URI}/${FF_PV}/source/firefox-${FF_PV}.source.tar.bz2"
	S="${WORKDIR}/mozilla-${MAJ_XUL_PV}"
fi

pkg_setup() {
	# Ensure we always build with C locale.
	export LANG="C"
	export LC_ALL="C"
	export LC_MESSAGES="C"
	export LC_CTYPE="C"

	python_set_active_version 2
}

src_prepare() {
	# Apply our patches
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
	epatch "${WORKDIR}"

	# Allow user to apply any additional patches without modifing ebuild
	epatch_user

	# Same as in config/autoconf.mk.in
	MOZLIBDIR="/usr/$(get_libdir)/${PN}-${MAJ_XUL_PV}"
	SDKDIR="/usr/$(get_libdir)/${PN}-devel-${MAJ_XUL_PV}/sdk"

	# Gentoo install dirs
	sed -i -e "s:@PV@:${MAJ_XUL_PV}:" "${S}"/config/autoconf.mk.in \
		|| die "${MAJ_XUL_PV} sed failed!"

	# Enable gnomebreakpad
	if use debug ; then
		sed -i -e "s:GNOME_DISABLE_CRASH_DIALOG=1:GNOME_DISABLE_CRASH_DIALOG=0:g" \
			"${S}"/build/unix/run-mozilla.sh || die "sed failed!"
	fi

	#Ensure we disable javaxpcom by default to prevent configure breakage
	sed -i -e s:MOZ_JAVAXPCOM\=1::g ${S}/xulrunner/confvars.sh

	eautoreconf

	cd js/src
	eautoreconf
}

src_configure() {
	####################################
	#
	# mozconfig, CFLAGS and CXXFLAGS setup
	#
	####################################

	mozconfig_init
	mozconfig_config

	MEXTENSIONS="default"

	MOZLIBDIR="/usr/$(get_libdir)/${PN}-${MAJ_XUL_PV}"

	# It doesn't compile on alpha without this LDFLAGS
	use alpha && append-ldflags "-Wl,--no-relax"

	mozconfig_annotate '' --with-default-mozilla-five-home="${MOZLIBDIR}"
	mozconfig_annotate '' --enable-extensions="${MEXTENSIONS}"
	mozconfig_annotate '' --enable-application=xulrunner
	mozconfig_annotate '' --disable-mailnews
	mozconfig_annotate 'broken' --disable-crashreporter
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
	mozconfig_annotate '' --with-system-nspr
	mozconfig_annotate '' --with-system-nss
	mozconfig_annotate '' --with-system-bz2
	mozconfig_annotate '' --with-system-libevent=/usr

	mozconfig_use_enable ipc # +ipc, upstream default
	mozconfig_use_enable libnotify
	mozconfig_use_enable wifi necko-wifi
	mozconfig_use_enable alsa ogg
	mozconfig_use_enable alsa wave
	mozconfig_use_enable system-sqlite
	mozconfig_use_enable webm
	mozconfig_use_enable cups printing

	# NOTE: Uses internal copy of libvpx
	if use webm && ! use alsa; then
		ewarn "USE=webm needs USE=alsa, disabling WebM support."
		mozconfig_annotate '+webm -alsa' --disable-webm
	fi

	if use amd64 || use x86 || use arm || use sparc; then
		mozconfig_annotate 'tracejit' --enable-tracejit
	fi

	# Debug
	if use debug ; then
		mozconfig_annotate 'debug' --disable-optimize
		mozconfig_annotate 'debug' --enable-debug=-ggdb
		mozconfig_annotate 'debug' --enable-debug-modules=all
		mozconfig_annotate 'debug' --enable-debugger-info-modules
	fi

	# Finalize and report settings
	mozconfig_final

	if [[ $(gcc-major-version) -lt 4 ]]; then
		append-flags -fno-stack-protector
	fi

	####################################
	#
	#  Configure and build
	#
	####################################

	# Disable no-print-directory
	MAKEOPTS=${MAKEOPTS/--no-print-directory/}

	# Ensure that are plugins dir is enabled as default
	sed -i -e "s:/usr/lib/mozilla/plugins:/usr/$(get_libdir)/nsbrowser/plugins:" \
		"${S}"/xpcom/io/nsAppFileLocationProvider.cpp || die "sed failed to replace plugin path!"

	CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" PYTHON="$(PYTHON)" econf
}

src_install() {
	emake DESTDIR="${D}" install || die "emake install failed"

	rm "${D}"/usr/bin/xulrunner

	MOZLIBDIR="/usr/$(get_libdir)/${PN}-${MAJ_XUL_PV}"
	SDKDIR="/usr/$(get_libdir)/${PN}-devel-${MAJ_XUL_PV}/sdk"

	if has_multilib_profile; then
		local config
		for config in "${D}"/etc/gre.d/*.system.conf ; do
			mv "${config}" "${config%.conf}.${CHOST}.conf"
		done
	fi

	dodir /usr/bin
	dosym "${MOZLIBDIR}/xulrunner" "/usr/bin/xulrunner-${MAJ_XUL_PV}" || die

	# env.d file for ld search path
	dodir /etc/env.d
	echo "LDPATH=${MOZLIBDIR}" > "${D}"/etc/env.d/08xulrunner || die "env.d failed"

	# Add our defaults to xulrunner and out of firefox
	cp "${FILESDIR}"/xulrunner-default-prefs.js \
		"${D}/${MOZLIBDIR}/defaults/pref/all-gentoo.js" || \
			die "failed to cp xulrunner-default-prefs.js"

	pax-mark m "${D}"/${MOZLIBDIR}/plugin-container
}

pkg_postinst() {
	ewarn "If firefox fails to start with \"failed to load xpcom\", run revdep-rebuild"
	ewarn "If that does not fix the problem, rebuild dev-libs/nss"
	ewarn "Try dev-util/lafilefixer if you get build failures related to .la files"

	einfo
	ewarn "Any package that requires xulrunner:1.9 slot could and most likely will"
	ewarn "have issues. These issues should be reported to maintainer,"
	ewarn "and mozilla@gentoo.org should be CC'd on the bug report."
}
