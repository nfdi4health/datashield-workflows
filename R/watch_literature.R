#!/usr/bin/env Rscript
# The literature watch of the hub for missing DataSHIELD functions, run by
# literature-watch.yml (dev-notes/issue-agents.md, "A central hub"): which
# statistical methods health research uses, from PubMed and PMC (NCBI
# E-utilities). Claude only reads the papers (profile methods-extraction),
# through the subscription or WIF.
#
# Every query of config/literature-watch.yml (WATCH_QUERY: only that one)
# is run. The month's data file (literature-watch/data/YYYY-MM.yml, month
# WATCH_MONTH) gets their entries, a query run again replaces its own, and
# the report (literature-watch/reports/YYYY-MM.md) is built from the whole
# file; both folders are settings (files). At the subscription's usage
# limit the run stops and keeps what it has. Modes (WATCH_MODE), built one
# at a time: pilot (methods named in the abstract against the methods
# section).

library(httr2)
library(jsonlite)
library(purrr)
library(yaml)

functions_dir <- if (dir.exists("R/functions/literature")) "R/functions" else ".shared-workflows/R/functions"
walk(list.files(file.path(functions_dir, c("shared", "literature")), pattern = "\\.R$", full.names = TRUE), source)

settings <- read_config_yaml("config/literature-watch.yml")
mode <- Sys.getenv("WATCH_MODE", "pilot")
if (!identical(mode, "pilot")) {
  stop(sprintf("Mode %s isn't built yet; only pilot is.", mode), call. = FALSE)
}
queries <- settings$queries %||% list()
if (length(queries) == 0) {
  stop("No queries in config/literature-watch.yml.", call. = FALSE)
}
names(queries) <- vapply(queries, function(q) q$name, "")
wanted <- Sys.getenv("WATCH_QUERY")
if (nzchar(wanted)) {
  if (!wanted %in% names(queries)) {
    stop(sprintf("No query named %s in config/literature-watch.yml.", wanted), call. = FALSE)
  }
  queries <- queries[wanted]
}

month <- Sys.getenv("WATCH_MONTH", format(Sys.Date(), "%Y-%m"))
data_file <- file.path(settings$files$data %||% "literature-watch/data", paste0(month, ".yml"))
report_file <- file.path(settings$files$reports %||% "literature-watch/reports", paste0(month, ".md"))

claude <- claude_client("methods-extraction", "prompts/methods-extraction-prompt.md")
entries <- list()
for (query in queries) {
  entry <- watch_query(query, settings, claude)
  # A query with nothing compared because of the limit keeps its earlier
  # entry of the month, if there is one.
  if (!(isTRUE(entry$stopped) && entry$compared == 0)) entries[[query$name]] <- entry
  if (isTRUE(entry$stopped)) {
    message("The subscription's usage limit was reached: the remaining queries are left for another run.")
    break
  }
}
if (length(entries) == 0) {
  stop("No query could be run (see the messages above): nothing written.", call. = FALSE)
}

old <- if (file.exists(data_file)) read_yaml(data_file) else NULL
data <- merge_watch_data(old, month, mode, entries)
missing <- setdiff(vapply(settings$queries, function(q) q$name, ""), names(data$queries))
report <- format_watch_report(data, settings$pilot$top %||% 20, missing)

dir.create(dirname(data_file), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(report_file), recursive = TRUE, showWarnings = FALSE)
write_yaml(data, data_file)
writeLines(report, report_file)
writeLines(c(data_file, report_file), "watch_files.txt")
cat(report, sep = "\n")
