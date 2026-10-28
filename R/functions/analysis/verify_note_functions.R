# Checks the function named in each "other_package" note: it must be a
# client function of that package in the function catalogue (`functions`,
# read_function_catalogue(); client package = package + `client_suffix`).
# The tool's enum only ensures the function exists somewhere; a function
# of another package is cleared here, the note itself is kept. Returns
# `steps` with checked notes.
verify_note_functions <- function(steps, functions, client_suffix) {
  lapply(steps, function(s) {
    s$notes <- lapply(s$notes, function(n) {
      fn <- if (is.null(n[["function"]])) {
        ""
      } else {
        n[["function"]]
      }
      pkg <- if (is.null(n$package)) {
        ""
      } else {
        n$package
      }
      belongs <- any(functions$package == paste0(pkg, client_suffix) & functions$function_name == fn)
      if (nzchar(fn) && !(identical(n$kind, "other_package") && belongs)) {
        message(sprintf("Note names %s() for package '%s', which the function catalogue doesn't list; cleared.", fn, pkg))
        n[["function"]] <- ""
      }
      n
    })
    s
  })
}
