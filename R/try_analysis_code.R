#!/usr/bin/env Rscript
# The analysis agent's only command: runs one R file the way the test run
# does (testing profile, DSLite setup with mock data, the scripts before
# this step), then the given file, echoing each statement and its output,
# so the agent can look at objects and errors before it answers. Usage:
#   Rscript <this file> .agent/draft.R
# Reads .agent/try-context.json (written by ask_agent_for_scripts()). Runs
# inside Claude Code's sandbox, without network or credentials.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1 || !file.exists(args[1])) {
  stop("Give one existing R file, e.g. .agent/draft.R", call. = FALSE)
}
if (!startsWith(normalizePath(args[1]), normalizePath(".agent"))) {
  stop("Only files in .agent/ can be tried.", call. = FALSE)
}
ctx <- jsonlite::fromJSON(".agent/try-context.json")
Sys.setenv(R_CONFIG_ACTIVE = ctx$profile)
options(width = 120)

quietly <- function(path) {
  invisible(utils::capture.output(source(path, local = globalenv(), echo = FALSE)))
}
ok <- tryCatch({
  quietly(ctx$login_file)
  for (s in ctx$scripts_before) quietly(s)
  TRUE
}, error = function(e) {
  cat("The setup or an earlier step failed:", conditionMessage(e), "\n")
  FALSE
})
if (!ok) quit(status = 1)
cat("Setup and earlier steps ran. Objects on the servers are available.\n\n")

res <- tryCatch({
  source(args[1], local = globalenv(), echo = TRUE, max.deparse.length = 300, spaced = TRUE)
  TRUE
}, error = function(e) {
  cat("\nError:", conditionMessage(e), "\n")
  ds <- tryCatch(unlist(DSI::datashield.errors()), error = function(e2) character(0))
  if (length(ds) > 0) cat("Server errors:", substr(paste(ds, collapse = " | "), 1, 1500), "\n")
  FALSE
})
quit(status = if (res) 0 else 1)
