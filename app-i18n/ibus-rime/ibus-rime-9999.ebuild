# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="Rime Input Method Engine for IBus Framework"
HOMEPAGE="https://rime.im/ https://github.com/rime/ibus-rime"
EGIT_REPO_URI="https://github.com/rime/${PN}.git"
EGIT_SUBMODULES=()

LICENSE="GPL-3+"
SLOT="0"

COMMON_DEPEND="app-i18n/ibus
	app-i18n/librime:=
	dev-libs/glib:2
	x11-libs/libnotify"
DEPEND="${COMMON_DEPEND}"
RDEPEND="${COMMON_DEPEND}
	app-i18n/rime-data"
BDEPEND="
	sys-devel/gettext
	virtual/pkgconfig
"

src_configure() {
	local mycmakeargs=(
		-DRIME_DATA_DIR="${EPREFIX}/usr/share/rime-data"
	)
	cmake_src_configure
}
