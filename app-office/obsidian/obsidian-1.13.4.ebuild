# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CHROMIUM_LANGS="
	af am ar bg bn ca cs da de el en-GB en-US es es-419 et fa fi fil fr gu he hi
	hr hu id it ja kn ko lt lv ml mr ms nb nl pl pt-BR pt-PT ro ru sk sl sr sv
	sw ta te th tr uk ur vi zh-CN zh-TW
"

inherit chromium-2 desktop xdg

DESCRIPTION="Knowledge base on top of a local folder of plain text Markdown files"
HOMEPAGE="https://obsidian.md/"
# Upstream also ships an arm64 tarball, but its bundled btime and get-fonts
# modules are x86-64 binaries there, so it installs with unresolved sonames.
SRC_URI="https://github.com/obsidianmd/obsidian-releases/releases/download/v${PV}/${P}.tar.gz"

LICENSE="Obsidian-EULA"
SLOT="0"
KEYWORDS="-* ~amd64"
IUSE="appindicator wayland"
RESTRICT="bindist mirror strip"

RDEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	app-crypt/libsecret
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/mesa[gbm(+)]
	net-print/cups
	sys-apps/dbus
	sys-apps/util-linux
	sys-libs/glibc
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/libdrm
	x11-libs/libX11
	x11-libs/libXScrnSaver
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/libxshmfence
	x11-libs/pango
	appindicator? ( dev-libs/libayatana-appindicator )
"

DESTDIR="/opt/${PN}"

QA_PREBUILT="*"

obsidian_desktop_entry() {
	local file="${T}/$1.desktop" name="$2" exec="$3"

	cat > "${file}" <<-EOF || die
		[Desktop Entry]
		Type=Application
		Name=${name}
		Comment=${DESCRIPTION}
		Exec=${exec} %u
		Icon=${PN}
		Terminal=false
		StartupWMClass=obsidian
		Categories=Office;
		MimeType=x-scheme-handler/obsidian;
	EOF

	domenu "${file}"
}

pkg_setup() {
	# chromium-2 inherits linux-info, but this binary package does not need kernel probing.
	:
}

src_prepare() {
	default

	pushd locales >/dev/null || die "location change for language cleanup failed"
	chromium_remove_language_paks
	popd >/dev/null || die "location reset for language cleanup failed"
}

src_install() {
	exeinto "${DESTDIR}"
	doexe obsidian obsidian-cli chrome-sandbox \
		libEGL.so libffmpeg.so libGLESv2.so libvk_swiftshader.so

	local optional
	for optional in chrome_crashpad_handler libvulkan.so.1; do
		[[ -f ${optional} ]] && doexe "${optional}"
	done

	insinto "${DESTDIR}"
	doins chrome_100_percent.pak chrome_200_percent.pak icudtl.dat resources.pak \
		snapshot_blob.bin v8_context_snapshot.bin vk_swiftshader_icd.json

	insopts -m0755
	doins -r locales resources

	# Chrome-sandbox requires the setuid bit to be specifically set.
	# see https://github.com/electron/electron/issues/17972
	fowners root "${DESTDIR}/chrome-sandbox"
	fperms 4711 "${DESTDIR}/chrome-sandbox"

	newicon -s 512 resources/icon.png "${PN}.png"

	dosym -r "${DESTDIR}/obsidian" /usr/bin/obsidian
	dosym -r "${DESTDIR}/obsidian-cli" /usr/bin/obsidian-cli

	if use appindicator; then
		dosym -r "/usr/$(get_libdir)/libayatana-appindicator3.so" "${DESTDIR}/libappindicator3.so"
	fi

	obsidian_desktop_entry "${PN}" Obsidian obsidian

	# Electron runs natively under Wayland with the Ozone platform, but that
	# crashes on some systems, so keep the XWayland entry above as the default
	# and offer this one alongside it. See https://bugs.gentoo.org/915899
	if use wayland; then
		obsidian_desktop_entry "${PN}-wayland" "Obsidian (Wayland)" \
			"obsidian --ozone-platform-hint=auto --enable-features=UseOzonePlatform,WaylandWindowDecorations --enable-wayland-ime"
	fi
}
