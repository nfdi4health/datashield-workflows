#!/usr/bin/env Rscript
# The literature watch's candidates (literature-watch.yml, after the
# report): when due (candidates_due(): WATCH_CANDIDATES auto, always or
# never), the methods and variants DataSHIELD lacks are ranked
# (rank_candidates()), the top `candidates$max` new ones researched by
# Claude with web search (profile methods-research), and written for a
# pull request to the hub: literature-watch/candidates/YYYY-MM.json in the
# hub's checkout, candidates_files.txt, candidates_title.txt,
# candidates_body.md and candidates_due.txt ("yes"/"no"). WATCH_TRACKED is
# a JSON file of key -> hub issue number (the workflow reads the issues'
# markers; R has no token). At the usage limit nothing is proposed: the
# next run tries again. WATCH_DATA_DIR, WATCH_TODAY for tests.

library(jsonlite)
library(purrr)

functions_dir <- if (dir.exists("R/functions/literature")) "R/functions" else ".shared-workflows/R/functions"
walk(list.files(file.path(functions_dir, c("shared", "literature")), pattern = "\\.R$", full.names = TRUE), source)

settings <- read_config_yaml("config/literature-watch.yml")
today <- as.Date(Sys.getenv("WATCH_TODAY", as.character(Sys.Date())))
month <- format(today, "%Y-%m")
dir <- file.path(Sys.getenv("WATCH_DATA_DIR", "watch-data"), settings$files$data %||% "literature-watch/data")
folder <- settings$candidates$folder %||% "literature-watch/candidates"
writeLines("no", "candidates_due.txt")

fields <- settings$fields %||% list()
names(fields) <- vapply(fields, function(f) f$name, "")
target <- as.integer(settings$sampling$target_per_month %||% 25)
months <- watch_months(today, settings$sampling$lag_months %||% 2, settings$sampling$years_back %||% 5)
recent <- utils::head(months, 12 * (settings$report$share_years %||% 3))
queries <- stats::setNames(as.list(hash_keys(vapply(fields, field_search, "", settings = settings))), names(fields))
progress <- watch_progress(read_months_state(dir), fields, months, target, queries)
complete <- nrow(progress) > 0 && all(progress$months_complete == progress$months)

if (!candidates_due(Sys.getenv("WATCH_CANDIDATES", "auto"), folder, month, complete)) {
  message("No candidates due in this run.")
  quit(save = "no")
}

reg <- read_register(dir)
vocab <- read_vocabulary(dir)
tracked_file <- Sys.getenv("WATCH_TRACKED")
tracked <- if (nzchar(tracked_file) && file.exists(tracked_file)) fromJSON(tracked_file, simplifyVector = FALSE) else list()
ranked <- rank_candidates(reg, vocab, settings, read_decisions(dir), tracked, months, recent)
new <- utils::head(ranked[ranked$status == "new", , drop = FALSE], settings$candidates$max %||% 10)
deferred <- ranked[ranked$status == "deferred", , drop = FALSE]
tracked_rows <- ranked[ranked$status == "tracked", , drop = FALSE]
if (nrow(new) + nrow(deferred) == 0) {
  message("No candidates to propose: every gap is tracked, decided or used in too few papers.")
  quit(save = "no")
}

claude <- claude_client("methods-research", "prompts/methods-research-prompt.md")
research <- list()
for (i in seq_len(nrow(new))) {
  r <- research_candidate(claude, new[i, ], vocab)
  if (r$limit) {
    message("Stopped at the subscription's usage limit; the candidates are proposed with a later run.")
    quit(save = "no")
  }
  research[[new$key[i]]] <- r$research
}

by <- hash_keys(paste(claude$config$model %||% "", hash_keys(claude$prompt %||% "")))
record <- list(month = month, created = as.character(today), researched_by = by,
  round = list(target_per_month = target, first_month = utils::tail(months, 1), last_month = months[1], complete = complete),
  candidates = lapply(seq_len(nrow(new)), function(i) {
    row <- new[i, ]
    list(key = row$key, method = row$method, variant = row$variant, name = method_label(vocab, row$method),
      variant_name = if (nzchar(row$variant)) method_label(vocab, row$method, row$variant) else "",
      verdict = row$verdict, `function` = row[["function"]], note = candidate_text(row$note), papers = row$papers,
      share = round(row$share, 4), trend = row$trend, fields = row$fields,
      examples = fromJSON(row$examples, simplifyVector = FALSE), research = research[[row$key]])
  }),
  deferred = lapply(seq_len(nrow(deferred)), function(i) list(key = deferred$key[i], name = method_label(vocab, deferred$method[i]),
    variant_name = if (nzchar(deferred$variant[i])) method_label(vocab, deferred$method[i], deferred$variant[i]) else "",
    papers = deferred$papers[i])))
dir.create(folder, recursive = TRUE, showWarnings = FALSE)
path <- file.path(folder, paste0(month, ".json"))
write_json(record, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
writeLines(path, "candidates_files.txt")
writeLines(sprintf("Literature watch: candidates %s", month), "candidates_title.txt")
writeLines(c(format_candidates_body(new, deferred, tracked_rows, tracked, vocab, research, month),
  sprintf("<!-- literature-watch-candidates: %s -->", month)), "candidates_body.md")
writeLines("yes", "candidates_due.txt")
message(sprintf("Candidates %s: %d new, %d deferred, %d already tracked.", month, nrow(new), nrow(deferred), nrow(tracked_rows)))
