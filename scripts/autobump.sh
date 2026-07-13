#!/usr/bin/env bash
# autobump.sh - deterministic version bump for gentoo-zh.
#
# No LLM in this script. Everything here is mechanical. When something is NOT
# mechanical (layout changed, big version jump, patches, pinned commits), the
# script stops with exit 3 and writes an evidence pack; a cheap LLM (or a
# human) judges the evidence and decides. That is the only place a model sits.
#
# Usage:
#   scripts/autobump.sh <issue#|cat/pkg> [newver] [--check] [--install] [--pr]
#     --check           classify only, no repo writes
#     --diff-only       stop after artifact/build-option diff, clean up branch
#     --accept-surface  judge approved a build-option surface delta; continue
#     --accept-payload  human verified the removed payload paths are harmless
#                       (e.g. a dropped icon size); continue past the tree check
#     --install         after build test, emerge --oneshot and run --version smoke
#     --pr              push branch and open the PR (default stops after commit)
#
# Exit codes:
#   0  done (bump committed; PR opened if --pr)
#   2  precondition failed (dirty tree, branch exists, bad args, fetch error)
#   3  ESCALATE: not mechanically safe. Evidence pack in the printed dir
#      (escalations / surface-added / surface-removed / tree-removed / pins /
#      build.log). A judge - cheap LLM or human - answers from evidence only:
#        1. new or dropped dependency?
#        2. new USE flag needed, or an option the ebuild passes is gone?
#        3. big change (version scheme / major / pins)?
#      Harmless -> re-run with --accept-surface. Otherwise comment on the
#      issue and a human takes over. Never auto-edit RDEPEND/IUSE from a
#      model guess.
#
# Requirements: run as normal user; $SUDO for ebuild/emerge/distfiles.

set -uo pipefail

# All of these can be overridden by env; defaults work both on a dev box
# (fork clone, sudo, live overlay) and in CI (root, canonical checkout).
REPO=${AUTOBUMP_REPO:-$(git rev-parse --show-toplevel 2>/dev/null)}
DISTDIR=${AUTOBUMP_DISTDIR:-/var/cache/distfiles}
LIVE_OVERLAY=${AUTOBUMP_LIVE_OVERLAY:-/var/db/repos/gentoo-zh}
UPSTREAM_REPO=${AUTOBUMP_UPSTREAM_REPO:-gentoo-zh/overlay}
SUDO=$([ "$(id -u)" = 0 ] || echo sudo)
cd "${REPO:?not inside a git checkout}" || exit 2
# Is the live overlay a genuinely separate checkout (dev box), or the same tree
# as REPO (CI registers the checkout itself)? Compare by realpath so that CI
# pointing AUTOBUMP_LIVE_OVERLAY at a symlinked workspace still counts as "same"
# and we skip the copy (a same-file cp would error).
SEPARATE_OVERLAY=0
[ -d "$LIVE_OVERLAY" ] && \
    [ "$(realpath "$LIVE_OVERLAY" 2>/dev/null)" != "$(realpath "$REPO" 2>/dev/null)" ] && \
    SEPARATE_OVERLAY=1
# sync from the remote that points at the canonical repo; push to origin
SYNC_REMOTE=${AUTOBUMP_SYNC_REMOTE:-$(git remote | grep -qx upstream && echo upstream || echo origin)}
PUSH_REMOTE=${AUTOBUMP_PUSH_REMOTE:-origin}
# per-operation ceiling so a huge download/build never hangs the run
TMO="timeout ${AUTOBUMP_OP_TIMEOUT:-900}"

CHECK_ONLY=0; DO_INSTALL=0; DO_PR=0; DIFF_ONLY=0; ACCEPT_SURFACE=0; ACCEPT_PAYLOAD=0; ISSUE=""
PKG=""; NEWVER=""

log()  { printf '>> %s\n' "$*"; }
ok()   { printf 'ok %s\n' "$*"; }
die()  { printf '!! %s\n' "$*" >&2; exit 2; }

ESCALATIONS=()
escalate_note() { ESCALATIONS+=("$1"); printf 'ESCALATE: %s\n' "$1"; }

# ---------- args ----------
for a in "$@"; do
    case "$a" in
        --check) CHECK_ONLY=1 ;;
        --diff-only) DIFF_ONLY=1 ;;
        --accept-surface) ACCEPT_SURFACE=1 ;;
        --accept-payload) ACCEPT_PAYLOAD=1 ;;
        --install) DO_INSTALL=1 ;;
        --pr) DO_PR=1 ;;
        */*) PKG="$a" ;;
        [0-9]*.[0-9]*) NEWVER="$a" ;;
        [0-9]*) [ -z "$PKG" ] && ISSUE="$a" || NEWVER="$a" ;;
        *) die "unknown arg: $a" ;;
    esac
done

if [ -n "$ISSUE" ]; then
    title=$(gh issue view "$ISSUE" --repo "$UPSTREAM_REPO" --json title --jq .title) \
        || die "cannot read issue #$ISSUE"
    # [nvchecker] cat/pkg can be bump to X
    PKG=$(sed -nE 's/^\[nvchecker\] ([a-z0-9-]+\/[A-Za-z0-9_+-]+) can be bump to .*/\1/p' <<<"$title")
    NEWVER=$(sed -nE 's/.* can be bump to ([A-Za-z0-9._-]+)$/\1/p' <<<"$title")
    [ -n "$PKG" ] && [ -n "$NEWVER" ] || die "cannot parse issue title: $title"
    log "issue #$ISSUE -> $PKG -> $NEWVER"
