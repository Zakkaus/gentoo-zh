## Kernel Packages

Read with: `version-bumps.md` for a bump; `new-packages.md` for a new kernel package; `prebuilt-binaries.md` for a `-kernel-bin`; `pr-text.md` before committing.

The overlay carries seven kernel packages, all inheriting `cjktty`: `gentoo-cjk-sources`, `gentoo-cjk-kernel`, and `gentoo-cjk-kernel-bin` (the dist-kernel source, self-built, and prebuilt forms); `cachyos-sources`, `xanmod-sources`, and `liquorix-sources` (downstream source kernels); and `xanmod-kernel` (a dist-kernel built from the XanMod patch). Every one of them carries `CJKTTY_PV` and is coupled to cjktty's live bytes.

- Each kernel package follows its own upstream, not kernel.org: `gentoo-cjk-*` follows `::gentoo`'s `gentoo-kernel` and `gentoo-sources` on the branches this overlay already carries; `cachyos-sources` follows CachyOS, `xanmod-*` follows XanMod, `liquorix-sources` follows Liquorix. Decide a bump from that upstream's newest release on the branch.
- Copy per-version variables from the same-version upstream ebuild or release; never derive them from the version number. `PATCHSET` in particular lags its branch.
- `CJKTTY_PV` is the version suffix of the cjktty patch file the package applies. It changes whenever the patch changes, inside a branch as well as across branches.
- A point release reuses the current cjktty patch unless upstream touched a file the patch touches. Take the file list from the patch itself (`grep '^+++ b/' cjktty-code-${CJKTTY_PV}.patch`), intersect it with the incremental `.../incr/patch-A-B.xz`, and keep the patch and `CJKTTY_PV` only when the intersection is empty. Do not keep a hand-written path list.
- `cjktty.eclass` points `SRC_URI` at raw addresses on `cjktty-patches` `master`, so those distfiles are live bytes: a change in that repository stales every Manifest that names them. Regenerate them together, after confirming the distdir copy equals `master`'s current bytes; `pkgdev manifest` rehashes whatever is in the distdir, and mirrors cache old copies.
- The downstream kernels pin commit- or release-specific bytes: CachyOS patch, config, and rebase inputs by commit, XanMod's SourceForge `patch-<ver>-xanmod<N>.xz`, Liquorix's zen-kernel `v<ver>-lqx<N>.patch.xz`. Reuse the exact host and naming the existing `SRC_URI` uses; never switch source or invent a filename.
- For a `-bin` gpkg, regenerate the Manifest from a real download and cross-check each entry's size against the source's HTTP `content-length`; never paste a hash from elsewhere.
- A `-bin` gpkg is built after the fact, so a source bump usually lands before its binary exists. Land the source, kernel, and virtual first, the virtual listing only the source provider; add `-bin` and its virtual entry in a second PR once the gpkg is published. A `-bin` trailing its source sibling by one point release is expected, not a retention that needs explaining.
- In a `virtual/dist-kernel-*-r100` `||` group the order is the preference order: list `-bin` first so portage installs the prebuilt kernel, then the source package, then any other provider such as `xanmod-kernel`.
- A new kernel package takes its shape from the row below that matches its model: `kernel-2` + `cjktty` for a `-sources`, `kernel-build` for a self-built dist-kernel, `kernel-install` for a `-bin`. It gets its own `overlay.toml` entry, a dist-kernel provider gets its `virtual/dist-kernel-*` entry, and this table gets a row.
- Gentoo's personal mirrors (`dev.gentoo.org/~<dev>`) can lag `distfiles.gentoo.org` for a new genpatches, so a `DeadUrl` there is often mirror lag. Re-check the primary mirror before acting.

### What each bump checks

Every variable below is compared with the same-version upstream ebuild or release on every bump and copied when it differs; the last column names values that only change when upstream changes its scheme.

| Package | Check against the same version of | Variables | Fixed by design |
| --- | --- | --- | --- |
| `gentoo-cjk-sources` | `gentoo-sources` | `K_GENPATCHES_VER`, `K_WANT_GENPATCHES`, `CJKTTY_PV` | the all-arch `KEYWORDS` |
| `gentoo-cjk-kernel` | `gentoo-kernel` | `PATCHSET`, `CONFIG_VER`, `GENTOO_CONFIG_P`, `SHA256SUM_DATE`, `DEBIAN_COMMIT`, `CJKTTY_PV` | |
| `gentoo-cjk-kernel-bin` | `gentoo-kernel-bin`; gpkg on `distfiles.gentoozh.org/gentoo-cjk-kernel/amd64/<major.minor>/` | `PATCHSET`, `SHA256SUM_DATE`, `CJKTTY_PV`; Manifest from the real download | |
| `cachyos-sources` | CachyOS repositories; `gentoo-sources` for genpatches | `CACHYOS_PATCHES_COMMIT`, `CACHYOS_CONFIGS_COMMIT`, `CACHYOS_PR`, `ZFS_COMMIT`, `K_GENPATCHES_VER`, `CJKTTY_PV`; the version path embedded in the rebase URI | `UNIPATCH_EXCLUDE`, `K_NO_VERSION_CHECK` |
| `xanmod-sources` | XanMod on SourceForge; `gentoo-sources` for genpatches | `K_GENPATCHES_VER`, `CJKTTY_PV`, `XANMOD_VERSION` (the spin number in `patch-<PV>-xanmod<N>.xz`) | |
| `xanmod-kernel` | `gentoo-kernel` on the same branch; XanMod on SourceForge | `PATCHSET`, `CJKTTY_PV`, `XV` (the XanMod spin number), `LLVM_COMPAT` when upstream's clang support changed; the matching `virtual/dist-kernel` entry | |
| `liquorix-sources` | zen-kernel releases; `gentoo-sources` for genpatches | `K_GENPATCHES_VER`, `K_WANT_GENPATCHES`, `CJKTTY_PV`, the `lqx<N>` suffix in `SRC_URI` and `UNIPATCH_LIST_DEFAULT` | `K_NOSETEXTRAVERSION`, `K_EXP_GENPATCHES_NOUSE` |
