#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2319  # backticks and $(...) in single quotes are
# meant literally; `[ ... ]; check ... $?` is the style of this file
# Tests for .github/actions/issue-label-check/, with a stand-in for `gh`
# that records every call. Needs jq.
#   bash tests/shell/test-label-check.sh
# Prints one line per test and exits non-zero if any failed.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACTION="$ROOT/.github/actions/issue-label-check"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin"
mkdir -p "$BIN"
command -v jq > /dev/null || { echo "FAIL jq is needed"; exit 1; }

passed=0
failed=0
check() {  # check <name> <condition result>
  if [ "$2" = 0 ]; then echo "ok   $1"; passed=$((passed + 1)); else echo "FAIL $1"; failed=$((failed + 1)); fi
}

# gh: answers from $WORK/labels (the issue's labels), $WORK/read-error and
# $WORK/delete-error (what reading them or a removal fails with), and
# writes each call to $WORK/calls.
cat > "$BIN/gh" <<STANDIN
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$WORK/calls"
case "\$*" in
  *"--paginate"*) [ ! -s "$WORK/read-error" ] || { cat "$WORK/read-error" >&2; exit 1; }; cat "$WORK/labels" ;;
  "api -X DELETE"*) [ ! -s "$WORK/delete-error" ] || { cat "$WORK/delete-error" >&2; exit 1; } ;;
esac
STANDIN
chmod +x "$BIN/gh"

# run_check <action> <sender> <label> [allowed-logins] [label input]
# The issue's title tries to run code; EVENT_NAME overrides `issues`.
run_check() {
  : > "$WORK/calls"
  jq -n --arg action "$1" --arg sender "$2" --arg label "$3" \
    '{action: $action, sender: {login: $sender}, label: {name: $label},
      issue: {number: 7, title: "$(touch pwned-title)"}}' > "$WORK/event.json"
  (cd "$WORK" && PATH="$BIN:$PATH" GITHUB_EVENT_NAME="${EVENT_NAME:-issues}" GITHUB_EVENT_PATH="$WORK/event.json" \
    GITHUB_REPOSITORY=me/pkg LABEL="${5:-bot-proceed}" ALLOWED_LOGINS="${4-FlorianSchw}" \
    bash "$ACTION/issue-label-check.sh" > "$WORK/out.txt" 2>&1)
}
no_writes() { ! grep -Eq 'DELETE|comments' "$WORK/calls"; }
no_calls()  { [ ! -s "$WORK/calls" ]; }
removed()   { grep -Fq "api -X DELETE repos/me/pkg/issues/7/labels/$1" "$WORK/calls"; }
comments()  { grep -c 'issues/7/comments' "$WORK/calls"; }
: > "$WORK/labels"
: > "$WORK/read-error"
: > "$WORK/delete-error"

# --- labeled -----------------------------------------------------------------

run_check labeled FlorianSchw bot-proceed; status=$?
[ "$status" = 0 ] && no_calls; check "allowed user: the label stays" $?

run_check labeled someone bot-proceed
removed bot-proceed && [ "$(comments)" = 1 ]; check "other user: removed, one comment" $?
grep -q 'body=Removed `bot-proceed`: only the people named' "$WORK/calls"; check "other user: the comment says why" $?
[ "$(grep -n . "$WORK/calls" | grep -m 1 DELETE | cut -d: -f1)" = 1 ]; check "removal before the comment" $?

for login in florianschw FlorianSchw2 Florian ''; do
  run_check labeled "$login" bot-proceed
  removed bot-proceed; check "exact login only: '$login' removed" $?
done

run_check labeled 'github-actions[bot]' bot-proceed
removed bot-proceed; check "a bot setting the label: removed" $?

run_check labeled someone bug
no_calls; check "another label: nothing" $?

run_check labeled someone Bot-Proceed
removed Bot-Proceed; check "the label in another case: removed" $?

