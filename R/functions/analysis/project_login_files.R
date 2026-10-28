# Where the project's two login files are, read from its config.yml (the
# `config` package file dsAnalysis uses to switch between the real login
# and the DSLite test setup). `paths` (settings) gives that file's name
# and the fallbacks if it has no login_folder / login_file entries;
# `profiles` (settings) the names of the real and the test profile in it.
project_login_files <- function(paths, profiles) {
  cfg <- tryCatch(yaml::read_yaml(paths$project_config), error = function(e) list())
  path_of <- function(profile, fallback) {
    p <- cfg[[profile]]
    if (!is.null(p$login_folder) && !is.null(p$login_file)) {
      file.path(p$login_folder, p$login_file)
    } else {
      fallback
    }
  }
  list(
    production = path_of(profiles$production, paths$login_production),
    testing = path_of(profiles$testing, paths$login_testing)
  )
}
