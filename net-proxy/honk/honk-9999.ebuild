# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CRATES=""
RUST_MIN_VER="1.85.0"
# same requirement as dev-util/bpf-linker
RUST_REQ_USE="llvm_targets_BPF(+),rust_sysroots_bpf(-)"

inherit cargo git-r3 linux-info systemd

DESCRIPTION="Rust eBPF transparent proxy engine with a dae datapath and sing-box outbounds"
HOMEPAGE="https://github.com/daeuniverse/honk"
EGIT_REPO_URI="https://github.com/daeuniverse/honk.git"

LICENSE="GPL-3"
# Dependent crate licenses
LICENSE+="
	0BSD Apache-2.0 BSD-2 BSD CC0-1.0 ISC MIT MPL-2.0 openssl
	Unicode-3.0 Unlicense ZLIB
"
SLOT="0"

BDEPEND="
	dev-build/cmake
	llvm-core/clang
	virtual/pkgconfig
	>=dev-util/bpf-linker-0.11.0
"
RDEPEND="
	app-alternatives/v2ray-geoip
	app-alternatives/v2ray-geosite
"

MINKV="5.8"

pkg_setup() {
	# linux-info exports pkg_setup too, so call rust's explicitly
	linux-info_pkg_setup
	rust_pkg_setup
}

pkg_pretend() {
	local CONFIG_CHECK="~BPF ~BPF_SYSCALL ~BPF_JIT ~CGROUP_BPF ~NET_CLS_BPF
		~NET_SCH_INGRESS ~NET_CLS_ACT ~NET_NS
		~NF_TABLES ~NF_TABLES_INET ~NETFILTER_NETLINK_QUEUE"

	if kernel_is -lt ${MINKV//./ }; then
		ewarn "Kernel version at least ${MINKV} required"
	fi

	check_extra_config
}

src_unpack() {
	git-r3_src_unpack
	cargo_live_src_unpack

	# honk-ebpf is outside the workspace with its own lock, and --sync adds its
	# crates to the vendor directory rather than replacing it
	local -x CARGO_HOME="${ECARGO_REGISTRY_DIR}"
	addwrite "${CARGO_HOME}"

	cd "${S}" || die
	"${CARGO}" vendor --sync crates/honk-ebpf/Cargo.toml "${ECARGO_VENDOR}" \
		|| die "failed to vendor the eBPF crate's dependencies"
}

src_configure() {
	local myfeatures=(
		ebpf
	)

	cargo_src_configure
}

src_compile() {
	# build.rs builds this itself through rustup, which we do not have
	# aya-ebpf needs #![feature(asm_experimental_arch)]
	local -x RUSTC_BOOTSTRAP=1
	# any value here, empty included, drops the crate's own target rustflags
	# carrying -C linker=bpf-linker and the --btf link argument
	unset RUSTFLAGS

	local cmd=(
		"${CARGO}" build
		--release
		--offline
		--target=bpfel-unknown-none
	)

	pushd crates/honk-ebpf >/dev/null || die
	echo "${cmd[*]}" >&2
	"${cmd[@]}" || die "${cmd[*]} failed"
	# aya rejects an object without it, and losing the flags above is silent
	readelf -S target/bpfel-unknown-none/release/honk-ebpf | grep -q '\.BTF' \
		|| die "eBPF object has no .BTF section"
	popd >/dev/null || die

	cargo_src_compile -p honk-core -p honk-tool
}

src_install() {
	# cargo install takes neither a virtual manifest nor -p
	dobin "$(cargo_target_dir)"/honk-core
	dobin "$(cargo_target_dir)"/honk-tool

	newinitd "${FILESDIR}"/honk.initd honk
	newconfd "${FILESDIR}"/honk.confd honk
	systemd_newunit "${FILESDIR}"/honk.service honk.service

	keepdir /etc/honk
	insinto /usr/share/honk
	newins example.dae config.dae.example
	doins config.min.dae

	dodoc README.md README_CN.md
	docinto doc
	dodoc -r doc/en doc/zh

	# honk-config's DEFAULT_DATA_DIR, and the only asset path find_dat() searches
	# that we control
	keepdir /var/share/honk
	dosym -r /usr/share/v2ray/geoip.dat /var/share/honk/geoip.dat
	dosym -r /usr/share/v2ray/geosite.dat /var/share/honk/geosite.dat
}

pkg_postinst() {
	elog "honk needs a configuration at /etc/honk/config.dae before it will start."
	elog "An annotated example is installed as /usr/share/honk/config.dae.example."
	elog
	elog "The engine runs as root: it loads eBPF programs, creates the dae0/daens"
	elog "pair, and owns nftables table 'inet honk_nfqueue' and netlink queue 320."
	elog "A firewall manager in the same network namespace must leave those alone."
}
