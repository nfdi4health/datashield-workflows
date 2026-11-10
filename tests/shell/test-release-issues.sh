#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2319  # backticks and $(...) in single quotes are
# meant literally; `[ ... ]; check ... $?` is the style of this file
# Tests for .github/actions/release-issues/, with a stand-in for `gh` that
# answers from files and records every call. Needs jq.
#   bash tests/shell/test-release-issues.sh
# Prints one line per test and exits non-zero if any failed.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACTION="$ROOT/.github/actions/release-issues"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin"
mkdir -p "$BIN" "$WORK/issues" "$WORK/labels"
command -v jq > /dev/null || { echo "FAIL jq is needed"; exit 1; }

passed=0
failed=0
check() {  # check <name> <condition result>
  if [ "$2" = 0 ]; then echo "ok   $1"; passed=$((passed + 1)); else echo "FAIL $1"; failed=$((failed + 1)); fi
}

# gh: answers from $WORK (issues/<n>.json, labels/<n>, commits, body,
# labelled.json with its --jq filter applied, delete-error), keeps the pull request's description in
# $WORK/body when it is changed, and writes each call to $WORK/calls.
cat > "$BIN/gh" <<STANDIN
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$WORK/calls"
case "\$*" in
  "api repos/me/pkg/pulls/9/commits"*) cat "$WORK/commits" ;;
  "api repos/me/pkg/pulls/9 "*) cat "$WORK/body" ;;
  "api -X PATCH repos/me/pkg/pulls/9"*)
    for arg in "\$@"; do case "\$arg" in body=*) printf '%s' "\${arg#body=}" > "$WORK/body" ;; esac; done ;;
  "api repos/me/pkg/issues?state="*)
    filter=""; prev=""; for arg in "\$@"; do [ "\$prev" = --jq ] && filter="\$arg"; prev="\$arg"; done
    jq -r "\$filter" "$WORK/labelled.json" ;;
  "api repos/me/pkg/issues/"*"/labels"*) n="\${2#repos/me/pkg/issues/}"; cat "$WORK/labels/\${n%%/*}" 2>/dev/null ;;
  "api repos/me/pkg/issues/"*) f="$WORK/issues/\${2#repos/me/pkg/issues/}.json"; [ -f "\$f" ] || { echo "HTTP 404" >&2; exit 1; }; cat "\$f" ;;
  "api -X DELETE"*) [ ! -s "$WORK/delete-error" ] || { cat "$WORK/delete-error" >&2; exit 1; } ;;
esac
STANDIN
chmod +x "$BIN/gh"

issue() {  # issue <n> [state] [pull request?]
  jq -n --argjson n "$1" --arg state "${2:-open}" --arg pr "${3:-}" \
    '{number: $n, state: $state} + (if $pr == "" then {} else {pull_request: {url: "x"}} end)' > "$WORK/issues/$1.json"
}
# labelled <n[:state[:reason]]|n:pr> ...: the issues the label search finds.
labelled_issues() {
  local spec n state reason
  for spec in "$@"; do
    IFS=: read -r n state reason <<< "$spec"
    jq -n --argjson n "$n" --arg state "${state:-open}" --arg reason "${reason:-}" \
      '{number: $n, state: (if $state == "pr" then "open" else $state end), state_reason: (if $reason == "" then null else $reason end)}
       + (if $state == "pr" then {pull_request: {url: "x"}} else {} end)'
  done | jq -s . > "$WORK/labelled.json"
}
reset() {
  rm -f "$WORK/issues/"* "$WORK/labels/"*
  : > "$WORK/calls"; : > "$WORK/commits"; labelled_issues; : > "$WORK/delete-error"
  printf 'The release.' > "$WORK/body"
}

# run <step> [merged] [base] [event body]
run() {
  jq -n --arg merged "${2:-true}" --arg base "${3:-dev}" --arg body "${4:-}" \
    '{pull_request: {number: 9, merged: ($merged == "true"), base: {ref: $base}, body: $body}}' > "$WORK/event.json"
  (cd "$WORK" && PATH="$BIN:$PATH" GITHUB_EVENT_PATH="$WORK/event.json" GITHUB_REPOSITORY=me/pkg \
    STEP="$1" NEXT_LABEL=next-release RELEASED_LABEL=released BRANCH=dev \
    bash "$ACTION/release-issues.sh" > "$WORK/out.txt" 2>&1)
}
labelled() { grep -qF "api -X POST repos/me/pkg/issues/$1/labels -f labels[]=$2" "$WORK/calls"; }
commented() { grep -qF "api -X POST repos/me/pkg/issues/$1/comments" "$WORK/calls"; }
writes() { grep -cE 'api -X (POST|PATCH|DELETE)' "$WORK/calls"; }

# --- mark: a pull request merged into dev ------------------------------------

reset; issue 12; issue 15; issue 20
printf 'fix: the median\n\nFixes #15\n' > "$WORK/commits"
run mark true dev 'Closes #12. Refs #20.'; status=$?
[ "$status" = 0 ] && labelled 12 next-release && labelled 15 next-release; check "mark: issues closed in the description and in commits" $?
! labelled 20 next-release && ! commented 20; check "mark: a mere mention (Refs) doesn't count" $?
commented 12 && grep -qF 'Merged into `dev` with #9. This issue will be closed by the next release.' "$WORK/calls"; check "mark: one comment saying so" $?

