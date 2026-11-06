#!/usr/bin/env bash
# Keeps the approval label of the issue flow honest (dev-notes/issue-agents.md):
#   labeled: the label set by anyone not in ALLOWED_LOGINS is removed;
#   edited:  the label is removed from an issue whose title or body changed.
# OTHER_LABELS (optional, separated by commas) get the first rule only: they
# ask for something once, and no edit changes who asked.
# Every other event does nothing, so removing the label cannot start a
# loop: `unlabeled` is ignored, and neither a removal nor a comment is an
# edit. A run that finds the label already gone stays silent, which keeps
# it to one comment when two events arrive together.
#
# Reads the event file; needs LABEL, ALLOWED_LOGINS, GH_TOKEN and the
# GITHUB_* variables of the runner; OTHER_LABELS is optional.
set -euo pipefail

: "${LABEL:?the label input is empty}"

if [ "${GITHUB_EVENT_NAME:-}" != issues ]; then
  echo "Not an issue event, nothing to check."
  exit 0
fi

event_field() { jq -r "$1 // \"\"" "$GITHUB_EVENT_PATH"; }
number="$(event_field .issue.number)"

# GitHub treats label names as equal whatever their case, and so does `==`
# in workflow expressions: `Bot-Proceed` has to count here too.
same_label() {
  [ "$(tr '[:upper:]' '[:lower:]' <<< "$1")" = "$(tr '[:upper:]' '[:lower:]' <<< "$2")" ]
}
is_approval_label() { same_label "$1" "$LABEL"; }
is_guarded_label() {
  local other
  is_approval_label "$1" && return 0
  while IFS= read -r other; do
    other="$(sed 's/^ *//; s/ *$//' <<< "$other")"
    [ -n "$other" ] && same_label "$1" "$other" && return 0
  done < <(tr ',' '\n' <<< "${OTHER_LABELS:-}")
  return 1
}

# Exact, case-sensitive comparison, one login at a time: no patterns (bot
# logins contain brackets), no access level. `read` rather than an
# unquoted expansion, so the list is never expanded as file names.
is_allowed() {
  local logins login
  read -r -a logins <<< "$(tr ',\n' '  ' <<< "$ALLOWED_LOGINS")"
  for login in "${logins[@]}"; do
    [ "$login" = "$1" ] && return 0
  done
  return 1
}

# remove_label <name> <comment>: the comment only follows a real removal.
remove_label() {
  local encoded output
  encoded="$(jq -rn --arg label "$1" '$label | @uri')"
  if ! output="$(gh api -X DELETE "repos/$GITHUB_REPOSITORY/issues/$number/labels/$encoded" 2>&1)"; then
    case "$output" in
      *"HTTP 404"*) echo "The label is already gone."; return 0 ;;
      *) echo "$output" >&2; exit 1 ;;
    esac
  fi
  gh api "repos/$GITHUB_REPOSITORY/issues/$number/comments" -f body="$2" > /dev/null
  echo "Label removed from issue $number."
}

case "$(event_field .action)" in
  labeled)
    name="$(event_field .label.name)"
    if ! is_guarded_label "$name"; then
      echo "Another label, nothing to check."
    elif is_allowed "$(event_field .sender.login)"; then
      echo "Set by an allowed login."
    else
      remove_label "$name" "Removed \`$name\`: only the people named in this repository's workflow may set this label."
    fi
    ;;
  edited)
    # The labels as they are now, not as the event lists them: this also
    # catches a label set while the edit was on its way. Worst case, an
    # approval right after one's own edit has to be repeated.
    # A failed read fails the run: it must not pass for "no label".
    labels="$(gh api --paginate "repos/$GITHUB_REPOSITORY/issues/$number/labels" --jq '.[].name')"
    name=""
    while IFS= read -r candidate; do
      if is_approval_label "$candidate"; then name="$candidate"; fi
    done <<< "$labels"
    if [ -n "$name" ]; then
      remove_label "$name" "Removed \`$name\`: the title or body changed, so this issue needs approving again."
    else
      echo "The issue does not carry the label."
    fi
    ;;
  *)
    echo "Nothing to check for this action."
    ;;
esac