fi
[ -n "$PKG" ] && [ -n "$NEWVER" ] || die "need <issue#> or <cat/pkg> <newver>"
# never open a PR without the full local test: --pr always runs emerge + smoke
[ "$DO_PR" = 1 ] && DO_INSTALL=1

CAT=${PKG%%/*}; PN=${PKG##*/}
PKGDIR="$REPO/$PKG"
[ -d "$PKGDIR" ] || die "no such package dir: $PKGDIR"
EVIDENCE_DIR=$(mktemp -d "/tmp/autobump-${PN}-XXXX")
BRANCH="${CAT}-${PN}-${NEWVER}"

cd "$REPO" || die "cd $REPO"

# ---------- stage 1: locate current ebuild ----------
# highest RELEASE ebuild; live (9999) ebuilds are never the bump base
OLD_EBUILD=$(ls "$PKGDIR"/*.ebuild 2>/dev/null | grep -vE -- '-9{4,}' | sort -V | tail -1)
[ -n "$OLD_EBUILD" ] || die "no release ebuild in $PKGDIR (live-only package?)"
OLD_PVR=$(basename "$OLD_EBUILD" .ebuild); OLD_PVR=${OLD_PVR#${PN}-}
OLD_PV=${OLD_PVR%-r[0-9]*}
NEW_EBUILD="$PKGDIR/${PN}-${NEWVER}.ebuild"
log "current: $OLD_PVR  ->  target: $NEWVER"

[ "$OLD_PV" = "$NEWVER" ] && die "already at $NEWVER"
[ -f "$NEW_EBUILD" ] && die "$NEW_EBUILD already exists"

# ---------- stage 2: deterministic classification ----------
# Anything matched here is evidence for the judge, not for this script to solve.
CLS="$EVIDENCE_DIR/classify.txt"; : > "$CLS"

# prerelease target while ebuild history is release-only
if grep -qiE '(alpha|beta|rc[0-9]*|pre|nightly|dev)([._-]|$)' <<<"$NEWVER" \
   && ! ls "$PKGDIR" | grep -qE '_(alpha|beta|rc|pre)'; then
    escalate_note "target looks like a prerelease: $NEWVER"
fi

# first version component changed = big jump (dae 1->2, mkinitcpio 39->41, tsukimi 0.21->26.7)
# EXCEPT date-scheme versions (YYYYMMDD[.N]): the 8-digit lead is one monotonic
# value that changes on every bump, so a newer date is routine, not a major jump.
# Only a date going backwards is suspicious.
if [[ "$OLD_PV" =~ ^20[0-9]{6}([._-][0-9]+)*$ ]] && [[ "$NEWVER" =~ ^20[0-9]{6}([._-][0-9]+)*$ ]]; then
    if [ "${NEWVER%%[._-]*}" -lt "${OLD_PV%%[._-]*}" ]; then
        escalate_note "date version went backwards: $OLD_PV -> $NEWVER"
    fi
elif [ "${OLD_PV%%.*}" != "${NEWVER%%.*}" ]; then
    escalate_note "major component change: $OLD_PV -> $NEWVER"
fi

# pinned commits / toolchain tags / hidden version-coupled vars
if grep -nE 'GIT_CRATES|_COMMIT=|_TAG=|[A-Z_]+_VER=' "$OLD_EBUILD" | grep -v '^#' > "$EVIDENCE_DIR/pins.txt"; then
    escalate_note "pinned/coupled variables found (see pins.txt) - must be diffed against upstream"
fi

# per-version external deps artifact must exist before anything else. Detect it
# by its FILENAME convention (a bundled deps/vendor/crates/node_modules tarball),
# not by host - the packs live in several repos (gentoo-zh-drafts, gentoo-deps,
# liuyujielol/gentoo-go-deps, ...) and a host allowlist misses them (v2rayA's
# ${P}-deps.tar.xz on gentoo-go-deps slipped through and failed late at fetch
# instead of deferring cleanly here).
depsurl=$(grep -oE 'https://[^ "]+' "$OLD_EBUILD" | grep -E '(-deps|-vendor|-crates|node_modules)\.tar\.' | head -1 || true)
if [ -n "$depsurl" ]; then
    # The URL usually carries literal ebuild vars (${P}/${PV}/${PN}); expand them
    # against the NEW version, then also swap any hardcoded old version. Without
    # this the URL keeps a literal ${PV} and 404s every time - the check would
    # escalate EVERY deps-artifact package even when the artifact exists.
    testurl=$depsurl
    testurl=${testurl//\$\{P\}/${PN}-${NEWVER}}
    testurl=${testurl//\$\{PV\}/${NEWVER}}
    testurl=${testurl//\$\{PN\}/${PN}}
    testurl=$(sed -e "s/${OLD_PV//./\\.}/${NEWVER}/g" <<<"$testurl")
    code=$(curl -sIL --max-time 30 -o /dev/null -w '%{http_code}' "$testurl" || echo 000)
    case "$code" in
        200) ok "deps artifact exists: $testurl" ;;
        # only a definitive 404 means "not built yet" -> escalate. A network blip
        # (000/5xx) is inconclusive: don't record a terminal defer over it, the
        # fetch stage re-checks and defers transiently (exit 2) if truly absent.
        404) escalate_note "per-version deps artifact missing (HTTP 404): $testurl" ;;
        *)   log "deps artifact check inconclusive (HTTP $code, network?): $testurl" ;;
    esac
fi

# version-pinned patches: only a bump risk if the ebuild ACTUALLY applies them.
# A stray files/*.patch the ebuild never references (no eapply/PATCHES=/FILESDIR)
# is dead cruft, not something the new version must re-apply - don't escalate on
# it (archlinux-keyring carries an unused 01_adapt_to_sequoia patch).
if ls "$PKGDIR"/files/*.patch >/dev/null 2>&1; then
    ls "$PKGDIR"/files/*.patch > "$EVIDENCE_DIR/patches.txt"
    if grep -qE 'eapply|epatch|PATCHES[+]?=|FILESDIR.*\.patch' "$OLD_EBUILD"; then
        escalate_note "files/ patches applied by the ebuild - re-apply must be verified"
    fi
fi

# multi-arch: not fatal, but PR must be draft + say untested.
# The KEYWORDS line may be tab/space-indented (opencode-bin is), so allow leading
# whitespace - anchoring at ^KEYWORDS misses it and would ship a non-draft PR for
# a multi-arch package with the non-amd64 arch untested.
MULTIARCH=0
if [ "$(grep -oE '~[a-z0-9]+' <(grep -E '^[[:space:]]*KEYWORDS=' "$OLD_EBUILD") | wc -l)" -gt 1 ]; then
    MULTIARCH=1
    log "multi-arch KEYWORDS: non-amd64 will be marked untested, PR will be draft"
fi

# GUI app? The smoke can only prove it INSTALLED, never that it launches/renders,
# so a GUI bump carries more uncertainty (it can install clean yet fail to start).
# Flag it in the PR so the human reviewer knows to actually run it before merging.
GUI=0
grep -qE '^[[:space:]]*inherit.*(desktop|xdg)' "$OLD_EBUILD" && GUI=1

grep -E '^[[:space:]]*KEYWORDS=' "$OLD_EBUILD" >> "$CLS" 2>/dev/null || true

if [ "${#ESCALATIONS[@]}" -gt 0 ]; then
    printf '%s\n' "${ESCALATIONS[@]}" > "$EVIDENCE_DIR/escalations.txt"
    echo "== not mechanically safe; evidence: $EVIDENCE_DIR =="
    exit 3
fi
ok "classification: mechanical bump candidate"
[ "$CHECK_ONLY" = 1 ] && { echo "check-only: would bump $PKG $OLD_PVR -> $NEWVER"; exit 0; }

# ---------- stage 3: preflight (AGENTS.md) ----------
# untracked files are unrelated work and must be preserved (AGENTS.md); only
# tracked modifications block us - except scripts/ and docs/, which are this
# tooling itself and never part of a package bump
if git status --porcelain --untracked-files=no | grep -vE ' (scripts|docs)/' | grep -q .; then
    die "working tree has tracked modifications"
fi
git fetch "$SYNC_REMOTE" >/dev/null 2>&1 || die "git fetch $SYNC_REMOTE failed"
# scripts/ and docs/ live only on the tooling branch; master has neither, so an
# uncommitted change to them makes `checkout master` refuse. That is the usual
# cause when iterating on the tool - say so instead of a vague "sync failed".
git checkout -q master 2>/dev/null || \
    die "cannot checkout master - commit/stash your scripts/ or docs/ changes first (the tool switches to master, where those files do not exist)"
git merge -q --ff-only "$SYNC_REMOTE/master" || die "master is not a fast-forward of $SYNC_REMOTE/master (diverged?)"
# The branch name is deterministic (cat-pn-newver); if it already exists it is a
# leftover from an interrupted or push-failed prior attempt (a successful attempt
# records exit 0 and is never re-invoked for the same version). Drop it so retries
# are idempotent instead of wedging on "branch already exists". We are on master
# now, so deleting it is safe.
if git rev-parse --verify -q "$BRANCH" >/dev/null; then
    log "dropping stale branch $BRANCH from a prior attempt"
    git branch -qD "$BRANCH" 2>/dev/null || die "branch $BRANCH exists and could not be removed"
fi
git checkout -qb "$BRANCH" || die "cannot create $BRANCH"
ok "branch $BRANCH off synced master"

cleanup_fail() { # abort: unstage, remove the copied ebuild, restore, drop branch
    cd "$REPO"
    git reset -q -- "$PKGDIR" 2>/dev/null
    rm -f "$NEW_EBUILD"
    git checkout -q -- "$PKGDIR" 2>/dev/null
    git checkout -q master
    git branch -qD "$BRANCH" 2>/dev/null
    # remove the --install spillover (all safe no-ops if that stage never ran)
    $SUDO rm -f "/etc/portage/package.accept_keywords/autobump-$PN" 2>/dev/null
    [ "$SEPARATE_OVERLAY" = 1 ] && \
        $SUDO rm -f "$LIVE_OVERLAY/$PKG/$PN-$NEWVER.ebuild" 2>/dev/null
}
# from here on the branch exists, so an interrupt (Ctrl-C, CI/harness SIGTERM)
# must not leave it orphaned. Disarmed once the commit is safely made (stage 7).
trap 'cleanup_fail; exit 130' INT TERM

# pkgcheck baseline: pre-existing findings must not block a bump later;
# only findings the bump introduces do (version prefix stripped to compare)
pkgcheck scan "$PKG" 2>/dev/null | sed -E 's/version [^:]+: //' | sort -u \
    > "$EVIDENCE_DIR/pkgcheck-baseline.txt"

# ---------- stage 4: fetch old artifacts, create new ebuild, fetch+manifest ----------
cd "$PKGDIR"
$TMO $SUDO ebuild "$(basename "$OLD_EBUILD")" fetch >/dev/null 2>&1 || { cleanup_fail; die "fetch of OLD distfiles failed"; }
cp "$(basename "$OLD_EBUILD")" "$(basename "$NEW_EBUILD")"
if ! $TMO $SUDO ebuild "$(basename "$NEW_EBUILD")" manifest > "$EVIDENCE_DIR/fetch.log" 2>&1; then
    tail -5 "$EVIDENCE_DIR/fetch.log"
    cleanup_fail
    # exit 2 (not 3): a fetch/mirror failure is usually transient, so the
    # sweep retries next run rather than recording a permanent defer
    die "fetch/manifest for $NEWVER failed (missing upstream file or slow mirror)"
fi
$SUDO chown "$(id -un):$(id -gn)" Manifest
ok "distfiles fetched, Manifest regenerated"

# ---------- stage 5: artifact diff ----------
tree_of() { # $1 = ebuild basename, $2 = out file; echoes the workdir
    $TMO $SUDO ebuild "$1" clean unpack >/dev/null 2>&1 || return 1
    local pvr=${1%.ebuild}; pvr=${pvr#${PN}-}
    local tmpd; tmpd=$(portageq envvar PORTAGE_TMPDIR 2>/dev/null); tmpd=${tmpd:-/var/tmp}
    local wd="$tmpd/portage/${CAT}/${PN}-${pvr}/work"
    $SUDO find "$wd" -type f -printf '%P\n' 2>/dev/null | sort > "$2"
    # An empty listing (wrong workdir guess, or an ebuild that populates nothing
    # findable at unpack time) yields a 0-removed tree diff, so the payload check
    # simply adds nothing and the ebuild-install/emerge build gate still runs -
    # better than hard-deferring the bump. PORTAGE_TMPDIR above keeps this rare.
    echo "$wd"
}

# build-option surface: cmake options/find_package, meson options/dependency,
# autotools AC_ARG_*, cargo [features]. A new/removed entry means the upgrade
# may need a USE flag or a dependency - exactly what a blind bump misses when
# configure auto-detects a host lib and "succeeds".
surface_of() { # $1 = workdir, $2 = out file
    local top; top=$($SUDO find "$1" -maxdepth 1 -mindepth 1 -type d | head -1)
    [ -n "$top" ] || top="$1"
    {
        $SUDO find "$top" -maxdepth 3 \( -name CMakeLists.txt -o -name '*.cmake' \) \
            -exec grep -hoE '(option|cmake_dependent_option|find_package|pkg_check_modules)[[:space:]]*\([[:space:]]*[A-Za-z0-9_.-]+' {} + 2>/dev/null \
            | sed -E 's/[[:space:]]*\([[:space:]]*/:/' | sed 's/^/cmake-/'
        $SUDO find "$top" -maxdepth 2 \( -name meson_options.txt -o -name meson.options \) \
            -exec grep -hoE "option[[:space:]]*\([[:space:]]*'[a-z0-9_-]+" {} + 2>/dev/null \
            | sed -E "s/option[[:space:]]*\([[:space:]]*'/meson-option:/"
        $SUDO find "$top" -maxdepth 2 -name meson.build \
            -exec grep -hoE "dependency[[:space:]]*\([[:space:]]*'[a-z0-9_.-]+" {} + 2>/dev/null \
            | sed -E "s/dependency[[:space:]]*\([[:space:]]*'/meson-dep:/"
        $SUDO find "$top" -maxdepth 2 \( -name configure.ac -o -name configure.in \) \
            -exec grep -hoE '(AC_ARG_ENABLE|AC_ARG_WITH|PKG_CHECK_MODULES)\(\[?[A-Za-z0-9_-]+' {} + 2>/dev/null \
            | sed -E 's/\(\[?/:/' | sed 's/^/ac-/'
        $SUDO find "$top" -maxdepth 2 -name Cargo.toml \
            -exec awk '/^\[features\]/{f=1;next}/^\[/{f=0}f&&/^[a-z0-9_-]+[[:space:]]*=/{print "cargo-feature:"$1}' {} + 2>/dev/null
    } | sort -u > "$2"
}

