# Copyright 2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="A Layer Two Peer-to-Peer VPN"

inherit autotools git-r3 systemd

HOMEPAGE="https://github.com/ntop/n2n"
LICENSE="GPL-3"
SLOT="0"
IUSE="
	+openssl
	caps
	pcap
	zstd
	upnp
"

EGIT_REPO_URI="https://github.com/ntop/n2n.git"

DEPEND="
	acct-user/n2n
	acct-group/n2n
	openssl? ( dev-libs/openssl:= )
	caps? ( sys-libs/libcap )
	pcap? ( net-libs/libpcap )
	zstd? ( app-arch/zstd )
	upnp? ( net-libs/miniupnpc net-libs/libnatpmp )
"
RDEPEND="${DEPEND}"

src_prepare() {
	default
	rm -rf .git || die
	eautoreconf
}

src_configure() {
	local myeconfargs=(
		$(use_with openssl)
		$(use_with zstd)
		$(use_enable caps cap)
		$(use_enable pcap)
		$(use_enable upnp miniupnp)
		$(use_enable upnp natpmp)
	)
	econf "${myeconfargs[@]}"
}

src_install() {
	dosbin edge supernode tools/n2n-{benchmark,decode,keygen,portfwd,route}
	doman edge.8 n2n.7 supernode.1
	keepdir /var/log/n2n
	systemd_newunit packages/etc/systemd/system/edge@.service n2n-edge@.service
	systemd_newunit packages/etc/systemd/system/supernode.service n2n-supernode.service
	insinto /etc/n2n
	newins packages/etc/n2n/edge.conf.sample edge-example.conf
	doins packages/etc/n2n/supernode.conf.sample
}
