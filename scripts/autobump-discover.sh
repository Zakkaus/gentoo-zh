#!/usr/bin/env bash
# autobump-discover: recommend packages for the autobump whitelist.
#
# Scans git history for packages whose recent version bumps were purely MECHANICAL -- either an
# ebuild renamed with no content change (drop-old), or one new ebuild added byte-identical to the
# previous version with the old one kept (keep-old / add-only), plus Manifest and nothing else.
# Those are the packages a human keeps hand-bumping identically; the engine would do them safely
# (keep-old ones need the engine's per-package `keep_old = N`, which keeps the N most-recent versions).
#
# Prints a recommendation list only. A maintainer reviews it and adds `autobump = true`
# in overlay.toml -- nothing here auto-enables a package or opens a PR.
#
# usage: autobump-discover.sh [N_COMMITS] [MIN_BUMPS] [MIN_PCT]
#   N_COMMITS  how far back to scan (default 300)
#   MIN_BUMPS  need at least this many bumps to judge (default 3)
#   MIN_PCT    recommend if this %% of them were mechanical (default 80)
set -uo pipefail
REF=${AUTOBUMP_DISCOVER_REF:-upstream/master}
N=${1:-300}; MIN=${2:-3}; PCT=${3:-80}
TOML=.github/workflows/overlay.toml

# Self-hosted per-version dependency bundles (regenerated out of band by gentoo-deps or a draft
# repo): a bump that adds or changes one is NOT mechanical -- autobump would 404 on the freshly
# named bundle. Match by filename suffix. Prebuilt upstream blobs (incl. multi-arch .deb/.AppImage
# for amd64+arm64) are NOT bundles and must not match, so this is a suffix allowlist, not a count.
BUNDLE_RE='(-vendor|-crates|-deps|-pubcache|-vcpkg|-gomod|-go-mod|-cargo|-web|node_modules)'

already_on() {  # already whitelisted with autobump = true?
    # strip an inline comment after the table header (`["cat/pkg"] # note` is valid TOML)
    # so a commented-header package isn't re-recommended as if it were never whitelisted.
    awk -v w="[\"$1\"]" '
        {h=$0; sub(/[[:space:]]*#.*/,"",h); gsub(/[[:space:]]+$/,"",h)}
        h==w{f=1;next}/^\[/{f=0}f&&/autobump = true/{e=1}END{exit !e}' "$TOML" 2>/dev/null
}

# every package with an "add ..." bump commit in the window
git log "$REF" --oneline -"$N" --no-merges 2>/dev/null \
  | grep -oE '[a-z0-9-]+/[A-Za-z0-9_.+-]+: add ' | sed 's/: add //' | sort -u \
  | while read -r pkg; do
    already_on "$pkg" && continue
    total=0 mech=0
    for sha in $(git log "$REF" --oneline -"$N" -- "$pkg" 2>/dev/null | grep ': add ' | awk '{print $1}'); do
        total=$((total + 1))
        ns=$(git show "$sha" --numstat --format= -- "$pkg" 2>/dev/null)
        # mechanical iff only Manifest / *.ebuild changed, AND the version transition is either
        #   drop-old : the ebuild was RENAMED with 0 added / 0 deleted (version-only rename), or
        #   keep-old : exactly one new ebuild was ADDED, byte-identical to the newest prior
        #              version, with the old ebuild(s) kept (add-only bump of a version keeper).
        echo "$ns" | grep -qvE 'Manifest$|\.ebuild' && continue          # some other file touched
        if echo "$ns" | grep -E '\.ebuild' | grep -q '=>'; then
            echo "$ns" | grep -E '\.ebuild.*=>' | grep -qvE '^0[[:space:]]+0' && continue # renamed ebuild body changed
            echo "$ns" | grep -E '\.ebuild' | grep -qv '=>' && continue                   # a co-added/modified ebuild alongside the rename -> not mechanical
        else
            # keep-old add-only: one ebuild ADDED (status A), none modified/deleted/renamed, and
            # the new ebuild is byte-identical to the newest pre-existing version's ebuild (only
            # the version in the filename differs) -- a rename that git didn't detect as such.
            st=$(git show "$sha" --name-status --format= -- "$pkg" 2>/dev/null | grep -E '\.ebuild$')
            echo "$st" | grep -qvE '^A[[:space:]]' && continue            # a modified/deleted/renamed ebuild disqualifies
            [ "$(echo "$st" | grep -c '.')" -eq 1 ] || continue          # exactly one added ebuild
            newpath=$(echo "$st" | sed -E 's/^A[[:space:]]+//')
            oldpath=$(git ls-tree -r --name-only "$sha^" -- "$pkg" 2>/dev/null \
                        | grep '\.ebuild$' | grep -vE -- '-9{4,}' | sort -V | tail -1)  # newest non-live prior version
            [ -n "$oldpath" ] || continue                                 # no prior version to copy from
            cmp -s <(git show "$sha:$newpath" 2>/dev/null) <(git show "$sha^:$oldpath" 2>/dev/null) || continue # body differs
            # add-only has no old bundle to compare, so a freshly ADDED self-hosted bundle is caught here
            git show "$sha" -- "$pkg" 2>/dev/null | grep -qE "^\+DIST.*$BUNDLE_RE" && continue
        fi
        # A self-hosted bundle whose hash CHANGES every version needs out-of-band regeneration ->
        # autobump would 404-defer, so it is NOT mechanical. Count the bump only if such a bundle
        # DIST keeps the same size+BLAKE2B across the bump (codex case). Multi-arch prebuilt blobs
        # (amd64/arm64 .deb/.AppImage from upstream) do not match BUNDLE_RE and are correctly kept.
        vlines=$(git show "$sha" -- "$pkg" 2>/dev/null | grep -E "^[-+]DIST.*$BUNDLE_RE")
        if [ -n "$vlines" ]; then
            oldv=$(echo "$vlines" | awk '/^-DIST/{print $3,$5}' | sort -u)
            newv=$(echo "$vlines" | awk '/^\+DIST/{print $3,$5}' | sort -u)
            [ "$oldv" != "$newv" ] && continue   # bundle content changed -> not mechanical
        fi
        mech=$((mech + 1))
    done
    [ "$total" -ge "$MIN" ] || continue
    p=$(( mech * 100 / total ))
    [ "$p" -ge "$PCT" ] && printf 'RECOMMEND  %-42s %d/%d mechanical (%d%%)\n' "$pkg" "$mech" "$total" "$p"
done | sort
