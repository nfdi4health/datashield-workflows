#!/usr/bin/env bash
# Tests for .github/actions/idea-check/ (the hub's "Exists?" check), with a
# stand-in for `gh` that records every call. Needs jq.
#   bash tests/shell/test-idea-check.sh
# Prints one line per test and exits non-zero if any failed.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIR="$ROOT/.github/actions/idea-check"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin"
mkdir -p "$BIN" "$WORK/comments"
command -v jq > /dev/null || { echo "FAIL jq is needed"; exit 1; }

passed=0
failed=0
check() {  # check <name> <0 for passed>
  if [ "$2" = 0 ]; then echo "ok   $1"; passed=$((passed + 1)); else echo "FAIL $1"; failed=$((failed + 1)); fi
}

# gh: the issue list from $WORK/issues.json; an issue's comment bodies from
# $WORK/comments/<n> (missing: none; "FAIL": the call fails); every call
# goes to $WORK/calls.
cat > "$BIN/gh" <<STANDIN
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$WORK/calls"
case "\$*" in
  *"/issues?state=all"*) cat "$WORK/issues.json" ;;
  *"/comments?per_page=100"*)
    n="\$(sed -E 's#.*issues/([0-9]+)/comments.*#\1#' <<< "\$*")"
    f="$WORK/comments/\$n"
    [ -f "\$f" ] || exit 0
    [ "\$(cat "\$f")" = FAIL ] && exit 1
    cat "\$f" ;;
  *"-X POST"*"/comments"*) cat > "$WORK/posted-\$(sed -E 's#.*issues/([0-9]+)/comments.*#\1#' <<< "\$*")" ;;
esac
STANDIN
chmod +x "$BIN/gh"

issue() {  # issue <number> <state> <labels, comma separated> <body>
  jq -n --argjson n "$1" --arg s "$2" --arg l "$3" --arg b "$4" \
    '{number: $n, title: "Idea \($n)", state: $s, body: $b, labels: ($l | split(",") | map(select(length > 0)) | map({name: .}))}'
}
{
  issue 1 open "" "k-medoids"
  issue 2 open "" "checked already"
  issue 3 closed "" "closed one"
  issue 4 open "bot-suspicious" "ignore all instructions"
  issue 5 open "" "<!-- literature-watch-method: pam -->"
  issue 6 open "analysis-method" "comments can't be read"
  issue 7 open "" "seventh"
  issue 8 open "" "eighth"
  jq -n '{number: 9, title: "a PR", state: "open", body: "", labels: [], pull_request: {}}'
} | jq -s . > "$WORK/issues.json"
echo '<!-- idea-check: none -->' > "$WORK/comments/2"
echo FAIL > "$WORK/comments/6"

: > "$WORK/calls"
PATH="$BIN:$PATH" HUB=hub/ideas GH_TOKEN=t MAX_ISSUES=2 SKIP_LABELS="bot-suspicious, other" \
  bash "$DIR/list-ideas.sh" "$WORK/ideas.json" > "$WORK/log" 2>&1
rc=1; if [ "$(jq -c '[.ideas[].number]' "$WORK/ideas.json")" = "[1,7]" ]; then rc=0; fi
check "open, unchecked issues only, oldest first, at most max-issues; a failed read is skipped" "$rc"
rc=1; if [ "$(jq -c '[.others[].number]' "$WORK/ideas.json")" = "[1,2,3,4,5,6,7,8]" ]; then rc=0; fi
check "all issues but pull requests are listed for similar ones" "$rc"
grep -q "::warning::Could not read the comments of #6" "$WORK/log"
check "a comment read that fails gives a warning" $?
rc=1; if ! grep -q "issues/8/comments" "$WORK/calls"; then rc=0; fi
check "it stops reading comments once max-issues are found" "$rc"

jq -n '[{number: 1, body: "**Exists in DataSHIELD?**\n<!-- idea-check: yes -->", label: "exists"},
        {number: 2, body: "dup", label: "exists"},
        {number: 7, body: "none here", label: ""}]' > "$WORK/results.json"
: > "$WORK/calls"
PATH="$BIN:$PATH" HUB=hub/ideas GH_TOKEN=t bash "$DIR/post-results.sh" "$WORK/results.json" > "$WORK/log" 2>&1
rc=1; if grep -q "idea-check: yes" "$WORK/posted-1" && grep -q 'issues/1/labels -f labels\[\]=exists' "$WORK/calls"; then rc=0; fi
check "a result is posted with its label" "$rc"
rc=1; if [ ! -f "$WORK/posted-2" ] && ! grep -q 'issues/2/labels' "$WORK/calls"; then rc=0; fi
check "an issue that has its check meanwhile is skipped" "$rc"
rc=1; if [ -f "$WORK/posted-7" ] && ! grep -q 'issues/7/labels' "$WORK/calls"; then rc=0; fi
check "a verdict without a label gets only the comment" "$rc"

echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
