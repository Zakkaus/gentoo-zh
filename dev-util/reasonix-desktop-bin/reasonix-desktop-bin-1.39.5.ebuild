# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop optfeature unpacker xdg

DESCRIPTION="Reasonix desktop client"
HOMEPAGE="https://reasonix.io https://github.com/esengine/DeepSeek-Reasonix"
SRC_URI="
	https://dl.reasonix.io/desktop-v${PV}/Reasonix-linux-amd64.deb
		-> ${P}-amd64.deb
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
KEYWORDS="-* ~amd64"
RESTRICT="strip"

RDEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa[gbm(+)]
	net-print/cups
	sys-apps/dbus
	virtual/libudev:=
	x11-libs/cairo
	x11-libs/gtk+:3
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/pango
"

QA_PREBUILT="
	usr/bin/reasonix-desktop
	usr/bin/reasonix-launcher
	usr/lib/reasonix/app/*
"

src_unpack() {
	unpack_deb ${A}
}

src_install() {
	# Deb also ships /usr/bin/reasonix; leave that path to reasonix-bin.
	dobin usr/bin/reasonix-desktop
	dobin usr/bin/reasonix-launcher

	# reasonix-desktop in /usr/bin starts the Electron shell from this fixed path.
	dodir /usr/lib/reasonix
	cp -r usr/lib/reasonix/app "${ED}"/usr/lib/reasonix/ || die
	fperms 4711 /usr/lib/reasonix/app/chrome-sandbox

	# Skip update-helper and polkit: they implement .deb self-update.
	domenu usr/share/applications/reasonix.desktop

	local size
	for size in 16 24 32 48 64 128 256 512; do
		doicon -s ${size} usr/share/icons/hicolor/${size}x${size}/apps/reasonix-desktop.png
	done
	doicon -s scalable usr/share/icons/hicolor/scalable/apps/reasonix-desktop.svg
	doicon usr/share/pixmaps/reasonix-desktop.png
}

pkg_postinst() {
	xdg_pkg_postinst
	optfeature "terminal agent CLI" dev-util/reasonix-bin
}
