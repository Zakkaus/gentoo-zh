# Copyright 2023-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg unpacker

DESCRIPTION="Platform for API design, debugging, testing, and documentation"
HOMEPAGE="https://apifox.com/"
SRC_URI="
	amd64? ( https://file-assets.apifox.com/download/Apifox-linux-latest.zip -> ${P}-amd64.zip )
"

S="${WORKDIR}"
LICENSE="all-rights-reserved"
# From www-client/chromium for the bundled Electron runtime
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
# From net-libs/nodejs
LICENSE+=" Apache-1.1 BlueOak-1.0.0"

SLOT="0"
KEYWORDS="~amd64"

RESTRICT="bindist mirror strip"

RDEPEND="sys-fs/fuse:0"
BDEPEND="app-arch/unzip"

src_install() {
	into /opt/apifox
	dobin "${S}/Apifox.AppImage"
	domenu "${FILESDIR}/apifox.desktop"
	doicon -s scalable "${FILESDIR}/apifox.svg"
}
