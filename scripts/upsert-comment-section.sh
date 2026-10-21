#!/usr/bin/env bash
# usage: upsert-comment-section.sh <repository> <issue> <marker> <section> <body-file>
# Several workflows share one bot comment, each owning one section of it.
set -euo pipefail
SECTIONS=(pkgcheck elog)

repository=${1:?repository}
issue=${2:?issue}
marker=${3:?marker}
section=${4:?section}
body_file=${5:?body-file}
[[ " ${SECTIONS[*]} " == *" $section "* ]] || { echo "unknown section: $section" >&2; exit 1; }

comments=$(gh api "repos/$repository/issues/$issue/comments" --paginate --slurp)
comment=$(jq -c --arg marker "$marker" '
    [.[][] | select(.user.type == "Bot" and (.body | contains($marker)))][0] // {}
' <<< "$comments")

# Section text comes from pull request runs; dropping "<!--" keeps it from forging a marker.
new_body=$(mktemp)
trap 'rm -f "$new_body"' EXIT
jq -r --arg marker "$marker" --arg section "$section" --rawfile text "$body_file" '
    def between($n):
        split("<!-- \($n):begin -->") | if length > 1 then .[1] | split("<!-- \($n):end -->")[0] else null end;
    (.body // "") as $old
    | [$ARGS.positional[] as $n
        | (if $n == $section then $text | gsub("<!--"; "") else $old | between($n) end)
        | select(. != null)
        | ltrimstr("\n") | rtrimstr("\n")
        | "<!-- \($n):begin -->\n\(.)\n<!-- \($n):end -->"]
    | join("\n\n") + "\n\n" + $marker
' --args "${SECTIONS[@]}" <<< "$comment" > "$new_body"

comment_id=$(jq -r '.id // empty' <<< "$comment")
if [ -n "$comment_id" ]; then
    gh api -X PATCH "repos/$repository/issues/comments/$comment_id" -F "body=@$new_body" >/dev/null
else
    gh api "repos/$repository/issues/$issue/comments" -F "body=@$new_body" >/dev/null
fi
