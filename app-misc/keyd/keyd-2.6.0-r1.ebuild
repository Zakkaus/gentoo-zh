# Copyright 2024-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..15} )

inherit python-single-r1 systemd toolchain-funcs

DESCRIPTION="A key remapping daemon for linux"
HOMEPAGE="https://github.com/rvaiya/keyd"
SRC_URI="https://github.com/rvaiya/keyd/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"
DEPEND="acct-group/keyd"
RDEPEND="
	${DEPEND}
	${PYTHON_DEPS}
"

src_prepare() {
	sed -i -e "/-groupadd keyd/d" -e "/-D_FORTIFY_SOURCE=2/d" -e "s/ -O3//" Makefile || die
	default
}

src_compile() {
	emake CC="$(tc-getCC)" PREFIX="${EPREFIX}/usr"
}

src_install() {
	dobin bin/keyd
	dobin bin/keyd-application-mapper
	python_fix_shebang "${ED}"/usr/bin/keyd-application-mapper

	sed -e 's#@PREFIX@#/usr#' keyd.service.in > keyd.service || die
	systemd_dounit keyd.service

	insinto /usr/share/keyd
	doins data/keyd.compose
	doins -r data/gnome-extension{,-45} layouts

	dodoc docs/{CHANGELOG.md,DESIGN.md}
	dodoc README.md
	dodoc -r examples

	insinto /etc/keyd
	doins "${FILESDIR}"/default.conf
	gzip -d data/{keyd,keyd-application-mapper}.1.gz || die
	doman data/{keyd,keyd-application-mapper}.1
}
