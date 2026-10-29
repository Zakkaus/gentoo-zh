# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="NCBI Datasets command-line tools to download biological sequence data"
HOMEPAGE="https://www.ncbi.nlm.nih.gov/datasets/ https://github.com/ncbi/datasets"
SRC_URI="
	amd64? ( https://github.com/ncbi/datasets/releases/download/v${PV}/linux-amd64.cli.package.zip -> ${P}-amd64.zip )
	arm64? ( https://github.com/ncbi/datasets/releases/download/v${PV}/linux-arm64.cli.package.zip -> ${P}-arm64.zip )
"
S="${WORKDIR}"

LICENSE="public-domain"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"

BDEPEND="app-arch/unzip"

QA_PREBUILT="
	usr/bin/datasets
	usr/bin/dataformat
"

src_install() {
	dobin datasets dataformat
}
