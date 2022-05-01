# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

MOZ_ESR=

MOZ_PV=${PV}
MOZ_PV_SUFFIX=
if [[ ${PV} =~ (_(alpha|beta|rc).*)$ ]] ; then
	MOZ_PV_SUFFIX=${BASH_REMATCH[1]}

	# Convert the ebuild version to the upstream Mozilla version
	MOZ_PV="${MOZ_PV/_alpha/a}" # Handle alpha for SRC_URI
	MOZ_PV="${MOZ_PV/_beta/b}"  # Handle beta for SRC_URI
	MOZ_PV="${MOZ_PV%%_rc*}"    # Handle rc for SRC_URI
fi

if [[ -n ${MOZ_ESR} ]] ; then
	# ESR releases have slightly different version numbers
	MOZ_PV="${MOZ_PV}esr"
fi

MOZ_PN="${PN%-bin}"
MOZ_P="${MOZ_PN}-${MOZ_PV}"
MOZ_PV_DISTFILES="${MOZ_PV}${MOZ_PV_SUFFIX}"
MOZ_P_DISTFILES="${MOZ_PN}-${MOZ_PV_DISTFILES}"

inherit desktop linux-info pax-utils xdg

MOZ_SRC_BASE_URI="https://archive.mozilla.org/pub/${MOZ_PN}/releases/${MOZ_PV}"