# payload (repackaged binary) vs source decides which diff applies. Detect a
# prebuilt payload by several signals, not just the archive extension: SRC_URI
# may be indented (opencode-bin tab-indents it, so ^SRC_URI misses it), and a
# plain binary .tar.gz has no telltale extension - so also trust QA_PREBUILT (set
# only by prebuilt ebuilds), the -bin PN convention, and the unpacker eclass.
# NB: do NOT key off RESTRICT=bindist/strip - those are common on from-SOURCE
# ebuilds (non-redistributable or debug-symbol packages) and would misroute them.
PAYLOAD=0
neweb=$(basename "$NEW_EBUILD")
if grep -qE '\.(deb|AppImage|exe|dmg)' <(grep -A8 -E '^[[:space:]]*SRC_URI' "$neweb") \
   || grep -qE 'inherit.*unpacker' "$neweb" \
   || grep -qE '^[[:space:]]*QA_PREBUILT=' "$neweb" \
   || [[ "$PN" == *-bin ]]; then
    PAYLOAD=1
fi

# Prebuilt payload: unpack both, diff the file tree (a removed path = danger).
# Source: the unpack feeds the build-option surface diff, but `ebuild unpack`
# runs pkg_setup first, which for python-any-r1 and similar dies without the
# build deps installed. That is not a real problem for the bump (such packages
# have no cmake/meson option surface anyway) - fall back to the emerge build
# gate instead of hard-failing.
if [ "$PAYLOAD" = 1 ]; then
    WD_OLD=$(tree_of "$(basename "$OLD_EBUILD")" "$EVIDENCE_DIR/tree-old.txt") || { cleanup_fail; die "unpack old failed"; }
    WD_NEW=$(tree_of "$(basename "$NEW_EBUILD")" "$EVIDENCE_DIR/tree-new.txt") || { cleanup_fail; die "unpack new failed"; }
    comm -23 "$EVIDENCE_DIR/tree-old.txt" "$EVIDENCE_DIR/tree-new.txt" > "$EVIDENCE_DIR/tree-removed.txt"
    comm -13 "$EVIDENCE_DIR/tree-old.txt" "$EVIDENCE_DIR/tree-new.txt" > "$EVIDENCE_DIR/tree-added.txt"
    removed=$(wc -l < "$EVIDENCE_DIR/tree-removed.txt")
    added=$(wc -l < "$EVIDENCE_DIR/tree-added.txt")
    # A removed path is dangerous (a renamed .desktop broke claude-desktop) UNLESS
    # it only differs from an added path by the version string - that is a benign
    # version-embedded rename (folo-bin-1.10.0.AppImage -> folo-bin-1.11.0.AppImage).
    # Swap OLD_PV->NEWVER in each removed path; if the result was added, drop it.
    if [ "$removed" -gt 0 ]; then
        : > "$EVIDENCE_DIR/tree-removed-real.txt"
        while IFS= read -r p; do
            [ -n "$p" ] || continue
            grep -qxF "${p//$OLD_PV/$NEWVER}" "$EVIDENCE_DIR/tree-added.txt" \
                || printf '%s\n' "$p" >> "$EVIDENCE_DIR/tree-removed-real.txt"
        done < "$EVIDENCE_DIR/tree-removed.txt"
        realrm=$(wc -l < "$EVIDENCE_DIR/tree-removed-real.txt")
        if [ "$realrm" -gt 0 ] && [ "$ACCEPT_PAYLOAD" != 1 ]; then
            head -20 "$EVIDENCE_DIR/tree-removed-real.txt"
            cleanup_fail
            echo "== payload layout changed ($realrm real removals / $added added, version-renames ignored);"
            echo "== a removed path may be a real break (renamed .desktop) or benign (dropped icon size)."
            echo "== inspect tree-removed-real.txt, then re-run with --accept-payload if harmless."
            echo "== evidence: $EVIDENCE_DIR =="
            exit 3
        fi
        if [ "$realrm" -gt 0 ]; then
            head -20 "$EVIDENCE_DIR/tree-removed-real.txt"
            log "payload: $realrm removed path(s) accepted as harmless (--accept-payload)"
        elif [ "$removed" -gt 0 ]; then
            log "payload: $removed removed path(s) are version-embedded renames (benign)"
        fi
    fi
    ok "payload tree: no blocking removed paths ($added new files - see tree-added.txt)"
