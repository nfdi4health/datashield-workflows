#!/usr/bin/env bash
# shellcheck disable=SC2034  # history_* are read by determine-changes.sh, which sources this file
# What earlier runs of this workflow reviewed, read from the run history
# (no storage of its own): every review job ends with a notice annotation
# "<kind> <branch> <sha>" (title "bot-suggest review", step "Record
# review"), and every failed Claude call leaves a "Suggestion not made"
# warning annotation with the file. Sourced by determine-changes.sh, after
# checkout. Design: dev-notes/suggestions-trigger-model.md.
#
# Reads KIND (docs, tests), BRANCH, GH_TOKEN, GITHUB_REPOSITORY,
# GITHUB_WORKFLOW_REF (the caller's workflow file, also inside a reusable
# workflow), GITHUB_RUN_ID. Newest successful runs of the caller workflow
# first, up to the last review of BRANCH that is in HEAD's history:
#   history_start   — the commit that review reached (empty: none found);
#   history_run     — that run's id;
#   history_failed.txt — files whose Claude call failed in that run;
#   history_pr.txt  — "<base> <head>" per pull request reviewed since then
#                     (newer PR runs), whose commits count as reviewed.
# Needs `actions: read` and `checks: read`; without them nothing is found,
# with a notice.

history_start=""
history_run=""
: > history_failed.txt
: > history_pr.txt

workflow_file="$(basename "${GITHUB_WORKFLOW_REF%@*}")"
runs="$(gh api "repos/$GITHUB_REPOSITORY/actions/workflows/$workflow_file/runs?status=success&per_page=50" \
  --jq '.workflow_runs[] | [.id, .event, (.pull_requests[0].base.sha // "")] | @tsv' 2>/dev/null)" || {
  # Pushes only use the history to leave out what PR runs reviewed; for
  # scheduled and manual runs it is the starting point, so say why it's missing.
  [ "$GITHUB_EVENT_NAME" = "push" ] || echo "::notice::Can't read this workflow's earlier runs (the calling job needs 'actions: read' and 'checks: read'): starting without them."
  runs=""
}

while IFS=$'\t' read -r run_id run_event pr_base; do
  [ -z "$run_id" ] || [ "$run_id" = "$GITHUB_RUN_ID" ] && continue
  jobs="$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$run_id/jobs" --jq '.jobs[].id' 2>/dev/null || true)"
  notes=""
  failed=""
  for job in $jobs; do
    ann="$(gh api "repos/$GITHUB_REPOSITORY/check-runs/$job/annotations" \
      --jq '.[] | [.title, .path, .message] | @tsv' 2>/dev/null || true)"
    notes="$notes$(printf '%s\n' "$ann" | awk -F'\t' '$1 == "bot-suggest review" {print $3}')"$'\n'
    failed="$failed$(printf '%s\n' "$ann" | awk -F'\t' '$1 == "Suggestion not made" {print $2}')"$'\n'
  done
  review="$(printf '%s\n' "$notes" | awk -v k="$KIND" '$1 == k' | head -1)"
  [ -z "$review" ] && continue   # skipped or another kind of review
  reviewed_branch="$(echo "$review" | awk '{print $2}')"
  reviewed_sha="$(echo "$review" | awk '{print $3}')"
  git cat-file -e "$reviewed_sha^{commit}" 2>/dev/null || continue

  if [ "$run_event" = "pull_request" ]; then
    # A reviewed pull request: its commits between base and reviewed head
    [ -n "$pr_base" ] && git cat-file -e "$pr_base^{commit}" 2>/dev/null && echo "$pr_base $reviewed_sha" >> history_pr.txt
    continue
  fi
  if [ "$reviewed_branch" = "$BRANCH" ] && git merge-base --is-ancestor "$reviewed_sha" HEAD 2>/dev/null; then
    history_start="$reviewed_sha"
    history_run="$run_id"
    printf '%s\n' "$failed" | sed '/^$/d' | sort -u > history_failed.txt
    break
  fi
done <<< "$runs"
