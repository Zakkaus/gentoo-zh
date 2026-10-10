#!/usr/bin/env bash
# usage: pr-template.sh <pull request number>
# prints the checkboxes of .github/pull_request_template.md missing from the pull request description
set -euo pipefail
pr=$(gh api "repos/$GITHUB_REPOSITORY/pulls/${1:?pull request number}")
[ "$(jq -r .user.login <<< "$pr")" != 'gentoo-zh-autobump[bot]' ] || exit 0
body=$(jq -r '.body // ""' <<< "$pr")
# shellcheck disable=SC2016 # literal backticks of the template
for box in 'I have run `pkgcheck scan --commits --net`' 'If I used AI:'; do
    grep -iF -- "$box" <<< "$body" | grep -qE '^- \[[ xX]\] ' || echo "- $box"
done
