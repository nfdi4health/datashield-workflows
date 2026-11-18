#!/usr/bin/env bash
# The hub's issues for the "Exists?" check (idea-check.yml): open issues
# without the check's comment (<!-- idea-check: ... -->), oldest first, at
# most $MAX_ISSUES, leaving out pull requests, issues carrying a label of
# $SKIP_LABELS (comma or space separated) and issues the literature watch
# opened (its <!-- literature-watch-method: --> marker: already checked).
# Writes {ideas: [{number, title, body}], others: [{number, title}]} to $1;
# `others` lists every issue of the hub, open or closed, for similar ones.
# Needs $HUB and $GH_TOKEN; R gets only the file.
set -euo pipefail
out="$1"
max="${MAX_ISSUES:-5}"
skip_json="$(jq -cn --arg s "${SKIP_LABELS:-}" '$s | [splits("[ ,]+")] | map(select(length > 0))')"
all="$(gh api --paginate "repos/$HUB/issues?state=all&per_page=100&sort=created&direction=asc" | jq -s 'add // [] | map(select(.pull_request == null))')"
candidates="$(jq -c --argjson skip "$skip_json" '
  map(select(.state == "open")
      | select(([.labels[].name] - $skip | length) == (.labels | length))
      | select((.body // "") | test("<!--\\s*literature-watch-method:") | not))
  | .[] | {number, title, body: (.body // "")}' <<< "$all")"
ideas='[]'
count=0
while IFS= read -r issue; do
  [ -n "$issue" ] || continue
  [ "$count" -ge "$max" ] && break
  n="$(jq -r '.number' <<< "$issue")"
  if ! comments="$(gh api --paginate "repos/$HUB/issues/$n/comments?per_page=100" --jq '.[].body')"; then
    echo "::warning::Could not read the comments of #$n; checked next time."
    continue
  fi
  if grep -q '<!-- idea-check:' <<< "$comments"; then continue; fi
  ideas="$(jq -c --argjson i "$issue" '. + [$i]' <<< "$ideas")"
  count=$((count + 1))
done <<< "$candidates"
jq -n --argjson ideas "$ideas" --argjson all "$all" '{ideas: $ideas, others: ($all | map({number, title}))}' > "$out"
echo "Issues to check: $count."
