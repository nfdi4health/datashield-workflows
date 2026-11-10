#!/usr/bin/env bash
# The deterministic checks between the agent's rounds: R CMD check of the
# package in the current directory (tests included). Writes
# .agent/checks.json ({"ok": …, "errors": n, "warnings": n}; ok = no error,
# failing tests included: warnings the package had before must not doom a run) and
# .agent/checks.md, the part of the output the next round and the pull
# request show. Never fails the step: the result is in the files.
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
cat .agent/checks.md
exit 0
