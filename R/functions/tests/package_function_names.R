# Names of the functions the package defines at the top level of its R/
# files (read_r_definitions(), R's own parser). Used to tell a
# categorised test file name, test-<category>-<function>.R, from a plain
# name that merely contains a dash.
package_function_names <- function() {
  files <- list.files("R", pattern = "\\.[Rr]$", full.names = TRUE)
  unique(unlist(lapply(files, function(f) vapply(read_r_definitions(f), `[[`, character(1), "name"))))
}
