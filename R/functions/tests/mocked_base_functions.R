# The functions of base R a generated test replaces (local_mocked_bindings()
# or with_mocked_bindings() with `.package` set to a base package, or
# without `.package` for a name only base R has, not the package under test
# itself): testthat can't do that reliably, and R CMD check fails such
# tests even when they pass in the bot's run (dsAnalysis #38/#41). `code`
# is the test's code; `own` the names the package defines
# (package_function_names()). Returns the replaced names, e.g.
# "base::interactive"; character(0) when none or the code doesn't parse.
mocked_base_functions <- function(code, own = character(0)) {
  base_pkgs <- c("base", "utils", "stats", "methods", "tools", "graphics", "grDevices", "datasets", "parallel", "compiler", "grid", "splines", "stats4", "tcltk")
  exprs <- tryCatch(parse(text = code, keep.source = FALSE), error = function(e) NULL)
  if (is.null(exprs)) return(character(0))
  found <- character(0)
  walk_call <- function(x) {
    if (!is.call(x)) return(invisible())
    head <- x[[1]]
    fn <- if (is.name(head)) as.character(head) else if (is.call(head) && identical(head[[1]], as.name("::"))) as.character(head[[3]]) else ""
    if (fn %in% c("local_mocked_bindings", "with_mocked_bindings")) {
      args <- as.list(x)[-1]
      nms <- names(args) %||% rep("", length(args))
      pkg <- if (".package" %in% nms && is.character(args[[".package"]])) args[[".package"]] else NA_character_
      mocked <- setdiff(nms[nzchar(nms)], c(".package", ".env", "code"))
      for (m in mocked) {
        from <- if (!is.na(pkg)) {
          if (pkg %in% base_pkgs) pkg else NA_character_
        } else if (!m %in% own) {
          hit <- Filter(function(p) exists(m, envir = asNamespace(p), inherits = FALSE), intersect(base_pkgs, loadedNamespaces()))
          if (length(hit) > 0) hit[1] else NA_character_
        } else {
          NA_character_
        }
        if (!is.na(from)) found <<- c(found, paste0(from, "::", m))
      }
    }
    for (part in as.list(x)[-1]) if (is.call(part)) walk_call(part)
  }
  for (e in exprs) walk_call(e)
  unique(found)
}
