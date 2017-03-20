# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

PYTHON_COMPAT=( python2_7 )

inherit python-any-r1

KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~ia64 ~ppc ~ppc64 ~x86 ~amd64-linux ~x86-linux"

SLOT="0"
LICENSE="MPL-2.0 GPL-2"
IUSE="+thunderbird seamonkey"
SRC_URI="http://www.enigmail.net/download/source/${P}.tar.gz"

DEPEND="app-arch/zip"

RDEPEND="thunderbird? ( mail-client/thunderbird[-crypt(-)] )
	seamonkey? ( www-client/seamonkey[-crypt(-)] )
	|| (
		( >=app-crypt/gnupg-2.0
			|| (
				app-crypt/pinentry[gtk(-)]
				app-crypt/pinentry[qt4(-)]
				app-crypt/pinentry[qt5(-)]
			)
		)
		=app-crypt/gnupg-1.4*
	) "

S="${WORKDIR}/${PN}"

src_compile() {
	emake -j1
	emake -j1 xpi
}

src_install() {
	local emid impl
	local enigmail_xpipath="${S}"/build

	cd "${T}" || die
	unzip "${enigmail_xpipath}"/enigmail*.xpi install.rdf || die
	emid=$(sed -n '/<em:id>/!d; s/.*\({.*}\).*/\1/; p; q' install.rdf)

	for impl in thunderbird seamonkey ; do
		if use ${impl} ; then
			dodir /usr/$(get_libdir)/${impl}/extensions/${emid}
			cd "${ED}"/usr/$(get_libdir)/${impl}/extensions/${emid} || die
			unzip "${enigmail_xpipath}"/enigmail*.xpi || die
		fi
	done
	if ! use thunderbird && ! use seamonkey ; then
		dodir /usr/share/${PN}
		cd "${ED}"/usr/share/${PN} || die
		unzip "${enigmail_xpipath}"/enigmail*.xpi || die
	fi
}

pkg_postinst() {
        local peimpl=$(eselect --brief --colour=no pinentry show)
        case "${peimpl}" in
        *gtk*|*qt*) ;;
        *)      ewarn "The pinentry front-end currently selected is not one supported."
                ewarn "You may be prompted for your password in an inaccessible shell!!"
                ewarn "Please use 'eselect pinentry' to select either the gtk or qt front-end"
                ;;
        esac
}
