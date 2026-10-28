# Parses R code and calls `on_node(node, arg)` for every part of it: each
# call, name and constant, with `arg` the argument name it was passed
# under ("" if unnamed or at the top). Empty arguments (the gap in
# x[, 1]) are skipped: they can't be passed on. Returns the parse error
# (a condition) if the code doesn't parse, else NULL.
walk_code <- function(text, on_node) {
  exprs <- tryCatch(parse(text = text, keep.source = FALSE), error = function(e) e)
  if (inherits(exprs, "error")) {
    return(exprs)
  }
  visit <- function(x, arg) {
    on_node(x, arg)
    if (!is.call(x)) {
      return(invisible())
    }
    args <- as.list(x)[-1]
    arg_names <- if (is.null(names(args))) {
      rep("", length(args))
    } else {
      names(args)
    }
    for (i in seq_along(args)) {
      if (!identical(args[[i]], quote(expr = ))) {
      visit(args[[i]], arg_names[i])
    }
    }
  }
  for (e in exprs) {
    visit(e, "")
  }
  NULL
}
