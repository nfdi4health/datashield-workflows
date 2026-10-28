# roxygen's implicit title and description: text before the first tag,
# where the first paragraph is the title and the second the description
# (paragraphs separated by blank #' lines). Returned like
# original_roxygen_field(), with the tag made explicit (`@title` /
# `@description`, the project convention) and the text unchanged. NULL if
# the block has no such paragraph.
implicit_roxygen_field <- function(parsed, key) {
  body <- sub("^\\s*#'\\s?", "", parsed$roxygen_lines)
  first_tag <- which(grepl("^@[A-Za-z]", body))[1]
  intro <- if (is.na(first_tag)) {
    body
  } else {
    body[seq_len(first_tag - 1)]
  }

  paragraphs <- list()
  current <- character(0)
  for (line in c(intro, "")) {
    if (nzchar(trimws(line))) {
      current <- c(current, line)
    } else if (length(current) > 0) {
      paragraphs[[length(paragraphs) + 1]] <- current
      current <- character(0)
    }
  }

  index <- switch(key, title = 1, description = 2)
  if (length(paragraphs) < index) {
    return(NULL)
  }
  text <- paragraphs[[index]]
  lines <- sprintf("#' @%s %s", key, text[1])
  if (length(text) > 1) {
    lines <- c(lines, paste0("#' ", text[-1]))
  }
  list(lines = lines, text = paste(text, collapse = "\n"))
}
