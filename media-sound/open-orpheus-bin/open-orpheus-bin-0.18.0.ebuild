# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker desktop xdg

DESCRIPTION="An open-source implementation of Netease Cloud Music's Orpheus browser host"
HOMEPAGE="https://github.com/YUCLing/open-orpheus"
SRC_URI="
	amd64? (
		https://github.com/YUCLing/open-orpheus/releases/download/v${PV}/open-orpheus_${PV}-1_amd64.deb
			-> open-orpheus-${PV}-amd64.deb
	)
	arm64? (
		https://github.com/YUCLing/open-orpheus/releases/download/v${PV}/open-orpheus_${PV}-1_arm64.deb
			-> open-orpheus-${PV}-arm64.deb
	)
"

S="${WORKDIR}"

LICENSE="MIT"
# From www-client/chromium for the bundled Electron runtime
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
# From net-libs/nodejs
LICENSE+=" Apache-1.1 BlueOak-1.0.0"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"

RESTRICT="bindist"

RDEPEND="
	app-accessibility/at-spi2-core:2
	dev-libs/nss
	media-libs/alsa-lib
	net-print/cups
	x11-libs/gtk+:3
	x11-libs/libdrm
	x11-libs/libnotify
	x11-libs/libxcb
	x11-libs/libXi
	x11-libs/libXdamage
	x11-libs/libXcomposite
	x11-libs/libxkbcommon
	x11-misc/xdg-utils
"

QA_PREBUILT="opt/open-orpheus/*"

src_install() {
	insinto /opt/open-orpheus
	doins -r usr/lib/open-orpheus/*
	dosym ../open-orpheus/open-orpheus /opt/bin/open-orpheus
	fperms +x /opt/open-orpheus/{open-orpheus,chrome-sandbox,chrome_crashpad_handler}
	fperms u+s /opt/open-orpheus/chrome-sandbox
	domenu usr/share/applications/open-orpheus.desktop
	local size
	for size in 256 512; do
		doicon -s "${size}" "usr/share/icons/hicolor/${size}x${size}/apps/open-orpheus.png"
	done
	doicon -s scalable usr/share/icons/hicolor/scalable/apps/open-orpheus.svg
}
