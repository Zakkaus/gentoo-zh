# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( 22 )

inherit llvm-r2

DESCRIPTION="A dynamic wallpaper solution for Linux desktops"
HOMEPAGE="https://github.com/waywallen/open-wallpaper-engine"

EIGEN_COMMIT="bc3b39870ecb690a623a3f49149a358b95c5781d"
GLSLANG_COMMIT="275822a6261ee689aadb1da5f09a0ec2f058685c"
QUICKJS_COMMIT="3c051980ab7e783dfbfb1c70c014ce5e05ecf24c"
RSTD_COMMIT="99e7d045c8bd340ba942ca742a66b89ede02fa4c"
SPIRV_REFLECT_COMMIT="355785128c1b6ba808e3a7d0e344814fe6cff502"
VMA_COMMIT="3aa921224c154a0d2c43912bc88e1c42ce1f7607"
VVK_COMMIT="5f1a0984e1023114d52b01d9b4967c8e52f16706"
WAVSEN_COMMIT="3b1041ced39d5c156efa5777af122c1fc781c28f"
WAYWALLEN_PV="0.3.5"
declare -A CEF_FILENAMES=(
	[amd64]="cef_binary_149.0.4+g2f1bfd8+chromium-149.0.7827.156_linux64_minimal"
	[arm64]="cef_binary_149.0.4+g2f1bfd8+chromium-149.0.7827.156_linuxarm64_minimal"
)

