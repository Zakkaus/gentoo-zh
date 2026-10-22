# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg
DESCRIPTION="A cross-platform music player"

MY_PN="SPlayer"
HOMEPAGE="https://splayer.imsyy.top/"
SRC_URI="
	amd64? ( https://github.com/SPlayer-Dev/${MY_PN}/releases/download/v${PV}/${P}-amd64.deb )
	arm64? ( https://github.com/SPlayer-Dev/${MY_PN}/releases/download/v${PV}/${P}-arm64.deb )
"

S="${WORKDIR}"
LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
RESTRICT="strip"

QA_PREBUILT="opt/${MY_PN}/*"

RDEPEND="
	app-accessibility/at-spi2-core:2
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa
	media-libs/vips
	net-print/cups
	sys-apps/dbus
	virtual/libudev
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

DEPEND="${RDEPEND}"

src_prepare() {
	default
	unpack usr/share/doc/splayer/changelog.gz
}

src_install() {
	insinto /opt
	doins -r opt/${MY_PN}

	domenu usr/share/applications/${MY_PN}.desktop
	doicon -s 512 usr/share/icons/hicolor/512x512/apps/${MY_PN}.png

	dodoc changelog

	fperms +x "/opt/${MY_PN}/${MY_PN}"
	dosym -r "/opt/${MY_PN}/${MY_PN}" "/usr/bin/${PN}"
}
