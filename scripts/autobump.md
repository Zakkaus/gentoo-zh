# autobump

[简体中文](autobump.zh.md)

Auto-bumps the **mechanical** version updates that nvchecker reports: change the version, regenerate
the Manifest, verify with a real emerge, and open a PR if it passes. Non-mechanical bumps (needing a
human to touch deps / USE / patches, or a missing vendor bundle) only get an evidence comment on the
issue — no PR. **Every PR is reviewed and merged by a human; nothing is auto-merged.**

## Opting a package in / out

Add `autobump = true` to the package in `.github/workflows/overlay.toml`:

```toml
["net-proxy/mihomo"]
source = "github"
github = "MetaCubeX/mihomo"
autobump = true          # ← add to enable; remove to disable
```

Packages without it are not autobumped. If one keeps opening bad PRs, remove the line to stop it. Good
candidates: `-bin` prebuilt packages, single-file source packages, rust / npm packages with a stable
vendor bundle.

## Finding opt-in candidates (recommendations)

The `autobump-recommend` workflow (Actions → autobump-recommend → Run workflow) periodically collects
packages that are **not yet opted in but look mechanically bumpable** into **one fixed issue**,
replacing its body in place — so it never spams. Two signals:

- `scripts/autobump-discover.sh` — scans git history for packages whose recent bumps were purely
  mechanical.
- `scripts/autobump-probe.sh` — runs the engine `--check` over the open nvchecker issues and lists the
  ones it judges mechanical **right now** but that are not opted in.

Both are recommendations only; you review and add `autobump = true` by hand — nothing is enabled
automatically. Both scripts can also be run locally.

## Usage

- **Manual**: repo → Actions → autobump → Run workflow. Empty `issues` = process every open nvchecker
  issue (not-opted-in ones are skipped); `limit` = how many at most this run.
- **Local**: clone the engine into the overlay root (`git clone https://github.com/gentoo-zh/autobump-rb`),
  install `dev-lang/ruby`, then
  `AUTOBUMP_ENGINE='ruby autobump-rb/bin/autobump' bash scripts/autobump-sweep.sh [issue#...] [--limit N] [--pr]`.
- **Scheduled**: the cron at the top of `autobump.yml` is commented out by default; uncomment it once a
  few manual runs look stable to enable the daily run.

## Outcomes

- **mechanical** — plain version change, real emerge passed → opens a PR.
- **escalate** — major jump, changed dep surface, `files/` patch to re-verify, missing per-version
  vendor bundle → evidence comment on the issue, no PR.
- **defer** — transient network / mirror / missing-upstream-file problems, or a heavy dependency with
  no matching binpkg on the binhost that would build from source and exceed the CI timeout; retried
  automatically.

Opened PRs still go through `emerge-on-pr` + `pkgcheck` and are merged by a human after review. Which
issues a run processed and their outcomes (bumped / deferred / skip) are in the sweep summary at the
end of that Actions run log.

---

Engine internals, classification details, deploy and ops: **[autobump-rb](https://github.com/gentoo-zh/autobump-rb)**.
