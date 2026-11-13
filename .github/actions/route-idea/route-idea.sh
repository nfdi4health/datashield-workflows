#!/usr/bin/env bash
# Routes an idea of the hub (e.g. nfdi4health/datashield-function-ideas) to
# a topic package's repository (dev-notes/issue-agents.md, "A central hub"):
# a routing label on a hub issue copies the issue there, with a link back;
# the hub issue stays open as the demand record.
#
#   plan  On `issues: labeled`: is the label a route (ROUTES, lines
#         "label = owner/repo"), set by a login in ALLOWED_LOGINS, and not
#         copied there before? Writes target=owner/repo, owner, repo to
#         GITHUB_OUTPUT, or nothing. A route label set by anyone else is
#         removed, with a comment.
#   copy  Opens the issue in TARGET with TARGET_TOKEN (an App token for
#         that repository), then comments on the hub issue with the link
#         and a hidden marker, and adds ROUTED_LABEL (GH_TOKEN).
#
# Reads the event file; no issue text passes through an expression.
set -euo pipefail

step="${1:?plan or copy}"
event_field() { jq -r "$1 // \"\"" "$GITHUB_EVENT_PATH"; }
number="$(event_field .issue.number)"
lower() { tr '[:upper:]' '[:lower:]' <<< "$1"; }

# The target of a label, from lines "label = owner/repo" (case of the
# label ignored, as GitHub does; blank lines and # comments skipped).
route_target() {
  local line label repo
  while IFS= read -r line; do
    line="${line%%#*}"
    [[ "$line" == *=* ]] || continue
    label="$(sed 's/^ *//; s/ *$//' <<< "${line%%=*}")"
    repo="$(sed 's/^ *//; s/ *$//' <<< "${line#*=}")"
    if [ "$(lower "$label")" = "$(lower "$1")" ]; then
      [[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "Route for $label is not owner/repo: $repo" >&2; exit 1; }
      echo "$repo"
      return 0
    fi
  done <<< "${ROUTES:-}"
}

is_allowed() {
  local logins login
  read -r -a logins <<< "$(tr ',\n' '  ' <<< "$ALLOWED_LOGINS")"
  for login in "${logins[@]}"; do
    [ "$login" = "$1" ] && return 0
  done
  return 1
}

marker() { printf '<!-- routed-to: %s -->' "$1"; }

case "$step" in
  plan)
    [ "$(event_field .action)" = labeled ] || { echo "Not a label being set."; exit 0; }
    label="$(event_field .label.name)"
    target="$(route_target "$label")"
    [ -n "$target" ] || { echo "Not a routing label ($label)."; exit 0; }
    if ! is_allowed "$(event_field .sender.login)"; then
      encoded="$(jq -rn --arg l "$label" '$l | @uri')"
      gh api -X DELETE "repos/$GITHUB_REPOSITORY/issues/$number/labels/$encoded" > /dev/null 2>&1 || true
      gh api "repos/$GITHUB_REPOSITORY/issues/$number/comments" \
        -f body="Removed \`$label\`: only the people named in this repository's workflow may route an idea." > /dev/null
      echo "Route label removed: not an allowed login."
      exit 0
    fi
    if gh api "repos/$GITHUB_REPOSITORY/issues/$number/comments" --paginate --jq '.[].body' | grep -qF "$(marker "$target")"; then
      echo "Already copied to $target."
      exit 0
    fi
    { echo "target=$target"; echo "owner=${target%%/*}"; echo "repo=${target#*/}"; } >> "$GITHUB_OUTPUT"
    echo "Route to $target."
    ;;

  copy)
    : "${TARGET:?}" "${TARGET_TOKEN:?no App token for the target repository}"
    title="$(event_field .issue.title)"
    url="$(event_field .issue.html_url)"
    # Mentions in the copy would notify people a second time: @name loses
    # its effect with a zero-width space after the @.
    body="$(event_field .issue.body | sed 's/@\([A-Za-z0-9]\)/@\xe2\x80\x8b\1/g')"
    copy_body="$(printf 'Copied from %s, the place for missing DataSHIELD functions: votes and discussion stay there.\n\n---\n\n%s\n\n<!-- function-idea: %s#%s -->' \
      "$url" "$body" "$GITHUB_REPOSITORY" "$number")"
    new_url="$(GH_TOKEN="$TARGET_TOKEN" gh api "repos/$TARGET/issues" -f title="$title" -f body="$copy_body" --jq '.html_url')"
    new_ref="$TARGET#${new_url##*/}"
    gh api "repos/$GITHUB_REPOSITORY/issues/$number/comments" \
      -f body="$(printf 'Tracked in %s: work on it happens there.\n\n%s' "$new_ref" "$(marker "$TARGET")")" > /dev/null
    gh api "repos/$GITHUB_REPOSITORY/issues/$number/labels" -f "labels[]=${ROUTED_LABEL:-routed}" > /dev/null
    echo "Copied to $new_url."
    ;;

  *) echo "Unknown step: $step (plan or copy)." >&2; exit 1 ;;
esac