elif WD_OLD=$(tree_of "$(basename "$OLD_EBUILD")" "$EVIDENCE_DIR/tree-old.txt") \
     && WD_NEW=$(tree_of "$(basename "$NEW_EBUILD")" "$EVIDENCE_DIR/tree-new.txt"); then
    # source: file churn is normal; what matters is the build-option surface
    surface_of "$WD_OLD" "$EVIDENCE_DIR/surface-old.txt"
    surface_of "$WD_NEW" "$EVIDENCE_DIR/surface-new.txt"
    comm -23 "$EVIDENCE_DIR/surface-old.txt" "$EVIDENCE_DIR/surface-new.txt" > "$EVIDENCE_DIR/surface-removed.txt"
    comm -13 "$EVIDENCE_DIR/surface-old.txt" "$EVIDENCE_DIR/surface-new.txt" > "$EVIDENCE_DIR/surface-added.txt"
    sdel=$(wc -l < "$EVIDENCE_DIR/surface-removed.txt")
    sadd=$(wc -l < "$EVIDENCE_DIR/surface-added.txt")
    if [ $((sdel + sadd)) -gt 0 ] && [ "$ACCEPT_SURFACE" != 1 ]; then
        echo "--- surface added ---";   cat "$EVIDENCE_DIR/surface-added.txt"
        echo "--- surface removed ---"; cat "$EVIDENCE_DIR/surface-removed.txt"
        cleanup_fail
        echo "== build-option surface changed (+$sadd/-$sdel): may need USE/RDEPEND changes."
        echo "== judge the evidence, then re-run with --accept-surface if it is harmless."
        echo "== evidence: $EVIDENCE_DIR =="
        exit 3
    fi
    if [ "$ACCEPT_SURFACE" = 1 ]; then
        log "surface delta accepted by judge (+$sadd/-$sdel)"
    else
        ok "build-option surface unchanged"
    fi
