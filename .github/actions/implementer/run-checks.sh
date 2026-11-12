#!/usr/bin/env bash
# The deterministic checks between the agent's rounds: R CMD check of the
# package in the current directory (tests included). Writes
# .agent/checks.json ({"ok": …, "errors": n, "warnings": n}; ok = no error,
# failing tests included: warnings the package had before must not doom a run) and
# .agent/checks.md, the part of the output the next round and the pull
# request show. Also .agent/lint.md: lints on the changed lines
# (lint-changes.R, with the package's `.lintr` or layout linters only), for
# the maintainability reviewer; they don't count in "ok". A change to the
# tests written from the spec (.agent/oracle.json) sets "ok" to false. Never fails the step: the result is in the files.
set -uo pipefail
mkdir -p .agent
case "${SETUP:-r}" in
  r)
    Rscript - <<'RSCRIPT'
res <- tryCatch(
  rcmdcheck::rcmdcheck(args = c("--no-manual", "--ignore-vignettes"), build_args = "--no-build-vignettes",
                       error_on = "never", quiet = TRUE, check_dir = file.path(tempdir(), "check")),
  error = function(e) e)
if (inherits(res, "error")) {
  writeLines(c("R CMD check could not run:", "", "```", conditionMessage(res), "```"), ".agent/checks.md")
  writeLines('{"ok": false, "errors": 1, "warnings": 0, "notes": 0}', ".agent/checks.json")
} else {
  cut <- function(x) if (nchar(x) > 3000) paste0(substr(x, 1, 3000), "\n…") else x
  lines <- c(sprintf("R CMD check: %d error(s), %d warning(s), %d note(s).",
                     length(res$errors), length(res$warnings), length(res$notes)))
  for (kind in c("errors", "warnings")) for (x in res[[kind]]) lines <- c(lines, "", "```", cut(x), "```")
  writeLines(lines, ".agent/checks.md")
  writeLines(sprintf('{"ok": %s, "errors": %d, "warnings": %d, "notes": %d}',
                     tolower(length(res$errors) == 0),
                     length(res$errors), length(res$warnings), length(res$notes)), ".agent/checks.json")
}
RSCRIPT
    ;;
  *)
    echo "No checks for setup '${SETUP}'." > .agent/checks.md
    echo '{"ok": true, "errors": 0, "warnings": 0, "notes": 0}' > .agent/checks.json
    ;;
esac
# The tests from the spec (run-oracle.sh) are not the writer's to change:
# a change to them fails the checks, so it goes back in a correction round.
if [ -f .agent/oracle.json ]; then
  oracle_sha="$(jq -r .sha .agent/oracle.json)"
  mapfile -t oracle_files < <(jq -r '.files[]' .agent/oracle.json)
  changed="$(git diff --name-only "$oracle_sha" HEAD -- "${oracle_files[@]}")"
  if [ -n "$changed" ]; then
    {
      echo ""
      echo "The tests written from the spec were changed: $(paste -sd ' ' <<< "$changed")."
      echo "Restore them with \`git checkout ${oracle_sha:0:7} -- <file>\`; if one is wrong, leave it and explain why in the summary."
    } >> .agent/checks.md
    jq '.ok = false | .oracle_changed = true' .agent/checks.json > .agent/checks.tmp && mv .agent/checks.tmp .agent/checks.json
  fi
fi
cat .agent/checks.md
rm -f .agent/lint.md
if [ "${SETUP:-r}" = r ] && [ -n "${BASE:-}" ]; then
  Rscript "$(dirname "$0")/lint-changes.R" "$BASE"
  cat .agent/lint.md
fi
exit 0
