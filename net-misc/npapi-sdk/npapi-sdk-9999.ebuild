# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=4
inherit autotools-utils

#if LIVE
EGIT_REPO_URI="git://github.com/mgorny/${PN}.git
	http://github.com/mgorny/${PN}.git"
inherit autotools git-2
#endif

DESCRIPTION="NPAPI headers bundle"
HOMEPAGE="https://github.com/mgorny/npapi-sdk/"
SRC_URI="http://cloud.github.com/downloads/mgorny/${PN}/${P}.tar.bz2"

LICENSE="MPL-1.1"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND="!net-libs/xulrunner"
#if LIVE

KEYWORDS=
SRC_URI=

src_prepare() {
	autotools-utils_src_prepare
	eautoreconf
}
#endif
