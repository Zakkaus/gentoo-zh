# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Probe package for testing the tatt workflow"
HOMEPAGE="https://github.com/gentoo-zh/overlay"
S=${WORKDIR}

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~arm ~arm64 ~loong ~ppc64 ~riscv ~x86"
IUSE="foo bar cpu_flags_x86_avx2"
REQUIRED_USE="amd64? ( cpu_flags_x86_avx2 ) ?? ( foo bar )"

src_install() {
	echo "foo=$(usex foo) bar=$(usex bar)" > probe.txt
	insinto /usr/share/tatt-probe
	doins probe.txt
}
