# Copyright 2025-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

MY_PN="${PN%-bin}"

DESCRIPTION="A faster, better and more stable Redis desktop manager [GUI client]"
HOMEPAGE="https://github.com/qishibo/AnotherRedisDesktopManager"
SRC_URI="https://github.com/qishibo/AnotherRedisDesktopManager/releases/download/v${PV}/Another-Redis-Desktop-Manager-linux-${PV}-x86_64.AppImage -> ${P}.AppImage"
S="${WORKDIR}/squashfs-root"
LICENSE="MIT"

SLOT="0"
KEYWORDS="~amd64"

RESTRICT="strip"

RDEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	app-crypt/libsecret
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa[opengl]
	net-print/cups
	sys-apps/dbus
	virtual/libudev
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/libdrm
	x11-libs/libnotify
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/libxshmfence
	x11-libs/pango
"

QA_PREBUILT="opt/${MY_PN}/*"

src_unpack() {
	cp "${DISTDIR}/${P}.AppImage" "${MY_PN}" || die
	chmod +x "${MY_PN}" || die
	./"${MY_PN}" --appimage-extract > /dev/null || die
}

src_prepare() {
	default
	find . -type d -exec chmod a+rx {} + || die
}

src_install() {
	rm -r AppRun .DirIcon "${MY_PN}".{desktop,png} usr || die

	dodir /opt/${MY_PN}
	cp -r . "${ED}"/opt/${MY_PN} || die
	fperms 4711 /opt/${MY_PN}/chrome-sandbox
	dosym -r /opt/${MY_PN}/${MY_PN} /usr/bin/${MY_PN}

	domenu "${FILESDIR}/${MY_PN}.desktop"
	doicon -s scalable "${FILESDIR}/${MY_PN}.svg"
}
