#!/usr/bin/env bash
# Decides whether an issue gets triaged (dev-notes/issue-agents.md), and
# writes run=true|false and number=<issue> to GITHUB_OUTPUT. Not triaged:
# other events; closed issues; issues written by a bot; `bot-created`
# issues; issues carrying APPROVAL_LABEL. One triage per issue: an earlier
# triage ends it, unless it asked for more information (needs-info) and
# fewer than MAX_TRIAGES were made.
#
# Earlier triages are the marker comments of format_triage_comment(), and
# only github-actions[bot]'s count: anyone can write the same text in a
# comment, which must not switch triage off.
#
# Reads the event file and the API; needs APPROVAL_LABEL, MAX_TRIAGES,
# GH_TOKEN and the GITHUB_* variables of the runner.
set -euo pipefail

skip() {
  echo "No triage: $1."
  echo "run=false" >> "$GITHUB_OUTPUT"
  exit 0
}

[ "${GITHUB_EVENT_NAME:-}" = issues ] || skip "not an issue event"
case "$(jq -r '.action // ""' "$GITHUB_EVENT_PATH")" in
  opened|edited) ;;
  *) skip "another action" ;;
esac

number="$(jq -r '.issue.number' "$GITHUB_EVENT_PATH")"
echo "number=$number" >> "$GITHUB_OUTPUT"

issue="$(gh api "repos/$GITHUB_REPOSITORY/issues/$number")"
[ "$(jq -r '.state' <<< "$issue")" = open ] || skip "the issue is closed"
[ "$(jq -r '.user.type' <<< "$issue")" != Bot ] || skip "written by a bot"
labels_match() {  # labels_match <label>: GitHub treats label names as equal whatever their case
  jq -e --arg label "$1" 'any(.labels[]; (.name | ascii_downcase) == ($label | ascii_downcase))' <<< "$issue" > /dev/null
}
if labels_match bot-created; then skip "a bot-created issue"; fi
if labels_match "$APPROVAL_LABEL"; then skip "already approved"; fi

# --paginate gives one JSON array per page; a failed read fails the run.
triages="$(gh api --paginate "repos/$GITHUB_REPOSITORY/issues/$number/comments" | jq -rs '
  add // [] | .[]
  | select(.user.login == "github-actions[bot]")
  | .body | capture("^<!-- bot-triage: (?<category>[a-z-]+) -->") | .category')"

if [ -n "$triages" ]; then
  [ "$(tail -n 1 <<< "$triages")" = needs-info ] || skip "already triaged"
  [ "$(wc -l <<< "$triages")" -lt "$MAX_TRIAGES" ] || skip "the most triages for one issue reached"
fi

echo "Issue $number needs triage."
echo "run=true" >> "$GITHUB_OUTPUT"
