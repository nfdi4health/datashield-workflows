#!/usr/bin/env bash
# Counts this run by downloading one file from the usage-counter release:
# <workflow>-<outcome>-<channel>. Called by action.yml; never fails the run.
#   outcome: failed   — the job failed or was cancelled;
#            proposed — the run wrote files for the suggestion PR
#                       (updated_files.txt, the commit step's manifest);
#            nothing  — otherwise.
#   channel: release  — a vX tag of this repository points to the commit
#                       this run used: the runner keeps this action in a
#                       folder named after that commit (as shared-files
#                       reads it);
#            dev      — otherwise: @main or a branch, i.e. development and
#                       testing.
# Both lookups only read public data from GitHub; nothing about the calling
# repository is sent. Design: dev-notes/usage-counting.md.
repo_url="https://github.com/nfdi4health/datashield-workflows"

outcome="nothing"
if [ "$JOB_STATUS" = "failure" ] || [ "$JOB_STATUS" = "cancelled" ]; then
  outcome="failed"
elif [ -s "${GITHUB_WORKSPACE:-.}/updated_files.txt" ]; then
  outcome="proposed"
fi

WORKFLOW_SHA="$(basename "$(cd "$GITHUB_ACTION_PATH/../../.." && pwd)")"
if ! [[ "$WORKFLOW_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  WORKFLOW_SHA=""
fi

channel="dev"
# Lightweight tags list the commit, annotated ones also the peeled commit
# (^{}); either way the first column holds it.
if [ -n "$WORKFLOW_SHA" ] && git ls-remote --tags "$repo_url" 'refs/tags/v*' 2> /dev/null \
     | awk '{print $1}' | grep -qx "$WORKFLOW_SHA"; then
  channel="release"
fi

file="${WORKFLOW}-${outcome}-${channel}"
if curl -sfL --max-time 10 -o /dev/null "$repo_url/releases/download/usage-counter/$file"; then
  echo "Counted this run as $file."
else
  echo "Could not count this run ($file) — ignored."
fi
exit 0
