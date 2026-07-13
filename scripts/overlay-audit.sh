#!/usr/bin/env bash
# overlay-audit.sh - periodic whole-overlay rot scan. Read-only, no changes.
# The long-term feedback loop: per-bump checks catch drift at bump time, this
# catches what accumulated anyway. Cron it monthly (with --net).
#
# usage: scripts/overlay-audit.sh [--net] [report-file]
#   --net  also run pkgcheck network checks (DeadUrl etc.) - slow, cron only
#
# Sections:
#   1. pkgcheck findings over the whole overlay
#   2. nvchecker coverage: packages nobody tracks / stale overlay.toml entries
#   3. dep rot on installed overlay packages (qa-vdb, both directions:
#      undeclared-but-linked and declared-but-unused)

set -uo pipefail
REPO=/home/zakk/code/gentoo-zh
NET=0; OUT=""
for a in "$@"; do case "$a" in --net) NET=1 ;; *) OUT="$a" ;; esac; done
OUT=${OUT:-/tmp/overlay-audit-$(date +%Y%m%d).md}
cd "$REPO" || exit 2

{
    echo "# overlay audit $(date +%F)"
    echo
    echo "## 1. pkgcheck $([ "$NET" = 1 ] && echo '(with --net)')"
    echo '```'
} > "$OUT"
if [ "$NET" = 1 ]; then pkgcheck scan --net >> "$OUT" 2>&1; else pkgcheck scan >> "$OUT" 2>&1; fi
echo '```' >> "$OUT"

# ---- 2. nvchecker coverage ----
ALLPKG=$(mktemp); RELPKG=$(mktemp); LIVEPKG=$(mktemp); TOML=$(mktemp)
for d in */*/; do
    d=${d%/}
    case "$d" in .git*|.github*|metadata/*|profiles/*|licenses/*|scripts/*|docs/*|eclass/*|.claude*) continue ;; esac
    # uid/gid and virtual packages have no upstream version to track
    case "$d" in acct-group/*|acct-user/*|virtual/*) continue ;; esac
    ls "$d"/*.ebuild >/dev/null 2>&1 || continue
    echo "$d" >> "$ALLPKG"
    if ls "$d"/*.ebuild | grep -vqE -- '-9{4,}'; then echo "$d" >> "$RELPKG"; else echo "$d" >> "$LIVEPKG"; fi
done
sort -u "$ALLPKG" -o "$ALLPKG"; sort -u "$RELPKG" -o "$RELPKG"; sort -u "$LIVEPKG" -o "$LIVEPKG" 2>/dev/null
sed -nE 's/^\["([a-z0-9-]+\/[A-Za-z0-9_.+-]+)"\]/\1/p' .github/workflows/overlay.toml | sort -u > "$TOML"

{
    echo
    echo "## 2. nvchecker coverage"
    echo
    echo "### release packages with no overlay.toml entry (never get bump issues)"
    comm -23 "$RELPKG" "$TOML" | sed 's/^/- /'
    echo
    echo "### overlay.toml entries whose package is gone (stale)"
    comm -13 "$ALLPKG" "$TOML" | sed 's/^/- /'
    echo
    echo "### live-only packages (untracked by design)"
    comm -23 "$LIVEPKG" "$TOML" 2>/dev/null | sed 's/^/- /'
} >> "$OUT"

# ---- 3. dep rot on installed overlay packages ----
{
    echo
    echo "## 3. dep rot (qa-vdb) on installed ::gentoo-zh packages"
    echo
    echo "'>' = linked but missing from RDEPEND; '<' = in RDEPEND but not linked (drop candidate)."
    echo "Prebuilt (QA_PREBUILT) packages dlopen a lot - treat their '<' lines as advisory."
    echo '```'
} >> "$OUT"
if command -v qa-vdb >/dev/null; then
    for repof in /var/db/pkg/*/*/repository; do
        grep -qx gentoo-zh "$repof" 2>/dev/null || continue
        pdir=$(dirname "$repof")
        cpv="${pdir#/var/db/pkg/}"
        tag=""
        [ -s "$pdir/QA_PREBUILT" ] && tag=" [prebuilt: advisory]"
        out=$(qa-vdb "=$cpv" 2>&1)
        [ -n "$out" ] && printf '%s%s\n%s\n\n' "$cpv" "$tag" "$out"
    done >> "$OUT"
else
    echo "qa-vdb not installed (app-portage/iwdevtools)" >> "$OUT"
fi
echo '```' >> "$OUT"

# ---- 4. archived / gone upstreams (deprecation candidates) ----
# A github-tracked package whose upstream repo is archived or 404 will silently
# stop getting bump issues (nvchecker goes quiet); flag it so a human can decide
# to deprecate/last-rite it (e.g. net-proxy/yass, issue #10832). --net only.
{
    echo
    echo "## 4. archived / gone upstreams (deprecation candidates)"
    echo
} >> "$OUT"
if [ "$NET" = 1 ] && command -v gh >/dev/null; then
    MAP=$(mktemp)
    awk '
      /^\["/ { pkg=$0; gsub(/^\["|"\].*/,"",pkg); next }
      /^github *=/ { r=$0; sub(/^github *= *"/,"",r); sub(/".*/,"",r); if(pkg!=""){print pkg" "r; pkg=""} }
    ' .github/workflows/overlay.toml | sort -u > "$MAP"
    echo "checking $(wc -l < "$MAP") github upstreams..." >&2
    # query in parallel (authenticated gh api is well within rate limits)
    while read -r pkg repo; do printf '%s\t%s\n' "$pkg" "$repo"; done < "$MAP" \
      | xargs -P 6 -d '\n' -I{} bash -c '
          pkg=$(cut -f1 <<<"{}"); repo=$(cut -f2 <<<"{}")
          resp=$(gh api "repos/$repo" 2>/dev/null); rc=$?
          if [ $rc -ne 0 ]; then
              echo "- $pkg: upstream $repo NOT FOUND (deleted/renamed?) - verify"
          elif [ "$(jq -r .archived <<<"$resp")" = true ]; then
              echo "- $pkg: upstream $repo is ARCHIVED - deprecation candidate"
          fi
      ' | sort >> "$OUT"
    rm -f "$MAP"
else
    echo "_(run with --net to check upstream archive/404 status)_" >> "$OUT"
fi

rm -f "$ALLPKG" "$RELPKG" "$LIVEPKG" "$TOML"

# summary to stdout
echo "report: $OUT"
grep -cE '^- ' "$OUT" | xargs -I{} echo "coverage findings: {}"
grep -c 'incorrect RDEPEND' "$OUT" | xargs -I{} echo "dep-rot packages: {}"
grep -cE '^- .*(ARCHIVED|NOT FOUND)' "$OUT" | xargs -I{} echo "archived/gone upstreams: {}"
