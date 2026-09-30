# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="tatt probe"
HOMEPAGE="https://github.com/gentoo-zh/overlay"
S="${WORKDIR}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="foo +bar"

src_install() {
	insinto /usr/share/tatt-probe
	usex foo foo nofoo > flags || die
	doins flags
}
