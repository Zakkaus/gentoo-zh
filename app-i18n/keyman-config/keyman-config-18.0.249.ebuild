# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{11..14} )

inherit desktop distutils-r1 gnome2-utils optfeature xdg

DESCRIPTION="Keyman for Linux configuration and keyboard installer"
HOMEPAGE="https://keyman.com/ https://github.com/keymanapp/keyman"
SRC_URI="https://downloads.keyman.com/linux/stable/${PV}/keyman-${PV}.tar.gz"
S="${WORKDIR}/keyman/linux/keyman-config"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	${PYTHON_DEPS}
	app-i18n/ibus[introspection]
	net-libs/webkit-gtk:4.1[introspection]
	x11-libs/gtk+:3[introspection]
	dev-python/dbus-python[${PYTHON_USEDEP}]
	dev-python/fonttools[${PYTHON_USEDEP}]
	dev-python/lxml[${PYTHON_USEDEP}]
	dev-python/numpy[${PYTHON_USEDEP}]
	dev-python/packaging[${PYTHON_USEDEP}]
	dev-python/pillow[${PYTHON_USEDEP}]
	dev-python/pygobject:3[${PYTHON_USEDEP}]
	dev-python/python-magic[${PYTHON_USEDEP}]
	dev-python/pyxdg[${PYTHON_USEDEP}]
	dev-python/qrcode[${PYTHON_USEDEP}]
	dev-python/requests[${PYTHON_USEDEP}]
	dev-python/requests-cache[${PYTHON_USEDEP}]
"
BDEPEND="sys-devel/gettext"

PATCHES=(
	"${FILESDIR}"/${P}-packaging.patch
	"${FILESDIR}"/${P}-window-icon.patch
)

src_prepare() {
	# version.py is generated from VERSION.md by the upstream build system;
	# __uploadsentry__ = False keeps the optional Sentry telemetry (and its
	# unpackaged sentry-sdk dependency) disabled.
	printf '%s\n' \
		"__version__ = '${PV}'" \
		"__versionwithtag__ = '${PV}'" \
		"__versiongittag__ = 'release-${PV}'" \
		"__majorversion__ = '${PV%.*}'" \
		"__releaseversion__ = '${PV}'" \
		"__tier__ = 'stable'" \
		"__pkgversion__ = ''" \
		"__environment__ = 'stable'" \
		"__uploadsentry__ = False" \
		> keyman_config/version.py || die
	distutils-r1_src_prepare
}

python_install_all() {
	distutils-r1_python_install_all

	# Data the setup.py does not carry (handled by the upstream Makefile).
	insinto /usr/share/glib-2.0/schemas
	doins resources/com.keyman.gschema.xml

	insinto /usr/share/mime/packages
	newins resources/keyman.sharedmimeinfo keyman.xml

	domenu resources/km-config.desktop

	# hicolor icons the .desktop and the MIME type reference by name; the two
	# icons ship in different size sets, so install each where it exists.
	local f size
	for f in icons/*/km-config.png; do
		size=$(basename "$(dirname "${f}")")
		insinto /usr/share/icons/hicolor/${size}x${size}/apps
		doins "${f}"
	done
	for f in icons/*/application-x-kmp.png; do
		size=$(basename "$(dirname "${f}")")
		insinto /usr/share/icons/hicolor/${size}x${size}/mimetypes
		doins "${f}"
	done

	insinto /usr/share/keyman/icons
	doins keyman_config/icons/*

	local po lang
	for po in locale/*.po; do
		lang=$(basename "${po}" .po)
		msgfmt "${po}" -o "${T}/${lang}.mo" || die
		insinto /usr/share/locale/${lang}/LC_MESSAGES
		newins "${T}/${lang}.mo" keyman-config.mo
	done
}

pkg_postinst() {
	xdg_pkg_postinst
	gnome2_schemas_update
	optfeature "using the installed keyboards with an input method" \
		app-i18n/ibus-keyman app-i18n/fcitx-keyman
}

pkg_postrm() {
	xdg_pkg_postrm
	gnome2_schemas_update
}
