# Finds the top-level test_that() blocks of a test file with R's own
# parser: description plus first/last line. Only these blocks can be
# updated or deleted (rewrite_test_content()); everything else in the file
# — comments, helpers, setup code — is carried forward line for line. A
# block is `editable` only if its description is unique in the file and no
# other expression shares its lines. Returns an empty list if the file
# doesn't parse.
parse_test_file <- function(content) {
  exprs <- tryCatch(parse(text = content, keep.source = TRUE), error = function(e) NULL)
  if (is.null(exprs) || length(exprs) == 0) {
    return(list())
  }
  refs <- attr(exprs, "srcref")

  blocks <- list()
  for (i in seq_along(exprs)) {
    e <- exprs[[i]]
    if (!is.call(e)) {
      next
    }
    fn <- paste(deparse(e[[1]]), collapse = "")
    if (!fn %in% c("test_that", "testthat::test_that") || length(e) < 2 || !is.character(e[[2]])) {
      next
    }

    shares_lines <- any(vapply(seq_along(refs)[-i], function(j) {
      refs[[j]][1] <= refs[[i]][3] && refs[[j]][3] >= refs[[i]][1]
    }, logical(1)))
    blocks[[length(blocks) + 1]] <- list(
      description = e[[2]], first_line = refs[[i]][1], last_line = refs[[i]][3], shares_lines = shares_lines
    )
  }

  descriptions <- vapply(blocks, function(b) b$description, character(1))
  lapply(blocks, function(b) {
    b$editable <- !b$shares_lines && sum(descriptions == b$description) == 1
    b
  })
}
