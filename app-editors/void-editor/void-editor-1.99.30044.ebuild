# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

DESCRIPTION="Void Editor - AI Code Editor"
HOMEPAGE="https://voideditor.com"

SRC_URI="https://github.com/voideditor/binaries/releases/download/${PV}/Void-linux-x64-${PV}.tar.gz"
S="${WORKDIR}"

LICENSE="Apache-2.0 MIT"
# From www-client/chromium for the bundled Electron runtime
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
# From net-libs/nodejs
LICENSE+=" Apache-1.1 BlueOak-1.0.0"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="mirror strip"

RDEPEND="
	app-crypt/libsecret
	x11-libs/libX11
	x11-libs/libxkbfile
	sys-apps/ripgrep
"

QA_PREBUILT="
	opt/void/*
"

src_install() {
	insinto /opt/void
	doins -r "${S}"/*
	fperms +x /opt/void/void
	dosym ../../opt/void/void /usr/bin/void

	domenu "${FILESDIR}"/void-editor.desktop
	doicon -s 256 "${S}/resources/app/resources/linux/code.png"
	dodoc "${S}/LICENSES.chromium.html"
}
