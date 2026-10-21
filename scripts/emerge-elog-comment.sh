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

pr=$(scripts/pr-at-commit.sh "$GITHUB_REPOSITORY" "$HEAD_SHA")
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

# add_detail <atom> <profile> <title> <file>: a collapsed block, shared by the profiles
# that printed the same text
keys=()
declare -A detail_title detail_text detail_profiles
add_detail() {
    local text key
    text=$(sed 's/\x1b\[[0-9;]*m//g' "$4")
    key=$(md5sum <<< "$1 $3 $text")
    if [ -z "${detail_text[$key]+set}" ]; then
        keys+=("$key")
        detail_title[$key]="$3 of <code>$1</code>"
        detail_text[$key]=$text
    fi
    detail_profiles[$key]+="${detail_profiles[$key]:+, }<code>$2</code>"
}

rows=()
broken=0
failing=0
warned=0
for dir in "${targets[@]}"; do
    atom=$(field "$dir" atom)
    profile=$(field "$dir" profile)
    outcome=$(field "$dir" outcome)
    if [ "$(field "$dir" deps)" = failure ]; then
        emerge=':x: dependencies failed'
    else
        case $outcome in
            success) emerge=':white_check_mark: success' ;;
            failure) emerge=':x: failure' ;;
            skipped) emerge=':x: not run, an earlier step failed' ;;
            *) emerge=':x: unknown' ;;
        esac
    fi
    [ "$outcome" = success ] || broken=$(( broken + 1 ))
    [ ! -s "$dir/output" ] || add_detail "$atom" "$profile" 'emerge output' "$dir/output"
    elog=$dir/elog
    if [ ! -s "$elog" ]; then
        rows+=("| \`$atom\` | \`$profile\` | $emerge | no elog |")
        continue
    fi
    n=$(sections "$elog")
    if fails "$elog"; then
        failing=$(( failing + 1 ))
        rows+=("| \`$atom\` | \`$profile\` | $emerge | :x: QA or error (${n}) |")
    else
        warned=$(( warned + 1 ))
        rows+=("| \`$atom\` | \`$profile\` | $emerge | :warning: warnings (${n}) |")
    fi
    add_detail "$atom" "$profile" elog "$elog"
done

{
    echo '## emerge elog'
    echo
    echo "*Newest commit emerged*: \`${HEAD_SHA:0:9}\`"
    if [ "$broken" -gt 0 ]; then
        echo "*Status*: :x: **emerge failed**, the output is below and in the [run](${RUN_URL})"
    elif [ "$failing" -gt 0 ]; then
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
for key in "${keys[@]}"; do
    text=${detail_text[$key]}
    lines=$(wc -l <<< "$text")
    detail=$(
        echo
        echo "<details><summary>${detail_title[$key]} (${detail_profiles[$key]})</summary>"
        echo
        echo '``````'
        head -n "$MAX_LINES" <<< "$text"
        echo '``````'
        if [ "$lines" -gt "$MAX_LINES" ]; then
            echo
            echo "$(( lines - MAX_LINES )) more lines in the [run](${RUN_URL})."
        fi
        echo
        echo '</details>'
    )
    if [ $(( $(wc -c < "$body_file") + ${#detail} )) -gt "$MAX_BYTES" ]; then
        printf '\nMore elog in the [run](%s).\n' "$RUN_URL" >> "$body_file"
        break
    fi
    printf '%s\n' "$detail" >> "$body_file"
done

scripts/upsert-comment-section.sh "$GITHUB_REPOSITORY" "$pr" "$MARKER" elog "$body_file"
echo "commented on #${pr}"
