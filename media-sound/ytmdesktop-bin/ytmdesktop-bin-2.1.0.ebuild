# Copyright 2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker desktop xdg

MY_PN="${PN/-bin/}"
D_PN="youtube-music-desktop-app"
MY_PR="${PR/r/}"
MY_P="${D_PN}-${PV}"

DESCRIPTION="A Desktop App for YouTube Music"
HOMEPAGE="https://github.com/ytmdesktop/ytmdesktop"
SRC_URI="
	amd64? (
		https://github.com/ytmdesktop/ytmdesktop/releases/download/v${PV}/${D_PN}_${PV}_amd64.deb
			-> ${MY_P}.deb
	)
	arm64? (
		https://github.com/ytmdesktop/ytmdesktop/releases/download/v${PV}/${D_PN}_${PV}_arm64.deb
			-> ${MY_P}-arm64.deb
	)
"

S="${WORKDIR}"

LICENSE="GPL-3"
SLOT="0"

KEYWORDS="-* ~amd64 ~arm64"

RDEPEND="
		>=app-accessibility/at-spi2-core-2.46.0:2
		app-crypt/libsecret
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
		x11-libs/gtk+:3[X]
		x11-libs/libnotify
		x11-libs/libX11
		x11-libs/libxcb
		x11-libs/libXcomposite
		x11-libs/libXdamage
		x11-libs/libXext
		x11-libs/libXfixes
		x11-libs/libxkbcommon
		x11-libs/libXrandr
		x11-libs/libXtst
		x11-libs/pango
		x11-misc/xdg-utils
"

RESTRICT="strip"

QA_PREBUILT="
	/opt/${MY_PN}/chrome-sandbox
	/opt/${MY_PN}/chrome_crashpad_handler
	/opt/${MY_PN}/libffmpeg.so
	/opt/${MY_PN}/libvk_swiftshader.so
	/opt/${MY_PN}/libvulkan.so.1
	/opt/${MY_PN}/${D_PN}
	/opt/${MY_PN}/resources/app.asar.unpacked/node_modules/*
"

src_install() {
	insinto /opt/"${MY_PN}"
	doins -r usr/lib/${D_PN}/*

	doicon usr/share/pixmaps/"${D_PN}".png

	make_desktop_entry "/opt/${MY_PN}/${D_PN}" "YouTube Music Desktop App" "${D_PN}" "AudioVideo;Audio;"

	make_desktop_entry "/opt/${MY_PN}/${D_PN} --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime" "YouTube Music Desktop App Wayland" "${D_PN}" "AudioVideo;Audio;"

	fperms +x /opt/"${MY_PN}"/{chrome-sandbox,chrome_crashpad_handler,libffmpeg.so,libvk_swiftshader.so,libvulkan.so.1,"${D_PN}"}

	fperms u+s /opt/"${MY_PN}"/chrome-sandbox
}
