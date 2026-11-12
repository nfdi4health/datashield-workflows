#!/usr/bin/env bash
# After the test agent (prompts/implementer-oracle.md), before the writer:
# keeps its commits only if they change nothing outside tests/, then runs
# its test files on the code as it is. Writes .agent/oracle.json ({"sha",
# "files", "tests", "failing"}), which the writer's prompt and the later
# checks (run-checks.sh: the writer may not change these files) read, and
# .agent/oracle.md for the pull request. Never fails the step.
# See dev-notes/implementer-plan.md, "Tests from the spec".
set -uo pipefail
mkdir -p .agent
rm -f .agent/oracle.json
notes=""
[ -f .agent/oracle-notes.md ] && notes="$(cat .agent/oracle-notes.md)"
start="$(git merge-base HEAD "origin/$BASE")"
files="$(git diff --name-only "$start" HEAD)"

write_md() {
  { echo "$1"; [ -n "$notes" ] && printf '\n%s\n' "$notes"; } > .agent/oracle.md
  cat .agent/oracle.md
}

if [ -z "$files" ]; then
  write_md "The test agent wrote no tests."
  exit 0
fi
outside="$(grep -v '^tests/' <<< "$files" || true)"
if [ -n "$outside" ]; then
  git reset -q --hard "$start"
  write_md "The test agent's work was thrown away: it changed files outside tests/ ($(tr '\n' ' ' <<< "$outside"))."
  exit 0
fi
mapfile -t tests < <(grep -E '^tests/testthat/test.*\.[Rr]$' <<< "$files" || true)
failing=0; total=0; counts=""
if [ "${#tests[@]}" -gt 0 ] && [ "${SETUP:-r}" = r ]; then
  counts="$(Rscript - "${tests[@]}" 2> /dev/null <<'RSCRIPT'
files <- commandArgs(trailingOnly = TRUE)
pkgload::load_all(quiet = TRUE)
res <- do.call(rbind, lapply(files, function(f) {
  r <- tryCatch(as.data.frame(testthat::test_file(f, reporter = "silent", stop_on_failure = FALSE)),
                error = function(e) data.frame(failed = 1, error = TRUE))
  data.frame(failed = sum(r$failed > 0 | r$error), total = max(nrow(r), 1))
}))
cat(sum(res$failed), sum(res$total), "\n")
RSCRIPT
  )"
  read -r failing total <<< "${counts:-0 0}"
fi
sha="$(git rev-parse HEAD)"
jq -n --arg sha "$sha" --argjson tests "${total:-0}" --argjson failing "${failing:-0}" \
  --arg files "$files" '{sha: $sha, files: ($files | split("\n") | map(select(. != ""))), tests: $tests, failing: $failing}' > .agent/oracle.json
# shellcheck disable=SC2016 # backticks are Markdown, not a command
list="$(sed 's/^/- `/; s/$/`/' <<< "$files")"
if [ -z "$counts" ] && [ "${#tests[@]}" -gt 0 ] && [ "${SETUP:-r}" = r ]; then
  verdict="The tests could not be run on the code before the change."
elif [ "${failing:-0}" -gt 0 ]; then
  verdict="On the code before the change, ${failing} of ${total} test(s) failed: the failing ones describe what the change has to do."
else
  verdict="On the code before the change, none of the ${total} test(s) failed: for a bug, they don't reproduce it."
fi
write_md "Written from the spec by a separate agent before the change (commit ${sha:0:7}); the writer may not change them.

${list}

${verdict}"
exit 0
