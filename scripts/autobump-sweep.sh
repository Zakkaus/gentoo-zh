#!/usr/bin/env bash
# autobump-sweep.sh - the whole loop, end to end:
#   nvchecker issues -> autobump.sh -> (exit 3) judge -> retry / defer
#
# usage: autobump-sweep.sh [issue#...] [--limit N] [--pr] [--comment]
#   no issue numbers   process all open "[nvchecker]" issues (up to --limit, default 5)
#   --pr               let autobump.sh push + open PRs (default: local branch only)
#   --comment          post the judge's comment on deferred issues (default: print only)
#
# State: ~/.local/state/autobump/done.list - one "cat/pkg ver result date" per
# attempt. Terminal results (bumped/deferred) are never retried for the same
# version; a new upstream version gets a fresh attempt.

set -uo pipefail
REPO=/home/zakk/code/gentoo-zh
UPSTREAM_REPO=gentoo-zh/overlay
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/autobump
DONE="$STATE_DIR/done.list"
mkdir -p "$STATE_DIR"; touch "$DONE"
cd "$REPO" || exit 2

PR=""; COMMENT=0; LIMIT=5; ISSUES=()
prev=""
for a in "$@"; do
    case "$a" in
        --pr) PR="--pr" ;;
        --comment) COMMENT=1 ;;
        --limit) prev=limit ;;
        [0-9]*) if [ "$prev" = limit ]; then LIMIT=$a; prev=""; else ISSUES+=("$a"); fi ;;
        *) echo "unknown arg: $a" >&2; exit 2 ;;
    esac
done

if [ ${#ISSUES[@]} -eq 0 ]; then
    mapfile -t ISSUES < <(gh issue list --repo "$UPSTREAM_REPO" --search '[nvchecker] in:title' \
        --state open --limit "$LIMIT" --json number --jq '.[].number')
fi
[ ${#ISSUES[@]} -gt 0 ] || { echo "no open nvchecker issues"; exit 0; }

ORIG_BRANCH=$(git branch --show-current)
declare -A RESULT

# run the tools from a copy: autobump.sh switches branches, and if the scripts
# only exist on the current branch they would vanish mid-sweep
TOOLS=$(mktemp -d /tmp/autobump-tools-XXXX)
cp scripts/autobump.sh scripts/autobump-judge.sh "$TOOLS/"

for n in "${ISSUES[@]}"; do
    title=$(gh issue view "$n" --repo "$UPSTREAM_REPO" --json title --jq .title 2>/dev/null)
    pkg=$(sed -nE 's/^\[nvchecker\] ([a-z0-9-]+\/[A-Za-z0-9_.+-]+) can be bump to .*/\1/p' <<<"$title")
    ver=$(sed -nE 's/.* can be bump to ([A-Za-z0-9._-]+)$/\1/p' <<<"$title")
    if [ -z "$pkg" ] || [ -z "$ver" ]; then RESULT[$n]="unparseable title"; continue; fi

    if prior=$(grep -m1 -F "$pkg $ver " "$DONE"); then
        RESULT[$n]="skip ($prior)"; continue
    fi

    echo "==== #$n $pkg -> $ver ===="
    out=$(bash "$TOOLS/autobump.sh" "$n" $PR 2>&1); ec=$?
    echo "$out" | tail -4

    case "$ec" in
    0)
        echo "$pkg $ver bumped $(date +%F)" >> "$DONE"
        RESULT[$n]="bumped$([ -n "$PR" ] && echo ' + PR')"
        ;;
    3)
        ev=$(grep -oE '/tmp/autobump-[A-Za-z0-9._-]+' <<<"$out" | tail -1)
        old=$(sed -nE 's/^>> current: ([^ ]+) +-> +target:.*/\1/p' <<<"$out" | head -1)
        verdict_json=$(bash "$TOOLS/autobump-judge.sh" "$ev" "$pkg" "${old:-?}" "$ver")
        verdict=$(jq -r .verdict <<<"$verdict_json")
        echo "judge: $verdict_json"
        if [ "$verdict" = proceed ]; then
            out2=$(bash "$TOOLS/autobump.sh" "$n" --accept-surface $PR 2>&1); ec2=$?
            echo "$out2" | tail -3
            if [ "$ec2" = 0 ]; then
                echo "$pkg $ver bumped-after-judge $(date +%F)" >> "$DONE"
                RESULT[$n]="bumped (judge accepted surface delta)"
            else
                echo "$pkg $ver deferred $(date +%F)" >> "$DONE"
                RESULT[$n]="deferred (retry failed, exit $ec2)"
            fi
        else
            echo "$pkg $ver deferred $(date +%F)" >> "$DONE"
            comment=$(jq -r .issue_comment <<<"$verdict_json")
            reasons=$(jq -r '.reasons | join("; ")' <<<"$verdict_json")
            RESULT[$n]="deferred: $reasons"
            if [ "$COMMENT" = 1 ] && [ -n "$comment" ]; then
                gh issue comment "$n" --repo "$UPSTREAM_REPO" \
                    --body "$comment"$'\n\n'"(autobump: not mechanically safe - $reasons)"
            fi
        fi
        ;;
    *)
        # precondition (branch exists, dirty tree, fetch error): not terminal,
        # do not record; next sweep retries
        RESULT[$n]="not attempted: $(tail -1 <<<"$out")"
        ;;
    esac
done

[ -n "$ORIG_BRANCH" ] && git checkout -q "$ORIG_BRANCH" 2>/dev/null
rm -rf "$TOOLS"

echo
echo "==== sweep summary ===="
for n in "${ISSUES[@]}"; do printf '#%s  %s\n' "$n" "${RESULT[$n]:-?}"; done
