# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Clojure and Clojurescript source code formatter"
HOMEPAGE="https://github.com/kkinnear/zprint"
SRC_URI="https://github.com/kkinnear/zprint/releases/download/${PV}/zprintl-${PV}"

S="${DISTDIR}"
LICENSE="MIT"
# From dev-lang/clojure for the bundled Clojure
LICENSE+=" Apache-2.0 BSD EPL-1.0"
SLOT="0"
KEYWORDS="~amd64"

src_install() {
	newbin "${S}/zprintl-${PV}" zprint
}
