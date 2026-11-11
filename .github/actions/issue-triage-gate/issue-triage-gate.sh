#!/usr/bin/env bash
# Decides whether an issue gets triaged (dev-notes/issue-agents.md), and
# writes run=true|false and number=<issue> to GITHUB_OUTPUT. Not triaged:
# other events; pull requests; closed issues; issues carrying
# APPROVAL_LABEL; issues written by a bot not listed in TRIAGE_BOTS, and
# `bot-created` issues — except on a person's request (TRIAGE_LABEL).
#
# The first triage runs on `opened` or `edited`. After that, one triage per
# issue, repeated only if someone answers it, and at most MAX_TRIAGES:
#   last verdict                  repeated on
#   needs-info                    an edit, or any person's comment
#   duplicate, spam, out-of-scope a comment or edit by the issue's author,
#                                 who may disagree
#   anything else                 nothing
# Before the first triage, the author's comment counts like an edit: they
# are still writing, so the wait starts again. Anyone else's starts nothing,
# and the triage reads it anyway. An issue carrying SUSPICIOUS_LABEL (text
# tried to steer the bot) gets one triage only: more answers from the same
# author would only give them more tries.
#
# TRIAGE_LABEL set by an exact login in ALLOWED_LOGINS is a person's request:
# it needs no reason and no wait, and works on issues from before triage
# existed, whatever the earlier verdicts and however many. Writes
# request=true then, so the workflow can take the label off again; who else
# sets it is the label check's business.
#
# Earlier triages are the marker comments of format_triage_comment(), and
# only github-actions[bot]'s count: anyone can write the same text in a
# comment, which must not switch triage off.
#
# Reads the event file and the API; needs APPROVAL_LABEL, TRIAGE_LABEL,
# ALLOWED_LOGINS, MAX_TRIAGES, GH_TOKEN and the GITHUB_* variables of the
# runner; SUSPICIOUS_LABEL (default bot-suspicious) and TRIAGE_BOTS (empty:
# no bot's issues) are optional.
set -euo pipefail

skip() {
  echo "No triage: $1."
  echo "run=false" >> "$GITHUB_OUTPUT"
  exit 0
}
event() { jq -r "$1 // \"\"" "$GITHUB_EVENT_PATH"; }
lower() { tr '[:upper:]' '[:lower:]' <<< "$1"; }
is_allowed() {  # exact and case-sensitive, one login at a time, no patterns
  local logins login
  read -r -a logins <<< "$(tr ',\n' '  ' <<< "$ALLOWED_LOGINS")"
  for login in "${logins[@]}"; do
    [ "$login" = "$1" ] && return 0
  done
  return 1
}

action="$(event .action)"
case "${GITHUB_EVENT_NAME:-}/$action" in
  issues/opened|issues/edited) trigger=edit ;;
  issue_comment/created) trigger=comment ;;
  issues/labeled)
    trigger=request
    [ "$(lower "$(event .label.name)")" = "$(lower "$TRIAGE_LABEL")" ] || skip "another label"
    is_allowed "$(event .sender.login)" || skip "the label was set by a login not on the list"
    ;;
  *) skip "not a new or edited issue, a new comment or a triage request" ;;
esac
# issue_comment fires for pull requests too.
[ -z "$(event .issue.pull_request)" ] || skip "a pull request"

number="$(event .issue.number)"
echo "number=$number" >> "$GITHUB_OUTPUT"
if [ "$trigger" = request ]; then
  echo "request=true" >> "$GITHUB_OUTPUT"
fi

if [ "$trigger" = comment ] && [ "$(event .comment.user.type)" = Bot ]; then
  skip "a bot's comment"
fi

issue="$(gh api "repos/$GITHUB_REPOSITORY/issues/$number")"
[ "$(jq -r '.state' <<< "$issue")" = open ] || skip "the issue is closed"
labels_match() {  # labels_match <label>: GitHub treats label names as equal whatever their case
  jq -e --arg label "$1" 'any(.labels[]; (.name | ascii_downcase) == ($label | ascii_downcase))' <<< "$issue" > /dev/null
}
if labels_match "$APPROVAL_LABEL"; then skip "already approved"; fi

# A person's request works on any open issue, also one a bot wrote.
if [ "$trigger" = request ]; then
  echo "Triage requested for issue $number."
  echo "run=true" >> "$GITHUB_OUTPUT"
  exit 0
fi

# Issues by bots: only those listed in TRIAGE_BOTS (exact logins, e.g. the
# App the suggestion bots open their issues with), and none labelled
# bot-created.
if [ "$(jq -r '.user.type' <<< "$issue")" = Bot ]; then
  author="$(jq -r '.user.login' <<< "$issue")"
  listed=false
  read -r -a bots <<< "$(tr ',\n' '  ' <<< "${TRIAGE_BOTS:-}")"
  for bot in "${bots[@]}"; do [ "$bot" = "$author" ] && listed=true; done
  [ "$listed" = true ] || skip "written by a bot not in triage-bots ($author)"
fi
if labels_match bot-created; then skip "a bot-created issue"; fi

# --paginate gives one JSON array per page; a failed read fails the run.
triages="$(gh api --paginate "repos/$GITHUB_REPOSITORY/issues/$number/comments" | jq -rs '
  add // [] | .[]
  | select(.user.login == "github-actions[bot]")
  | .body | capture("^<!-- bot-triage: (?<category>[a-z-]+) -->") | .category')"

if [ -z "$triages" ]; then
  [ "$trigger" = edit ] || [ "$(event .sender.login)" = "$(jq -r '.user.login' <<< "$issue")" ] \
    || skip "no triage yet, the first one reads this comment"
else
  if labels_match "${SUSPICIOUS_LABEL:-bot-suspicious}"; then
    skip "the issue is marked ${SUSPICIOUS_LABEL:-bot-suspicious}: one triage only (a listed login can still ask with the triage label)"
  fi
  case "$trigger/$(tail -n 1 <<< "$triages")" in
    edit/needs-info|comment/needs-info) ;;
    edit/duplicate|edit/spam|edit/out-of-scope|comment/duplicate|comment/spam|comment/out-of-scope)
      actor="$(event .sender.login)"
      [ "$actor" = "$(jq -r '.user.login' <<< "$issue")" ] \
        || skip "only the issue's author can object to this verdict"
      ;;
    *) skip "already triaged" ;;
  esac
  [ "$(wc -l <<< "$triages")" -lt "$MAX_TRIAGES" ] || skip "the most triages for one issue reached"
fi

echo "Issue $number needs triage."
echo "run=true" >> "$GITHUB_OUTPUT"
