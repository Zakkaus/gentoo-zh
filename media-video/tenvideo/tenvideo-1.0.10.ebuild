# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7
inherit unpacker xdg

DESCRIPTION="Tencent videos"
HOMEPAGE="https://v.qq.com/download.html#linux"
SRC_URI="https://dldir1.qq.com/qqtv/linux/Tenvideo_universal_${PV}_amd64.deb"

S="${WORKDIR}"

LICENSE="tenvideo-privacy"
# From www-client/chromium for the bundled Electron runtime
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
# From net-libs/nodejs
LICENSE+=" Apache-1.1 BlueOak-1.0.0"
SLOT="0"
KEYWORDS="~amd64"

RESTRICT="strip mirror bindist"

RDEPEND="
	app-accessibility/at-spi2-core
	dev-libs/nss
	media-libs/alsa-lib
	x11-libs/gtk+:3
	x11-libs/libXScrnSaver
"

QA_PREBUILT="*"

src_install() {
	sed -i 's/腾讯视频/tenvideo/g' "${S}"/usr/share/applications/TencentVideo.desktop || die
	insinto /usr/share
	doins -r "${S}"/usr/share/{applications,icons}

	insinto /opt/tenvideo
	doins -r "${S}"/opt/腾讯视频/*

	fperms 0755 /opt/tenvideo/TencentVideo
	fperms 4755 /opt/tenvideo/chrome-sandbox
}
