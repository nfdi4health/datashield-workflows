#!/usr/bin/env bash
# Closes issues with the release that ships their fix, not with the merge
# into dev (dev-notes/implementer-plan.md, "Closing issues"). STEP is one of:
#
#   mark  A pull request merged into BRANCH: the issues its description
#         or commit messages close (Closes/Fixes/Resolves #n, which GitHub
#         ignores outside the default branch) get NEXT_LABEL and one comment.
#         A mere mention (Refs #n) doesn't count: that is how unfinished
#         work stays open.
#   link  The release pull request (dev into the default branch), before it
#         is merged: a marked block in its description lists `Closes #n` for
#         every issue with NEXT_LABEL, so merging it closes them. Open ones,
#         and those already closed by hand as completed (their fix ships with
#         this release too; the keyword does nothing for them); not those
#         closed as not planned. Replaced on each run; removed when there are
#         none, which is no failure: a release without issues goes ahead.
#         Removing NEXT_LABEL by hand takes an issue out of the release.
#   swap  After the release pull request was merged: the issues of that block
#         lose NEXT_LABEL and get RELEASED_LABEL.
#
# Only issues of this repository, never pull requests. Reads the event file
# and the API, so no text of a pull request or issue is written into a
# script. Needs STEP, NEXT_LABEL, RELEASED_LABEL, BRANCH, GH_TOKEN and
# the GITHUB_* variables of the runner.
set -euo pipefail

: "${STEP:?the step input is empty}"
: "${NEXT_LABEL:?the next-label input is empty}"
: "${RELEASED_LABEL:?the released-label input is empty}"

BLOCK_START="<!-- release-issues: closed by this release -->"
BLOCK_END="<!-- /release-issues -->"

event_field() { jq -r "$1 // \"\"" "$GITHUB_EVENT_PATH"; }
pr="$(event_field .pull_request.number)"
[ -n "$pr" ] || { echo "Not a pull request event, nothing to do."; exit 0; }

# Issue numbers that closing keywords name in the text on stdin, as GitHub
# reads them: close(s|d), fix(es|ed), resolve(s|d), an optional colon, then
# #n or owner/repo#n of this repository (any case). One per line, sorted.
closing_numbers() {
  local repo_pattern
  repo_pattern="$(sed 's/[][\.*^$/]/\\&/g' <<< "$GITHUB_REPOSITORY")"
  # Each grep finds nothing for text without closing keywords, which is no
  # error: with pipefail it would end the script.
  { grep -oiE "\\b(close[sd]?|fix(e[sd])?|resolve[sd]?):?[[:space:]]+(${repo_pattern})?#[0-9]+\\b" || true; } \
    | { grep -oE '[0-9]+$' || true; } | sort -un
}

# is_open_issue <n>: an open issue, not a pull request, of this repository.
is_open_issue() {
  local issue
  issue="$(gh api "repos/$GITHUB_REPOSITORY/issues/$1" 2>/dev/null)" || return 1
  [ "$(jq -r '.pull_request == null and .state == "open"' <<< "$issue")" = true ]
}

has_label() {  # has_label <n> <label>, ignoring case as GitHub does
  gh api "repos/$GITHUB_REPOSITORY/issues/$1/labels" --paginate --jq '.[].name' \
    | tr '[:upper:]' '[:lower:]' | grep -qxF -- "$(tr '[:upper:]' '[:lower:]' <<< "$2")"
}

add_label() { gh api -X POST "repos/$GITHUB_REPOSITORY/issues/$1/labels" -f "labels[]=$2" > /dev/null; }

remove_label() {  # a label that is already gone is fine
  local encoded output
  encoded="$(jq -rn --arg label "$2" '$label | @uri')"
  if ! output="$(gh api -X DELETE "repos/$GITHUB_REPOSITORY/issues/$1/labels/$encoded" 2>&1)"; then
    case "$output" in
      *"HTTP 404"*) ;;
      *) echo "$output" >&2; return 1 ;;
    esac
  fi
}

# The current description (not the event's: an earlier run may have changed it).
pr_body() { gh api "repos/$GITHUB_REPOSITORY/pulls/$pr" --jq '.body // ""'; }

# The description without our block.
strip_block() {
  awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

case "$STEP" in
  mark)
    [ "$(event_field .pull_request.merged)" = true ] || { echo "Not merged, nothing to mark."; exit 0; }
    base="$(event_field .pull_request.base.ref)"
    [ "$base" = "${BRANCH:-dev}" ] || { echo "Merged into $base, not ${BRANCH:-dev}: nothing to mark."; exit 0; }
    numbers="$( { event_field .pull_request.body
                  gh api "repos/$GITHUB_REPOSITORY/pulls/$pr/commits" --paginate --jq '.[].commit.message'; } | closing_numbers)"
    [ -n "$numbers" ] || { echo "No issue to close in #$pr."; exit 0; }
    while IFS= read -r n; do
      if ! is_open_issue "$n"; then
        echo "#$n is no open issue of this repository: skipped."
        continue
      fi
      if has_label "$n" "$NEXT_LABEL"; then
        echo "#$n already carries $NEXT_LABEL."
        continue
      fi
      add_label "$n" "$NEXT_LABEL"
      gh api -X POST "repos/$GITHUB_REPOSITORY/issues/$n/comments" \
        -f body="Merged into \`${BRANCH:-dev}\` with #$pr. This issue will be closed by the next release." > /dev/null
      echo "#$n: $NEXT_LABEL."
    done <<< "$numbers"
    ;;

  link)
    numbers="$(gh api "repos/$GITHUB_REPOSITORY/issues?state=all&labels=$(jq -rn --arg l "$NEXT_LABEL" '$l | @uri')&per_page=100" \
      --paginate --jq '.[] | select(.pull_request == null)
        | select(.state == "open" or .state_reason == "completed") | .number' | sort -un)"
    body="$(pr_body | strip_block)"
    if [ -n "$numbers" ]; then
      block="$(printf '%s\n' "$BLOCK_START"; while IFS= read -r n; do printf 'Closes #%s\n' "$n"; done <<< "$numbers"; printf '%s' "$BLOCK_END")"
      body="$(printf '%s\n\n%s' "$body" "$block")"
      echo "Release #$pr closes: $(tr '\n' ' ' <<< "$numbers")"
    else
      echo "No issue carries $NEXT_LABEL."
    fi
    gh api -X PATCH "repos/$GITHUB_REPOSITORY/pulls/$pr" -f body="$body" > /dev/null
    ;;

  swap)
    numbers="$(pr_body | awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
      $0 == start { inside = 1; next } $0 == end { inside = 0 } inside' | closing_numbers)"
    [ -n "$numbers" ] || { echo "Release #$pr closed no issue."; exit 0; }
    while IFS= read -r n; do
      remove_label "$n" "$NEXT_LABEL"
      add_label "$n" "$RELEASED_LABEL"
      echo "#$n: $RELEASED_LABEL."
    done <<< "$numbers"
    ;;

  *)
    echo "Unknown step: $STEP (mark, link or swap)." >&2
    exit 1
    ;;
esac
