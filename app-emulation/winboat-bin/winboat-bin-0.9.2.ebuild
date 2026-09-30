# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg unpacker

DESCRIPTION="Run Windows apps on Linux with seamless integration"
HOMEPAGE="https://www.winboat.app/"
SRC_URI="https://github.com/winboat-org/winboat/releases/download/v${PV}/winboat-${PV}-amd64.deb"

S="${WORKDIR}"
LICENSE="MIT"
# From www-client/chromium for the bundled Electron runtime
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
# From net-libs/nodejs
LICENSE+=" Apache-1.1 BlueOak-1.0.0"
SLOT="0"
KEYWORDS="~amd64"

RESTRICT="strip"

RDEPEND="
	app-containers/docker
	app-containers/docker-compose
	dev-libs/nspr
	dev-libs/nss
	net-misc/freerdp:3
	virtual/libudev
"

src_prepare() {
	default

	for mode in argon2 usb; do
		local pre="${S}/opt/winboat/resources/app.asar.unpacked/node_modules/${mode}/prebuilds"
		if [[ -d ${pre} ]]; then
			find "${pre}/" -mindepth 1 -maxdepth 1 ! -name "linux-x64" -type d -exec rm -rf {} + || die
			rm -f "${pre}/linux-x64/"*musl* || die
		fi
	done
}

src_install() {
	insinto /opt/winboat
	doins -r "${S}"/opt/winboat/*
	fperms +x /opt/winboat/winboat
	fperms +x /opt/winboat/chrome-sandbox
	fperms +x /opt/winboat/chrome_crashpad_handler
	domenu "${S}/usr/share/applications/winboat.desktop"
	newicon -s scalable "${S}/usr/share/icons/hicolor/scalable/apps/winboat.svg" winboat.svg
}
