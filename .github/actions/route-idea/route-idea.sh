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
#   labels  Creates every route's label in the hub that doesn't exist
#         yet (colour LABEL_COLOR, description "Route to owner/repo");
#         existing labels are left as they are.
#   copy  Opens the issue in TARGET with TARGET_TOKEN (the caller's
#         route-token, or an App token for that repository), then comments on the hub issue with the link
#         and a hidden marker, and adds ROUTED_LABEL (GH_TOKEN).
#   sync  For every hub issue carrying ROUTED_LABEL: how are its copies
#         doing (the "Tracked in owner/repo#n" of the copy step)? Each
#         change since the last check gets one short comment on the hub
#         issue, with a hidden marker of the new state: closed as
#         completed (the hub issue is closed as completed once every copy
#         is), closed otherwise (DECLINED_LABEL; the idea stays open), or
#         reopened (the label goes; a hub issue closed by this step opens
#         again). Reads the copies with GH_TOKEN: public repositories.
#
# Reads the event file; no issue text passes through an expression.
set -euo pipefail

step="${1:?plan, copy or labels}"

# Without ROUTES, the routes come from ROUTES_FILE: a YAML mapping
#   routes:
#     dsSurvival: datashield/dsSurvivalClient   # a comment
# read line by line (no YAML library needed), as "label = owner/repo".
if [ -z "${ROUTES:-}" ] && [ -n "${ROUTES_FILE:-}" ]; then
  [ -f "$ROUTES_FILE" ] || { echo "No routes: $ROUTES_FILE doesn't exist." >&2; exit 1; }
  ROUTES="$(sed -nE 's/^[[:space:]]+([A-Za-z0-9_.-]+):[[:space:]]*([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)[[:space:]]*(#.*)?$/\1 = \2/p' "$ROUTES_FILE")"
fi
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
status_marker() { printf '<!-- route-status: %s %s -->' "$1" "$2"; }

# The last state recorded for a copy in a hub issue's comments (open
# when none is recorded yet).
last_status() {
  local found
  found="$(grep -F "<!-- route-status: $2 " <<< "$1" | tail -n 1 | sed -E 's/.*route-status: [^ ]+ ([a-z-]+) -->.*/\1/')"
  echo "${found:-open}"
}

case "$step" in
  labels)
    existing="$(gh api --paginate "repos/$GITHUB_REPOSITORY/labels?per_page=100" --jq '.[].name' | tr '[:upper:]' '[:lower:]')"
    while IFS= read -r line; do
      line="${line%%#*}"
      [[ "$line" == *=* ]] || continue
      label="$(sed 's/^ *//; s/ *$//' <<< "${line%%=*}")"
      repo="$(sed 's/^ *//; s/ *$//' <<< "${line#*=}")"
      if grep -qxF "$(lower "$label")" <<< "$existing"; then continue; fi
      gh api "repos/$GITHUB_REPOSITORY/labels" -f name="$label" -f color="${LABEL_COLOR:-1d76db}" \
        -f description="Route to $repo" > /dev/null
      echo "Created the label $label."
    done <<< "${ROUTES:-}"
    ;;
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
    : "${TARGET:?}" "${TARGET_TOKEN:?no token for the target repository (route-token or the App)}"
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

  sync)
    routed="${ROUTED_LABEL:-routed}"
    declined="${DECLINED_LABEL:-declined}"
    gh api --paginate "repos/$GITHUB_REPOSITORY/issues?state=all&per_page=100&labels=$(jq -rn --arg l "$routed" '$l | @uri')" \
      --jq '.[] | select(.pull_request == null) | "\(.number) \(.state) \(.state_reason // "")"' > "${RUNNER_TEMP:-/tmp}/routed.txt"
    while read -r n hub_state hub_reason; do
      [ -n "$n" ] || continue
      if ! comments="$(gh api --paginate "repos/$GITHUB_REPOSITORY/issues/$n/comments?per_page=100" --jq '.[].body')"; then
        echo "::warning::Could not read the comments of hub issue #$n; it is checked again next time."
        continue
      fi
      copies="$(grep -oE 'Tracked in [A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+' <<< "$comments" | sed 's/^Tracked in //' | sort -u || true)"
      [ -n "$copies" ] || continue
      all_done=1
      reopened=0
      lines=""
      markers=""
      for c in $copies; do
        if ! info="$(gh api "repos/${c%#*}/issues/${c##*#}" --jq '"\(.state) \(.state_reason // "")"' 2>/dev/null)"; then
          echo "::warning::Could not read $c (hub issue #$n)."
          all_done=0
          continue
        fi
        case "$info" in
          open*) now=open ;;
          "closed completed") now=completed ;;
          "closed duplicate") now=duplicate ;;
          *) now=not-planned ;;
        esac
        [ "$now" = completed ] || all_done=0
        last="$(last_status "$comments" "$c")"
        [ "$now" = "$last" ] && continue
        case "$now" in
          completed) lines+="Done: $c was closed as completed. Thank you to everyone who asked for it; follow-ups belong there."$'\n' ;;
          not-planned) lines+="$c was closed there as not planned. This idea stays open here: it can keep collecting 👍 or be routed to another package."$'\n' ;;
          duplicate) lines+="$c was closed there as a duplicate of another issue in that repository. This idea stays open here until that work is done."$'\n' ;;
          open) lines+="$c was reopened; the work continues there."$'\n'; reopened=1 ;;
        esac
        markers+="$(status_marker "$c" "$now")"$'\n'
        if [ "$now" = not-planned ] || [ "$now" = duplicate ]; then
          gh api "repos/$GITHUB_REPOSITORY/issues/$n/labels" -f "labels[]=$declined" > /dev/null
        elif [ "$last" = not-planned ] || [ "$last" = duplicate ]; then
          gh api -X DELETE "repos/$GITHUB_REPOSITORY/issues/$n/labels/$(jq -rn --arg l "$declined" '$l | @uri')" > /dev/null 2>&1 || true
        fi
        echo "Hub issue #$n: $c is now $now (was $last)."
      done
      close=0
      # Closed only in the run that sees the last copy done, so a hub issue
      # reopened by hand afterwards stays open.
      if [ "$all_done" = 1 ] && [ "$hub_state" = open ] && [ -n "$lines" ]; then
        close=1
        lines+="This idea is closed here with it."$'\n'
      fi
      # One short comment per hub issue and run, only when something changed.
      if [ -n "$lines" ]; then
        gh api "repos/$GITHUB_REPOSITORY/issues/$n/comments" -f body="$(printf '%s\n%s' "$lines" "$markers")" > /dev/null
      fi
      if [ "$close" = 1 ]; then
        gh api -X PATCH "repos/$GITHUB_REPOSITORY/issues/$n" -f state=closed -f state_reason=completed > /dev/null
        echo "Hub issue #$n closed as completed."
      elif [ "$reopened" = 1 ] && [ "$hub_state" = closed ] && [ "$hub_reason" = completed ]; then
        gh api -X PATCH "repos/$GITHUB_REPOSITORY/issues/$n" -f state=open > /dev/null
        echo "Hub issue #$n reopened."
      fi
    done < "${RUNNER_TEMP:-/tmp}/routed.txt"
    ;;

  *) echo "Unknown step: $step (plan, copy, labels or sync)." >&2; exit 1 ;;
esac
