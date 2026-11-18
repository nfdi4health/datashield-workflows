#!/usr/bin/env Rscript
# The literature watch's candidates (literature-watch.yml, job
# `candidates`, after the vocabulary): when due (candidates_due():
# WATCH_CANDIDATES auto, always or never), every method and variant is
# ranked by how much the papers of all years use it (rank_candidates()),
# then checked against the DataSHIELD functions down that ranking until
# `candidates$most_used` gaps are found, and down the rising methods
# (ordered by their share in the last years) until `candidates$rising`
# more are (exists_for_ranked(), profile
# methods-exists; verdicts stored in vocabulary.yml, asked again only when
# a method's candidate functions change). The gaps are researched by
# Claude with web search (profile methods-research) and written for a
# pull request to the hub: literature-watch/candidates/YYYY-MM.json in the
# hub's checkout, candidates_files.txt, candidates_title.txt,
# candidates_body.md and candidates_due.txt ("yes"/"no"). WATCH_TRACKED is
# a JSON file of key -> hub issue number (the workflow reads the issues'
# markers; R has no token). At the usage limit, or when the inventory
# can't be read, nothing is proposed: the next run tries again (the
# verdicts so far are kept). WATCH_DATA_DIR, WATCH_TODAY for tests.

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
inventory <- read_function_inventory(settings)
if (is.null(inventory)) {
  message("The function inventory couldn't be read; the candidates wait for the next run.")
  quit(save = "no")
}
auth <- claude_auth()
exists_claude <- claude_client("methods-exists", "prompts/methods-exists-prompt.md", auth = auth)
by_exists <- hash_keys(paste(exists_claude$config$model %||% "", hash_keys(exists_claude$prompt %||% "")))
update_lookup_table(file.path(dir, "readers.csv"), data.frame(fingerprint = by_exists, group = "exists",
  model = exists_claude$config$model, prompt = hash_keys(exists_claude$prompt)), today)
# Two lists (user, 2026-11-18): the most used methods DataSHIELD lacks
# (share over all years read), then those on the rise (a rising trend,
# ordered by their share in the last years), leaving out the first list's
# candidates and their variants. Exists? runs down each list until it has
# enough gaps; a method checked in the first walk isn't asked again.
cs <- settings$candidates
calls <- as.integer(settings$exists$max_calls %||% 15)
x <- exists_for_ranked(ranked, vocab, exists_claude, inventory, settings, today, by_exists, calls,
  as.integer(cs$most_used %||% 7))
vocab <- x$vocab
rising_ranked <- ranked[ranked$trend == "rising", , drop = FALSE]
rising_ranked <- rising_ranked[order(-rising_ranked$recent_share, rising_ranked$key), , drop = FALSE]
y <- list(vocab = vocab, gaps = character(0), calls = 0, limit = FALSE, checked = 0, complete = TRUE)
if (!x$limit) {
  y <- exists_for_ranked(rising_ranked, vocab, exists_claude, inventory, settings, today, by_exists,
    calls - x$calls, as.integer(cs$rising %||% 3), exclude = x$gaps)
  vocab <- y$vocab
}
write_vocabulary(vocab, dir)
message(sprintf("Exists in DataSHIELD?: %d verdicts from Claude (%d calls) down the rankings, against %d functions; %d most used and %d rising gaps.",
  x$checked + y$checked, x$calls + y$calls, nrow(inventory), length(x$gaps), length(y$gaps)))
if (x$limit || y$limit) {
  message("Stopped at the subscription's usage limit; the candidates are proposed with a later run.")
  quit(save = "no")
}
if (!x$complete || !y$complete) message("The calls for Exists? ran out before the rankings were checked far enough; the gaps found so far are proposed.")
ranked <- annotate_verdicts(ranked, vocab)
gap <- c("none", "partial")
new <- rbind(cbind(ranked[match(x$gaps, ranked$key), , drop = FALSE], list = rep("most-used", length(x$gaps))),
  cbind(ranked[match(y$gaps, ranked$key), , drop = FALSE], list = rep("rising", length(y$gaps))))
deferred <- ranked[ranked$status == "deferred" & ranked$verdict %in% gap, , drop = FALSE]
tracked_rows <- ranked[ranked$status == "tracked", , drop = FALSE]
if (nrow(new) + nrow(deferred) == 0) {
  message("No candidates to propose: every gap is tracked, decided or used in too few papers.")
  quit(save = "no")
}

claude <- claude_client("methods-research", "prompts/methods-research-prompt.md", auth = auth)
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
      share = round(row$share, 4), recent_papers = row$recent_papers, recent_share = round(row$recent_share, 4),
      list = row$list, trend = row$trend, fields = row$fields,
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
