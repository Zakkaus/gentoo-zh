# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

MY_PN="fcitx5-keyman"

inherit cmake optfeature unpacker xdg

DESCRIPTION="Keyman input method engine for Fcitx5"
HOMEPAGE="https://github.com/fcitx/fcitx5-keyman"
SRC_URI="https://download.fcitx-im.org/fcitx5/${MY_PN}/${MY_PN}-${PV}.tar.zst"
S="${WORKDIR}/${MY_PN}-${PV}"

LICENSE="GPL-2+"
SLOT="5"
KEYWORDS="~amd64"

RDEPEND="
	>=app-i18n/fcitx-5.1.13:5
	>=app-i18n/keyman-core-18:=
	dev-cpp/nlohmann_json
"
DEPEND="${RDEPEND}"
BDEPEND="
	kde-frameworks/extra-cmake-modules:0
	sys-devel/gettext
	virtual/pkgconfig
"

PATCHES=(
	"${FILESDIR}"/${P}-cmake_316.patch
)

pkg_postinst() {
	xdg_pkg_postinst
	optfeature "downloading and installing Keyman keyboards" app-i18n/keyman-config
}
