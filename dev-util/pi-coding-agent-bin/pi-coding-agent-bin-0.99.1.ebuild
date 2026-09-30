# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="A terminal-based coding agent with multi-model support"
HOMEPAGE="https://github.com/earendil-works/pi"
SRC_URI="
	amd64? ( https://github.com/earendil-works/pi/releases/download/v${PV}/pi-linux-x64.tar.gz -> ${P}-amd64.tar.gz )
	arm64? ( https://github.com/earendil-works/pi/releases/download/v${PV}/pi-linux-arm64.tar.gz -> ${P}-arm64.tar.gz )
"
S="${WORKDIR}"/pi

LICENSE="MIT"
# From dev-lang/bun-bin for the bundled Bun runtime
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 BSD-4 CC0-1.0 IJG ISC"
LICENSE+=" LGPL-2+ LGPL-2.1 public-domain ZLIB"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
IUSE="+system-fd"
RESTRICT="bindist strip"

RDEPEND="
	x11-libs/libxcb
	system-fd? ( sys-apps/fd )
"

QA_PREBUILT="
	opt/${PN}/pi
	opt/${PN}/native/linux/prebuilds/*/*.node
"

src_install() {
	insinto /opt/${PN}
	doins -r .
	fperms +x /opt/${PN}/pi

	dosym ../${PN}/pi /opt/bin/pi
}
