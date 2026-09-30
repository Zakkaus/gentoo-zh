# Copyright 2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker desktop xdg

MY_PN="${PN/-bin/}"
D_PN="youtube-music-desktop-app"
MY_PR="${PR/r/}"
MY_P="${D_PN}-${PVR}"

DESCRIPTION="A Desktop App for YouTube Music"
HOMEPAGE="https://github.com/ytmdesktop/ytmdesktop"
SRC_URI="https://github.com/ytmdesktop/ytmdesktop/releases/download/v${PV}/${D_PN}_${PV}_amd64.deb -> ${MY_P}.deb"

S="${WORKDIR}"

LICENSE="GPL-3"
# From www-client/chromium for the bundled Electron runtime
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
# From net-libs/nodejs
LICENSE+=" Apache-1.1 BlueOak-1.0.0"
SLOT="0"

KEYWORDS="~amd64"

RDEPEND="
		>=app-accessibility/at-spi2-core-2.46.0:2
		app-crypt/libsecret
		dev-libs/nss
		media-libs/alsa-lib
		media-libs/mesa[gbm(+)]
		net-print/cups
		virtual/libudev:=
		x11-libs/gtk+:3[X]
		x11-libs/libnotify
		x11-libs/libxcb
		x11-libs/libxkbcommon
		x11-libs/libXtst
		x11-misc/xdg-utils
"

RESTRICT="mirror strip"

QA_PREBUILT="
	/opt/${MY_PN}/chrome-sandbox
	/opt/${MY_PN}/chrome_crashpad_handler
	/opt/${MY_PN}/libffmpeg.so
	/opt/${MY_PN}/libvk_swiftshader.so
	/opt/${MY_PN}/libvulkan.so.1
	/opt/${MY_PN}/${D_PN}
"

src_install() {
	insinto /opt/"${MY_PN}"
	doins -r usr/lib/${D_PN}/*

	doicon usr/share/pixmaps/"${D_PN}".png

	make_desktop_entry "/opt/${MY_PN}/${D_PN}" "YouTube Music Desktop App" "${D_PN}" "AudioVideo;Audio;"

	make_desktop_entry "/opt/${MY_PN}/${D_PN} --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime" "YouTube Music Desktop App Wayland" "${D_PN}" "AudioVideo;Audio;"

	local f
	for f in ${QA_PREBUILT}; do
		fperms +x "${f}"
	done

	fperms u+s /opt/"${MY_PN}"/chrome-sandbox
}
