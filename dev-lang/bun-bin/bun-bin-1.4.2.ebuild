# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit shell-completion

DESCRIPTION="Incredibly fast JavaScript runtime, bundler, test runner, and package manager"
HOMEPAGE="https://bun.sh https://github.com/oven-sh/bun"
SRC_URI="
	amd64? ( https://github.com/oven-sh/bun/releases/download/bun-v${PV}/bun-linux-x64.zip -> ${P}-amd64.zip )
	arm64? ( https://github.com/oven-sh/bun/releases/download/bun-v${PV}/bun-linux-aarch64.zip -> ${P}-arm64.zip )
"
S="${WORKDIR}"

LICENSE="MIT"
# Statically linked JavaScriptCore, TinyCC and libraries listed in LICENSE.md
LICENSE+=" Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 BSD-4 CC0-1.0 IJG ISC"
LICENSE+=" LGPL-2+ LGPL-2.1 public-domain ZLIB"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"

IUSE="symlink"

BDEPEND="app-arch/unzip"
RDEPEND="
	symlink? ( !net-libs/nodejs )
"

RESTRICT="strip"

QA_PREBUILT="usr/bin/bun"

src_prepare() {
	default
	mv bun-linux*/bun . || die "Failed to move bun binary"
	# generate shell completion scripts
	for sh in bash fish zsh; do
		env SHELL=${sh} "${S}/bun" completions ${sh} > "${WORKDIR}/completion.${sh}"
	done
}

src_install() {
	dobin bun
	dosym bun /usr/bin/bunx
	use symlink && dosym bun /usr/bin/node # fix env: node: No such file or directory

	newbashcomp completion.bash "${PN}"
	newfishcomp completion.fish "${PN}".fish
	newzshcomp completion.zsh _"${PN}"
}
