# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit xdg desktop wrapper

DESCRIPTION="BiliBili third-party client developed using Flutter"
HOMEPAGE="https://github.com/bggRGjQaUbCoE/PiliPlus"
MY_PV="2.1.5+5410"
SRC_URI="https://github.com/bggRGjQaUbCoE/PiliPlus/releases/download/${PV}/PiliPlus_linux_${MY_PV}_amd64.tar.gz"
S="${WORKDIR}"
LICENSE="GPL-3"
# Flutter engine and Dart packages listed in data/flutter_assets/NOTICES.Z
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions Boost-1.0 BSD BSD-2 FTL IJG ISC MIT"
LICENSE+=" MPL-2.0 public-domain Unicode-3.0 Unicode-DFS-2016 ZLIB"
# Bundled Font Awesome fonts
LICENSE+=" OFL-1.1"
SLOT="0"
KEYWORDS="~amd64"
QA_PREBUILT="*"
QA_DT_NEEDED="opt/${PN}/lib/libdartjni.so"
DEPEND="
	net-libs/webkit-gtk:4.1
	dev-libs/libayatana-appindicator
	media-video/mpv
	x11-misc/xdg-user-dirs
"
RDEPEND="
	${DEPEND}
	dev-java/openjdk-jre-bin:*
"

src_install() {
	local instdir="/opt/${PN}"
	insinto "${instdir}"
	doins piliplus
	fperms +x "${instdir}/piliplus"
	doins -r data
	insinto "${instdir}/lib"
	doins lib/*.so
	make_wrapper "${PN}" "${instdir}/piliplus"
	domenu "${FILESDIR}/${PN}.desktop"
}
