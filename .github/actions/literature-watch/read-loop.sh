#!/usr/bin/env bash
# The literature watch's reading: R/watch_literature.R reads one stretch
# (WATCH_CHUNK papers) into watch-data, this script pushes it to the hub's
# data branch, and starts the next stretch while the run's budget lasts
# (watch_status.json: "chunk"). A stop at the usage limit, the budget or
# an error loses at most the papers of the current stretch that weren't
# written yet (R writes after every fetch). Then $REPORT_SCRIPT (if set)
# writes the report and progress.csv into watch-data, pushed the same way,
# also after a stop by an error. R runs without $HUB_TOKEN in its
# environment.
set -uo pipefail
dir=watch-data
push() {
  [ -n "${HUB_TOKEN:-}" ] || return 0
  git -C "$dir" add -A
  if git -C "$dir" diff --cached --quiet; then return 0; fi
  git -C "$dir" commit --quiet -m "data: literature watch, $1"
  local auth
  auth="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$HUB_TOKEN" | base64 -w0)"
  git -C "$dir" -c "http.https://github.com/.extraheader=$auth" push --quiet origin "HEAD:refs/heads/$DATA_BRANCH"
}
remaining="${MAX_PAPERS:-}"
stopped="error"
progress=""
while :; do
  rm -f watch_status.json
  if ! env -u HUB_TOKEN WATCH_MAX_PAPERS="$remaining" WATCH_DATA_DIR="$dir" Rscript "$SCRIPT"; then
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
if [ -n "${REPORT_SCRIPT:-}" ]; then
  if env -u HUB_TOKEN WATCH_DATA_DIR="$dir" Rscript "$REPORT_SCRIPT"; then
    push "report" || { echo "::error::Pushing the report to the data branch failed."; stopped="error"; }
  else
    echo "::error::The report could not be built."
    stopped="error"
  fi
fi
{
  echo "### Literature watch"
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
