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

issue() {  # issue [state] [user type] [labels as a JSON array of names] [author login]
  jq -n --arg state "${1:-open}" --arg type "${2:-User}" --argjson labels "${3:-[]}" --arg login "${4:-author}" \
    '{state: $state, user: {type: $type, login: $login}, title: "$(touch pwned)", labels: ($labels | map({name: .}))}' > "$WORK/issue.json"
}
bot_triage() {  # bot_triage <category> [open]: a page with the bot's comment for it; "open": its spec has open questions
  local marker=""
  [ "${2:-}" = open ] && marker='\\n<!-- bot-triage-open-questions -->'
  printf '[{"user": {"login": "github-actions[bot]"}, "body": "<!-- bot-triage: %s -->\\n**Triage**%s"}]\n' "$1" "$marker"
}
# gate [action]; EVENT_NAME overrides `issues`, COMMENTER and COMMENTER_TYPE
# the comment's author, IS_PR makes it a pull request, LABEL and SENDER the
# label that was set and who set it.
gate() {
  : > "$WORK/out.txt"
  jq -n --arg action "${1:-opened}" --arg who "${COMMENTER:-someone}" --arg type "${COMMENTER_TYPE:-User}" --arg pr "${IS_PR:-}" \
    --arg label "${LABEL:-bug}" --arg sender "${SENDER:-someone}" \
    '{action: $action, issue: ({number: 7} + (if $pr == "" then {} else {pull_request: {url: "x"}} end)),
      comment: {user: {login: $who, type: $type}}, label: {name: $label}, sender: {login: $sender}}' > "$WORK/event.json"
  (cd "$WORK" && PATH="$BIN:$PATH" GITHUB_EVENT_NAME="${EVENT_NAME:-issues}" GITHUB_EVENT_PATH="$WORK/event.json" \
    GITHUB_OUTPUT="$WORK/out.txt" GITHUB_REPOSITORY=me/pkg APPROVAL_LABEL=bot-proceed MAX_TRIAGES=3 \
    TRIAGE_LABEL=bot-triage ALLOWED_LOGINS="${ALLOWED-FlorianSchw}" TRIAGE_BOTS="${BOTS:-}" \
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

# --- comments ----------------------------------------------------------------

comment() { EVENT_NAME=issue_comment gate "${1:-created}"; }

echo '[]' > "$WORK/comments.json"
comment; skips; check "someone's comment before the first triage: nothing, it reads it" $?
SENDER=author COMMENTER=author comment; runs; check "the author's comment before the first triage restarts the wait" $?
! grep -qx 'request=true' "$WORK/out.txt"; check "that is no request: the wait applies" $?
SENDER=author COMMENTER=author COMMENTER_TYPE=Bot comment; skips; check "a bot author's comment does not" $?
bot_triage needs-info > "$WORK/comments.json"
comment; runs; check "needs-info: any person's comment" $?
COMMENTER=author comment; runs; check "needs-info: the author's comment" $?
COMMENTER_TYPE=Bot COMMENTER='github-actions[bot]' comment; skips; check "needs-info: a bot's comment does not count" $?
comment edited; skips; check "an edited comment is no new answer" $?
IS_PR=1 comment; skips; check "a comment on a pull request: no triage" $?

for verdict in duplicate spam out-of-scope; do
  bot_triage "$verdict" > "$WORK/comments.json"
  SENDER=author COMMENTER=author comment; runs; check "$verdict: the author can object" $?
  SENDER=someone comment; skips; check "$verdict: someone else cannot" $?
  SENDER=author gate edited; runs; check "$verdict: the author's edit counts too" $?
  SENDER=someone gate edited; skips; check "$verdict: someone else's edit does not" $?
done

for verdict in bug idea question; do
  bot_triage "$verdict" > "$WORK/comments.json"
  COMMENTER=author comment; skips; check "$verdict: a comment starts nothing" $?
done

for verdict in duplicate spam out-of-scope; do
  bot_triage "$verdict" > "$WORK/comments.json"
  SENDER=FlorianSchw COMMENTER=FlorianSchw comment; runs; check "$verdict: a maintainer's comment can object" $?
done

# A spec with open questions: the author's or a maintainer's answer.
bot_triage bug open > "$WORK/comments.json"
SENDER=author COMMENTER=author comment; runs; check "open questions: the author's answer" $?
SENDER=FlorianSchw COMMENTER=FlorianSchw comment; runs; check "open questions: a maintainer's answer" $?
SENDER=someone comment; skips; check "open questions: someone else's comment starts nothing" $?
SENDER=author gate edited; skips; check "open questions: an edit starts nothing" $?
{ bot_triage needs-info; bot_triage needs-info; bot_triage idea open; } > "$WORK/comments.json"
SENDER=author COMMENTER=author comment; runs; check "open questions: one answer beyond the most triages" $?
{ bot_triage needs-info; bot_triage idea open; bot_triage idea open; } > "$WORK/comments.json"
SENDER=author COMMENTER=author comment; skips; check "open questions again: the limit applies" $?

{ bot_triage needs-info; bot_triage duplicate; bot_triage duplicate; } > "$WORK/comments.json"
COMMENTER=author comment; skips; check "the most triages reached: an objection starts nothing" $?
issue open User '["bot-proceed"]'
bot_triage needs-info > "$WORK/comments.json"
comment; skips; check "approved: a comment starts nothing" $?
issue

# --- a request by label --------------------------------------------------------

request() { LABEL="${1:-bot-triage}" SENDER="${2:-FlorianSchw}" gate labeled; }
requested() { grep -qx 'request=true' "$WORK/out.txt"; }

echo '[]' > "$WORK/comments.json"
request; runs && requested; check "request: an old issue gets its first triage" $?
{ bot_triage bug; } > "$WORK/comments.json"
request; runs; check "request: repeats a finished triage" $?
{ bot_triage needs-info; bot_triage needs-info; bot_triage duplicate; } > "$WORK/comments.json"
request; runs; check "request: not limited by the most triages" $?
request Bot-Triage; runs; check "request: the label in another case" $?
request bot-triage florianschw; skips; check "request: exact login only" $?
request bot-triage someone; skips && ! requested; check "request: another login, nothing to clean up" $?
request bug FlorianSchw; skips; check "request: another label is none" $?
gate edited; ! requested; check "an edit is no request" $?
issue closed; request; skips && requested; check "request on a closed issue: no triage, the label still goes" $?
issue open User '["bot-proceed"]'; request; skips && requested; check "request on an approved issue: no triage, the label still goes" $?
issue
echo '[]' > "$WORK/comments.json"

# No allowed-logins (the input's default): nobody can ask by label, and the
# triage of new issues works as before.
ALLOWED='' request; skips && ! requested; check "no allowed logins: no request, also not the listed one" $?
ALLOWED='' gate opened; runs; check "no allowed logins: a new issue is still triaged" $?

# --- failures ----------------------------------------------------------------

echo '[]' > "$WORK/comments.json"
echo 'gh: Server Error (HTTP 502)' > "$WORK/read-error"
gate edited; status=$?
[ "$status" != 0 ] && ! runs; check "issue not readable: the run fails" $?
: > "$WORK/read-error"

# --- marked bot-suspicious: one triage only ------------------------------------

issue open User '["bot-suspicious"]'
echo '[]' > "$WORK/comments.json"
gate opened; runs; check "suspicious, no triage yet: triaged once" $?
bot_triage needs-info > "$WORK/comments.json"
gate edited; skips; check "suspicious after a triage: an edit starts none" $?
SENDER=author COMMENTER=author comment; skips; check "suspicious after a triage: the author's comment starts none" $?
issue open User '["Bot-Suspicious"]'
gate edited; skips; check "suspicious in another case: none either" $?
LABEL=bot-triage SENDER=FlorianSchw gate labeled; runs; check "suspicious: a listed login can still ask by label" $?
issue
echo '[]' > "$WORK/comments.json"

# --- issues by bots ---------------------------------------------------------------

echo '[]' > "$WORK/comments.json"
issue open Bot '[]' 'app[bot]'
BOTS='app[bot]' gate opened; runs; check "a listed bot's new issue: triaged" $?
BOTS='other[bot], app[bot]' gate opened; runs; check "a listed bot among several: triaged" $?
gate opened; skips; check "a bot not listed: no triage" $?
BOTS='App[bot]' gate opened; skips; check "bot logins are compared exactly" $?
issue open Bot '["bot-created"]' 'app[bot]'
BOTS='app[bot]' gate opened; skips; check "a listed bot's issue labelled bot-created: no triage" $?
issue open Bot '[]' 'app[bot]'
LABEL=bot-triage SENDER=FlorianSchw gate labeled; runs; check "a request works on an unlisted bot's issue" $?
issue open Bot '["bot-created"]' 'app[bot]'
LABEL=bot-triage SENDER=FlorianSchw gate labeled; runs; check "a request works on a bot-created issue" $?
issue closed Bot '[]' 'app[bot]'
LABEL=bot-triage SENDER=FlorianSchw gate labeled; skips; check "a request on a closed issue: no triage" $?
issue open Bot '["bot-proceed"]' 'app[bot]'
LABEL=bot-triage SENDER=FlorianSchw gate labeled; skips; check "a request on an approved issue: no triage" $?
issue

echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
