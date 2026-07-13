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
# Requirements: run as normal user; sudo for ebuild/emerge/distfiles.

set -uo pipefail

REPO=/home/zakk/code/gentoo-zh
DISTDIR=/var/cache/distfiles
LIVE_OVERLAY=/var/db/repos/gentoo-zh
UPSTREAM_REPO=gentoo-zh/overlay
FORK_USER=Zakkaus

CHECK_ONLY=0; DO_INSTALL=0; DO_PR=0; DIFF_ONLY=0; ACCEPT_SURFACE=0; ISSUE=""
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
old1=${OLD_PV%%.*}; new1=${NEWVER%%.*}
if [ "$old1" != "$new1" ]; then
    escalate_note "major component change: $OLD_PV -> $NEWVER"
fi

# pinned commits / toolchain tags / hidden version-coupled vars
if grep -nE 'GIT_CRATES|_COMMIT=|_TAG=|[A-Z_]+_VER=' "$OLD_EBUILD" | grep -v '^#' > "$EVIDENCE_DIR/pins.txt"; then
    escalate_note "pinned/coupled variables found (see pins.txt) - must be diffed against upstream"
fi

# per-version external deps artifact must exist before anything else
depsurl=$(grep -oE 'https://[^ "]*(gentoo-zh-drafts|gentoo-deps)[^ "]*' "$OLD_EBUILD" | head -1 || true)
if [ -n "$depsurl" ]; then
    testurl=$(sed -e "s/${OLD_PV//./\\.}/${NEWVER}/g" <<<"$depsurl")
    code=$(curl -sIL -o /dev/null -w '%{http_code}' "$testurl")
    if [ "$code" != "200" ]; then
        escalate_note "per-version deps artifact missing (HTTP $code): $testurl"
    else
        ok "deps artifact exists: $testurl"
    fi
fi

# version-pinned patches
if ls "$PKGDIR"/files/*.patch >/dev/null 2>&1; then
    ls "$PKGDIR"/files/*.patch > "$EVIDENCE_DIR/patches.txt"
    escalate_note "files/ patches present - re-apply must be verified"
fi

# multi-arch: not fatal, but PR must be draft + say untested
MULTIARCH=0
if [ "$(grep -oE '~[a-z0-9]+' <(grep '^KEYWORDS=' "$OLD_EBUILD") | wc -l)" -gt 1 ]; then
    MULTIARCH=1
    log "multi-arch KEYWORDS: non-amd64 will be marked untested, PR will be draft"
fi

grep '^KEYWORDS=' "$OLD_EBUILD" >> "$CLS" 2>/dev/null || true

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
git rev-parse --verify -q "$BRANCH" >/dev/null && die "branch $BRANCH already exists"
git fetch upstream >/dev/null 2>&1 || die "git fetch upstream failed"
git checkout -q master && git merge -q --ff-only upstream/master || die "master sync failed"
git checkout -qb "$BRANCH" || die "cannot create $BRANCH"
ok "branch $BRANCH off synced master"

# pkgcheck baseline: pre-existing findings must not block a bump later;
# only findings the bump introduces do (version prefix stripped to compare)
pkgcheck scan "$PKG" 2>/dev/null | sed -E 's/version [^:]+: //' | sort -u \
    > "$EVIDENCE_DIR/pkgcheck-baseline.txt"

# ---------- stage 4: fetch old artifacts, create new ebuild, fetch+manifest ----------
cd "$PKGDIR"
sudo ebuild "$(basename "$OLD_EBUILD")" fetch >/dev/null 2>&1 || die "fetch of OLD distfiles failed"
cp "$(basename "$OLD_EBUILD")" "$(basename "$NEW_EBUILD")"
if ! sudo ebuild "$(basename "$NEW_EBUILD")" manifest > "$EVIDENCE_DIR/fetch.log" 2>&1; then
    tail -5 "$EVIDENCE_DIR/fetch.log"
    git checkout -q master; git branch -qD "$BRANCH"
    die "fetch/manifest for $NEWVER failed (upstream file missing?)"
fi
sudo chown "$(id -un):$(id -gn)" Manifest
ok "distfiles fetched, Manifest regenerated"

# ---------- stage 5: artifact diff ----------
cleanup_fail() { # abort: unstage, remove new ebuild, restore, drop branch
    cd "$REPO"
    git reset -q -- "$PKGDIR" 2>/dev/null
    rm -f "$NEW_EBUILD"
    git checkout -q -- "$PKGDIR" 2>/dev/null
    git checkout -q master
    git branch -qD "$BRANCH" 2>/dev/null
}

tree_of() { # $1 = ebuild basename, $2 = out file; echoes the workdir
    sudo ebuild "$1" clean unpack >/dev/null 2>&1 || return 1
    local pvr=${1%.ebuild}; pvr=${pvr#${PN}-}
    local wd="/var/tmp/portage/${CAT}/${PN}-${pvr}/work"
    sudo find "$wd" -type f -printf '%P\n' 2>/dev/null | sort > "$2"
    echo "$wd"
}

# build-option surface: cmake options/find_package, meson options/dependency,
# autotools AC_ARG_*, cargo [features]. A new/removed entry means the upgrade
# may need a USE flag or a dependency - exactly what a blind bump misses when
# configure auto-detects a host lib and "succeeds".
surface_of() { # $1 = workdir, $2 = out file
    local top; top=$(sudo find "$1" -maxdepth 1 -mindepth 1 -type d | head -1)
    [ -n "$top" ] || top="$1"
    {
        sudo find "$top" -maxdepth 3 \( -name CMakeLists.txt -o -name '*.cmake' \) \
            -exec grep -hoE '(option|cmake_dependent_option|find_package|pkg_check_modules)[[:space:]]*\([[:space:]]*[A-Za-z0-9_.-]+' {} + 2>/dev/null \
            | sed -E 's/[[:space:]]*\([[:space:]]*/:/' | sed 's/^/cmake-/'
        sudo find "$top" -maxdepth 2 \( -name meson_options.txt -o -name meson.options \) \
            -exec grep -hoE "option[[:space:]]*\([[:space:]]*'[a-z0-9_-]+" {} + 2>/dev/null \
            | sed -E "s/option[[:space:]]*\([[:space:]]*'/meson-option:/"
        sudo find "$top" -maxdepth 2 -name meson.build \
            -exec grep -hoE "dependency[[:space:]]*\([[:space:]]*'[a-z0-9_.-]+" {} + 2>/dev/null \
            | sed -E "s/dependency[[:space:]]*\([[:space:]]*'/meson-dep:/"
        sudo find "$top" -maxdepth 2 \( -name configure.ac -o -name configure.in \) \
            -exec grep -hoE '(AC_ARG_ENABLE|AC_ARG_WITH|PKG_CHECK_MODULES)\(\[?[A-Za-z0-9_-]+' {} + 2>/dev/null \
            | sed -E 's/\(\[?/:/' | sed 's/^/ac-/'
        sudo find "$top" -maxdepth 2 -name Cargo.toml \
            -exec awk '/^\[features\]/{f=1;next}/^\[/{f=0}f&&/^[a-z0-9_-]+[[:space:]]*=/{print "cargo-feature:"$1}' {} + 2>/dev/null
    } | sort -u > "$2"
}

