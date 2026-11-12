#!/usr/bin/env bash
# Decides whether a suggestion run does anything, its mode and its branch,
# from the event alone (GITHUB_EVENT_NAME, the event JSON at
# GITHUB_EVENT_PATH, GITHUB_REF, HEAD_REF, REF_NAME, ACTOR) and the inputs
# (REVIEW_SCOPE, REVIEW_BRANCH, ALLOW_SCHEDULED). Writes skip, mode, ref and branch
# to GITHUB_OUTPUT. Called by action.yml.
set -eo pipefail

out() { echo "$1=$2" >> "$GITHUB_OUTPUT"; }
skip() {
  echo "::notice::Nothing to do: $1"
  out skip true
  exit 0
}

event="$GITHUB_EVENT_NAME"
branch="${HEAD_REF:-$REF_NAME}"
field() { jq -r "$1 // empty" "$GITHUB_EVENT_PATH"; }

# --- Runs that should do nothing ---------------------------------------------

case "$branch" in bot-suggest/*) skip "this is the bot's own branch ($branch)." ;; esac
# The implementer (implement-issue.yml) writes documentation and tests in
# its own run; its branches are agent-suggest/<type>/issue-<n>. Other
# agent-suggest/* branches (Claude Code sessions) are reviewed as usual.
case "$branch" in agent-suggest/*/issue-*) skip "the implementer's branch ($branch) brings its own documentation and tests." ;; esac
if [ "$event" = "push" ]; then
  case "$GITHUB_REF" in refs/tags/*) skip "a tag was pushed ($GITHUB_REF)." ;; esac
  [ "$(field '.deleted')" = "true" ] && skip "the branch $branch was deleted."
fi
if [ "$event" = "pull_request" ]; then
  head_repo="$(field '.pull_request.head.repo.full_name')"
  [ -n "$head_repo" ] && [ "$head_repo" != "$GITHUB_REPOSITORY" ] && \
    skip "the pull request comes from a fork ($head_repo), which gets no secrets and can't receive the bot's commits."
  # A draft is work in progress: reviewed once it is marked ready, which callers pass as
  # `ready_for_review` and determine-changes.sh treats like `opened`.
  [ "$(field '.pull_request.draft')" = "true" ] && skip "the pull request is a draft; it is reviewed once it is marked ready."
fi
# A self-test needs no secrets (recorded answers), so it also checks
# Dependabot's updates of the actions.
[ "$ACTOR" = "dependabot[bot]" ] && [ "${SELF_TEST:-false}" != "true" ] && skip "Dependabot runs get no secrets."

# --- Mode ------------------------------------------------------------------------

# Scheduled and manual runs are about a branch other than the event's: the
# one chosen in "Run workflow", dev on schedules (a schedule always starts
# on the default branch), or review-branch.
case "$event" in
  pull_request|push) ;;
  *)
    [ "$ALLOW_SCHEDULED" = "true" ] || skip "this workflow runs on pull requests and pushes only."
    if [ -n "$REVIEW_BRANCH" ]; then branch="$REVIEW_BRANCH"
    elif [ "$event" = "workflow_dispatch" ]; then branch="$REF_NAME"
    else branch="dev"; fi
    ;;
esac

# "changed": what changed since the last review — for a PR or push since the
# last run (determine-changes.sh), for a scheduled or manual run since the
# last review of the branch in the run history. "all": every file.
mode="$REVIEW_SCOPE"
case "$mode" in
  changed)
    out skip false
    out mode changed
    out ref "$branch"
    out branch "$branch"
    ;;
  all)
    [ "$ALLOW_SCHEDULED" = "true" ] || skip "this workflow has no full review; it runs on pull requests and pushes."
    echo "Full review of $branch."
    out skip false
    out mode all
    out ref "$branch"
    out branch "$branch"
    ;;
  *) echo "::error::Unknown review-scope \"$REVIEW_SCOPE\" (changed or all)."; exit 1 ;;
esac
