<div align="right">

English | [简体中文](./CONTRIBUTING.md) | [正體中文](./CONTRIBUTING.zh-TW.md)

</div>

# Contributing to gentoo-zh

**DO NOT BREAK PEOPLE'S SYSTEM.**

* Everyone is welcome to contribute, but committers should check their work
  carefully before committing.

## Ebuild quality

* Use the latest [EAPI](https://devmanual.gentoo.org/ebuild-writing/eapi/index.html) that
  every [eclass](https://devmanual.gentoo.org/eclass-reference/index.html) you inherit
  supports.
* Quote string variable expansions: `"${P}"`, not `${P}`.
* Follow the coding style in the
  [Policy Guide](https://projects.gentoo.org/qa/policy-guide/ebuild-format.html#pg0101): tab
  indentation, `${foo}` over `$foo`, `[[ ]]` over `[ ]`.
* Do not use symlinks, such as `foobar-1.2.3.ebuild -> foobar-9999.ebuild`. Every ebuild
  must be a standalone file.
* Do not depend on deprecated EAPIs, eclasses or packages; they are listed in the
  [Policy Guide](https://projects.gentoo.org/qa/policy-guide/deprecation.html) and in
  `$(portageq get_repo_path / gentoo)/profiles/package.deprecated`.
* Always install small files such as bash completions, init.d scripts, logrotate
  configuration and systemd units; do not put them behind a USE flag, because they add no
  build dependency and no meaningful build time. See
  [PG 0301](https://projects.gentoo.org/qa/policy-guide/installed-files.html#pg0301).
* Do not add a USE flag that leaves the compiled result unchanged and only pulls in an
  optional runtime dependency; use `optfeature` to tell the user about it instead. See
  [PG 0001](https://projects.gentoo.org/qa/policy-guide/dependencies.html#pg0001).
* Run `pkgcheck scan --commits --net` locally before you open a pull request.

## Licenses

* `LICENSE` must match what upstream actually grants. When the license is not in
  `::gentoo`, add its full text under [`licenses/`](./licenses), put it in the matching
  group in [`profiles/license_groups`](./profiles/license_groups), and set `RESTRICT`
  from its redistribution terms.
* Check the upstream license file against the source headers: without `or later` in the
  headers it is `GPL-3`, not `GPL-3+`.
* Rust, Go and Node packages bundle dependencies; `LICENSE` must list their licenses too.
  Check them with `dev-util/cargo-license` and `dev-go/lichen`.
* Set [`RESTRICT`](https://devmanual.gentoo.org/ebuild-writing/variables/index.html#restrict)
  from the redistribution terms: `mirror` when the distfile may not be mirrored, `bindist`
  when the binary package may not be redistributed.

## Vendored dependencies

Because Portage enables `FEATURES=network-sandbox` by default, do not use `EGO_SUM`. Pack the
dependencies into a tarball, publish it and fetch it from `SRC_URI`; see
[gentoo-deps](https://github.com/gentoo-zh/gentoo-deps) for how to use it.

## Version tracking

* A new package must be added to
  [`.github/workflows/overlay.toml`](./.github/workflows/overlay.toml), inserted in
  alphabetical order by `category/package`. If it can be bumped automatically, see
  [scripts/autobump.md](./scripts/autobump.md).
* If a package is not suitable for nvchecker to check for new versions, add a comment
  in that position explaining why. When several nvchecker entries point at the same
  source, comment out one of them as well; a package that can enable autobump is
  exempt.
* `prefix` only strips that prefix when the version carries it, it does not filter.
  When upstream also tags something else in the same repository, select with
  `include_regex` or `exclude_regex`; both full-match the raw tag.
* Once the entry is written, run `nvchecker -c <config> -k <keyfile>` and confirm it
  selects the version you expect.

## Commits

* Every commit in a pull request must carry all the changes it needs; do not split a
  change across commits without reason, e.g. an ebuild and its `Manifest` belong in
  the same commit.
* Every ebuild change must compile before committing.
* Use the [pull request template](./.github/pull_request_template.md).

We recommend generating them with `pkgdev commit`. Version bump:

```
$category/$package: add $new_version, drop $old_version
```

Anything else:

```
$category/$package: one line short description message

multiple lines of description about why you change this.
if you change to fix the bug, and if there is an GitHub
issue entry for that bug, then point the bug link here.
```

## CI

* CI runs with [`PORTAGE_ELOG_CLASSES`](https://wiki.gentoo.org/wiki/Portage_log#Setup) set to
  `qa warn error`.
* Use `einfo`, `elog`, `ewarn`, `eerror` and `eqawarn` as
  [devmanual](https://devmanual.gentoo.org/ebuild-writing/messages/index.html) defines them.
* Fix whatever the pkgcheck report and CI flag, QA warnings included.
* CI builds on amd64 and arm64. If a problem shows up on an arch you do not have and
  you cannot solve it, remove that keyword.

## Maintenance

* Keep maintaining the packages you add.
* When you stop maintaining a package, look for a new maintainer in the issues, or
  mask it in [`profiles/package.mask`](./profiles/package.mask) and drop it when the
  mask expires.
* When you remove a package, remove its entry from
  [`.github/workflows/overlay.toml`](./.github/workflows/overlay.toml) as well.

## AI policy

Generative AI may assist, but it must follow [AGENTS.md](./AGENTS.md) and the
contributor is responsible for every commit: ensure the quality of the ebuild and
verify that it works, smoke-test it before submitting, and keep the pull request
description short, precise and professional, written from tested results, not
guesses. The contributor, submitter, and commit author must be a human, not an AI
tool or model identity.

## References

### This repository

* [AGENTS.md](./AGENTS.md): the detailed rules for this repository, binding on generative AI assistance
* [scripts/autobump.md](./scripts/autobump.md): how to opt a package into autobump
* [gentoo-deps](https://github.com/gentoo-zh/gentoo-deps): workflow that generates dependency tarballs
* [Dependency table](https://github.com/gentoo-zh/overlay/blob/deps-table/relation.md): how the packages depend on each other

### Gentoo upstream

* [Gentoo Development Manual](https://devmanual.gentoo.org/): the reference for writing ebuilds
* [Basic guide to write Gentoo Ebuilds](https://wiki.gentoo.org/wiki/Basic_guide_to_write_Gentoo_Ebuilds): a starting point
* [Package Manager Specification](https://projects.gentoo.org/pms/8/pms.html): what EAPI 8 actually specifies
* [eclass reference](https://devmanual.gentoo.org/eclass-reference/index.html): variables, phases and supported EAPIs per eclass
* [Python Guide](https://projects.gentoo.org/python/guide/): `distutils-r1` and Python packages
* [Repository format](https://wiki.gentoo.org/wiki/Repository_format): the layout of `metadata/`, `profiles/` and `layout.conf`
* [Package testing](https://wiki.gentoo.org/wiki/Package_testing): local testing and QA check configuration
* [Gentoo Policy Guide](https://projects.gentoo.org/qa/policy-guide/): the QA policies, the rules pkgcheck enforces
* [License groups](https://wiki.gentoo.org/wiki/License_groups): `ACCEPT_LICENSE` and license grouping
* [A better ebuild workflow with pure git and pkgcheck](https://blogs.gentoo.org/mgorny/2019/12/12/a-better-ebuild-workflow-with-pure-git-and-pkgcheck/): why and how to use `pkgdev`
* [GURU CONTRIBUTING.md](https://github.com/gentoo/guru/blob/master/CONTRIBUTING.md): common mistakes and tips from the official community overlay