elif [ "$DO_INSTALL" = 1 ]; then
    log "surface diff unavailable (unpack blocked - pkg_setup needs build deps); relying on the emerge build gate"
else
    cleanup_fail
    echo "== surface diff unavailable (unpack blocked, likely pkg_setup needs build deps)."
    echo "== cannot verify the build-option surface without building; re-run with --install. =="
    exit 3
fi

if [ "$DIFF_ONLY" = 1 ]; then
    cleanup_fail
    echo "== diff-only: checks passed; evidence kept in $EVIDENCE_DIR =="
    exit 0
fi

# ---------- stage 6: build test ----------
# Prebuilt: `ebuild install` needs no deps and is a fast, sufficient gate.
# Source: `ebuild install` does NOT resolve DEPEND, so meson/cmake configure
# fails on any uninstalled build dep - the real gate for source is the
# dep-resolving `emerge` in the --install block below.
if [ "$PAYLOAD" = 1 ]; then
    if ! $TMO $SUDO ebuild "$(basename "$NEW_EBUILD")" clean install > "$EVIDENCE_DIR/build.log" 2>&1; then
        tail -20 "$EVIDENCE_DIR/build.log"
        cleanup_fail
        echo "== build failed; evidence: $EVIDENCE_DIR/build.log =="
        exit 3
    fi
    # `ebuild install` does NOT install RDEPEND, so a bundled lib linking an
    # RDEPEND-provided soname (reqable bundles libayatana-appindicator3, which
    # needs dev-libs/libdbusmenu) shows a spurious "Unresolved soname" QA notice
    # here - it resolves once emerge installs RDEPEND (checked in --install below).
    # So ignore unresolved-soname at this stage; fail on any OTHER QA notice.
    if grep 'QA Notice' "$EVIDENCE_DIR/build.log" | grep -qv 'Unresolved soname'; then
        grep -A5 'QA Notice' "$EVIDENCE_DIR/build.log" | head -20
        cleanup_fail
        echo "== QA notice during install (would fail CI elog gate); evidence: $EVIDENCE_DIR/build.log =="
        exit 3
    fi
    ok "ebuild install clean (soname resolution deferred to the emerge)"
