# Copyright 2025-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker

DESCRIPTION="at32 workbench is a GUI tool for AT32 MCU startup code generation"
HOMEPAGE="https://www.arterytek.com/cn/support/tools.jsp"
SRC_URI="https://www.arterytek.com/download/AT32%20Workbench/AT32_Work_Bench_Linux-x86_64_V${PV}.zip"
S="${WORKDIR}"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="-* ~amd64"
REQUIRED_USE="elibc_glibc"

RESTRICT="bindist mirror strip"

RDEPEND="
	dev-libs/glib:2
	media-libs/fontconfig:1.0
	media-libs/freetype:2
	media-libs/libglvnd:0
	sys-apps/dbus:0
	sys-devel/gcc:*
	sys-libs/glibc:2.2
	virtual/zlib:0/1
	x11-libs/libICE:0
	x11-libs/libSM:0
	x11-libs/libX11:0
	x11-libs/libXi:0
	x11-libs/libxcb:0/1.12
"

BDEPEND="
	app-arch/unzip
	dev-util/patchelf
"

QA_PREBUILT="
	/opt/AT32_Work_Bench/AT32_Work_Bench
	/opt/AT32_Work_Bench/lib*.so*
	/opt/AT32_Work_Bench/platforms/libqxcb.so
"

src_unpack() {
	unpack "${A}"
	unpack_deb "${WORKDIR}/AT32_Work_Bench_Linux-x86_64_V${PV}.deb"
}

src_prepare() {
	default

	rm usr/local/AT32_Work_Bench/copylib.sh || die
	sed -i \
		-e "/^Encoding=/d" \
		-e "s|^Name=AT32_Work_Bench[[:space:]]*$|Name=AT32_Work_Bench|" \
		-e "s|/usr/local/AT32_Work_Bench|/opt/AT32_Work_Bench|" \
		-e "s|Categories=Application;Development;|Categories=Development;|" \
		usr/share/applications/AT32_Work_Bench.desktop || die
	sed -i \
		-e "/^LD_LIBRARY_PATH=/a QT_QPA_PLATFORM=xcb" \
		-e "s/^export LD_LIBRARY_PATH$/export LD_LIBRARY_PATH QT_QPA_PLATFORM/" \
		usr/local/AT32_Work_Bench/AT32_Work_Bench.sh || die
}

src_install() {
	insinto /opt
	doins -r usr/local/AT32_Work_Bench
	fperms 0755 \
		/opt/AT32_Work_Bench/{AT32_Work_Bench,AT32_Work_Bench.sh}

	local elf
	for elf in \
		AT32_Work_Bench \
		libicudata.so.56 \
		libicui18n.so.56 \
		libicuuc.so.56 \
		libqscintilla2_qt5.so.15.0.0 \
		libssl.so; do
		patchelf --set-rpath '$ORIGIN' \
			"${D}/opt/AT32_Work_Bench/${elf}" || die
	done
	patchelf --set-rpath '$ORIGIN/..' \
		"${D}/opt/AT32_Work_Bench/platforms/libqxcb.so" || die

	dosym libcrypto.so /opt/AT32_Work_Bench/libcrypto.so.1.0.0
	dosym libssl.so /opt/AT32_Work_Bench/libssl.so.1.0.0

	dodoc usr/local/Documents/*.pdf
	insinto /usr
	doins -r usr/share
}
