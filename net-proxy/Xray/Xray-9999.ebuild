# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module systemd git-r3

DESCRIPTION="Xray, Penetrates Everything. Also the best v2ray-core, with XTLS support"
HOMEPAGE="https://xtls.github.io/ https://github.com/XTLS/Xray-core"
EGIT_REPO_URI="https://github.com/XTLS/Xray-core.git"
EGIT_BRANCH="main"

LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS=""

DEPEND="app-alternatives/v2ray-geoip
	app-alternatives/v2ray-geosite"
RDEPEND="${DEPEND}"
BDEPEND=">=dev-lang/go-1.26.0"

src_unpack() {
	git-r3_src_unpack

	# The live ebuild has no pre-generated vendor tarball; vendor from network.
	cd "${S}" || die
	ego mod vendor
}

src_compile() {
	ego build -mod vendor -o xray -gcflags="all=-l=4" \
		-ldflags "-X github.com/XTLS/Xray-core/core.build=${PV}" ./main
}

src_install() {
	dobin xray
	newinitd "${FILESDIR}/xray.initd" xray
	systemd_dounit "${FILESDIR}/xray.service"
	systemd_newunit "${FILESDIR}/xray_at.service" xray@.service
	dosym -r /usr/share/v2ray/geosite.dat /usr/share/xray/geosite.dat
	dosym -r /usr/share/v2ray/geoip.dat /usr/share/xray/geoip.dat
	keepdir /etc/xray
}
