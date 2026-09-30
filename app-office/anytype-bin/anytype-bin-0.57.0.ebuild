# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

DESCRIPTION="A notebook based on p2p network"
HOMEPAGE="https://anytype.io"
SRC_URI="
	https://github.com/anyproto/anytype-ts/releases/download/v${PV}/Anytype-${PV}.AppImage
		-> anytype-${PV}.AppImage
	https://github.com/anyproto/anytype-ts/releases/download/v${PV}/anytype_${PV}_amd64.deb
"

S="${WORKDIR}"
LICENSE="ASAL-1.0"
# From www-client/chromium for the bundled Electron runtime
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
# From net-libs/nodejs
LICENSE+=" Apache-1.1 BlueOak-1.0.0"
SLOT="0"
KEYWORDS="~amd64"

RESTRICT="strip"

RDEPEND="sys-fs/fuse:0"
BDEPEND="app-arch/dpkg"

QA_PRESTRIPPED="*"

src_unpack() {
	cp "${DISTDIR}/anytype-$PV.AppImage" anytype-bin || die
}

src_prepare() {
	default
	dpkg -x "${DISTDIR}"/anytype_${PV}_amd64.deb . || die "dpkg icon extraction failed"
	sed -i 's|^Exec=/opt/Anytype/anytype|Exec=anytype-bin|' usr/share/applications/anytype.desktop ||
		die "Sed Exec command failed"
}

src_install() {
	dobin anytype-bin
	for size in 16 32 64 128 256 512 1024; do
		doicon -s "$size" usr/share/icons/hicolor/"$size"x"$size"/apps/anytype.png || die "Icon installation failed"
	done
	domenu usr/share/applications/anytype.desktop || die "Desktop file installation failed"
}
