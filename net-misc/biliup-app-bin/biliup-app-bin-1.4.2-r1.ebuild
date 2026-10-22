# Copyright 2023-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker xdg

MY_PN="biliup-app"

DESCRIPTION="A Tool for Upload video to bilibili"

HOMEPAGE="https://github.com/biliup/biliup-app-new"
SRC_URI="
	amd64? ( https://github.com/biliup/biliup-app-new/releases/download/app-v${PV}/${MY_PN}_${PV}_amd64.deb )
	arm64? ( https://github.com/biliup/biliup-app-new/releases/download/app-v${PV}/${MY_PN}_${PV}_arm64.deb )
"

S="${WORKDIR}"

LICENSE="0BSD Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD Boost-1.0 CC0-1.0 ISC MIT MIT-0 MPL-2.0 Unicode-DFS-2016 Unlicense ZLIB"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
RESTRICT="mirror strip"

RDEPEND="
	dev-libs/glib:2
	net-libs/libsoup:3.0
	net-libs/webkit-gtk:4.1
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/pango
"

src_install() {
	insinto /
	doins -r .
	fperms 0755 /usr/bin/biliup-app
}