reset; issue 3; issue 4; issue 5; issue 6; issue 7; issue 8; issue 9
run mark true dev 'closes #3, Fixed: #4, RESOLVES me/pkg#5, resolved #6, other/repo#7 fixes, fixes other/repo#8, prefix#9'
for n in 3 4 5 6; do labelled "$n" next-release || status=1; done
[ "${status:-0}" = 0 ] && ! labelled 7 next-release && ! labelled 8 next-release && ! labelled 9 next-release
check "mark: keywords in any case and form, only for this repository" $?

reset; issue 12 closed; issue 13 open pr
run mark true dev 'Closes #12, closes #13, closes #14'; status=$?
[ "$status" = 0 ] && [ "$(writes)" = 0 ]; check "mark: closed issues, pull requests and unknown numbers are skipped" $?

reset; issue 12; echo next-release > "$WORK/labels/12"
run mark true dev 'Closes #12'
[ "$(writes)" = 0 ]; check "mark: an issue already labelled gets no second comment" $?

reset; issue 12; echo Next-Release > "$WORK/labels/12"
run mark true dev 'Closes #12'
[ "$(writes)" = 0 ]; check "mark: the label in another case counts" $?

reset; issue 12
run mark true dev 'A change without closing keywords. Refs #12.'; status=$?
[ "$status" = 0 ] && [ "$(writes)" = 0 ]; check "mark: no closing keyword, nothing, and no failure" $?

reset; issue 12
run mark false dev 'Closes #12'
[ ! -s "$WORK/calls" ]; check "mark: a closed, unmerged pull request: nothing" $?
run mark true main 'Closes #12'
[ ! -s "$WORK/calls" ]; check "mark: merged into another branch: nothing" $?

reset; issue 12
run mark true dev '$(touch pwned) Closes #12'
[ ! -e "$WORK/pwned" ]; check "mark: text is not run as code" $?

# --- link: the release pull request ------------------------------------------

reset; labelled_issues 12 15
run link; status=$?
[ "$status" = 0 ] && grep -qxF 'Closes #12' "$WORK/body" && grep -qxF 'Closes #15' "$WORK/body" && grep -q '^The release.$' "$WORK/body"
check "link: Closes for each labelled issue, the description kept" $?

labelled_issues 15
run link
[ "$(grep -c 'release-issues: closed by this release' "$WORK/body")" = 1 ] && ! grep -q '#12' "$WORK/body" && grep -qxF 'Closes #15' "$WORK/body"
check "link: run again, the block is replaced, not added" $?

labelled_issues
run link
! grep -q 'release-issues' "$WORK/body" && [ "$(cat "$WORK/body")" = 'The release.' ]
check "link: no labelled issue, no block" $?

reset; labelled_issues 12 13:closed:completed 14:closed:not_planned 16:pr
run link; status=$?
[ "$status" = 0 ] && grep -qxF 'Closes #12' "$WORK/body" && grep -qxF 'Closes #13' "$WORK/body" \
  && ! grep -q '#14' "$WORK/body" && ! grep -q '#16' "$WORK/body"
check "link: open and closed-as-completed issues, not 'not planned', not pull requests" $?
: > "$WORK/calls"; run swap
labelled 13 released && ! labelled 14 released; check "swap: an issue closed by hand gets released too" $?

reset; labelled_issues 12; printf 'Notes\n\nCloses #3 by hand.' > "$WORK/body"
run link
grep -qF 'Closes #3 by hand.' "$WORK/body" && grep -qxF 'Closes #12' "$WORK/body"; check "link: a person's own lines stay" $?

# --- swap: after the release -------------------------------------------------

reset; labelled_issues 12 15; run link; : > "$WORK/calls"
run swap; status=$?
[ "$status" = 0 ] && labelled 12 released && labelled 15 released \
  && grep -qF 'api -X DELETE repos/me/pkg/issues/12/labels/next-release' "$WORK/calls"
check "swap: next-release becomes released" $?
! grep -q 'issues/3/' "$WORK/calls"; check "swap: only the issues of the block" $?

reset; printf 'Closes #3 by hand.' > "$WORK/body"
run swap; status=$?
[ "$status" = 0 ] && [ "$(writes)" = 0 ]; check "swap: no block, nothing, and no failure" $?

reset; labelled_issues 12; run link; : > "$WORK/calls"
echo 'gh: Label does not exist (HTTP 404)' > "$WORK/delete-error"
run swap; status=$?
[ "$status" = 0 ] && labelled 12 released; check "swap: a label already gone is fine" $?
echo 'gh: Resource not accessible by integration (HTTP 403)' > "$WORK/delete-error"
run swap; status=$?
[ "$status" != 0 ]; check "swap: a refused removal fails the run" $?

# --- the step and the workflow -----------------------------------------------

reset; run other; status=$?
[ "$status" != 0 ] && grep -q 'Unknown step' "$WORK/out.txt"; check "an unknown step fails" $?

FILES=("$ROOT/.github/workflows/release-issues.yml" "$ACTION/action.yml")
! grep -q 'actions/checkout' "${FILES[@]}"; check "no checkout" $?
! grep -q 'github\.event' "${FILES[@]}"; check "no event fields in expressions" $?

echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
