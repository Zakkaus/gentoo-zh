# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

DESCRIPTION="A third party music player for Netease Music"
HOMEPAGE="https://github.com/qier222/YesPlayMusic"
BASE_URI="https://github.com/qier222/YesPlayMusic/releases/download"
SRC_URI="${BASE_URI}/v${PV}/${PN%-bin}-${PV}.pacman"

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

RESTRICT="mirror strip"

QA_PRESTRIPPED="*"

RDEPEND="
	app-arch/gzip
	dev-libs/nss
	media-libs/alsa-lib
	net-print/cups
	x11-libs/gtk+:*
	x11-libs/libxkbcommon"

QA_PREBUILT="
	opt/YesPlayMusic/chrome-sandbox
	opt/YesPlayMusic/libEGL.so
	opt/YesPlayMusic/libGLESv2.so
	opt/YesPlayMusic/libffmpeg.so
	opt/YesPlayMusic/libvk_swiftshader.so
	opt/YesPlayMusic/libvulkan.so.1
	opt/YesPlayMusic/swiftshader/libEGL.so
	opt/YesPlayMusic/swiftshader/libGLESv2.so
	opt/YesPlayMusic/yesplaymusic
"

src_unpack(){
	tar xf "${DISTDIR}/yesplaymusic-${PV}.pacman" || die
}

src_install(){
	insinto "/opt"
	doins -r "${S}/opt/YesPlayMusic"
	for si in 16 24 32 48 64 128 256 512; do
		doicon -s ${si} usr/share/icons/hicolor/${si}x${si}/apps/${PN%-bin}.png
	done
	domenu "${FILESDIR}/${PN%-bin}.desktop"
	fperms 0755 "/opt/YesPlayMusic/yesplaymusic"
}
