# Reads the top-level function definitions of one R file through R's own
# parser (not regex): name, line, formals with their deparsed defaults,
# the function's source text, and the @param texts and tags of the roxygen
# block right above it (roxygen_params()). Several definitions per file
# are fine. A file that doesn't parse is skipped with a warning.
read_r_definitions <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  exprs <- tryCatch(parse(text = lines, keep.source = TRUE), error = function(e) {
    warning(sprintf("%s does not parse, skipped: %s", path, conditionMessage(e)), call. = FALSE)
    NULL
  })
  if (is.null(exprs)) {
    return(list())
  }
  refs <- attr(exprs, "srcref")

  defs <- list()
  for (i in seq_along(exprs)) {
    e <- exprs[[i]]
    if (!is.call(e) || !is.name(e[[1]]) || !as.character(e[[1]]) %in% c("<-", "=", "<<-")) {
      next
    }
    value <- e[[3]]
    if (!is.call(value) || !identical(value[[1]], as.name("function"))) {
      next
    }
    name <- if (is.name(e[[2]])) {
      as.character(e[[2]])
    } else if (is.character(e[[2]])) {
      e[[2]]
    } else {
      next
    }
    fmls <- value[[2]]
    defaults <- vapply(as.list(fmls), function(d) {
      if (is.name(d) && !nzchar(as.character(d))) {
        ""
      } else {
        paste(deparse(d, width.cutoff = 500L), collapse = " ")
      }
    }, character(1))
    line <- refs[[i]][1]
    rox <- roxygen_params(lines, line)
    defs[[length(defs) + 1]] <- list(
      name = name,
      file = path,
      line = line,
      args = names(fmls) %||% character(0),
      defaults = unname(defaults),
      source = paste(as.character(refs[[i]]), collapse = "\n"),
      param_docs = rox$params,
      tags = rox$tags
    )
  }
  defs
}
