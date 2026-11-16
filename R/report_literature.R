#!/usr/bin/env Rscript
# The literature watch's report (literature-watch.yml): built from the data
# folder (WATCH_DATA_DIR, the hub's data branch) into the hub's checkout
# (files$reports/overview.md), with the pull request's title and body.
# Writes watch_files.txt (the files to propose), report_title.txt,
# report_body.md and report_due.txt ("yes" or "no"): WATCH_REPORT always,
# never, or auto (on report$weekday, and once when a round is complete).
# WATCH_TODAY for tests.

library(jsonlite)
library(purrr)

functions_dir <- if (dir.exists("R/functions/literature")) "R/functions" else ".shared-workflows/R/functions"
walk(list.files(file.path(functions_dir, c("shared", "literature")), pattern = "\\.R$", full.names = TRUE), source)

settings <- read_config_yaml("config/literature-watch.yml")
fields <- settings$fields %||% list()
names(fields) <- vapply(fields, function(f) f$name, "")
today <- as.Date(Sys.getenv("WATCH_TODAY", as.character(Sys.Date())))
dir <- file.path(Sys.getenv("WATCH_DATA_DIR", "watch-data"), settings$files$data %||% "literature-watch/data")

target <- as.integer(settings$sampling$target_per_month %||% 25)
months <- watch_months(today, settings$sampling$lag_months %||% 2, settings$sampling$years_back %||% 5)
queries <- stats::setNames(as.list(hash_keys(vapply(fields, field_search, "", settings = settings))), names(fields))
state <- read_months_state(dir)
progress <- watch_progress(state, fields, months, target, queries)
complete <- all(progress$months_complete == progress$months)
report <- format_watch_report(read_register(dir), state, fields, queries, months, progress, settings, today)

path <- file.path(settings$files$reports %||% "literature-watch/reports", "overview.md")
range <- sprintf("%d per month, %s to %s", target, utils::tail(months, 1), months[1])
# A complete round is reported once: not again while the report on the
# hub's main branch already says so for this round.
said_complete <- file.exists(path) && any(grepl(sprintf("%d papers per field and publication month, %s to %s (**complete**)",
  target, utils::tail(months, 1), months[1]), readLines(path, warn = FALSE), fixed = TRUE))
weekday <- c("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")[as.POSIXlt(today)$wday + 1]
mode <- Sys.getenv("WATCH_REPORT", "auto")
due <- identical(mode, "always") || (identical(mode, "auto") &&
  (identical(weekday, settings$report$weekday %||% "Monday") || (complete && !said_complete)))
writeLines(if (due) "yes" else "no", "report_due.txt")
dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
writeLines(report, path)
writeLines(path, "watch_files.txt")
writeLines(if (complete) sprintf("Literature watch: round complete (%s)", range) else sprintf("Literature watch: progress (%s)", today),
  "report_title.txt")
writeLines(c(sprintf("The literature watch's report, %s. Round: %s; %d of %d papers read, %d of %d field-months complete.",
  today, range, sum(progress$papers_read), sum(progress$sample_size), sum(progress$months_complete), sum(progress$months)), "",
  if (complete) "The round is complete: the nightly runs now only read each new month. To start the next round, raise `target_per_month` or `years_back` in `config/literature-watch.yml`." else
    "The data is on the `data` branch; this pull request only carries the report, updated by the runs until it's merged."), "report_body.md")
cat(report, sep = "\n")
