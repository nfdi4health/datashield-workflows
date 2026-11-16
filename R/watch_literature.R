#!/usr/bin/env Rscript
# The literature watch of the hub for missing DataSHIELD functions, run by
# literature-watch.yml (dev-notes/issue-agents.md, "A central hub"): which
# statistical methods health research uses, from PubMed and PMC (NCBI
# E-utilities). Claude only reads the papers (profile methods-extraction),
# through the subscription or WIF.
#
# One stretch of reading (run_watch_chunk()), up to WATCH_CHUNK papers
# (default 250) and at most WATCH_MAX_PAPERS (else papers_per_run of the
# hub's config), into the data folder WATCH_DATA_DIR (the hub's data
# branch, checked out by the workflow, which pushes it after each stretch
# and starts the next while watch_status.json says "chunk"). Every field
# of the hub's config, or only WATCH_FIELD. WATCH_TODAY for tests.

library(httr2)
library(jsonlite)
library(purrr)

functions_dir <- if (dir.exists("R/functions/literature")) "R/functions" else ".shared-workflows/R/functions"
walk(list.files(file.path(functions_dir, c("shared", "literature")), pattern = "\\.R$", full.names = TRUE), source)

settings <- read_config_yaml("config/literature-watch.yml")
fields <- settings$fields %||% list()
if (length(fields) == 0) {
  stop("No fields in config/literature-watch.yml.", call. = FALSE)
}
names(fields) <- vapply(fields, function(f) f$name, "")
wanted <- Sys.getenv("WATCH_FIELD")
if (nzchar(wanted)) {
  if (!wanted %in% names(fields)) stop(sprintf("No field named %s in config/literature-watch.yml.", wanted), call. = FALSE)
  fields <- fields[wanted]
}

today <- as.Date(Sys.getenv("WATCH_TODAY", as.character(Sys.Date())))
dir <- file.path(Sys.getenv("WATCH_DATA_DIR", "watch-data"), settings$files$data %||% "literature-watch/data")
max_papers <- suppressWarnings(as.integer(Sys.getenv("WATCH_MAX_PAPERS")))
if (is.na(max_papers)) max_papers <- as.integer(settings$sampling$papers_per_run %||% 1500)
chunk <- suppressWarnings(as.integer(Sys.getenv("WATCH_CHUNK", "250")))
if (is.na(chunk) || chunk < 1) chunk <- 250L
budget <- max(0L, min(max_papers, chunk))

claude <- claude_client("methods-extraction", "prompts/methods-extraction-prompt.md")
model <- claude$config$model %||% ""
prompt_hash <- hash_keys(claude$prompt %||% "")
reader <- hash_keys(paste(model, prompt_hash))
searches <- vapply(fields, field_search, "", settings = settings)
queries <- stats::setNames(as.list(hash_keys(searches)), names(fields))
update_lookup_table(file.path(dir, "queries.csv"),
  data.frame(fingerprint = unlist(queries), group = names(fields), search = unname(searches)), today)
update_lookup_table(file.path(dir, "readers.csv"),
  data.frame(fingerprint = reader, group = "reader", model = model, prompt = prompt_hash), today)

result <- if (budget > 0) run_watch_chunk(settings, fields, dir, claude, today, budget, reader) else list(read = 0, stopped = "budget")
stopped <- result$stopped
if (identical(stopped, "budget") && result$read < max_papers) stopped <- "chunk"

target <- as.integer(settings$sampling$target_per_month %||% 25)
months <- watch_months(today, settings$sampling$lag_months %||% 2, settings$sampling$years_back %||% 5)
progress <- watch_progress(read_months_state(dir), fields, months, target, queries)
complete <- all(progress$months_complete == progress$months)
line <- sprintf("Round %d per month, %s to %s: %d of %d papers read, %d of %d field-months complete%s.",
  target, utils::tail(months, 1), months[1], sum(progress$papers_read), sum(progress$sample_size),
  sum(progress$months_complete), sum(progress$months), if (complete) " (round complete)" else "")
message(sprintf("This stretch: %d papers (%s). %s", result$read, stopped, line))
write_json(list(read = result$read, stopped = stopped, remaining = max_papers - result$read,
  complete = complete, progress = line), "watch_status.json", auto_unbox = TRUE, pretty = TRUE)