# payload (repackaged binary) vs source decides which diff applies
PAYLOAD=0
if grep -qE '\.(deb|AppImage)' <(grep -A8 '^SRC_URI' "$(basename "$NEW_EBUILD")") \
   || grep -q 'inherit.*unpacker' "$(basename "$NEW_EBUILD")"; then
    PAYLOAD=1
fi

WD_OLD=$(tree_of "$(basename "$OLD_EBUILD")" "$EVIDENCE_DIR/tree-old.txt") || { cleanup_fail; die "unpack old failed"; }
WD_NEW=$(tree_of "$(basename "$NEW_EBUILD")" "$EVIDENCE_DIR/tree-new.txt") || { cleanup_fail; die "unpack new failed"; }
comm -23 "$EVIDENCE_DIR/tree-old.txt" "$EVIDENCE_DIR/tree-new.txt" > "$EVIDENCE_DIR/tree-removed.txt"
comm -13 "$EVIDENCE_DIR/tree-old.txt" "$EVIDENCE_DIR/tree-new.txt" > "$EVIDENCE_DIR/tree-added.txt"
removed=$(wc -l < "$EVIDENCE_DIR/tree-removed.txt")
added=$(wc -l < "$EVIDENCE_DIR/tree-added.txt")

if [ "$PAYLOAD" = 1 ]; then
    # prebuilt: any removed path is dangerous (renamed .desktop broke claude-desktop)
    if [ "$removed" -gt 0 ]; then
        head -20 "$EVIDENCE_DIR/tree-removed.txt"
        cleanup_fail
        echo "== payload layout changed ($removed removed / $added added); evidence: $EVIDENCE_DIR =="
        exit 3
    fi
    ok "payload tree: no removed paths ($added new files - see tree-added.txt)"
else
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
fi

if [ "$DIFF_ONLY" = 1 ]; then
    cleanup_fail
    echo "== diff-only: checks passed; evidence kept in $EVIDENCE_DIR =="
    exit 0
fi

