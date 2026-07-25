# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson

DESCRIPTION="Keyman system service for keyboard installation over D-Bus"
HOMEPAGE="https://keyman.com/ https://github.com/keymanapp/keyman"
SRC_URI="https://downloads.keyman.com/linux/stable/${PV}/keyman-${PV}.tar.gz"
S="${WORKDIR}/keyman"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	dev-libs/libevdev
	|| ( sys-apps/systemd sys-auth/elogind )
"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

EMESON_SOURCE="${S}/linux/keyman-system-service"
