# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson optfeature xdg

DESCRIPTION="Keyman input method engine for IBus"
HOMEPAGE="https://keyman.com/ https://github.com/keymanapp/keyman"
SRC_URI="https://downloads.keyman.com/linux/stable/${PV}/keyman-${PV}.tar.gz"
S="${WORKDIR}/keyman"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	>=app-i18n/keyman-core-18:=
	app-i18n/ibus
	app-i18n/keyman-system-service
	dev-libs/icu:=
	dev-libs/json-glib
	x11-libs/gtk+:3
	|| ( sys-apps/systemd sys-auth/elogind )
"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

PATCHES=(
	"${FILESDIR}"/${P}-system-keyman-core.patch
)

EMESON_SOURCE="${S}/linux/ibus-keyman"

pkg_postinst() {
	xdg_pkg_postinst
	optfeature "downloading and installing Keyman keyboards" app-i18n/keyman-config
}
