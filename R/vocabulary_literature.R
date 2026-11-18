#!/usr/bin/env Rscript
# The literature watch's vocabulary (literature-watch.yml, job
# `vocabulary`, after the reading): Claude (Opus) sorts the method names
# and variant wordings the papers gave into methods and variants
# (vocabulary.yml in the data folder), so that one method counts once
# however the papers word it. Only names not classified yet are asked
# about, within `vocabulary$max_calls` calls; the rest waits for the next
# run. At the usage limit it stops and keeps what it has, and writes
# "limit" to WATCH_VOCABULARY_STATUS (else "done"). Whether a method exists
# in DataSHIELD is checked later, for the ranked candidates only
# (R/candidates_literature.R). WATCH_DATA_DIR, WATCH_TODAY for tests.

library(jsonlite)
library(purrr)

functions_dir <- if (dir.exists("R/functions/literature")) "R/functions" else ".shared-workflows/R/functions"
walk(list.files(file.path(functions_dir, c("shared", "literature")), pattern = "\\.R$", full.names = TRUE), source)

settings <- read_config_yaml("config/literature-watch.yml")
today <- as.Date(Sys.getenv("WATCH_TODAY", as.character(Sys.Date())))
dir <- file.path(Sys.getenv("WATCH_DATA_DIR", "watch-data"), settings$files$data %||% "literature-watch/data")

reg <- read_register(dir)
vocab <- read_vocabulary(dir)
auth <- claude_auth()
fingerprint <- function(claude) hash_keys(paste(claude$config$model %||% "", hash_keys(claude$prompt %||% "")))

names_claude <- claude_client("methods-classification", "prompts/methods-classification-prompt.md", auth = auth)
variants_claude <- claude_client("methods-variants", "prompts/methods-variants-prompt.md", auth = auth)
by_names <- fingerprint(names_claude)
by_variants <- fingerprint(variants_claude)
update_lookup_table(file.path(dir, "readers.csv"), data.frame(
  fingerprint = c(by_names, by_variants), group = c("names", "variants"),
  model = c(names_claude$config$model, variants_claude$config$model),
  prompt = c(hash_keys(names_claude$prompt), hash_keys(variants_claude$prompt))), today)

calls <- as.integer(settings$vocabulary$max_calls %||% 15)
n <- classify_names_round(vocab, reg, names_claude, settings, today, by_names, calls)
vocab <- n$vocab
v <- list(calls = 0, limit = FALSE, classified = 0)
if (!n$limit) {
  v <- classify_variants_round(vocab, reg, variants_claude, settings, today, by_variants, calls - n$calls)
  vocab <- v$vocab
}
write_vocabulary(vocab, dir)
message(sprintf("Vocabulary: %d names and %d variant wordings classified (%d calls); %d methods known.",
  n$classified, v$classified, n$calls + v$calls, length(vocab$methods)))

limit <- n$limit || v$limit
if (limit) message("Stopped at the subscription's usage limit; the rest waits for the next run.")
writeLines(if (limit) "limit" else "done", Sys.getenv("WATCH_VOCABULARY_STATUS", "vocabulary_status.txt"))
