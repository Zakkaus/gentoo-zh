#!/usr/bin/env bash
# autobump-discover: recommend packages for the autobump whitelist.
#
# Scans git history for packages whose recent version bumps were purely MECHANICAL --
# an ebuild renamed with no content change, plus Manifest, and nothing else. Those are
# the packages a human keeps hand-bumping identically; the engine would do them safely.
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
        # mechanical iff: no file other than Manifest / *.ebuild changed,
        # AND the ebuild was renamed with 0 added / 0 deleted (no content change).
        echo "$ns" | grep -qvE 'Manifest$|\.ebuild' && continue          # some other file touched
        echo "$ns" | grep -E '\.ebuild' | grep -q '=>' || continue        # no ebuild rename
        echo "$ns" | grep -E '\.ebuild.*=>' | grep -qvE '^0[[:space:]]+0' && continue # ebuild body changed
        # A self-hosted vendor bundle whose hash CHANGES every version needs out-of-band
        # regeneration -> autobump would 404-defer, so it is NOT mechanical. Only count it if
        # any -vendor/-crates/-deps/node_modules DIST keeps the same size+BLAKE2B (codex case).
        vlines=$(git show "$sha" -- "$pkg" 2>/dev/null | grep -E '^[-+]DIST.*(-vendor|-crates|-deps|node_modules)')
        if [ -n "$vlines" ]; then
            oldv=$(echo "$vlines" | awk '/^-DIST/{print $3,$5}' | sort -u)
            newv=$(echo "$vlines" | awk '/^\+DIST/{print $3,$5}' | sort -u)
            [ "$oldv" != "$newv" ] && continue   # vendor content changed -> not mechanical
        fi
        mech=$((mech + 1))
    done
    [ "$total" -ge "$MIN" ] || continue
    p=$(( mech * 100 / total ))
    [ "$p" -ge "$PCT" ] && printf 'RECOMMEND  %-42s %d/%d mechanical (%d%%)\n' "$pkg" "$mech" "$total" "$p"
done | sort
