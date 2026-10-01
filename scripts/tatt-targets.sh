#!/usr/bin/env bash
# usage: tatt-targets.sh PR BASE LABELED, or tatt-targets.sh --ignore-prefixes
set -euo pipefail

ignore_prefixes=(
    elibc_ video_cards_ linguas_ python_targets_ python_single_target_
    kdeenablefinal test debug cpu_flags_
)
if [ "${1:-}" = --ignore-prefixes ]; then
    printf -v prefixes '"%s",' "${ignore_prefixes[@]}"
    printf '%s\n' "${prefixes%,}"
    exit 0
fi

pr=${1:?PR number}
base=${2:?base commit}
labeled=${3:?tatt label}
git fetch --quiet --depth=1 "https://github.com/$GITHUB_REPOSITORY" "$base"
files=$(gh api --paginate "repos/$GITHUB_REPOSITORY/pulls/$pr/files" \
    --jq '.[] | select(.additions > 0) | [.filename, .previous_filename // ""] | @tsv')

use_vars() {
    awk '
        !collecting && match($0, /^(IUSE|REQUIRED_USE)\+?=["\047]/) {
            collecting = 1
            quotes = 0
            quote = substr($0, RLENGTH, 1)
        }
        collecting {
            printf "%s ", $0
            quotes += gsub(quote, quote)
            if (quotes % 2 == 0) {
                collecting = 0
                print ""
            }
        }
    ' | tr "'" '"' | tr -s ' \t' ' '
}
flags() {
    local values flag prefix ignored
    values=$(use_vars | sed -n 's/^IUSE+\?="\([^"]*\)".*/\1/p')
    for flag in $values; do
        flag=${flag#[-+]}
        ignored=false
        for prefix in "${ignore_prefixes[@]}"; do
            if [[ "$flag" == "$prefix"* ]]; then
                ignored=true
                break
            fi
        done
        "$ignored" || printf '%s\n' "$flag"
    done
}
live='-9{4,}(-r[0-9]+)?\.ebuild$'

printf '| ebuild | tatt |\n|---|---|\n' >> "$GITHUB_STEP_SUMMARY"
while IFS=$'\t' read -r ebuild previous; do
    [[ "$ebuild" =~ ^[A-Za-z0-9+_.-]+/[A-Za-z0-9+_.-]+/[A-Za-z0-9+_.-]+\.ebuild$ && -f "$ebuild" ]] || continue
    package=${ebuild%/*}
    filename=${ebuild##*/}
    atom="=${package%%/*}/${filename%.ebuild}"
    keywords=$(sed -n "s/^KEYWORDS=[\"']\(.*\)[\"'].*/\1/p" "$ebuild")
    if [[ "$ebuild" =~ $live ]]; then
        keyword='**'
    elif [[ " $keywords " == *" ~amd64 "* || " $keywords " == *" amd64 "* ]]; then
        keyword='~amd64'
    else
        keyword=
    fi

    if [ -z "$keyword" ]; then
        reason="skipped: not keyworded ~amd64"
    elif [ "$labeled" = true ]; then
        reason="tested: tatt label"
    elif [ -z "$(flags < "$ebuild")" ]; then
        reason="skipped: no USE flag to vary"
    elif [ -z "$(git ls-tree "$base" -- "$package/")" ]; then
        reason="tested: new package"
    else
        vars=$(use_vars < "$ebuild")
        if [ -n "$previous" ]; then
            old=("$previous")
        elif git cat-file -e "$base:$ebuild" 2> /dev/null; then
            old=("$ebuild")
        else
            mapfile -t old < <(git ls-tree --name-only "$base" -- "$package/" | grep '\.ebuild$' | grep -vE -- "$live")
        fi
        reason="tested: IUSE or REQUIRED_USE changed"
        for file in "${old[@]}"; do
            if [ "$(git show "$base:$file" | use_vars)" = "$vars" ]; then
                reason="skipped: add the tatt label to test"
                break
            fi
        done
    fi
    echo "| \`$ebuild\` | $reason |" >> "$GITHUB_STEP_SUMMARY"
    if [[ "$reason" == tested:* ]]; then
        printf '%s\t%s\n' "$atom" "$keyword"
    fi
done <<< "$files" | jq -Rc 'split("\t") | {atom: .[0], keyword: .[1]}' | jq -sc .
