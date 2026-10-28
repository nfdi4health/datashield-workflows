# What the installed client packages offer: every exported function with
# its arguments and help title, plus DSI's datashield.*() functions.
# Returns list(functions, text): `functions` (name -> package, argument
# names, whether it takes `...`) is what check_ds_calls() checks generated
# code against; `text` is the same, one line per function, for the prompt.
# Built from the installed versions, so Claude sees exactly the functions
# the test run can call. `excluded` (settings) are left out, e.g.
# datashield.login(): the login already ran, so calls to them are flagged.
client_function_reference <- function(packages, excluded = character(0)) {
  functions <- list()
  lines <- character(0)
  for (pkg in c(packages, "DSI")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      next
    }
    exports <- setdiff(sort(getNamespaceExports(pkg)), excluded)
    if (pkg == "DSI") {
      exports <- grep("^datashield\\.", exports, value = TRUE)
    }
    titles <- rd_titles(pkg)
    lines <- c(lines, "", sprintf("Package %s %s:", pkg, utils::packageVersion(pkg)))
    for (fn in exports) {
      f <- getExportedValue(pkg, fn)
      if (!is.function(f)) {
        next
      }
      fm <- formals(f)
      args <- names(fm)
      # An argument without default is an empty symbol, which can't be
      # stored in a variable, so it is compared in place.
      shown_args <- vapply(args, function(a) {
        if (identical(fm[[a]], quote(expr = ))) {
          return(a)
        }
        paste(a, "=", paste(deparse(fm[[a]], width.cutoff = 500L), collapse = " "))
      }, character(1))
      line <- paste0(fn, "(", paste(shown_args, collapse = ", "), ")")
      if (!is.null(titles[[fn]])) {
        line <- paste0(line, " — ", titles[[fn]])
      }
      lines <- c(lines, line)
      functions[[fn]] <- list(package = pkg, args = setdiff(args, "..."), dots = "..." %in% args)
    }
  }
  list(functions = functions, text = paste(lines[-1], collapse = "\n"))
}