run_check labeled carol bot-proceed 'alice, bob,carol'
no_calls; check "several logins: commas and spaces" $?
run_check labeled carol bot-proceed $'alice\ncarol'
no_calls; check "several logins: one per line" $?
run_check labeled carol bot-proceed 'alice bob'
removed bot-proceed; check "several logins: anyone else removed" $?
run_check labeled someone bot-proceed '* s*'
removed bot-proceed; check "no patterns in the list" $?
run_check labeled 'my-app[bot]' bot-proceed 'my-app[bot]'
no_calls; check "a listed bot login, literally" $?
run_check labeled someone bot-proceed ''
removed bot-proceed; check "empty list: nobody allowed" $?

run_check labeled someone 'needs approval' FlorianSchw 'needs approval'
removed 'needs%20approval'; check "own label name, encoded in the path" $?

run_check labeled someone '$(touch pwned-label)' FlorianSchw '$(touch pwned-label)'
[ ! -e "$WORK/pwned-label" ] && [ ! -e "$WORK/pwned-title" ]; check "event text is not run as code" $?

# --- edited ------------------------------------------------------------------

printf 'bug\nbot-proceed\n' > "$WORK/labels"
run_check edited someone ''
removed bot-proceed && [ "$(comments)" = 1 ]; check "edit with the label: removed, one comment" $?
grep -q 'body=Removed `bot-proceed`: the title or body changed' "$WORK/calls"; check "edit: the comment says it needs approving again" $?
run_check edited FlorianSchw ''
removed bot-proceed; check "edit by an allowed user: removed too" $?
run_check edited 'github-actions[bot]' ''
removed bot-proceed; check "edit by a bot: removed too" $?

echo Bot-Proceed > "$WORK/labels"
run_check edited someone ''
removed Bot-Proceed; check "edit: the label under its own spelling" $?

echo bug > "$WORK/labels"
run_check edited someone ''
no_writes; check "edit without the label: nothing changed" $?
echo bot-proceed-later > "$WORK/labels"
run_check edited someone ''
no_writes; check "edit: a longer label name is not the label" $?
: > "$WORK/labels"
run_check edited someone ''; status=$?
[ "$status" = 0 ] && no_writes; check "edit of an issue without labels" $?

echo 'gh: Server Error (HTTP 502)' > "$WORK/read-error"
run_check edited someone ''; status=$?
[ "$status" != 0 ] && no_writes; check "labels not readable: the run fails" $?
: > "$WORK/read-error"

# --- the bot's own actions, and everything else ------------------------------

run_check unlabeled 'github-actions[bot]' bot-proceed
no_calls; check "the bot's own removal: nothing" $?
run_check unlabeled someone bot-proceed
no_calls; check "anyone's removal: nothing" $?
run_check opened someone ''
no_calls; check "another action: nothing" $?
EVENT_NAME=pull_request run_check edited someone ''
no_calls; check "another event: nothing" $?

echo 'gh: Label does not exist (HTTP 404)' > "$WORK/delete-error"
echo bot-proceed > "$WORK/labels"
run_check edited someone ''; status=$?
[ "$status" = 0 ] && [ "$(comments)" = 0 ]; check "label already gone: no second comment" $?
echo 'gh: Resource not accessible by integration (HTTP 403)' > "$WORK/delete-error"
run_check labeled someone bot-proceed; status=$?
[ "$status" != 0 ] && [ "$(comments)" = 0 ]; check "removal refused: the run fails, no comment" $?
: > "$WORK/delete-error"

# --- what the workflow may touch ---------------------------------------------

FILES=("$ROOT/.github/workflows/issue-label-check.yml" "$ACTION/action.yml")
! grep -q 'actions/checkout' "${FILES[@]}"; check "no checkout" $?
! grep -q 'github\.event' "${FILES[@]}"; check "no event fields in expressions" $?
[ "$(sed -n '/^jobs:/,$p' "${FILES[0]}" | sed -n '/permissions:/,/steps:/p' | grep -c ': ')" = 1 ] \
  && grep -q '^      issues: write$' "${FILES[0]}"; check "issues: write is the only permission" $?

echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
