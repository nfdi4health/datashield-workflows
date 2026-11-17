#!/usr/bin/env Rscript
# The literature watch's report (literature-watch.yml, from read-loop.sh):
# built from the data folder (WATCH_DATA_DIR, the hub's data branch) into
# that folder (files$reports: overview.md and progress.csv), pushed with
# the data. WATCH_TODAY for tests.

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
reg <- read_register(dir)
report <- format_watch_report(reg, state, fields, queries, months, progress, settings, today, read_vocabulary(dir))

# Next to the data on the data branch (read-loop.sh pushes it): the report
# and progress.csv, for a dashboard or anyone reading along. No pull
# request: a progress report has nothing to decide.
reports <- file.path(Sys.getenv("WATCH_DATA_DIR", "watch-data"), settings$files$reports %||% "literature-watch/reports")
dir.create(reports, recursive = TRUE, showWarnings = FALSE)
writeLines(report, file.path(reports, "overview.md"))
by_field <- lapply(fields, function(f) field_papers(reg, state, f$name, queries[[f$name]], months))
names(by_field) <- names(fields)
utils::write.csv(watch_progress_table(progress, by_field, queries, target, months, today),
  file.path(reports, "progress.csv"), row.names = FALSE)
cat(sprintf("Report: %d of %d papers read, %d of %d field-months complete%s.\n", sum(progress$papers_read),
  sum(progress$sample_size), sum(progress$months_complete), sum(progress$months), if (complete) " (round complete)" else ""))
