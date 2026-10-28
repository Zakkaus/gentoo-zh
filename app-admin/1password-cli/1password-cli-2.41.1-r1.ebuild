# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Command line interface for the 1Password password manager"
HOMEPAGE="https://www.1password.dev/cli"
SRC_URI="
	amd64? ( https://cache.agilebits.com/dist/1P/op2/pkg/v${PV}/op_linux_amd64_v${PV}.zip -> ${P}-amd64.zip )
	arm64? ( https://cache.agilebits.com/dist/1P/op2/pkg/v${PV}/op_linux_arm64_v${PV}.zip -> ${P}-arm64.zip )
"
S="${WORKDIR}"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
RESTRICT="bindist mirror"

RDEPEND="
	arm64? ( acct-group/onepassword )
	!arm64? ( acct-group/onepassword-cli )
	!app-admin/op-cli-bin
"
BDEPEND="
	arm64? ( acct-group/onepassword )
	!arm64? ( acct-group/onepassword-cli )
	app-arch/unzip
"

QA_PREBUILT="usr/bin/op"

# The CLI install guide names onepassword-cli, but the arm64 desktop app 8.12.42
# accepts only onepassword.
_op_group() {
	if use arm64; then
		echo onepassword
	else
		echo onepassword-cli
	fi
}

src_install() {
	dobin op
	# the desktop app resets a connection unless the GID of the connecting process
	# is the one it expects, so op runs setgid to that group
	fowners root:$(_op_group) /usr/bin/op
	fperms 2755 /usr/bin/op
}

pkg_postinst() {
	# Portage skips merging an identical file and keeps its old owner (bug 722270)
	chgrp "$(_op_group)" "${EROOT}"/usr/bin/op || die
	chmod 2755 "${EROOT}"/usr/bin/op || die
}
