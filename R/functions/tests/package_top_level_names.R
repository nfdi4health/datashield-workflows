# Every name the package assigns at the top level of its R/ files, functions
# or not (e.g. `interactive <- NULL`, testthat's way to make a base
# function replaceable in the package's own namespace). Used by
# mocked_base_functions(): replacing such a binding is fine.
package_top_level_names <- function(dir = "R") {
  files <- list.files(dir, pattern = "\\.[Rr]$", full.names = TRUE)
  unique(unlist(lapply(files, function(f) {
    exprs <- tryCatch(parse(f, keep.source = FALSE), error = function(e) NULL)
    unlist(lapply(exprs, function(e) {
      if (is.call(e) && is.name(e[[1]]) && as.character(e[[1]]) %in% c("<-", "=", "<<-") && (is.name(e[[2]]) || is.character(e[[2]]))) {
        as.character(e[[2]])
      }
    }))
  })))
}
