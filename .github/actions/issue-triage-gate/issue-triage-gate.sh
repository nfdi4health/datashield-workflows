#!/usr/bin/env bash
# Decides whether an issue gets triaged (dev-notes/issue-agents.md), and
# writes run=true|false and number=<issue> to GITHUB_OUTPUT. Not triaged:
# other events; pull requests; closed issues; issues written by a bot;
# `bot-created` issues; issues carrying APPROVAL_LABEL.
#
# The first triage runs on `opened` or `edited`. After that, one triage per
# issue, repeated only if someone answers it, and at most MAX_TRIAGES:
#   last verdict                  repeated on
#   needs-info                    an edit, or any person's comment
#   duplicate, spam, out-of-scope a comment or edit by the issue's author,
#                                 who may disagree
#   anything else                 nothing
# A comment before the first triage starts nothing: that triage reads it.
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
# runner.
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
[ "$(jq -r '.user.type' <<< "$issue")" != Bot ] || skip "written by a bot"
labels_match() {  # labels_match <label>: GitHub treats label names as equal whatever their case
  jq -e --arg label "$1" 'any(.labels[]; (.name | ascii_downcase) == ($label | ascii_downcase))' <<< "$issue" > /dev/null
}
if labels_match bot-created; then skip "a bot-created issue"; fi
if labels_match "$APPROVAL_LABEL"; then skip "already approved"; fi

if [ "$trigger" = request ]; then
  echo "Triage requested for issue $number."
  echo "run=true" >> "$GITHUB_OUTPUT"
  exit 0
fi

# --paginate gives one JSON array per page; a failed read fails the run.
triages="$(gh api --paginate "repos/$GITHUB_REPOSITORY/issues/$number/comments" | jq -rs '
  add // [] | .[]
  | select(.user.login == "github-actions[bot]")
  | .body | capture("^<!-- bot-triage: (?<category>[a-z-]+) -->") | .category')"

if [ -z "$triages" ]; then
  [ "$trigger" = edit ] || skip "no triage yet, the first one reads this comment"
else
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
