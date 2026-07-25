# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson

DESCRIPTION="Keyman keyboarding engine core library"
HOMEPAGE="https://keyman.com/ https://github.com/keymanapp/keyman"
SRC_URI="https://downloads.keyman.com/linux/stable/${PV}/keyman-${PV}.tar.gz"
# The core project lives in core/ but pulls sources from the sibling common/.
S="${WORKDIR}/keyman"

LICENSE="MIT"
# Subslot tracks the libkeymancore SONAME so consumers rebuild on ABI bumps.
SLOT="0/2"
KEYWORDS="~amd64"

RDEPEND="dev-libs/icu:="
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

EMESON_SOURCE="${S}/core"

src_configure() {
	local emesonargs=(
		# tests pull an ICU/gtest wrap subproject that would need network access
		-Dkeyman_core_tests=false
	)
	meson_src_configure
}
