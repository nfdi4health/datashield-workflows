#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2319  # $(...) in single quotes is meant
# literally; `[ ... ]; check ... $?` is the style of this file
# Tests for .github/actions/issue-triage-gate/, with a stand-in for `gh`.
# Needs jq.
#   bash tests/shell/test-triage-gate.sh
# Prints one line per test and exits non-zero if any failed.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACTION="$ROOT/.github/actions/issue-triage-gate"
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

# gh: the issue from $WORK/issue.json, its comments from $WORK/comments.json
# (one array per page); a read fails if $WORK/read-error has text.
cat > "$BIN/gh" <<STANDIN
#!/usr/bin/env bash
[ ! -s "$WORK/read-error" ] || { cat "$WORK/read-error" >&2; exit 1; }
case "\$*" in
  *"/comments"*) cat "$WORK/comments.json" ;;
  *) cat "$WORK/issue.json" ;;
esac
STANDIN
chmod +x "$BIN/gh"

issue() {  # issue [state] [user type] [labels as a JSON array of names]
  jq -n --arg state "${1:-open}" --arg type "${2:-User}" --argjson labels "${3:-[]}" \
    '{state: $state, user: {type: $type}, title: "$(touch pwned)", labels: ($labels | map({name: .}))}' > "$WORK/issue.json"
}
bot_triage() {  # bot_triage <category>: a page with the bot's comment for it
  printf '[{"user": {"login": "github-actions[bot]"}, "body": "<!-- bot-triage: %s -->\\n**Triage**"}]\n' "$1"
}
gate() {  # gate [action]; EVENT_NAME overrides `issues`
  : > "$WORK/out.txt"
  jq -n --arg action "${1:-opened}" '{action: $action, issue: {number: 7}}' > "$WORK/event.json"
  (cd "$WORK" && PATH="$BIN:$PATH" GITHUB_EVENT_NAME="${EVENT_NAME:-issues}" GITHUB_EVENT_PATH="$WORK/event.json" \
    GITHUB_OUTPUT="$WORK/out.txt" GITHUB_REPOSITORY=me/pkg APPROVAL_LABEL=bot-proceed MAX_TRIAGES=3 \
    bash "$ACTION/issue-triage-gate.sh" > "$WORK/log.txt" 2>&1)
}
runs()  { grep -qx 'run=true' "$WORK/out.txt"; }
skips() { grep -qx 'run=false' "$WORK/out.txt"; }

issue
echo '[]' > "$WORK/comments.json"
: > "$WORK/read-error"

# --- new issues --------------------------------------------------------------

gate opened; runs; check "new issue: triaged" $?
grep -qx 'number=7' "$WORK/out.txt"; check "the number is passed on" $?
gate edited; runs; check "edited before any triage: triaged" $?
[ ! -e "$WORK/pwned" ]; check "issue text is not run as code" $?

# --- what is left alone ------------------------------------------------------

gate labeled; skips; check "another action: no triage" $?
EVENT_NAME=pull_request gate opened; skips; check "another event: no triage" $?
issue closed; gate edited; skips; check "closed issue: no triage" $?
issue open Bot; gate opened; skips; check "written by a bot: no triage" $?
issue open User '["bot-created"]'; gate opened; skips; check "bot-created: no triage" $?
issue open User '["bot-proceed"]'; gate edited; skips; check "approved: no triage" $?
issue open User '["Bot-Proceed"]'; gate edited; skips; check "approved, other case: no triage" $?
issue open User '["bug"]'; gate opened; runs; check "another label: triaged" $?
issue

# --- one triage per issue ----------------------------------------------------

bot_triage bug > "$WORK/comments.json"
gate edited; skips; check "already triaged: no second triage" $?
bot_triage needs-info > "$WORK/comments.json"
gate edited; runs; check "the bot asked for more: triaged again" $?
{ bot_triage needs-info; bot_triage idea; } > "$WORK/comments.json"
gate edited; skips; check "two pages, the last one finished: no triage" $?
{ bot_triage idea; bot_triage needs-info; } > "$WORK/comments.json"
gate edited; runs; check "two pages, the last one asks for more: triaged" $?
{ bot_triage needs-info; bot_triage needs-info; bot_triage needs-info; } > "$WORK/comments.json"
gate edited; skips; check "the most triages reached: no triage" $?

printf '[{"user": {"login": "someone"}, "body": "<!-- bot-triage: bug -->"}]\n' > "$WORK/comments.json"
gate opened; runs; check "a person's copy of the marker does not count" $?
printf '[{"user": {"login": "github-actions[bot]"}, "body": "Removed `bot-proceed`: the title changed."}]\n' > "$WORK/comments.json"
gate edited; runs; check "the label check's comment is no triage" $?

# --- failures ----------------------------------------------------------------

echo '[]' > "$WORK/comments.json"
echo 'gh: Server Error (HTTP 502)' > "$WORK/read-error"
gate edited; status=$?
[ "$status" != 0 ] && ! runs; check "issue not readable: the run fails" $?
: > "$WORK/read-error"

echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
