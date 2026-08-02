# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=9

DESCRIPTION="Code knowledge graph and MCP server for AI coding agents"
HOMEPAGE="https://github.com/colbymchenry/codegraph"
# Two dependency trees, built per release at gentoo-zh-drafts/codegraph: the
# first carries tsc and vitest, the second is what gets installed.
SRC_URI="
	https://github.com/colbymchenry/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/gentoo-zh-drafts/${PN}/releases/download/v${PV}/${P}-node_modules.tar.xz
	https://github.com/gentoo-zh-drafts/${PN}/releases/download/v${PV}/${P}-node_modules-prod.tar.xz
"

# codegraph and its bundled dependencies are MIT, except tree-sitter-wasms
# (Unlicense) and two of the 36 grammars it is built from: tree-sitter-elixir
# (Apache-2.0) and tree-sitter-dart (ISC).
LICENSE="Apache-2.0 ISC MIT Unlicense"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# The index lives in node:sqlite, which needs no flag from 22.13 on
RDEPEND=">=net-libs/nodejs-22.13"
BDEPEND="${RDEPEND}"

src_prepare() {
	default

	# The V8 turboshaft crash upstream blocks for (issue 81) is Node 25 only, but
	# the check is `>= 25` and prints a 31-line banner on every run. Gentoo has
	# nothing between 24 and 26, and 26 indexes fine.
	sed -i 's/nodeMajor >= 25/nodeMajor === 25/' src/bin/codegraph.ts || die
}

src_compile() {
	node node_modules/typescript/bin/tsc || die "tsc failed"

	# package.json's copy-assets step
	mkdir -p dist/db dist/extraction/wasm || die
	cp src/db/schema.sql dist/db/ || die
	cp src/extraction/wasm/*.wasm dist/extraction/wasm/ || die
}

src_test() {
	DO_NOT_TRACK=1 node node_modules/vitest/vitest.mjs run || die "vitest failed"
}

src_install() {
	# Not under a node_modules directory: upgrade/index.js reads any such path as
	# an npm install and would run `npm install -g` over Portage's files.
	local dest="/usr/$(get_libdir)/${PN}"
	insinto "${dest}"
	doins -r dist package.json
	doins -r "${WORKDIR}/${P}-prod/node_modules"
	fperms +x "${dest}/dist/bin/${PN}.js"

	# Launcher, not a symlink: DO_NOT_TRACK is a cross-tool standard, so setting
	# it in /etc/env.d would reach unrelated software.
	newbin - "${PN}" <<-EOF
		#!/bin/sh
		export DO_NOT_TRACK="\${DO_NOT_TRACK:-1}"
		exec node "${EPREFIX}${dest}/dist/bin/${PN}.js" "\$@"
	EOF

	einstalldocs
}