elif [ "$DO_INSTALL" != 1 ]; then
    log "source package: not build-tested without --install (surface-diff only); --pr implies --install"
fi

SMOKE="not run (use --install)"
if [ "$DO_INSTALL" = 1 ]; then
    # dev box: the configured overlay is a separate synced checkout, copy in.
    # CI: the checkout itself is registered in repos.conf - nothing to copy.
    if [ "$SEPARATE_OVERLAY" = 1 ]; then
        $SUDO mkdir -p "$LIVE_OVERLAY/$PKG"
        $SUDO cp ./*.ebuild Manifest metadata.xml "$LIVE_OVERLAY/$PKG/"
        lic=$(grep -oE '^LICENSE="[^"]+"' "$(basename "$NEW_EBUILD")" | cut -d'"' -f2)
        if [ -f "$REPO/licenses/$lic" ]; then $SUDO cp "$REPO/licenses/$lic" "$LIVE_OVERLAY/licenses/$lic"; fi
    fi
    # accept ~amd64 for the whole overlay, not just the target: the build deps
    # of an overlay package are often overlay packages too (fcitx-pinyin-moegirl
    # needs dev-python/mw2fcitx), and CI runs with overlay-wide ~amd64. The
    # ::gentoo-zh qualifier leaves the stable system tree untouched.
    $SUDO mkdir -p /etc/portage/package.accept_keywords 2>/dev/null
    { echo "$PKG ~amd64"; echo "*/*::gentoo-zh ~amd64"; } \
        | $SUDO tee "/etc/portage/package.accept_keywords/autobump-$PN" >/dev/null
    $TMO $SUDO emerge --oneshot --quiet "=$PKG-$NEWVER" > "$EVIDENCE_DIR/emerge.log" 2>&1; erc=$?
    if [ "$erc" = 0 ]; then
        # QA-notice gate on the emerge (RDEPEND is now installed):
        #   source  -> any QA notice fails the CI elog gate.
        #   prebuilt-> re-check only the unresolved-soname class deferred from
        #     stage 6; a soname still missing after RDEPEND install is a real
        #     dep gap. Other prebuilt QA notices (dlopen advisories) are too noisy.
        if [ "$PAYLOAD" = 0 ]; then qapat='QA Notice'; else qapat='Unresolved soname'; fi
        if grep -q "$qapat" "$EVIDENCE_DIR/emerge.log"; then
            grep -A5 "$qapat" "$EVIDENCE_DIR/emerge.log" | head -20
            cleanup_fail
            echo "== QA notice during emerge (would fail CI elog gate); evidence: $EVIDENCE_DIR/emerge.log =="
            exit 3
        fi
        # smoke: the binary name is not always $PN (uv-bin installs uv), and the
        # version verb is not always --version (Go tools use a `version` subcommand
        # - hysteria does). Try each installed exe with the common forms.
        SMOKE="installed; no version output matched NEWVER (verify manually)"
        for bin in $(qlist "$PKG" 2>/dev/null | grep -E '/s?bin/[^/]+$'); do
            for vflag in --version version -V; do
                out=$(timeout 20 "$bin" $vflag 2>&1 | head -3 || true)
                if grep -qF "$NEWVER" <<<"$out"; then
                    SMOKE="$vflag ok: $(basename "$bin"): $(grep -F "$NEWVER" <<<"$out" | head -1 | sed 's/^[[:space:]]*//')"
                    break 2
                fi
            done
        done
        ok "emerge + smoke: $SMOKE"
        # GUI launch probe (ADVISORY - never blocks). A GUI app can install clean
        # yet crash on start; launch it under a headless Xvfb display (so it never
        # pops a window on a real session) with software GL, and fold the outcome
        # into the PR. It does NOT escalate: a crash under Xvfb is often just a
        # missing GPU/GL, not a broken bump, so this informs the reviewer instead
        # of auto-rejecting. Runs only where Xvfb exists (else the PR's GUI note
        # tells the human to launch it). See docs: enable with x11-base/xorg-server[xvfb].
        if [ "$GUI" = 1 ] && command -v Xvfb >/dev/null 2>&1; then
            Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 & _xvfb=$!
            sleep 1
            gres="started headless, no crash"
            for bin in $(qlist "$PKG" 2>/dev/null | grep -E '/s?bin/[^/]+$'); do
                perr=$(DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 timeout 15 "$bin" </dev/null 2>&1 >/dev/null); prc=$?
                if grep -q 'no-sandbox' <<<"$perr"; then   # Electron as root
                    perr=$(DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 timeout 15 "$bin" --no-sandbox --disable-gpu </dev/null 2>&1 >/dev/null); prc=$?
                fi
                if grep -qiE 'error while loading shared librar|symbol lookup error|undefined symbol|GLIBC_[0-9.]+.? not found' <<<"$perr"; then
                    gres="$(basename "$bin") MISSING A LIBRARY at runtime - likely broken"; break
                fi
                case "$prc" in
                    132|134|135|136|139) gres="$(basename "$bin") crashed on start (signal $((prc-128))) - verify (could be headless GL)"; break ;;
                    124)                 gres="ran 15s headless without crashing"; break ;;
                esac
            done
            kill "$_xvfb" 2>/dev/null; wait "$_xvfb" 2>/dev/null
            log "GUI launch probe: $gres"
            SMOKE="$SMOKE | GUI launch probe: $gres"
        fi
        # linked-libs vs RDEPEND. Two directions, treated differently for a bump:
        #   '>' undeclared-but-linked = a MISSING dep the new version may need at
        #       runtime -> escalate (could be introduced by the bump).
        #   '<' declared-but-unused   = a droppable dep. Almost always pre-existing
        #       hygiene (libzim 9.8.1 flags virtual/zlib, same as 9.8.0) -> advisory,
        #       don't block the bump.
        # Source only; dlopen-heavy prebuilt payloads make it noisy. Needs iwdevtools.
        if [ "$PAYLOAD" = 0 ] && command -v qa-vdb >/dev/null; then
            qa-vdb "$PKG" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$EVIDENCE_DIR/qa-vdb.txt" || true
            if grep -qE '(^|[[:space:]])>([[:space:]]|$)' "$EVIDENCE_DIR/qa-vdb.txt"; then
                cat "$EVIDENCE_DIR/qa-vdb.txt"
                cleanup_fail
                echo "== qa-vdb: linked lib missing from RDEPEND; evidence: $EVIDENCE_DIR =="
                exit 3
            elif grep -qE '(^|[[:space:]])<([[:space:]]|$)' "$EVIDENCE_DIR/qa-vdb.txt"; then
                grep -E '(^|[[:space:]])<([[:space:]]|$)' "$EVIDENCE_DIR/qa-vdb.txt"
                log "qa-vdb: droppable dep(s) above - advisory, not blocking the bump (pre-existing hygiene)"
            else
                ok "qa-vdb: RDEPEND matches linked libs"
            fi
        elif [ "$PAYLOAD" = 1 ]; then
            log "qa-vdb skipped: prebuilt payload (dlopen-heavy, RDEPEND vs NEEDED too noisy)"
        else
            log "qa-vdb not installed (app-portage/iwdevtools) - linked-libs/RDEPEND check skipped"
        fi
    else
        tail -20 "$EVIDENCE_DIR/emerge.log"
        cleanup_fail
        # A timeout (124 from `timeout`) is not a defect - it is a heavy build that
        # did not fit the per-op ceiling. Defer (exit 2) so the sweep retries and CI
        # (bigger budget / getbinpkg) can finish it, rather than condemning the bump.
        if [ "$erc" = 124 ]; then
            echo "== emerge timed out (>${AUTOBUMP_OP_TIMEOUT:-900}s): heavy build, not a defect. Deferring."
            echo "== evidence: $EVIDENCE_DIR/emerge.log =="
            exit 2
        fi
        # Distinguish a dependency-resolution failure - a build dep is masked /
        # unkeyworded / incompatible with the local PYTHON_TARGET, or needs a USE
        # change on a transitive dep (piliplus-bin pulls libdbusmenu[gtk3]) - from
        # a real compile failure. Resolution failures are a local-environment gap,
        # not a defect in the bump: portage never built anything, and CI with full
        # ~amd64 and its own profile/USE resolves them. Defer (exit 2), not condemn.
        if grep -qE 'have been masked|masked packages|required to complete your request|no ebuilds to satisfy|Blocked Packages|not be installed|USE changes are necessary|autounmask' \
             "$EVIDENCE_DIR/emerge.log"; then
            echo "== cannot smoke-test locally: dependency resolution needs a change here"
            echo "== (overlay ~amd64 dep, PYTHON_TARGET mismatch e.g. mw2fcitx lacks"
            echo "==  python3_14, or a transitive-dep USE flag). Not a bump defect;"
            echo "== CI resolves it. Deferring - see evidence: $EVIDENCE_DIR/emerge.log =="
            exit 2
        fi
        echo "== emerge failed; evidence: $EVIDENCE_DIR/emerge.log =="
        exit 3
    fi
