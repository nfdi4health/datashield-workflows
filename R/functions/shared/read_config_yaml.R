# Reads a YAML config (e.g. config/roxygen-style.yml) as the shared
# defaults with the project's own file at the same path merged over them,
# key by key (utils::modifyList(): nested entries merge, lists and values
# are replaced). A project only writes what it changes, and keys added to
# the defaults later still reach projects with an older copy. Inside this
# repository (no .shared-workflows/) the file is read as it is. Every
# config file is read this way. A missing config stops the run, unless
# `required` is FALSE: then NULL. The shared copy is looked up under
# option `bot.shared_root` (default ".shared-workflows"; the tests set
# this repository's root).
read_config_yaml <- function(rel_path, required = TRUE) {
  shared <- file.path(getOption("bot.shared_root", ".shared-workflows"), rel_path)
  defaults <- if (file.exists(shared)) {
    yaml::read_yaml(shared)
  } else {
    list()
  }
  own <- if (file.exists(rel_path)) {
    yaml::read_yaml(rel_path)
  } else {
    list()
  }
  if (length(defaults) == 0 && length(own) == 0) {
    if (!required) {
      return(NULL)
    }
    stop(sprintf("Config not found: %s", rel_path), call. = FALSE)
  }
  # An empty YAML file reads as NULL.
  utils::modifyList(defaults %||% list(), own %||% list())
}
