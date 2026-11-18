#!/usr/bin/env bash
# Commits what changed in watch-data and pushes it to the hub's data
# branch ($DATA_BRANCH), with $HUB_TOKEN in this command's header only,
# never in watch-data/.git/config. Without $HUB_TOKEN: nothing (a local
# run). The hub's candidate workflow may have pushed decisions.json
# meanwhile: then this commit goes on top of it and is pushed again.
# Usage: push-data.sh <what, for the commit message>
set -uo pipefail
dir="${WATCH_DATA_DIR:-watch-data}"
[ -n "${HUB_TOKEN:-}" ] || exit 0
git -C "$dir" add -A
if git -C "$dir" diff --cached --quiet; then exit 0; fi
git -C "$dir" commit --quiet -m "data: literature watch, $1"
auth="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$HUB_TOKEN" | base64 -w0)"
git -C "$dir" -c "http.https://github.com/.extraheader=$auth" push --quiet origin "HEAD:refs/heads/$DATA_BRANCH" ||
  { git -C "$dir" -c "http.https://github.com/.extraheader=$auth" pull --quiet --rebase origin "$DATA_BRANCH" &&
    git -C "$dir" -c "http.https://github.com/.extraheader=$auth" push --quiet origin "HEAD:refs/heads/$DATA_BRANCH"; }
