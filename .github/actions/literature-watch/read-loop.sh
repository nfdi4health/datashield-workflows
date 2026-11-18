#!/usr/bin/env bash
# The literature watch's reading (literature-watch.yml, job `read`):
# R/watch_literature.R reads one stretch (WATCH_CHUNK papers) into
# watch-data, this script pushes it to the hub's data branch
# (push-data.sh), and starts the next stretch while the run's budget lasts
# (watch_status.json: "chunk"). A stop at the usage limit, the budget or
# an error loses at most the papers of the current stretch that weren't
# written yet (R writes after every fetch). The vocabulary, the candidates
# and the report are jobs of their own. R runs without $HUB_TOKEN and the
# App's key in its environment.
#
# The hub token lasts an hour, the reading up to five and a half: with
# $APP_CLIENT_ID and $APP_PRIVATE_KEY, a new one is made (hub-token.sh)
# before a push once the current one is $TOKEN_RENEW_SECONDS (40 minutes)
# old.
set -uo pipefail
dir=watch-data
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
token_time=$(date +%s)
renew_token() {
  [ -n "${APP_PRIVATE_KEY:-}" ] && [ -n "${APP_CLIENT_ID:-}" ] || return 0
  [ $(( $(date +%s) - token_time )) -ge "${TOKEN_RENEW_SECONDS:-2400}" ] || return 0
  local fresh
  if fresh="$(bash "${HUB_TOKEN_SCRIPT:-$here/hub-token.sh}")" && [ -n "$fresh" ]; then
    echo "::add-mask::$fresh"
    HUB_TOKEN="$fresh"
    token_time=$(date +%s)
    echo "The hub token was renewed."
  else
    echo "::warning::The hub token couldn't be renewed; the old one is used while it lasts."
  fi
}
push() {
  [ -n "${HUB_TOKEN:-}" ] || return 0
  renew_token
  HUB_TOKEN="$HUB_TOKEN" WATCH_DATA_DIR="$dir" bash "$here/push-data.sh" "$1"
}
remaining="${MAX_PAPERS:-}"
stopped="error"
progress=""
while :; do
  rm -f watch_status.json
  if ! env -u HUB_TOKEN -u APP_PRIVATE_KEY -u APP_CLIENT_ID WATCH_MAX_PAPERS="$remaining" WATCH_DATA_DIR="$dir" Rscript "$SCRIPT"; then
    push "stretch stopped by an error" || true
    echo "::error::The reading stopped with an error; what was read until then is pushed."
    stopped="error"
    break
  fi
  stopped=$(jq -r .stopped watch_status.json)
  read=$(jq -r .read watch_status.json)
  remaining=$(jq -r .remaining watch_status.json)
  progress=$(jq -r .progress watch_status.json)
  push "$read papers" || { echo "::error::Pushing to the data branch failed."; stopped="error"; break; }
  echo "Stretch: $read papers ($stopped). $progress"
  [ "$stopped" = "chunk" ] || break
done
{
  echo "### Literature watch: reading"
  echo
  echo "$progress"
  echo
  case "$stopped" in
    done) echo "Nothing left to read in this round." ;;
    budget) echo "Stopped at this run's limit of papers." ;;
    limit) echo "Stopped at the subscription's usage limit; the next run carries on." ;;
    *) echo "Stopped by an error (see the log)." ;;
  esac
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
echo "stopped=$stopped" >> "${GITHUB_OUTPUT:-/dev/null}"
[ "$stopped" != "error" ]
