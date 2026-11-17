#!/usr/bin/env bash
# Posts the "Exists?" check's results ($1, written by R/check_ideas.R:
# [{number, body, label}]) to the hub ($HUB, $GH_TOKEN): one comment per
# issue and its label, if any (GitHub creates a label on first use). An
# issue that got its comment in the meantime (a parallel run) is skipped.
set -euo pipefail
results="$1"
[ -s "$results" ] || { echo "No results."; exit 0; }
n_results="$(jq 'length' "$results")"
for i in $(seq 0 $((n_results - 1))); do
  n="$(jq -r ".[$i].number" "$results")"
  label="$(jq -r ".[$i].label // \"\"" "$results")"
  if gh api --paginate "repos/$HUB/issues/$n/comments?per_page=100" --jq '.[].body' | grep -q '<!-- idea-check:'; then
    echo "#$n already has its check; skipped."
    continue
  fi
  jq -r ".[$i].body" "$results" | gh api -X POST "repos/$HUB/issues/$n/comments" -F body=@- > /dev/null
  if [ -n "$label" ]; then
    gh api -X POST "repos/$HUB/issues/$n/labels" -f "labels[]=$label" > /dev/null
  fi
  echo "#$n: commented${label:+, label $label}."
done