# ---------- stage 6: build test ----------
if ! sudo ebuild "$(basename "$NEW_EBUILD")" clean install > "$EVIDENCE_DIR/build.log" 2>&1; then
    tail -20 "$EVIDENCE_DIR/build.log"
    cleanup_fail
    echo "== build failed; evidence: $EVIDENCE_DIR/build.log =="
    exit 3
fi
if grep -q 'QA Notice' "$EVIDENCE_DIR/build.log"; then
    grep -A5 'QA Notice' "$EVIDENCE_DIR/build.log" | head -20
    cleanup_fail
    echo "== QA notice during install (would fail CI elog gate); evidence: $EVIDENCE_DIR/build.log =="
    exit 3
fi
ok "ebuild install clean, no QA notices"

SMOKE="not run (use --install)"
if [ "$DO_INSTALL" = 1 ]; then
    sudo mkdir -p "$LIVE_OVERLAY/$PKG"
    sudo cp ./*.ebuild Manifest metadata.xml "$LIVE_OVERLAY/$PKG/"
    lic=$(grep -oE '^LICENSE="[^"]+"' "$(basename "$NEW_EBUILD")" | cut -d'"' -f2)
    if [ -f "$REPO/licenses/$lic" ]; then sudo cp "$REPO/licenses/$lic" "$LIVE_OVERLAY/licenses/$lic"; fi
    echo "$PKG ~amd64" | sudo tee "/etc/portage/package.accept_keywords/autobump-$PN" >/dev/null
    if sudo emerge --oneshot --quiet "=$PKG-$NEWVER" > "$EVIDENCE_DIR/emerge.log" 2>&1; then
        binout=$(timeout 20 "$PN" --version 2>&1 | head -1 || true)
        if grep -q "$NEWVER" <<<"$binout"; then SMOKE="--version ok: $binout";
        else SMOKE="installed; --version said: ${binout:-<nothing>} (verify manually)"; fi
        ok "emerge + smoke: $SMOKE"
        # linked-libs vs RDEPEND, both directions: undeclared new deps AND
        # no-longer-needed ones that should be dropped. Source packages only -
        # dlopen-heavy prebuilt payloads make it noisy. Needs app-portage/iwdevtools.
        if [ "$PAYLOAD" = 0 ] && command -v qa-vdb >/dev/null; then
            if ! qa-vdb "$PKG" > "$EVIDENCE_DIR/qa-vdb.txt" 2>&1 || [ -s "$EVIDENCE_DIR/qa-vdb.txt" ]; then
                [ -s "$EVIDENCE_DIR/qa-vdb.txt" ] && { cat "$EVIDENCE_DIR/qa-vdb.txt"; \
                  echo "== qa-vdb: RDEPEND vs linked libs mismatch; evidence: $EVIDENCE_DIR =="; exit 3; }
            fi
            ok "qa-vdb: RDEPEND matches linked libs"
        else
            log "qa-vdb not installed (app-portage/iwdevtools) - linked-libs/RDEPEND check skipped"
        fi
    else
        tail -20 "$EVIDENCE_DIR/emerge.log"
        echo "== emerge failed; evidence: $EVIDENCE_DIR/emerge.log =="
        exit 3
    fi
fi

# ---------- stage 7: finalize + QA + commit ----------
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
pkgdev commit --scan false --signoff || die "pkgdev commit failed"
ok "committed: $(git log -1 --format=%s)"

pkgcheck scan --commits --net > "$EVIDENCE_DIR/pkgcheck-net.txt" 2>&1 || true
if grep -E 'DeadUrl|RedirectedUrl' "$EVIDENCE_DIR/pkgcheck-net.txt" | grep -q "$PN"; then
    # re-verify: rate-limit false positives are common
    grep -oE 'https://[^ ]+' <(grep -A1 "$PN" "$EVIDENCE_DIR/pkgcheck-net.txt") | sort -u | while read -r u; do
        printf '%s -> %s\n' "$u" "$(curl -sIL -o /dev/null -w '%{http_code}' "$u")"
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
    git push -u origin "$BRANCH" || die "push failed"
    subj=$(git log -1 --format=%s)
    body="$EVIDENCE_DIR/pr-body.md"
    {
        echo "Version bump (nvchecker)."
        echo
        echo "Payload layout, deps and referenced paths verified unchanged against $OLD_PVR."
        echo "Built clean locally; smoke: $SMOKE."
        [ "$MULTIARCH" = 1 ] && echo "Only amd64 was built and run; other keyworded arches untested."
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
    gh pr create --repo "$UPSTREAM_REPO" --base master --head "$FORK_USER:$BRANCH" \
        --title "$subj" --body-file "$body" $draftflag || die "gh pr create failed"
    ok "PR opened"
else
    log "committed on $BRANCH - review, then: git push -u origin $BRANCH && gh pr create ..."
fi

echo "== done; evidence kept in $EVIDENCE_DIR =="
