# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker desktop xdg
MY_PN="lx-music-desktop"
DESCRIPTION="一个基于 electron 的音乐软件"
HOMEPAGE="https://github.com/lyswhut/lx-music-desktop"
SRC_URI="
	amd64? ( https://github.com/lyswhut/lx-music-desktop/releases/download/v${PV}/lx-music-desktop_${PV}_amd64.deb )
	arm64? ( https://github.com/lyswhut/lx-music-desktop/releases/download/v${PV}/lx-music-desktop_${PV}_arm64.deb )
"
S="${WORKDIR}"
LICENSE="Apache-2.0"
# From www-client/chromium for the bundled Electron runtime
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
# From net-libs/nodejs
LICENSE+=" Apache-1.1 BlueOak-1.0.0"
SLOT="0"
QA_PREBUILT="*"
KEYWORDS="-* ~amd64 ~arm64"
RDEPEND="x11-libs/gtk+:3[cups]
	x11-libs/libXScrnSaver
	dev-libs/nss
	app-crypt/p11-kit
	dev-libs/libayatana-appindicator
	app-accessibility/at-spi2-core[X]
	app-crypt/libsecret
	x11-libs/libnotify
	media-libs/alsa-lib
"
src_install() {
	insinto /opt
	doins -r opt/*
	fperms +x /opt/${MY_PN}/${MY_PN}
	dosym -r /opt/${MY_PN}/${MY_PN} /usr/bin/${MY_PN}
	gzip -d usr/share/doc/${MY_PN}/*.gz || die
	dodoc usr/share/doc/${MY_PN}/*
	doicon -s 512 usr/share/icons/hicolor/512x512/apps/lx-music-desktop.png
	domenu usr/share/applications/lx-music-desktop.desktop
}
