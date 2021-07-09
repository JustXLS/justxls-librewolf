# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6
MOZ_ESR=0

# There are no language packs for librewolf
MOZ_LANGS=()

# Convert the ebuild version to the upstream mozilla version, used by mozlinguas
MOZ_PV="${PV/_beta/b}" # Handle beta for SRC_URI
MOZ_PV="${MOZ_PV/_rc/rc}" # Handle rc for SRC_URI
MOZ_PN="${PN/-bin}"
if [[ ${MOZ_ESR} == 1 ]]; then
	# ESR releases have slightly version numbers
	MOZ_PV="${MOZ_PV}esr"
fi
MOZ_P="${MOZ_PN}-${MOZ_PV}"

MOZ_HTTP_URI="https://archive.mozilla.org/pub/mozilla.org/firefox/releases/"

inherit desktop pax-utils xdg-utils eapi7-ver unpacker multilib

DESCRIPTION="LibreWolf Web Browser"
SRC_URI="${SRC_URI}
	amd64? ( https://gitlab.com/librewolf-community/browser/linux/-/jobs/1373756742/artifacts/raw/LibreWolf-89.0.2-1.x86_64.tar.bz2 -> ${PN}_x86_64-${PV}.tar.bz2 )"
HOMEPAGE="https://librewolf-community.gitlab.io/"
RESTRICT="strip mirror"

KEYWORDS="-* amd64"
SLOT="0"
LICENSE="MPL-2.0 GPL-2 LGPL-2.1"
IUSE="+alsa +ffmpeg +pulseaudio selinux startup-notification wayland"

DEPEND="app-arch/unzip
	alsa? (
		!pulseaudio? (
			dev-util/patchelf
			media-sound/apulse
		)
	)"

# librewolf's binary package needs x11-libs/gtk+:3 with wayland because of this error.
#
#   XPCOMGlueLoad error for file /opt/librewolf/libxul.so:
#   /opt/librewolf/libxul.so: undefined symbol: gdk_wayland_display_get_wl_compositor
#   Couldn't load XPCOM.
#
# As of 86.0 the Arch build of librewolf requires glibc-2.33.
RDEPEND="dev-libs/atk
	>=sys-libs/glibc-2.33
	>=sys-apps/dbus-0.60
	>=dev-libs/dbus-glib-0.72
	>=dev-libs/glib-2.26:2
	media-libs/fontconfig
	>=media-libs/freetype-2.4.10
	>=x11-libs/cairo-1.10[X]
	x11-libs/gdk-pixbuf
	>=x11-libs/gtk+-2.18:2
	>=x11-libs/gtk+-3.4.0:3[wayland,X]
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrender
	x11-libs/libXt
	>=x11-libs/pango-1.22.0
	virtual/freedesktop-icon-theme
	alsa? (
		!pulseaudio? (
			media-sound/apulse
		)
	)
	pulseaudio? ( media-sound/pulseaudio )
	ffmpeg? ( media-video/ffmpeg )
	selinux? ( sec-policy/selinux-mozilla )
"

QA_PREBUILT="
	opt/${MOZ_PN}/*.so
	opt/${MOZ_PN}/${MOZ_PN}
	opt/${MOZ_PN}/${PN}
	opt/${MOZ_PN}/crashreporter
	opt/${MOZ_PN}/webapprt-stub
	opt/${MOZ_PN}/plugin-container
	opt/${MOZ_PN}/mozilla-xremote-client
	opt/${MOZ_PN}/updater
	opt/${MOZ_PN}/minidump-analyzer
	opt/${MOZ_PN}/pingsender
"

S="${WORKDIR}/${MOZ_PN}"

src_unpack() {
	cd "${WORKDIR}"
	mkdir librewolf
	cd librewolf
	unpacker "${A}"
}

src_install() {
	local MOZILLA_FIVE_HOME=/opt/${MOZ_PN}

	# Install firefox in /opt
	dodir ${MOZILLA_FIVE_HOME%/*}
	mv "${S}"/ "${ED%/}"${MOZILLA_FIVE_HOME} || die
	cd "${WORKDIR}" || die

	if ! grep -q '"DisableAppUpdate": true' "${ED%/}${MOZILLA_FIVE_HOME}"/distribution/policies.json
	then
		die
	fi

	# cat "${FILESDIR}"/local-settings.js >> "${ED%/}/${MOZILLA_FIVE_HOME}/defaults/pref/local-settings.js"

	insinto ${MOZILLA_FIVE_HOME}
	# newins "${FILESDIR}"/all-gentoo-3.js all-gentoo.js

	local size sizes icon_path icon name
	sizes="16 32 48 128"
	icon_path="${MOZILLA_FIVE_HOME}/browser/chrome/icons/default"
	icon="${PN}"
	name="Mozilla Firefox (bin)"

	local apulselib=
	if use alsa && ! use pulseaudio; then
		apulselib="${EPREFIX%/}/usr/$(get_libdir)/apulse"
		patchelf --set-rpath "${apulselib}" "${ED%/}"${MOZILLA_FIVE_HOME}/libxul.so || die
	fi

	# Install icons and .desktop for menu entry
	for size in ${sizes} ; do
		insinto "/usr/share/icons/hicolor/${size}x${size}/apps"
		newins "${ED%/}${icon_path}/default${size}.png" "${icon}.png"
	done
	# Install a 48x48 icon into /usr/share/pixmaps for legacy DEs
	newicon "${ED%/}${MOZILLA_FIVE_HOME}/browser/chrome/icons/default/default48.png" ${PN}.png

	# Add StartupNotify=true bug 237317
	local startup_notify="false"
	if use startup-notification ; then
		startup_notify="true"
	fi

	local display_protocols="auto X11" use_wayland="false"
	if use wayland ; then
		display_protocols+=" Wayland"
		use_wayland="true"
	fi

	local app_name desktop_filename display_protocol exec_command
	for display_protocol in ${display_protocols} ; do
		app_name="${name} on ${display_protocol}"
		desktop_filename="${PN}-${display_protocol,,}.desktop"

		case ${display_protocol} in
			Wayland)
				exec_command="${PN}-wayland --name ${PN}-wayland"
				newbin "${FILESDIR}"/firefox-bin-wayland.sh ${PN}-wayland
				;;
			X11)
				if ! use wayland ; then
					# Exit loop here because there's no choice so
					# we don't need wrapper/.desktop file for X11.
					continue
				fi

				exec_command="${PN}-x11 --name ${PN}-x11"
				newbin "${FILESDIR}"/firefox-bin-x11.sh ${PN}-x11
				;;
			*)
				app_name="${name}"
				desktop_filename="${PN}.desktop"
				exec_command='firefox-bin'
				;;
		esac

		newmenu "${FILESDIR}/${PN/librewolf/firefox}-r1.desktop" "${desktop_filename}"
		sed -i \
			-e "s:@NAME@:${app_name}:" \
			-e "s:@EXEC@:${exec_command}:" \
			-e "s:@ICON@:${icon}:" \
			-e "s:@STARTUP_NOTIFY@:${startup_notify}:" \
			"${ED%/}/usr/share/applications/${desktop_filename}" || die
	done

	rm -f "${ED%/}"/usr/bin/librewolf-bin || die
	rm -f "${ED%/}"/opt/librewolf/librewolf-bin || die
	pushd "${ED%/}"/opt/librewolf || die
	ln -sv librewolf librewolf-bin || die
	popd || die
	newbin "${FILESDIR}"/firefox-bin.sh librewolf-bin

	local wrapper
	for wrapper in \
		"${ED%/}"/usr/bin/librewolf-bin \
		"${ED%/}"/usr/bin/librewolf-bin-x11 \
		"${ED%/}"/usr/bin/librewolf-bin-wayland \
	; do
		[[ ! -f "${wrapper}" ]] && continue

		sed -i \
			-e "s:@PREFIX@:${EPREFIX%/}/usr:" \
			-e "s:@MOZ_FIVE_HOME@:${MOZILLA_FIVE_HOME}:" \
			-e "s:@APULSELIB_DIR@:${apulselib}:" \
			-e "s:@DEFAULT_WAYLAND@:${use_wayland}:" \
			"${wrapper}" || die
	done

	# revdep-rebuild entry
	insinto /etc/revdep-rebuild
	echo "SEARCH_DIRS_MASK=${MOZILLA_FIVE_HOME}" >> ${T}/10${PN}
	doins "${T}"/10${PN}

	# Required in order to use plugins and even run firefox on hardened.
	pax-mark mr "${ED%/}"${MOZILLA_FIVE_HOME}/{librewolf,librewolf-bin,plugin-container}

	# Fix libnssckbi.so symlink
	ln -svf /usr/$(get_libdir)/libnssckbi.so "${ED%/}"/opt/librewolf/libnssckbi.so || die
}

pkg_postinst() {
	# Update mimedb for the new .desktop file
	xdg_desktop_database_update
	xdg_icon_cache_update

	if ! has_version 'gnome-base/gconf' || ! has_version 'gnome-base/orbit' \
		|| ! has_version 'net-misc/curl'; then
		einfo
		einfo "For using the crashreporter, you need gnome-base/gconf,"
		einfo "gnome-base/orbit and net-misc/curl emerged."
		einfo
	fi

	use ffmpeg || ewarn "USE=-ffmpeg : HTML5 video will not render without media-video/ffmpeg installed"

	local HAS_AUDIO=0
	if use alsa || use pulseaudio; then
		HAS_AUDIO=1
	fi

	if [[ ${HAS_AUDIO} -eq 0 ]] ; then
		ewarn "USE=-pulseaudio & USE=-alsa : For audio please either set USE=pulseaudio or USE=alsa!"
	fi

	local show_doh_information show_normandy_information

	if [[ -z "${REPLACING_VERSIONS}" ]] ; then
		# New install; Tell user that DoH is disabled by default
		show_doh_information=yes
		show_normandy_information=yes
	else
		local replacing_version
		for replacing_version in ${REPLACING_VERSIONS} ; do
			if ver_test "${replacing_version}" -lt 70 ; then
				# Tell user only once about our DoH default
				show_doh_information=yes
			fi

			if ver_test "${replacing_version}" -lt 74.0-r1 ; then
				# Tell user only once about our Normandy default
				show_normandy_information=yes
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
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
