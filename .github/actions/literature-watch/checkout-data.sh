#!/usr/bin/env bash
# Checks out the hub's data branch ($DATA_BRANCH of $HUB) into watch-data,
# or prepares an empty one the first push creates. The token goes into
# this command's header only, never into watch-data/.git/config, so the
# reading step (which runs Claude) can't find it there. Without
# $HUB_TOKEN: a local folder, nothing is pushed.
set -euo pipefail
dir=watch-data
if [ -z "${HUB_TOKEN:-}" ]; then
  mkdir -p "$dir"
  echo "No hub token: the data stays in this run (artifact)."
  exit 0
fi
auth="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$HUB_TOKEN" | base64 -w0)"
url="https://github.com/${HUB}.git"
if git -c "http.https://github.com/.extraheader=$auth" ls-remote --exit-code --heads "$url" "$DATA_BRANCH" > /dev/null 2>&1; then
  git -c "http.https://github.com/.extraheader=$auth" clone --quiet --depth 1 --branch "$DATA_BRANCH" "$url" "$dir"
  echo "Data branch $DATA_BRANCH of $HUB checked out."
else
  mkdir -p "$dir"
  git -C "$dir" init --quiet -b "$DATA_BRANCH"
  git -C "$dir" remote add origin "$url"
  echo "No branch $DATA_BRANCH in $HUB yet: the first push creates it."
fi
git -C "$dir" config user.name "datashield-literature-watch"
git -C "$dir" config user.email "datashield-literature-watch@users.noreply.github.com"
