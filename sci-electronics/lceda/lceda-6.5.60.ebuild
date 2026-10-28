# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

DESCRIPTION="LCEDA (binary package)"
HOMEPAGE="https://lceda.cn/"
SRC_URI="
	amd64? ( https://image.lceda.cn/files/${PN}-linux-x64-${PV}.zip )
	arm64? ( https://image.lceda.cn/files/${PN}-linux-arm64-${PV}.zip )
"

S="${WORKDIR}/${PN}"
LICENSE="LCEDA-Software-EULA LCEDA-Distribution-License"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"

DEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	app-crypt/libsecret
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa
	net-print/cups
	sys-apps/dbus
	sys-apps/util-linux
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/libdrm
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXcomposite
	x11-libs/libXcursor
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXi
	x11-libs/libxkbcommon
	x11-libs/libXrandr
	x11-libs/libXrender
	x11-libs/libXScrnSaver
	x11-libs/libxshmfence
	x11-libs/libXtst
	x11-libs/pango"
RDEPEND="${DEPEND}"
BDEPEND="app-arch/unzip"

RESTRICT="strip"

QA_PREBUILT="*"

src_unpack() {
	# unzip exits 1 on the warnings about the Chinese file names in the archive
	local ret=0
	unzip -qo "${DISTDIR}/${A}" -d "${WORKDIR}" || ret=$?
	(( ret <= 1 )) || die "unzip failed with exit status ${ret}"
	mv "${WORKDIR}"/${PN}-linux-* "${S}" || die
}

src_install(){
	insinto /opt/lceda
	doins -r .
	fperms 0755 /opt/lceda/lceda
	fperms 0755 /opt/lceda/chrome_crashpad_handler

	local size
	for size in 16 32 128 256 512; do
		newicon -s ${size} icon/icon_${size}x${size}.png lceda.png
	done
	newicon -s 64 icon/icon_32x32@2x.png lceda.png

	sed -i 's|^Icon=.*|Icon=lceda|' LCEDA.dkt || die
	newmenu LCEDA.dkt LCEDA.desktop

	dodoc "${FILESDIR}"/LCEDA-Distribution-License.txt
	docompress -x "/usr/share/doc/${PF}/LCEDA-Distribution-License.txt"
}
