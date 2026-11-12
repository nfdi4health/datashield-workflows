# The provenance of a bot's report: which Claude models, prompt templates,
# config files and workflow commit produced it (record_provenance()), as
# one small visible line and a hidden marker for later reading (the
# outcome record, dev-notes/feedback-loop.md):
#   <!-- bot-suggest-provenance: {"commit":…,"model":{…},"prompt":{…},"config":{…}} -->
# The commit comes from `.commit` in the shared files (written by the
# shared-files action); "local" when there is none.
provenance_footer <- function() {
  reg <- getOption("bot.provenance")
  get_kind <- function(kind) if (is.environment(reg)) reg[[kind]] %||% list() else list()
  commit_file <- file.path(getOption("bot.shared_root", ".shared-workflows"), ".commit")
  commit <- if (file.exists(commit_file)) trimws(readLines(commit_file, warn = FALSE)[1]) else ""
  if (!nzchar(commit %||% "")) commit <- "local"
  data <- list(commit = commit, model = get_kind("model"), prompt = get_kind("prompt"), config = get_kind("config"))
  models <- unique(unlist(data$model))
  visible <- sprintf("<sub>Made with %s · prompts %s · config %s · datashield-workflows %s</sub>",
    if (length(models) > 0) paste(models, collapse = ", ") else "no Claude call",
    short_hash(data$prompt), short_hash(data$config), substr(commit, 1, 7))
  json <- jsonlite::toJSON(data, auto_unbox = TRUE)
  json <- gsub("--", "-\\u002d", json, fixed = TRUE)  # an HTML comment can't hold "--"
  c(visible, sprintf("<!-- bot-suggest-provenance: %s -->", json))
}
