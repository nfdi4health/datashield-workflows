# The settings of one profile of config/claude.yml (e.g. "test-review"):
# its `default` entry with the profile's entries merged over it, key by
# key, after a project's own config/claude.yml was merged over the shared
# one (read_config_yaml()). An unknown profile stops the run.
#
# A caller's workflow inputs for this call (model, max-tokens, effort)
# replace the profile's. The workflows pass them as environment variables
# named after the profile: CLAUDE_MODEL_<PROFILE>, CLAUDE_MAX_TOKENS_<PROFILE>
# and CLAUDE_EFFORT_<PROFILE>, the profile in capitals with "_" for "-"
# (e.g. CLAUDE_MODEL_TEST_REVIEW); empty or 0 keeps the profile's. The
# profile is then fitted to what the model accepts (`model_rules`,
# adapt_to_model()), so a model can be chosen without knowing its rules.
claude_settings <- function(profile) {
  cfg <- read_config_yaml("config/claude.yml")
  if (is.null(cfg[[profile]]) || identical(profile, "model_rules")) {
    stop(sprintf("No profile '%s' in config/claude.yml.", profile), call. = FALSE)
  }
  settings <- utils::modifyList(cfg$default %||% list(), cfg[[profile]])
  input <- function(name) {
    trimws(Sys.getenv(sprintf("CLAUDE_%s_%s", name, toupper(gsub("-", "_", profile, fixed = TRUE)))))
  }
  model <- input("MODEL")
  if (nzchar(model)) {
    settings$anthropic$model <- model
  }
  max_tokens <- suppressWarnings(as.integer(input("MAX_TOKENS")))
  if (!is.na(max_tokens) && max_tokens > 0) {
    settings$anthropic$max_tokens <- max_tokens
  }
  effort <- tolower(input("EFFORT"))
  if (nzchar(effort)) {
    levels <- c("low", "medium", "high", "xhigh", "max")
    if (!effort %in% levels) {
      stop(sprintf("Unknown effort '%s' for %s; use one of: %s.", effort, profile, paste(levels, collapse = ", ")), call. = FALSE)
    }
    settings$anthropic$effort <- effort
  }
  settings$anthropic <- adapt_to_model(settings$anthropic, cfg$model_rules)
  settings
}
