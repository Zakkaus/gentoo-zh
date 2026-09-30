# Copyright 2023-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg

DATE_VER="202512110451"
DESCRIPTION="Brainstorming and Mind Mapping Software"
HOMEPAGE="https://www.xmind.net"
SRC_URI="https://dl3.xmind.net/Xmind-for-Linux-amd64bit-${PV}-${DATE_VER}.deb"

S=${WORKDIR}
LICENSE="all-rights-reserved"
# From www-client/chromium for the bundled Electron runtime
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
# From net-libs/nodejs
LICENSE+=" Apache-1.1 BlueOak-1.0.0"
SLOT="0"
KEYWORDS="-* ~amd64"
RESTRICT="bindist mirror strip"

DEPEND="
	x11-libs/gtk+:3
	media-libs/alsa-lib
	x11-libs/libxkbfile
	dev-libs/nss
"
RDEPEND="${DEPEND}"

src_install() {
	insinto /opt
	doins -r opt/*
	fperms +x /opt/Xmind/{xmind,chrome_crashpad_handler,chrome-sandbox,libEGL.so,libffmpeg.so,libGLESv2.so,libvk_swiftshader.so,libvulkan.so.1}
	dosym -r "/opt/Xmind/xmind" "/usr/bin/xmind"
	for size in 16 32 48 64 128 256 512 1024; do
		doicon -s $size usr/share/icons/hicolor/"$size"x"$size"/apps/xmind.png
	done
	insinto /usr/share/mime/packages
	doins usr/share/mime/packages/xmind.xml
	domenu usr/share/applications/xmind.desktop
	gzip -d usr/share/doc/xmind-vana/changelog.gz || die
	dodoc usr/share/doc/xmind-vana/changelog
}
