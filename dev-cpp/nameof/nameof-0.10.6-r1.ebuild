# Copyright 2021-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit cmake

DESCRIPTION="Nameof operator for modern C++"
HOMEPAGE="https://github.com/Neargye/nameof"
SRC_URI="https://github.com/Neargye/nameof/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

DOCS=(
	README.md doc/limitations.md doc/reference.md
)

src_compile() {
	cmake_src_compile
	echo "int main() { return undeclared; }" > "${T}"/broken.cpp || die
	$(tc-getCXX) -c "${T}"/broken.cpp -o "${T}"/broken.o || die "broken.cpp does not compile"
}
