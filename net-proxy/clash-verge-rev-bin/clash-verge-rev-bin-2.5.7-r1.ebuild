# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop systemd unpacker xdg

DESCRIPTION="(Continuation) of Clash Meta GUI based on Tauri"
HOMEPAGE="https://github.com/clash-verge-rev/clash-verge-rev"

if [[ ${PV} == 9999 ]]; then
	PROPERTIES+=" live"
else
	URL_PREFIX="https://github.com/clash-verge-rev/clash-verge-rev/releases/download/v${PV}/Clash.Verge_${PV}_"
	SRC_URI="
		amd64? ( ${URL_PREFIX}amd64.deb -> ${P}_amd64.deb )
		arm64? ( ${URL_PREFIX}arm64.deb -> ${P}_arm64.deb )
	"
	KEYWORDS="~amd64 ~arm64"
fi

S="${WORKDIR}"
LICENSE="GPL-3"
SLOT="0"

[[ ${PV} == *9999* ]] && BDEPEND+=" net-misc/curl app-misc/jq"

DEPEND="
	dev-libs/libayatana-appindicator
	net-libs/webkit-gtk:4.1
	dev-libs/openssl:0/3
"

RDEPEND="${DEPEND}"

RESTRICT="strip"

src_unpack() {
	if [[ ${PV} == 9999 ]]; then
		local arch_suffix
		case ${ARCH} in
			amd64) arch_suffix="amd64" ;;
			arm64) arch_suffix="arm64" ;;
			*) die "Unsupported architecture: ${ARCH}" ;;
		esac

		einfo "Fetching latest autobuild version for ${ARCH}..."

		# Get the latest version from latest.json
		local version
		local latest_url="https://github.com/clash-verge-rev/clash-verge-rev"
		latest_url+="/releases/download/autobuild/latest.json"
		version=$(curl -sL "${latest_url}" | jq -r '.version') || die "Failed to fetch latest version"

		# URL encode the + sign in version
		local encoded_version="${version//+/%2B}"
		local filename="Clash.Verge_${version}_${arch_suffix}.deb"
		local dl_url="https://github.com/clash-verge-rev/clash-verge-rev"
		dl_url+="/releases/download/autobuild/Clash.Verge_${encoded_version}_${arch_suffix}.deb"

		einfo "Downloading ${filename} (version ${version})..."
		curl -L -o "${WORKDIR}/${filename}" "${dl_url}" || die "Failed to download ${filename}"

		# Use Portage's unpack_deb function for proper extraction
		cd "${WORKDIR}" || die
		unpack_deb "./${filename}"
	else
		unpacker_src_unpack
	fi
}

src_install() {
	exeinto /opt/clash-verge/bin
	doexe "${S}"/usr/bin/*
	insinto /usr/lib/clash-verge
	doins -r "${S}"/usr/lib/Clash\ Verge/resources
	exeinto /opt/clash-verge/libexec/openrc
	newexe "${FILESDIR}"/clash-verge-openrc-systemctl systemctl
	newbin "${FILESDIR}"/clash-verge-launcher clash-verge
	domenu "${FILESDIR}"/clash-verge.desktop
	doicon -s 128 usr/share/icons/hicolor/128x128/apps/clash-verge.png
	doicon -s 256 usr/share/icons/hicolor/256x256@2/apps/clash-verge.png
	doicon -s 32 usr/share/icons/hicolor/32x32/apps/clash-verge.png
	newinitd "${FILESDIR}"/clash-verge.initd-r1 clash-verge
}

pkg_postinst() {
	xdg_pkg_postinst

	if ! systemd_is_booted; then
		elog "OpenRC 下请用 rc-service 管理服务，不要用应用内的安装/修复服务："
		elog "On OpenRC, manage the service with rc-service, not the in-app install/repair:"
		elog "  rc-update add clash-verge default"
		elog "  rc-service clash-verge start"
		elog "开机自启项需执行 /usr/bin/clash-verge 才能识别该服务。"
		elog "Autostart entries must run /usr/bin/clash-verge to detect the service."
	fi
}