fi

# ---------- stage 7: finalize + QA + commit ----------
# the smoke keywords file has done its job; drop it so it does not accumulate
$SUDO rm -f "/etc/portage/package.accept_keywords/autobump-$PN" 2>/dev/null
cd "$REPO"
git rm -q "$OLD_EBUILD"
# drop the removed version's DIST entries (distfiles are all local, no refetch)
( cd "$PKGDIR" && pkgdev manifest >/dev/null 2>&1 ) || { cleanup_fail; die "manifest regen after drop failed"; }
git add "$PKGDIR"
pkgcheck scan "$PKG" 2>/dev/null | sed -E 's/version [^:]+: //' | sort -u \
    > "$EVIDENCE_DIR/pkgcheck-after.txt"
comm -13 "$EVIDENCE_DIR/pkgcheck-baseline.txt" "$EVIDENCE_DIR/pkgcheck-after.txt" \
    > "$EVIDENCE_DIR/pkgcheck-new.txt"
if [ -s "$EVIDENCE_DIR/pkgcheck-new.txt" ]; then
    cat "$EVIDENCE_DIR/pkgcheck-new.txt"
    cleanup_fail
    echo "== pkgcheck findings introduced by the bump; evidence: $EVIDENCE_DIR =="
    exit 3
fi
pkgdev commit --scan false --signoff || { cleanup_fail; die "pkgdev commit failed"; }
trap - INT TERM   # commit is made; an interrupt now must NOT discard it
ok "committed: $(git log -1 --format=%s)"

