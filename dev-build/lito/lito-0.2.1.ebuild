# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( 22 )

inherit cmake llvm-r2

DESCRIPTION="Module-first C++ build tool with manifest"
HOMEPAGE="https://github.com/litocpp/lito"

RSTD_COMMIT="99e7d045c8bd340ba942ca742a66b89ede02fa4c"
LUATO_COMMIT="a5cfe5dbb67ab9161ba26776c93d7ef7141c838a"
LUA_PV="5.5.1"

SRC_URI="
	https://github.com/litocpp/lito/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/litocpp/rstd/archive/${RSTD_COMMIT}.tar.gz -> rstd-${RSTD_COMMIT}.tar.gz
	https://github.com/litocpp/luato/archive/${LUATO_COMMIT}.tar.gz -> luato-${LUATO_COMMIT}.tar.gz
	https://www.lua.org/ftp/lua-${LUA_PV}.tar.gz
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

RDEPEND="
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}=
		llvm-core/lld:${LLVM_SLOT}=
		llvm-core/llvm:${LLVM_SLOT}=
	')
	=llvm-runtimes/libcxx-22*
	dev-build/cmake
	dev-build/ninja
	dev-util/pkgconf
	dev-vcs/git
	net-misc/curl
"
BDEPEND="${RDEPEND}"

PATCHES=(
	"${FILESDIR}/${PN}-0.2.1-no-warn-unused-cli.patch"
)

src_configure() {
	local mycmakeargs=(
		-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF
		-DFETCHCONTENT_SOURCE_DIR_RSTD="${WORKDIR}/rstd-${RSTD_COMMIT}"
		-DFETCHCONTENT_SOURCE_DIR_LUATO="${WORKDIR}/luato-${LUATO_COMMIT}"
		-DFETCHCONTENT_SOURCE_DIR_LUA="${WORKDIR}/lua-${LUA_PV}"
	)

	# the std module fails to build with _FORTIFY_SOURCE
	# https://github.com/llvm/llvm-project/issues/121709
	local -x CPPFLAGS+=" -D_GENTOO_NO_FORTIFY_SOURCE"

	PATH="$(get_llvm_prefix -b)/bin:${PATH}" \
		CC=clang \
		CXX=clang++ \
		cmake_src_configure
}
