# Finds top-level calls to functions that only look at something
# (`inspection`, settings$inspection_functions: ds.class(), ds.colnames(),
# ...) whose result isn't assigned. In a script nobody reads that output,
# so it is noise; the bot used to write such calls because it couldn't
# look itself. Returns the problems, worded by `texts$checks`, for the
# repair round.
check_inspection_calls <- function(code, inspection, texts) {
  exprs <- tryCatch(parse(text = code, keep.source = FALSE), error = function(e) NULL)
  if (is.null(exprs) || length(inspection) == 0) {
    return(character(0))
  }
  found <- character(0)
  for (e in exprs) {
    if (!is.call(e)) {
      next
    }
    head <- e[[1]]
    name <- if (is.name(head)) {
      as.character(head)
    } else if (is.call(head) && as.character(head[[1]]) %in% c("::", ":::")) {
      as.character(head[[3]])
    } else {
      ""
    }
    if (name %in% inspection) {
      found <- c(found, name)
    }
  }
  vapply(unique(found), function(f) fill_template(texts$checks$inspection_call, list(FUNCTION = f)), character(1), USE.NAMES = FALSE)
}
