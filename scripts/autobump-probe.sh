#!/usr/bin/env bash
# autobump-probe: run the engine against EVERY open [nvchecker] issue and report what it
# would ACTUALLY do -- the engine's own mechanical/escalate/defer call on the *current*
# version. Unlike autobump-discover (which guesses from git history and is noisy), this is
# the ground truth: it lists real autobump candidates the engine judges mechanical but that
# are not yet opted in. Read-only: --check (fast, classify) and optionally --diff-only
# (fetches + surface-diffs, catches the fetch/vendor/surface problems --check cannot see).
# Opens no PR, bumps nothing, records no state.
#
# usage: autobump-probe.sh [--deep] [--limit N]
#   --deep     also run --diff-only on classify-mechanical issues (real fetch + surface
#              diff; slower, needs sudo/portage) so apifox-style fetch / openclaude-style
#              vendor-404 problems surface too
#   --limit N  probe at most N issues (default: all open)

set -uo pipefail
REPO=${AUTOBUMP_REPO:-$(git rev-parse --show-toplevel 2>/dev/null)}
UPSTREAM_REPO=${AUTOBUMP_UPSTREAM_REPO:-gentoo-zh/overlay}
ENGINE=${AUTOBUMP_ENGINE:?set AUTOBUMP_ENGINE, e.g. ruby autobump-rb/bin/autobump}
cd "$REPO" || exit 2

DEEP=0; LIMIT=0; prev=
for a in "$@"; do
    case "$a" in
        --deep)  DEEP=1; prev= ;;
        --limit) prev=limit ;;
        [0-9]*)  [[ $a =~ ^[0-9]+$ ]] || { echo "not a number: $a" >&2; exit 2; }
                 [ "$prev" = limit ] && LIMIT=$a; prev= ;;
        *) echo "unknown arg: $a" >&2; exit 2 ;;
    esac
done

# TOML allows a trailing comment after a table header (`["cat/pkg"] # note`), so strip an
# inline comment + trailing space before the exact-match compare -- otherwise an opted-in
# package with a commented header is silently treated as not-opted-in and never bumped.
autobump_enabled() {
    awk -v want="[\"$1\"]" '
        {h=$0; sub(/[[:space:]]*#.*/,"",h); gsub(/[[:space:]]+$/,"",h)}
        h==want{f=1;next}/^\[/{f=0}
        f&&h~/^[[:space:]]*autobump[[:space:]]*=/&&h!~/=[[:space:]]*false/{e=1}END{exit !e}' \
        .github/workflows/overlay.toml
}

autobump_disabled() {  # a maintainer explicitly turned it off (`# autobump off: ...`) -- never recommend it
    awk -v want="[\"$1\"]" '
        {h=$0; sub(/[[:space:]]*#.*/,"",h); gsub(/[[:space:]]+$/,"",h)}
        h==want{f=1;next}/^\[/{f=0}f&&/#[[:space:]]*autobump[[:space:]]+off/{e=1}END{exit !e}' \
        .github/workflows/overlay.toml
}

# gh lists 30 without --limit, and the probe claims to look at the whole open queue
if ! raw=$(gh issue list --repo "$UPSTREAM_REPO" --search '[nvchecker] in:title' \
    --state open --limit 500 --json number --jq '.[].number'); then
    echo "gh issue list failed (auth/rate-limit/network?)" >&2; exit 2
fi
mapfile -t ISSUES < <(printf '%s' "$raw")
[ "$LIMIT" -gt 0 ] && ISSUES=("${ISSUES[@]:0:$LIMIT}")
[ ${#ISSUES[@]} -gt 0 ] || { echo "no open nvchecker issues"; exit 0; }

declare -a CAND=() ESC=() DEFER=()
for n in "${ISSUES[@]}"; do
    title=$(gh issue view "$n" --repo "$UPSTREAM_REPO" --json title --jq .title 2>/dev/null)
    pkg=$(sed -nE 's/^\[nvchecker\] ([a-z0-9-]+\/[A-Za-z0-9_.+-]+) can be bump to .*/\1/p' <<<"$title")
    ver=$(sed -nE 's/.* can be bump to ([A-Za-z0-9._+-]+)$/\1/p' <<<"$title")
    [ -n "$pkg" ] && [ -n "$ver" ] || continue
    autobump_disabled "$pkg" && continue    # deliberately off -- keep it out of the recommendation
    tag=""; autobump_enabled "$pkg" && tag=" [opted-in]"

    ab_args=$(python3 scripts/autobump-args.py "$pkg" 2>/dev/null) || ab_args=""
    AB_ARGS=(); [ -n "$ab_args" ] && mapfile -t AB_ARGS <<<"$ab_args"
    $ENGINE "$n" --check "${AB_ARGS[@]}" >/dev/null 2>&1; ec=$?
    case "$ec" in
    0)  if [ "$DEEP" = 1 ]; then
            $ENGINE "$n" --diff-only "${AB_ARGS[@]}" >/dev/null 2>&1; dc=$?
            case "$dc" in
            0) CAND+=("#$n  $pkg -> $ver$tag") ;;
            3) ESC+=("#$n  $pkg -> $ver: surface/vendor changed (--diff-only)$tag") ;;
            *) DEFER+=("#$n  $pkg -> $ver: fetch/manifest failed (--diff-only)$tag") ;;
            esac
        else
            CAND+=("#$n  $pkg -> $ver (classify only)$tag")
        fi ;;
    3)  ESC+=("#$n  $pkg -> $ver: classify escalate$tag") ;;
    *)  DEFER+=("#$n  $pkg -> $ver: classify defer$tag") ;;
    esac
done

echo "==== autobump probe (${#ISSUES[@]} open issues$([ "$DEEP" = 1 ] && echo ', --deep')) ===="
echo
echo "-- mechanical bump candidates (${#CAND[@]}) --"
printf '  %s\n' "${CAND[@]}" 2>/dev/null
echo
echo "-- escalate: needs a human (major jump / deps / patch / vendor) (${#ESC[@]}) --"
printf '  %s\n' "${ESC[@]}" 2>/dev/null
echo
echo "-- defer: transient (fetch / network / mirror) (${#DEFER[@]}) --"
printf '  %s\n' "${DEFER[@]}" 2>/dev/null
