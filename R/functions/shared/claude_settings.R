# The settings of one profile of config/claude.yml (e.g. "test-review"):
# its `default` entry with the profile's entries merged over it, key by
# key, after a project's own config/claude.yml was merged over the shared
# one (read_config_yaml()). An unknown profile stops the run.
#
# A caller's workflow inputs `model` and `max-tokens` (environment
# variables CLAUDE_MODEL and CLAUDE_MAX_TOKENS, empty or 0: the profile's)
# replace the profile's for every Claude call of the run. The profile is
# then fitted to what the model accepts (`model_rules` in config/claude.yml,
# adapt_to_model()), so a model can be chosen without knowing its rules.
claude_settings <- function(profile) {
  cfg <- read_config_yaml("config/claude.yml")
  if (is.null(cfg[[profile]]) || identical(profile, "model_rules")) {
    stop(sprintf("No profile '%s' in config/claude.yml.", profile), call. = FALSE)
  }
  settings <- utils::modifyList(cfg$default %||% list(), cfg[[profile]])
  model <- trimws(Sys.getenv("CLAUDE_MODEL"))
  if (nzchar(model)) {
    settings$anthropic$model <- model
  }
  max_tokens <- suppressWarnings(as.integer(Sys.getenv("CLAUDE_MAX_TOKENS")))
  if (!is.na(max_tokens) && max_tokens > 0) {
    settings$anthropic$max_tokens <- max_tokens
  }
  settings$anthropic <- adapt_to_model(settings$anthropic, cfg$model_rules)
  settings
}
