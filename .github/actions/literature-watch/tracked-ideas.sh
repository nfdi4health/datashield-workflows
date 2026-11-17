#!/usr/bin/env bash
# The methods already tracked by an issue in the hub ($HUB), open or
# closed: the hidden marker <!-- literature-watch-method: KEY --> that the
# candidate workflow puts into the issues it opens. Writes a JSON object
# KEY -> issue number to $1 (empty object without a hub or token).
set -euo pipefail
out="$1"
if [ -z "${HUB:-}" ] || [ -z "${GH_TOKEN:-}" ]; then
  echo '{}' > "$out"
  exit 0
fi
gh api --paginate "repos/$HUB/issues?state=all&per_page=100" |
  jq -s '[ add[]? | select(.pull_request == null) | . as $i
           | ((.body // "") | [scan("<!--\\s*literature-watch-method:\\s*([^\\s>]+)\\s*-->")[0]])[]
           | {key: ., number: $i.number} ]
         | map({(.key): .number}) | add // {}' > "$out"
echo "Tracked ideas: $(jq 'length' "$out")."