SRC_URI="${SRC_URI}
	amd64? ( https://gitlab.com/api/v4/projects/12829184/packages/generic/librewolf/99.0.1-4/LibreWolf-99.0.1-4.x86_64.tar.bz2 )
	arm64? ( https://gitlab.com/api/v4/projects/12829184/packages/generic/librewolf/99.0.1-4/LibreWolf-99.0.1-4.aarch64.tar.bz2 )"

DESCRIPTION="LibreWolf Web Browser"
HOMEPAGE="https://librewolf-community.gitlab.io/"

KEYWORDS="-* amd64"
SLOT="0"
LICENSE="MPL-2.0 GPL-2 LGPL-2.1"
IUSE="+alsa +ffmpeg +pulseaudio selinux wayland"

RESTRICT="strip"

BDEPEND="app-arch/unzip
	alsa? (
		!pulseaudio? (
			dev-util/patchelf
		)
	)"

COMMON_DEPEND="alsa? (
		!pulseaudio? (
			media-sound/apulse
		)
	)"

DEPEND="${COMMON_DEPEND}"

# x11-libs/gtk+ needs wayland and X
RDEPEND="${COMMON_DEPEND}
	dev-libs/atk
	dev-libs/dbus-glib
	>=dev-libs/glib-2.26:2
	media-libs/alsa-lib
	media-libs/fontconfig
	>=media-libs/freetype-2.4.10
	sys-apps/dbus
	virtual/freedesktop-icon-theme
	>=x11-libs/cairo-1.10[X]
	x11-libs/gdk-pixbuf:2
	>=x11-libs/gtk+-3.11:3[wayland,X]
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXcursor
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXi
	x11-libs/libXrandr
	x11-libs/libXrender
	x11-libs/libXtst
	x11-libs/libxcb
	>=x11-libs/pango-1.22.0
	alsa? (
		  !pulseaudio? ( media-sound/apulse )
	)
	ffmpeg? ( media-video/ffmpeg )
	pulseaudio? ( media-sound/pulseaudio )
	selinux? ( sec-policy/selinux-mozilla )
"

QA_PREBUILT="opt/${MOZ_PN}/*"

# Allow MOZ_GMP_PLUGIN_LIST to be set in an eclass or
# overridden in the enviromnent (advanced hackers only)
if [[ -z "${MOZ_GMP_PLUGIN_LIST+set}" ]] ; then
	MOZ_GMP_PLUGIN_LIST=( gmp-gmpopenh264 gmp-widevinecdm )
fi

MOZ_LANGS=()

mozilla_set_globals() {
	# https://bugs.gentoo.org/587334
	local MOZ_TOO_REGIONALIZED_FOR_L10N=(
		fy-NL ga-IE gu-IN hi-IN hy-AM nb-NO ne-NP nn-NO pa-IN sv-SE
	)

	local lang xflag
	for lang in "${MOZ_LANGS[@]}" ; do
		# en and en_US are handled internally
		if [[ ${lang} == en ]] || [[ ${lang} == en-US ]] ; then
			continue
		fi

		# strip region subtag if $lang is in the list
		if has ${lang} "${MOZ_TOO_REGIONALIZED_FOR_L10N[@]}" ; then
			xflag=${lang%%-*}
		else
			xflag=${lang}
		fi

		SRC_URI+=" l10n_${xflag/[_@]/-}? ("
		SRC_URI+=" ${MOZ_SRC_BASE_URI}/linux-x86_64/xpi/${lang}.xpi -> ${MOZ_P_DISTFILES}-${lang}.xpi"
		SRC_URI+=" )"
		IUSE+=" l10n_${xflag/[_@]/-}"
	done
}
mozilla_set_globals

moz_install_xpi() {
	debug-print-function ${FUNCNAME} "$@"

	if [[ ${#} -lt 2 ]] ; then
		die "${FUNCNAME} requires at least two arguments"
	fi

	local DESTDIR=${1}
	shift

	insinto "${DESTDIR}"

	local emid xpi_file xpi_tmp_dir
	for xpi_file in "${@}" ; do
		emid=
		xpi_tmp_dir=$(mktemp -d --tmpdir="${T}")

		# Unpack XPI
		unzip -qq "${xpi_file}" -d "${xpi_tmp_dir}" || die

		# Determine extension ID
		if [[ -f "${xpi_tmp_dir}/install.rdf" ]] ; then
			emid=$(sed -n -e '/install-manifest/,$ { /em:id/!d; s/.*[\">]\([^\"<>]*\)[\"<].*/\1/; p; q }' "${xpi_tmp_dir}/install.rdf")
			[[ -z "${emid}" ]] && die "failed to determine extension id from install.rdf"
		elif [[ -f "${xpi_tmp_dir}/manifest.json" ]] ; then
			emid=$(sed -n -e 's/.*"id": "\([^"]*\)".*/\1/p' "${xpi_tmp_dir}/manifest.json")
			[[ -z "${emid}" ]] && die "failed to determine extension id from manifest.json"
		else
			die "failed to determine extension id"
		fi

		einfo "Installing ${emid}.xpi into ${ED}${DESTDIR} ..."
		newins "${xpi_file}" "${emid}.xpi"
	done
}

pkg_setup() {
	CONFIG_CHECK="~SECCOMP"
	WARNING_SECCOMP="CONFIG_SECCOMP not set! This system will be unable to play DRM-protected content."

	linux-info_pkg_setup
}

src_unpack() {
	local _lp_dir="${WORKDIR}/language_packs"
	local _src_file

	mkdir "${S}" || die

	if [[ ! -d "${_lp_dir}" ]] ; then
		mkdir "${_lp_dir}" || die
	fi

	for _src_file in ${A} ; do
		if [[ ${_src_file} == *.xpi ]]; then
			cp "${DISTDIR}/${_src_file}" "${_lp_dir}" || die "Failed to copy '${_src_file}' to '${_lp_dir}'!"
		else
			MY_SRC_FILE=${_src_file}
		fi
	done
}

src_install() {
	# Set MOZILLA_FIVE_HOME
	local MOZILLA_FIVE_HOME="/opt/${MOZ_PN}"

	dodir /opt
	# The tar file doesn't start in a directory called "librewolf"
	dodir /opt/"${MOZ_PN}"
	pushd "${ED}"/opt/"${MOZ_PN}" &>/dev/null || die
	unpack "${MY_SRC_FILE}"
	popd &>/dev/null || die

	pax-mark m \
		"${ED}${MOZILLA_FIVE_HOME}"/${MOZ_PN} \
		"${ED}${MOZILLA_FIVE_HOME}"/${MOZ_PN}-bin \
		"${ED}${MOZILLA_FIVE_HOME}"/plugin-container

	# Patch alsa support
	local apulselib=
	if use alsa && ! use pulseaudio ; then
		apulselib="${EPREFIX}/usr/$(get_libdir)/apulse"
		patchelf --set-rpath "${apulselib}" "${ED}${MOZILLA_FIVE_HOME}/libxul.so" || die
	fi

	# Install policy (currently only used to disable application updates)
	# insinto "${MOZILLA_FIVE_HOME}/distribution"
	# newins "${FILESDIR}"/disable-auto-update.policy.json policies.json

	# Install system-wide preferences
	local PREFS_DIR="${MOZILLA_FIVE_HOME}/browser/defaults/preferences"
	# insinto "${PREFS_DIR}"
	# newins "${FILESDIR}"/gentoo-default-prefs.js all-gentoo.js

	# local GENTOO_PREFS="${ED}${PREFS_DIR}/all-gentoo.js"

	# if ! use gmp-autoupdate ; then
	# 	local plugin
	# 	for plugin in "${MOZ_GMP_PLUGIN_LIST[@]}" ; do
	# 		einfo "Disabling auto-update for ${plugin} plugin ..."
	# 		cat >>"${GENTOO_PREFS}" <<-EOF || die "failed to disable autoupdate for ${plugin} media plugin"
	# 		pref("media.${plugin}.autoupdate",   false);
	# 		EOF
	# 	done
	# fi

	# Install language packs
	local langpacks=( $(find "${WORKDIR}/language_packs" -type f -name '*.xpi') )
	if [[ -n "${langpacks}" ]] ; then
		moz_install_xpi "${MOZILLA_FIVE_HOME}/distribution/extensions" "${langpacks[@]}"
	fi

	# Install icons
	local icon_srcdir="${ED}/${MOZILLA_FIVE_HOME}/browser/chrome/icons/default"

	insinto /usr/share/icons/hicolor/symbolic/apps

	local icon size
	for icon in "${icon_srcdir}"/default*.png ; do
		size=${icon%.png}
		size=${size##*/default}

		if [[ ${size} -eq 48 ]] ; then
			newicon "${icon}" ${PN}.png
		fi

		newicon -s ${size} "${icon}" ${PN}.png
	done

	# Install menu
	local app_name="LibreWolf (bin)"
	local desktop_file="${FILESDIR}/firefox-bin-r3.desktop"
	local desktop_filename="${PN}.desktop"
	local exec_command="${PN}"
	local icon="${PN}"
	local use_wayland="false"

	if use wayland ; then
		use_wayland="true"
	fi

	cp "${desktop_file}" "${WORKDIR}/${PN}.desktop-template" || die

	sed -i \
		-e "s:@NAME@:${app_name}:" \
		-e "s:@EXEC@:${exec_command}:" \
		-e "s:@ICON@:${icon}:" \
		"${WORKDIR}/${PN}.desktop-template" \
		|| die

	newmenu "${WORKDIR}/${PN}.desktop-template" "${desktop_filename}"

	rm "${WORKDIR}/${PN}.desktop-template" || die

	# Install wrapper script
	[[ -f "${ED}/usr/bin/${PN}" ]] && rm "${ED}/usr/bin/${PN}"
	newbin "${FILESDIR}/firefox-bin-r1.sh" ${PN}

	# Update wrapper
	sed -i \
		-e "s:@PREFIX@:${EPREFIX}/usr:" \
		-e "s:@MOZ_FIVE_HOME@:${MOZILLA_FIVE_HOME}:" \
		-e "s:@APULSELIB_DIR@:${apulselib}:" \
		-e "s:@DEFAULT_WAYLAND@:${use_wayland}:" \
		"${ED}/usr/bin/${PN}" \
		|| die
}

pkg_postinst() {
	xdg_pkg_postinst

	# if ! use gmp-autoupdate ; then
	# 	elog "USE='-gmp-autoupdate' has disabled the following plugins from updating or"
	# 	elog "installing into new profiles:"
	# 	local plugin
	# 	for plugin in "${MOZ_GMP_PLUGIN_LIST[@]}" ; do
	# 		elog "\t ${plugin}"
	# 	done
	# 	elog
	# fi

	if ! has_version 'gnome-base/gconf' || ! has_version 'gnome-base/orbit' \
		|| ! has_version 'net-misc/curl'; then
		einfo
		einfo "For using the crashreporter, you need gnome-base/gconf,"
		einfo "gnome-base/orbit and net-misc/curl emerged."
		einfo
	fi

	use ffmpeg || ewarn "USE=-ffmpeg : HTML5 video will not render without media-video/ffmpeg installed"

	local show_doh_information show_normandy_information show_shortcut_information

	if [[ -z "${REPLACING_VERSIONS}" ]] ; then
		# New install; Tell user that DoH is disabled by default
		show_doh_information=yes
		show_normandy_information=yes
		show_shortcut_information=no
	else
		local replacing_version
		for replacing_version in ${REPLACING_VERSIONS} ; do
			if ver_test "${replacing_version}" -lt 91.0 ; then
				# Tell user that we no longer install a shortcut
				# per supported display protocol
				show_shortcut_information=yes
			fi
		done
	fi

	if [[ -n "${show_doh_information}" ]] ; then
		elog
		elog "Note regarding Trusted Recursive Resolver aka DNS-over-HTTPS (DoH):"
		elog "Due to privacy concerns (encrypting DNS might be a good thing, sending all"
		elog "DNS traffic to Cloudflare by default is not a good idea and applications"
		elog "should respect OS configured settings), \"network.trr.mode\" was set to 5"
		elog "(\"Off by choice\") by default."
		elog "You can enable DNS-over-HTTPS in ${PN^}'s preferences."
	fi

	# bug 713782
	if [[ -n "${show_normandy_information}" ]] ; then
		elog
		elog "Upstream operates a service named Normandy which allows Mozilla to"
		elog "push changes for default settings or even install new add-ons remotely."
		elog "While this can be useful to address problems like 'Armagadd-on 2.0' or"
		elog "revert previous decisions to disable TLS 1.0/1.1, privacy and security"
		elog "concerns prevail, which is why we have switched off the use of this"
		elog "service by default."
		elog
		elog "To re-enable this service set"
		elog
		elog "    app.normandy.enabled=true"
		elog
		elog "in about:config."
	fi

	if [[ -n "${show_shortcut_information}" ]] ; then
		elog
		elog "Since firefox-91.0 we no longer install multiple shortcuts for"
		elog "each supported display protocol.  Instead we will only install"
		elog "one generic Mozilla Firefox shortcut."
		elog "If you still want to be able to select between running Mozilla Firefox"
		elog "on X11 or Wayland, you have to re-create these shortcuts on your own."
	fi
}
