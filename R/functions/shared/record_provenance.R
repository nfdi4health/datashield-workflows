# Notes what produced this run's output, for provenance_footer(): `kind`
# is "model" (name = Claude profile), "prompt" or "config" (name = file),
# `value` the model or a short hash of the text as used (a project's own
# prompt or merged config included). Kept in an environment under option
# `bot.provenance`, created on first use; called by claude_client(),
# read_text_file() and read_config_yaml(), so no workflow wires it.
record_provenance <- function(kind, name, value) {
  reg <- getOption("bot.provenance")
  if (!is.environment(reg)) {
    reg <- new.env(parent = emptyenv())
    options(bot.provenance = reg)
  }
  entries <- reg[[kind]] %||% list()
  entries[[name]] <- value
  assign(kind, entries, envir = reg)
  invisible(value)
}
