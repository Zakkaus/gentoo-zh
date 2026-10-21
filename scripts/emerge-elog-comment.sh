#!/usr/bin/env bash
# usage: emerge-elog-comment.sh <artifacts-directory>
# Each subdirectory holds one emerge-on-pr target: atom, profile, outcome, elog.
set -euo pipefail
MARKER='<!-- pkgcheck-report -->'
MAX_LINES=40
MAX_BYTES=40000
artifacts_dir=${1:?artifacts-directory}
body_file=$(mktemp)
trap 'rm -f "$body_file"' EXIT

pulls=$(gh api "repos/$GITHUB_REPOSITORY/pulls?state=open&per_page=100" --paginate --slurp)
matches=$(jq -r --arg head_sha "$HEAD_SHA" '
    .[][] | select(.head.sha == $head_sha) | .number
' <<< "$pulls")
pr=${matches%%$'\n'*}
if [ -z "$pr" ]; then
    echo 'no open pull request at this commit'
    exit 0
fi
echo "pull request #${pr}"

targets=()
while IFS= read -r dir; do
    targets+=("$dir")
done < <(find "$artifacts_dir" -mindepth 1 -maxdepth 1 -type d | sort -V)
if [ "${#targets[@]}" -eq 0 ]; then
    echo 'no elog reports'
    exit 0
fi

# field <dir> <name>: one artifact value, reduced to atom characters
field() {
    head -c 200 "$1/$2" 2>/dev/null | tr -cd '[:alnum:]/._+=~@:-'
}

# Portage starts every elog section with "CLASS: phase".
sections() {
    grep -cE '^(INFO|LOG|WARN|ERROR|QA): [a-z]+$' "$1" || true
}
fails() {
    grep -qE '^(QA|ERROR): [a-z]+$' "$1"
}

rows=() details=() failing=0 warned=0
for dir in "${targets[@]}"; do
    atom=$(field "$dir" atom) profile=$(field "$dir" profile)
    case $(field "$dir" outcome) in
        success) emerge=':white_check_mark: success' ;;
        failure) emerge=':x: failure' ;;
        skipped) emerge='not run, an earlier step failed' ;;
        *) emerge='unknown' ;;
    esac
    elog=$dir/elog
    if [ ! -s "$elog" ]; then
        rows+=("| \`$atom\` | \`$profile\` | $emerge | no elog |")
        continue
    fi
    n=$(sections "$elog")
    noun=sections
    [ "$n" -ne 1 ] || noun=section
    if fails "$elog"; then
        failing=$(( failing + 1 ))
        rows+=("| \`$atom\` | \`$profile\` | $emerge | :x: QA or error, ${n} ${noun} |")
    else
        warned=$(( warned + 1 ))
        rows+=("| \`$atom\` | \`$profile\` | $emerge | :warning: ${n} ${noun} |")
    fi
    lines=$(wc -l < "$elog")
    details+=("$(
        echo
        echo "<details><summary><code>${atom}</code> (<code>${profile}</code>)</summary>"
        echo
        echo '``````'
        head -n "$MAX_LINES" "$elog"
        echo '``````'
        if [ "$lines" -gt "$MAX_LINES" ]; then
            echo
            echo "$(( lines - MAX_LINES )) more lines in the [run](${RUN_URL})."
        fi
        echo
        echo '</details>'
    )")
done

{
    echo '## emerge elog'
    echo
    echo "*Commit*: \`${HEAD_SHA}\`"
    if [ "$failing" -gt 0 ]; then
        echo '*Status*: :x: **QA or error elog**, which fails the emerge job'
    elif [ "$warned" -gt 0 ]; then
        echo '*Status*: :warning: warnings only, which do not fail the emerge job'
    else
        echo '*Status*: :white_check_mark: no elog'
    fi
    echo
    echo '| Package | Profile | emerge | elog |'
    echo '| --- | --- | --- | --- |'
    printf '%s\n' "${rows[@]}"
} > "$body_file"
# a comment holds at most 65536 characters, shared with the pkgcheck section
for detail in "${details[@]}"; do
    if [ $(( $(wc -c < "$body_file") + ${#detail} )) -gt "$MAX_BYTES" ]; then
        printf '\nMore elog in the [run](%s).\n' "$RUN_URL" >> "$body_file"
        break
    fi
    printf '%s\n' "$detail" >> "$body_file"
done

scripts/upsert-comment-section.sh "$GITHUB_REPOSITORY" "$pr" "$MARKER" elog "$body_file"
echo "commented on #${pr}"
