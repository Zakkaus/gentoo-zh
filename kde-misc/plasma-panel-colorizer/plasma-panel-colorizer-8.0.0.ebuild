# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..15} )
KFMIN=6.0.0
QTMIN=6.6.0
inherit python-single-r1 ecm optfeature

DESCRIPTION="Latte-Dock and window manager status bar customization for Plasma panels"
HOMEPAGE="https://github.com/luisbocanegra/plasma-panel-colorizer"
SRC_URI="https://github.com/luisbocanegra/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

DEPEND="
	>=dev-qt/qtbase-${QTMIN}:6[gui]
	>=dev-qt/qtdeclarative-${QTMIN}:6
	>=kde-plasma/libplasma-6.0:6
"
BDEPEND="
	${PYTHON_DEPS}
	sys-devel/gettext
"
RDEPEND="${DEPEND}
	${PYTHON_DEPS}
	$(python_gen_cond_dep '
		dev-python/dbus-python[${PYTHON_USEDEP}]
		dev-python/pygobject:3[${PYTHON_USEDEP}]
	')
"

pkg_setup() {
	python-single-r1_pkg_setup
	ecm_pkg_setup
}

src_prepare() {
	python_fix_shebang package/contents/ui/tools
	ecm_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_PLUGIN=ON
		-DINSTALL_PLASMOID=ON
	)

	ecm_src_configure
}

src_compile() {
	# upstream builds the message catalogs outside cmake
	${EPYTHON} kpac i18n --no-merge || die

	ecm_src_compile
}

src_install() {
	ecm_src_install

	# plasma_install_package drops the executable bit the QML relies on
	local tools=/usr/share/plasma/plasmoids/luisbocanegra.panel.colorizer/contents/ui/tools
	fperms 0755 "${tools}"/{gdbus_get_signal.sh,list_presets.sh,service.py}
}

pkg_postinst() {
	if [[ -z ${REPLACING_VERSIONS} ]]; then
		optfeature "preset previews" kde-plasma/spectacle
	fi
	ecm_pkg_postinst
}
