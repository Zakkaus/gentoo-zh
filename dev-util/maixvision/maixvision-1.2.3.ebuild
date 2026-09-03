# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg

DESCRIPTION="MaixVision - AIoT development platform"
HOMEPAGE="https://sipeed.com/maixvision"
SRC_URI="https://cdn.sipeed.com/maixvision/${PV}/maixvision_${PV}_amd64.deb"

S="${WORKDIR}"
LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="bindist mirror strip"

RDEPEND="
	app-accessibility/at-spi2-core
	app-crypt/libsecret
	dev-libs/nss
	media-libs/alsa-lib
	sys-apps/util-linux
	x11-libs/gtk+:3
	x11-libs/libnotify
	x11-libs/libXScrnSaver
	x11-libs/libXtst
	x11-misc/xdg-utils
"

src_install() {
	insinto /opt
	doins -r opt/MaixVision/

	# doins -r drops the executable bit, restore it on what upstream ships executable
	fperms 755 /opt/MaixVision/maixvision \
		/opt/MaixVision/chrome_crashpad_handler \
		/opt/MaixVision/resources/app.asar.unpacked/node_modules/@esbuild/linux-x64/bin/esbuild \
		/opt/MaixVision/resources/app.asar.unpacked/node_modules/monaco-editor-wrapper/node_modules/@esbuild/linux-x64/bin/esbuild

	domenu usr/share/applications/maixvision.desktop
	doicon -s 512 usr/share/icons/hicolor/512x512/apps/maixvision.png
	dosym ../../opt/MaixVision/maixvision /usr/bin/maixvision
}
