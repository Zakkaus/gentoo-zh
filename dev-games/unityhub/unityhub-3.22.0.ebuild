# Copyright 2022-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop optfeature unpacker xdg

DESCRIPTION="The official unity tool for manager Unity Engines and projects"
HOMEPAGE="https://docs.unity.com/en-us/hub"
SRC_URI="https://hub.unity3d.com/linux/repos/deb/pool/main/u/unity/unityhub_amd64/UnityHubSetup-${PV}-amd64.deb -> ${PN}-amd64-${PV}.deb"
S=${WORKDIR}

LICENSE="unity-EULA"
# From www-client/chromium for the bundled Electron runtime
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl"
# From net-libs/nodejs
LICENSE+=" Apache-1.1 BlueOak-1.0.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+appindicator legacy"
RESTRICT="bindist mirror strip"

DEPEND="
	appindicator? (
		dev-libs/libdbusmenu
		legacy? (
			dev-libs/libayatana-appindicator
			x11-misc/appmenu-gtk-module[gtk2]
		)
	)
	app-arch/cpio
	dev-libs/nss
	dev-util/lttng-ust:0/2.12
	x11-libs/gtk+
	app-crypt/libsecret
	media-libs/alsa-lib
"
RDEPEND="${DEPEND}"

src_unpack(){
	unpack_deb ${PN}-amd64-${PV}.deb
}
src_install(){
	insinto /opt
	doins -r usr/lib/unityhub
	dosym -r /opt/unityhub/unityhub /usr/bin/unityhub
	insinto /usr/share/icons
	doins -r usr/share/icons/hicolor
	domenu usr/share/applications/${PN}.desktop
	fperms 0755 -R /opt/unityhub
}

pkg_postinst() {
	xdg_pkg_postinst

	optfeature_header "Older Unity Editor releases installed through the Hub may need:"
	optfeature "Editors before Unity's libxml2 fix (6000.0.76f1, 6000.3.13f1, 6000.4.1f1)" \
		dev-libs/libxml2-compat:2
	optfeature "Editors that still link OpenSSL 1.1" dev-libs/openssl-compat:1.1.1
}
