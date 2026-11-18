#!/usr/bin/env bash
# The methods already tracked by an issue in the hub ($HUB), open or
# closed: the hidden marker <!-- literature-watch-method: KEY --> that the
# candidate workflow puts into the issues it opens, and that the idea check
# (a bot's comment) puts on a hand-written issue whose method the
# vocabulary knows by that exact name. Only bots' comments count, so a
# person can't hide a candidate with a comment. Writes a JSON object
# KEY -> issue number to $1 (empty object without a hub or token).
set -euo pipefail
out="$1"
if [ -z "${HUB:-}" ] || [ -z "${GH_TOKEN:-}" ]; then
  echo '{}' > "$out"
  exit 0
fi
bodies="$(gh api --paginate "repos/$HUB/issues?state=all&per_page=100" |
  jq -s '[ add[]? | select(.pull_request == null) | . as $i
           | ((.body // "") | [scan("<!--\\s*literature-watch-method:\\s*([^\\s>]+)\\s*-->")[0]])[]
           | {key: ., number: $i.number} ]')"
comments="$(gh api --paginate "repos/$HUB/issues/comments?per_page=100" |
  jq -s '[ add[]? | select(.user.type == "Bot") | . as $c
           | ((.body // "") | [scan("<!--\\s*literature-watch-method:\\s*([^\\s>]+)\\s*-->")[0]])[]
           | {key: ., number: ($c.issue_url | split("/") | last | tonumber)} ]')"
# An issue's own marker wins over a comment's.
jq -n --argjson c "$comments" --argjson b "$bodies" '($c + $b) | map({(.key): .number}) | add // {}' > "$out"
echo "Tracked ideas: $(jq 'length' "$out")."
