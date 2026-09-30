# Copyright 2022-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg unpacker

DESCRIPTION="A simple and elegant markdown editor, available for Linux, macOS and Windows"
HOMEPAGE="https://github.com/marktext/marktext"
SRC_URI="https://github.com/marktext/marktext/releases/download/v${PV}/${PN%-bin}-linux-${PV}.deb -> ${P}.deb"

S="${WORKDIR}"
LICENSE="MIT"
# From www-client/chromium for the bundled Electron runtime
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
# From net-libs/nodejs
LICENSE+=" Apache-1.1 BlueOak-1.0.0"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	app-accessibility/at-spi2-core:2
	dev-libs/expat
	dev-libs/glib
	app-crypt/libsecret
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa
	net-print/cups
	sys-apps/dbus[X]
	virtual/libudev
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3[X]
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libdrm
	x11-libs/libxcb
	x11-libs/libxkbfile
	x11-libs/libxkbcommon
	x11-libs/libxshmfence
	x11-libs/pango
"

QA_PREBUILT="
	opt/marktext/chrome-sandbox
	opt/marktext/chrome_crashpad_handler
	opt/marktext/libEGL.so
	opt/marktext/libffmpeg.so
	opt/marktext/libGLESv2.so
	opt/marktext/libvk_swiftshader.so
	opt/marktext/libvulkan.so.1
	opt/marktext/marktext
	opt/marktext/resources/app.asar.unpacked/node_modules/*
"

src_prepare(){
	default
	sed -i 's|^MimeType=.*|MimeType=text/markdown;|' usr/share/applications/${PN%-bin}.desktop || die
	sed -i 's|^Categories=.*|Categories=Utility;TextEditor;|' usr/share/applications/${PN%-bin}.desktop || die
	unpack usr/share/doc/${PN%-bin}/changelog.gz
}

src_install(){
	insinto /opt
	doins -r opt/marktext

	insinto /usr/share
	doins -r usr/share/icons

	dodoc changelog
	domenu usr/share/applications/${PN%-bin}.desktop

	local f
	for f in ${QA_PREBUILT}; do
		fperms +x "/${f}"
	done
	fperms u+s /opt/marktext/chrome-sandbox

	dosym ../../opt/marktext/${PN%-bin} /usr/bin/${PN%-bin}
}