SRC_URI="
	https://github.com/waywallen/open-wallpaper-engine/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://gitlab.com/libeigen/eigen/-/archive/${EIGEN_COMMIT}/eigen-${EIGEN_COMMIT}.tar.bz2
	https://github.com/KhronosGroup/glslang/archive/${GLSLANG_COMMIT}.tar.gz -> glslang-${GLSLANG_COMMIT}.tar.gz
	https://github.com/quickjs-ng/quickjs/archive/${QUICKJS_COMMIT}.tar.gz -> quickjs-${QUICKJS_COMMIT}.tar.gz
	https://github.com/litocpp/rstd/archive/${RSTD_COMMIT}.tar.gz -> rstd-${RSTD_COMMIT}.tar.gz
	https://github.com/hypengw/SPIRV-Reflect/archive/${SPIRV_REFLECT_COMMIT}.tar.gz
		-> SPIRV-Reflect-${SPIRV_REFLECT_COMMIT}.tar.gz
	https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator/archive/${VMA_COMMIT}.tar.gz
		-> VulkanMemoryAllocator-${VMA_COMMIT}.tar.gz
	https://github.com/litocpp/vvk/archive/${VVK_COMMIT}.tar.gz -> vvk-${VVK_COMMIT}.tar.gz
	https://github.com/hypengw/wavsen/archive/${WAVSEN_COMMIT}.tar.gz -> wavsen-${WAVSEN_COMMIT}.tar.gz
	waywallen? (
		https://github.com/waywallen/waywallen/archive/refs/tags/v${WAYWALLEN_PV}.tar.gz
			-> waywallen-bridge-${WAYWALLEN_PV}.tar.gz
	)
	web? (
		amd64? ( https://cef-builds.spotifycdn.com/${CEF_FILENAMES[amd64]}.tar.bz2 )
		arm64? ( https://cef-builds.spotifycdn.com/${CEF_FILENAMES[arm64]}.tar.bz2 )
	)
"

LICENSE="
	GPL-2
	web? (
		Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD Base64 Boost-1.0 CC-BY-3.0
		CC-BY-4.0 Clear-BSD FFT2D FTL IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0
		Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0 Unicode-DFS-2015 Unlicense
		UoI-NCSA ZLIB libtiff openssl
	)
"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

IUSE="+scene +web +waywallen"
REQUIRED_USE="
	|| ( scene web )
	waywallen? ( scene web )
"

RDEPEND="
	app-arch/lz4
	dev-libs/glib
	dev-libs/icu
	media-libs/glfw
	media-libs/libpulse
	media-libs/libva
	media-libs/mesa
	media-libs/vulkan-loader
	media-video/ffmpeg
	virtual/zlib
	web? (
		app-accessibility/at-spi2-core
		dev-libs/expat
		dev-libs/nspr
		dev-libs/nss
		dev-libs/wayland
		media-libs/alsa-lib
		media-libs/fontconfig
		media-libs/freetype
		media-libs/libglvnd
		net-print/cups
		sys-apps/dbus
		virtual/libudev:=
		x11-libs/cairo
		x11-libs/libX11
		x11-libs/libXcomposite
		x11-libs/libXdamage
		x11-libs/libXext
		x11-libs/libXfixes
		x11-libs/libxcb
		x11-libs/libxkbcommon
		x11-libs/libXrandr
		x11-libs/pango
	)
	waywallen? ( gui-apps/waywallen )
"
DEPEND="
	${RDEPEND}
	dev-util/vulkan-headers
"
BDEPEND="
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}=
		llvm-core/lld:${LLVM_SLOT}=
	')
	>=dev-build/cmake-4.3.1
	>=dev-build/lito-0.2.1
	dev-build/ninja
	dev-util/pkgconf
	web? ( dev-util/patchelf )
"

# lito resolves these git URLs to the tarballs unpacked into vendor/, so no
# manifest needs patching and the build stays offline. Paths are project-root
# relative, which also covers the nested vvk and wavsen manifests.
LITO_PATCH_ARGS=(
	--config 'patch."https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator.git".path="vendor/vma"'
	--config 'patch."https://github.com/KhronosGroup/glslang.git".path="vendor/glslang"'
	--config 'patch."https://github.com/hypengw/SPIRV-Reflect.git".path="vendor/spirv-reflect"'
	--config 'patch."https://github.com/hypengw/wavsen.git".path="vendor/wavsen"'
	--config 'patch."https://github.com/litocpp/rstd.git".path="vendor/rstd"'
	--config 'patch."https://github.com/litocpp/vvk.git".path="vendor/vvk"'
	--config 'patch."https://gitlab.com/libeigen/eigen.git".path="vendor/eigen"'
	--config 'patch."https://github.com/quickjs-ng/quickjs.git".path="vendor/quickjs"'
)

src_prepare() {
	default

	mkdir vendor || die
	mv "${WORKDIR}/eigen-${EIGEN_COMMIT}" vendor/eigen || die
	mv "${WORKDIR}/glslang-${GLSLANG_COMMIT}" vendor/glslang || die
	mv "${WORKDIR}/quickjs-${QUICKJS_COMMIT}" vendor/quickjs || die
	mv "${WORKDIR}/rstd-${RSTD_COMMIT}" vendor/rstd || die
	mv "${WORKDIR}/SPIRV-Reflect-${SPIRV_REFLECT_COMMIT}" vendor/spirv-reflect || die
	mv "${WORKDIR}/VulkanMemoryAllocator-${VMA_COMMIT}" vendor/vma || die
	mv "${WORKDIR}/vvk-${VVK_COMMIT}" vendor/vvk || die
	mv "${WORKDIR}/wavsen-${WAVSEN_COMMIT}" vendor/wavsen || die

	if use waywallen; then
		mv "${WORKDIR}/waywallen-${WAYWALLEN_PV}" waywallen/bridge-source || die
	fi
	if use web; then
		mv "${WORKDIR}/${CEF_FILENAMES[${ARCH}]}" vendor/cef || die
	fi

	use web && eapply "${FILESDIR}/${PN}-0.2.5-use-local-cef.patch"
	use web && eapply "${FILESDIR}/${PN}-0.2.5-install-cef-runtime.patch"

	# upstream hardcodes quickjs' cmake package directory as lib/
	sed -i "s|^config-directory = \"lib/cmake/quickjs\"|config-directory = \"$(get_libdir)/cmake/quickjs\"|" \
		lito.toml || die

	lito update --offline "${LITO_PATCH_ARGS[@]}" || die
}

src_compile() {
	local -x PATH="$(get_llvm_prefix -b)/bin:${PATH}"
	local -a mylitoargs=(
		--locked
		--offline
		--profile release
		# the std module fails to build with _FORTIFY_SOURCE
		# https://github.com/llvm/llvm-project/issues/121709
		"${LITO_PATCH_ARGS[@]}"
		--config 'build.options=["-D_GENTOO_NO_FORTIFY_SOURCE","-U_FORTIFY_SOURCE"]'
	)

	if use waywallen; then
		cmake -S waywallen/bridge-source/bridge -B "${WORKDIR}/waywallen-bridge-build" -G Ninja \
			-DBUILD_SHARED_LIBS=OFF \
			-DCMAKE_BUILD_TYPE=Release \
			-DCMAKE_C_COMPILER=clang \
			-DCMAKE_INSTALL_PREFIX="${WORKDIR}/waywallen-bridge" \
			-DCMAKE_LINKER_TYPE=LLD || die
		cmake --build "${WORKDIR}/waywallen-bridge-build" || die
		cmake --install "${WORKDIR}/waywallen-bridge-build" || die
		mylitoargs+=( --config "cmake.search-path=[\"${WORKDIR}/waywallen-bridge\"]" )
	fi

	if use scene; then
		lito build "${mylitoargs[@]}" -p owe-sceneviewer || die
	fi
	if use web; then
		lito build "${mylitoargs[@]}" -p owe-webviewer || die
	fi
	if use waywallen; then
		lito build "${mylitoargs[@]}" -p owe-waywallen-scene-renderer || die
		lito build "${mylitoargs[@]}" -p owe-waywallen-web-renderer || die
	fi
}

src_install() {
	local -x PATH="$(get_llvm_prefix -b)/bin:${PATH}"
	local -a mylitoargs=(

		--locked
		--offline
		--prefix "${ED}/usr"
		--profile release
		# the std module fails to build with _FORTIFY_SOURCE
		# https://github.com/llvm/llvm-project/issues/121709
		"${LITO_PATCH_ARGS[@]}"
		--config 'build.options=["-D_GENTOO_NO_FORTIFY_SOURCE","-U_FORTIFY_SOURCE"]'
	)

	if use waywallen; then
		mylitoargs+=( --config "cmake.search-path=[\"${WORKDIR}/waywallen-bridge\"]" )
	fi

	if use scene; then
		lito install "${mylitoargs[@]}" -p owe-sceneviewer || die
	fi
	if use web; then
		lito install "${mylitoargs[@]}" -p owe-webviewer || die
	fi
	if use waywallen; then
		lito install "${mylitoargs[@]}" -p owe-waywallen-plugin || die
	fi

	if use web; then
		local weweb_dir="${ED}/usr/bin/weweb"

		dodir "/usr/libexec/${PN}"
		mv "${ED}/usr/bin/WebViewer" "${weweb_dir}" || die
		mv "${weweb_dir}" "${ED}/usr/libexec/${PN}" || die
		patchelf --set-rpath '$ORIGIN' \
			"${ED}/usr/libexec/${PN}/weweb/WebViewer" || die
		if use waywallen; then
			patchelf --set-rpath '$ORIGIN' \
				"${ED}/usr/libexec/${PN}/weweb/waywallen-weweb-renderer" || die
		fi
		dosym "../libexec/${PN}/weweb/WebViewer" /usr/bin/WebViewer
		dodoc vendor/cef/LICENSE.txt vendor/cef/CREDITS.html
	fi
}
