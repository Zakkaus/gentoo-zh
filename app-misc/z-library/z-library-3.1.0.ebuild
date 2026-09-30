# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker desktop xdg

DESCRIPTION="Z-library application"
HOMEPAGE="https://z-lib.fm/z-access"
URI_PREFIX="https://s3proxy-alp.cdn-zlib.sk/swfs_second_public_files/soft/desktop/Z-Library_"
SRC_URI="${URI_PREFIX}${PV}_amd64.deb"

S="${WORKDIR}"
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

RDEPEND="
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
"

src_install() {
	insinto /opt/Z-Library
	doins -r "${S}"/opt/Z-Library/.
	fperms +x /opt/Z-Library/Z-Library
	fperms +x /opt/Z-Library/chrome-sandbox
	fperms +x /opt/Z-Library/chrome_crashpad_handler

	domenu "${S}"/usr/share/applications/Z-Library.desktop

	for size in 16 32 128 256 512; do
		doicon -s ${size} "${S}"/usr/share/icons/hicolor/${size}x${size}/apps/Z-Library.png
	done
}
