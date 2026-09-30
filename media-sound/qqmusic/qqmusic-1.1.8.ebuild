# Copyright 2023-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

SIGNKEY="1-d1ca4d5c5a8369b26af88e881ba3ac544066a899dcaea29778b35c9f648e6fee-68cb7c1c"
inherit desktop unpacker xdg

DESCRIPTION="Tencent QQ Music, converted from .deb package"
HOMEPAGE="https://y.qq.com/"
SRC_URI="https://c.y.qq.com/cgi-bin/file_redirect.fcg?bid=dldir&file=ecosfile_plink%2Fmusic_clntupate%2Flinux%2Fother%2Fqqmusic_${PV}_amd64.deb&sign=${SIGNKEY} -> ${P}_amd64.deb"

S="${WORKDIR}"

LICENSE="Tencent"
# From www-client/chromium for the bundled Electron runtime
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
# From net-libs/nodejs
LICENSE+=" Apache-1.1 BlueOak-1.0.0"
SLOT="0"
KEYWORDS="-* ~amd64"
RESTRICT="bindist mirror strip"

RDEPEND="
	dev-libs/nss
	media-libs/alsa-lib
	x11-libs/gtk+:3
	x11-libs/libXScrnSaver
"

src_install() {
	insinto /opt
	doins -r opt/*
	fperms +x /opt/qqmusic/{qqmusic,chrome-sandbox,crashpad_handler,libEGL.so,libGLESv2.so,libffmpeg.so,libvk_swiftshader.so,swiftshader/libEGL.so,swiftshader/libGLESv2.so}
	newbin "${FILESDIR}"/qqmusic.sh qqmusic
	domenu "${FILESDIR}"/qqmusic.desktop
	for i in 16 32 64 128 256; do
		doicon -s $i usr/share/icons/hicolor/"$i"x"$i"/apps/qqmusic.png
	done
	gzip -d usr/share/doc/qqmusic/changelog.gz || die
	dodoc usr/share/doc/qqmusic/changelog
}
