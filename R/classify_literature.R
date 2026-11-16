#!/usr/bin/env Rscript
# The literature watch's vocabulary and "Exists in DataSHIELD?"
# (literature-watch.yml, from read-loop.sh after the reading, before the
# report): Claude (Opus) sorts the method names and variant wordings the
# papers gave into the vocabulary (vocabulary.yml in the data folder), then
# checks the methods named in enough papers against the DataSHIELD
# functions' documentation (the catalogue's inventory), with evidence R
# checks. Only what isn't classified or checked yet is asked about, within
# the calls of `vocabulary$max_calls` and `exists$max_calls`; the rest
# waits for the next run. At the usage limit it stops and keeps what it
# has. WATCH_DATA_DIR, WATCH_TODAY for tests.

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
exists_claude <- claude_client("methods-exists", "prompts/methods-exists-prompt.md", auth = auth)
by_names <- fingerprint(names_claude)
by_variants <- fingerprint(variants_claude)
by_exists <- fingerprint(exists_claude)
update_lookup_table(file.path(dir, "readers.csv"), data.frame(
  fingerprint = c(by_names, by_variants, by_exists), group = c("names", "variants", "exists"),
  model = c(names_claude$config$model, variants_claude$config$model, exists_claude$config$model),
  prompt = c(hash_keys(names_claude$prompt), hash_keys(variants_claude$prompt), hash_keys(exists_claude$prompt))), today)

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
if (!limit) {
  inventory <- read_function_inventory(settings)
  if (is.null(inventory)) {
    message("The function inventory couldn't be read; \"Exists?\" waits for the next run.")
  } else {
    x <- exists_round(vocab, reg, exists_claude, inventory, settings, today, by_exists,
      as.integer(settings$exists$max_calls %||% 15))
    vocab <- x$vocab
    write_vocabulary(vocab, dir)
    limit <- x$limit
    message(sprintf("Exists in DataSHIELD?: %d verdicts from Claude (%d calls), against %d functions.",
      x$checked, x$calls, nrow(inventory)))
  }
}
if (limit) message("Stopped at the subscription's usage limit; the rest waits for the next run.")