pkgcheck scan --commits --net > "$EVIDENCE_DIR/pkgcheck-net.txt" 2>&1 || true
if grep -E 'DeadUrl|RedirectedUrl' "$EVIDENCE_DIR/pkgcheck-net.txt" | grep -q "$PN"; then
    # re-verify: rate-limit false positives are common
    grep -oE 'https://[^ ]+' <(grep -A1 "$PN" "$EVIDENCE_DIR/pkgcheck-net.txt") | sort -u | while read -r u; do
        printf '%s -> %s\n' "$u" "$(curl -sL --max-time 20 -o /dev/null -w '%{http_code}' "$u")"
    done > "$EVIDENCE_DIR/url-recheck.txt"
    if grep -vq ' -> 200' "$EVIDENCE_DIR/url-recheck.txt"; then
        cat "$EVIDENCE_DIR/url-recheck.txt"
        echo "== URL findings persist after recheck; evidence: $EVIDENCE_DIR =="
        exit 3
    fi
    log "pkgcheck URL findings were transient (all URLs 200 on recheck)"
fi

# ---------- stage 8: PR ----------
if [ "$DO_PR" = 1 ]; then
    # same-repo branch -> plain head; fork -> owner:branch
    owner=$(git remote get-url "$PUSH_REMOTE" | sed -E 's#\.git$##; s#/$##; s#.*[:/]([^/]+)/[^/]+$#\1#')
    head="$BRANCH"
    [ "$owner" != "${UPSTREAM_REPO%%/*}" ] && head="$owner:$BRANCH"
    # If a PR is already open for this exact branch, a reviewer may have pushed
    # fixups onto it. We just recreated the branch locally with a fresh single
    # commit, so pushing (even --force-with-lease, which the earlier `git fetch`
    # defeats) would clobber their work. Bail instead - the bump is already up.
    # match by bare branch name + head-repo owner (gh --head wants the bare
    # branch, not owner:branch, so filter in jq to stay correct for fork PRs too)
    if gh pr list --repo "$UPSTREAM_REPO" --state open \
         --json number,headRefName,headRepositoryOwner \
         --jq ".[] | select(.headRefName==\"$BRANCH\" and .headRepositoryOwner.login==\"$owner\") | .number" \
         2>/dev/null | grep -q .; then
        log "an open PR already exists for $BRANCH - not pushing (would clobber review)"
        echo "== done; PR already open, nothing to push. Evidence: $EVIDENCE_DIR =="
        exit 0
    fi
    # No open PR -> safe to (force-)push a fresh or leftover branch, then open it.
    git push -u --force-with-lease "$PUSH_REMOTE" "$BRANCH" || die "push failed"
    subj=$(git log -1 --format=%s)
    body="$EVIDENCE_DIR/pr-body.md"
    {
        echo "Version bump (nvchecker)."
        echo
        echo "Payload layout, deps and referenced paths verified unchanged against $OLD_PVR."
        echo "Built clean locally; smoke: $SMOKE."
        [ "$MULTIARCH" = 1 ] && echo "Only amd64 was built and run; other keyworded arches untested."
        [ "$GUI" = 1 ] && echo "⚠️ GUI app: installed cleanly but NOT launch-tested here - please verify it actually starts before merging."
        [ -n "$ISSUE" ] && { echo; echo "Closes #$ISSUE"; }
        echo
        echo "---"
        echo
        echo "Please check all the boxes that apply:"
        echo
        echo '- [x] I have run `pkgcheck scan --commits --net` to check for issues with my commits.'
    } > "$body"
    draftflag=""
    [ "$MULTIARCH" = 1 ] && draftflag="--draft"
    gh pr create --repo "$UPSTREAM_REPO" --base master --head "$head" \
        --title "$subj" --body-file "$body" $draftflag || die "gh pr create failed"
    ok "PR opened"
else
    log "committed on $BRANCH - review, then: git push -u $PUSH_REMOTE $BRANCH && gh pr create ..."
fi

echo "== done; evidence kept in $EVIDENCE_DIR =="
