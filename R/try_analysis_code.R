#!/usr/bin/env Rscript
# The analysis agent's only command: runs one R file the way the test run
# does (testing profile, DSLite setup with mock data, the scripts before
# this step), then the given file, echoing each statement and its output,
# so the agent can look at objects and errors before it answers. Usage:
#   Rscript <this file> .agent/draft.R
# Reads .agent/try-context.json (written by ask_agent_for_scripts()). Runs
# inside Claude Code's sandbox, without network or credentials.
# Everything lives in a local() block, not the global environment: the
# DSLite setup ends with rm(list = setdiff(ls(), "conns")), which removed
# the helper's own objects there (DataSHIELD_CONF_DEMO, 2026-11-12).
# Like run_analysis_scripts(), statements calling a function DSLite can't
# run (`untestable`, settings dslite_untestable, e.g. ds.glmSLMA) are
# skipped when they fail, and so are later statements using what they
# assign; otherwise the first such call in an earlier step stopped every
# later step's tries (DataSHIELD_CONF_DEMO, 2026-11-13).
local({
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1 || !file.exists(args[1])) {
    stop("Give one existing R file, e.g. .agent/draft.R", call. = FALSE)
  }
  if (!startsWith(normalizePath(args[1]), normalizePath(".agent"))) {
    stop("Only files in .agent/ can be tried.", call. = FALSE)
  }
  ctx <- jsonlite::fromJSON(".agent/try-context.json")
  untestable <- as.character(unlist(ctx$untestable))
  Sys.setenv(R_CONFIG_ACTIVE = ctx$profile)
  options(width = 120)

  # Names a statement assigns at top level (x <- …, x$y <- …).
  assigned <- function(expr) {
    if (!is.call(expr) || !as.character(expr[[1]]) %in% c("<-", "=", "<<-")) {
      return(character(0))
    }
    lhs <- expr[[2]]
    while (is.call(lhs)) {
      lhs <- lhs[[2]]
    }
    if (is.name(lhs)) as.character(lhs) else character(0)
  }
  skipped_names <- character(0)
  shorten <- function(expr) substr(paste(deparse(expr, width.cutoff = 500L), collapse = " "), 1, 200)

  # Runs a file statement by statement; stops at the first error that isn't
  # an untestable call. `echo`: print each statement and its visible value.
  run_file <- function(path, echo) {
    exprs <- parse(path, keep.source = FALSE)
    for (expr in exprs) {
      if (echo) cat("\n>", paste(deparse(expr, width.cutoff = 120L), collapse = "\n+ "), "\n")
      if (length(intersect(all.names(expr), skipped_names)) > 0) {
        skipped_names <<- unique(c(skipped_names, assigned(expr)))
        if (echo) cat("(Skipped: uses the result of a statement DSLite can't run.)\n")
        next
      }
      tryCatch({
        if (echo) {
          res <- withVisible(eval(expr, envir = globalenv()))
          if (res$visible) print(res$value)
        } else {
          invisible(utils::capture.output(eval(expr, envir = globalenv())))
        }
      }, error = function(e) {
        if (length(intersect(all.names(expr), untestable)) == 0) stop(e)
        skipped_names <<- unique(c(skipped_names, assigned(expr)))
        if (echo) {
          cat("(Skipped: DSLite can't run", paste(intersect(all.names(expr), untestable), collapse = ", "),
            "- it runs on the real servers only. Later statements using its result are skipped too.)\n")
        } else {
          cat("Not run in DSLite (an earlier step):", shorten(expr), "\n")
        }
      })
    }
  }

  ok <- tryCatch({
    run_file(ctx$login_file, echo = FALSE)
    for (s in ctx$scripts_before) run_file(s, echo = FALSE)
    TRUE
  }, error = function(e) {
    cat("The setup or an earlier step failed:", conditionMessage(e), "\n")
    FALSE
  })
  if (!ok) quit(status = 1)
  cat("Setup and earlier steps ran. Objects on the servers are available.\n")

  res <- tryCatch({
    run_file(args[1], echo = TRUE)
    TRUE
  }, error = function(e) {
    cat("\nError:", conditionMessage(e), "\n")
    ds <- tryCatch(unlist(DSI::datashield.errors()), error = function(e2) character(0))
    if (length(ds) > 0) cat("Server errors:", substr(paste(ds, collapse = " | "), 1, 1500), "\n")
    FALSE
  })
  quit(status = if (res) 0 else 1)
})
