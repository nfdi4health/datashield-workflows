# The settings of one profile of config/claude.yml (e.g. "test-review"):
# its `default` entry with the profile's entries merged over it, key by
# key, after a project's own config/claude.yml was merged over the shared
# one (read_config_yaml()). An unknown profile stops the run.
claude_settings <- function(profile) {
  cfg <- read_config_yaml("config/claude.yml")
  if (is.null(cfg[[profile]])) {
    stop(sprintf("No profile '%s' in config/claude.yml.", profile), call. = FALSE)
  }
  utils::modifyList(cfg$default %||% list(), cfg[[profile]])
}
