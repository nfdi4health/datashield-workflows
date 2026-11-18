#!/usr/bin/env Rscript
# The "Exists in DataSHIELD?" check of new issues in the hub of missing
# DataSHIELD functions (idea-check.yml): for each issue in IDEAS_FILE
# (written by list-ideas.sh: the unchecked issues and all others' titles),
# Claude reads which method it asks for, R preselects the functions of the
# catalogue's inventory, Claude judges them (the literature watch's
# "Exists?" prompt), and R checks the answer and writes the comment and
# label to IDEA_RESULTS (post-results.sh posts them). R never sees a GitHub
# token. A method the literature watch's vocabulary knows by exactly this
# name gets its paper count and the watch's marker, so the candidate list
# treats it as tracked. At the usage limit it stops; the rest waits for the next run.
# IDEA_TODAY for tests.

library(jsonlite)
library(purrr)

functions_dir <- if (dir.exists("R/functions/literature")) "R/functions" else ".shared-workflows/R/functions"
walk(list.files(file.path(functions_dir, c("shared", "literature")), pattern = "\\.R$", full.names = TRUE), source)

settings <- read_config_yaml("config/idea-check.yml")
watch <- read_config_yaml("config/literature-watch.yml")
today <- as.Date(Sys.getenv("IDEA_TODAY", as.character(Sys.Date())))
ideas <- fromJSON(Sys.getenv("IDEAS_FILE", "ideas.json"), simplifyVector = FALSE)
out <- Sys.getenv("IDEA_RESULTS", "idea_results.json")
results <- list()
write_results <- function() writeLines(toJSON(results, auto_unbox = TRUE, pretty = TRUE), out)

if (length(ideas$ideas) == 0) {
  message("No unchecked issues.")
  write_results()
  quit(save = "no")
}
inventory <- read_function_inventory(watch)
if (is.null(inventory)) {
  message("The function inventory couldn't be read; the issues wait for the next run.")
  write_results()
  quit(save = "no")
}
# The literature watch's data (the hub's data branch, checked out by the
# workflow), for the vocabulary match; without it the comments go without.
data_dir <- file.path(Sys.getenv("WATCH_DATA_DIR", "watch-data"), watch$files$data %||% "literature-watch/data")
vocab <- if (dir.exists(data_dir)) read_vocabulary(data_dir) else NULL
reg <- if (dir.exists(data_dir)) read_register(data_dir) else NULL
auth <- claude_auth()
reader <- claude_client("idea-reading", "prompts/idea-reading-prompt.md", auth = auth)
judge <- claude_client("methods-exists", "prompts/methods-exists-prompt.md", auth = auth)

for (issue in ideas$ideas) {
  x <- check_idea(issue, ideas$others %||% list(), inventory, reader, judge, settings, today)
  if (x$limit) {
    message("Stopped at the subscription's usage limit; the rest waits for the next run.")
    break
  }
  if (is.null(x$result)) next
  if (!is.null(x$result$verdict)) x$result$literature <- idea_literature(x$result$method, vocab, reg)
  comment <- format_idea_comment(x$result, settings, today)
  results[[length(results) + 1]] <- list(number = issue$number, body = comment$body, label = comment$label)
  message(sprintf("#%s: %s", issue$number, if (is.null(x$result$verdict)) "not a method" else x$result$verdict$verdict))
}
write_results()
message(sprintf("Checked %d of %d issues against %d functions.", length(results), length(ideas$ideas), nrow(inventory)))
