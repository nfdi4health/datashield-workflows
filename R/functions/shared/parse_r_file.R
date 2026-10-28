# Parses a single R file to locate its (first) function definition and the
# roxygen block immediately preceding it (if any), plus enough structural
# detail (name, params, the blank-line gap between block and function, the
# existing block's tag lines) for both suggestion workflows to build their
# review requests and write results back. The definition and its
# arguments come from read_r_definitions() (R's own parser), so a file
# that doesn't parse counts as having no function.
parse_r_file <- function(path) {
  lines <- readLines(path, warn = FALSE)
  defs <- read_r_definitions(path)
  if (length(defs) == 0) {
    return(NULL)
  }
  if (length(defs) > 1) {
    warning(sprintf(
      "%s: found %d function definitions; only checking the first. Convention assumes one per file.",
      path, length(defs)
    ))
  }
  fn_start <- defs[[1]]$line
  fn_name <- defs[[1]]$name
  params <- defs[[1]]$args

  gap_end <- fn_start - 1
  while (gap_end >= 1 && !nzchar(trimws(lines[gap_end]))) {
    gap_end <- gap_end - 1
  }

  rox_end <- gap_end
  rox_start <- rox_end
  while (rox_start >= 1 && grepl("^\\s*#'", lines[rox_start])) {
    rox_start <- rox_start - 1
  }
  rox_start <- rox_start + 1
  has_roxygen <- rox_start <= rox_end
  roxygen_lines <- if (has_roxygen) {
    lines[rox_start:rox_end]
  } else {
    character(0)
  }

  # Without a block, it "starts" at the function and ends just above it.
  if (has_roxygen) {
    roxygen_start <- rox_start
    roxygen_end <- rox_end
    pre_end <- rox_start - 1
  } else {
    roxygen_start <- fn_start
    roxygen_end <- fn_start - 1
    pre_end <- fn_start - 1
  }
  gap_lines <- if (has_roxygen && (rox_end + 1) <= (fn_start - 1)) {
    lines[(rox_end + 1):(fn_start - 1)]
  } else {
    character(0)
  }

  body_text <- if (length(roxygen_lines) > 0) {
    sub("^\\s*#'\\s?", "", roxygen_lines)
  } else {
    character(0)
  }
  is_exported <- any(grepl("^@export\\b", body_text))

  # Each tag together with its continuation lines (everything up to the next
  # @tag, as roxygen itself reads them), kept as the original raw lines so
  # they can be carried forward byte-for-byte. Trailing blank lines are
  # dropped; text before the first tag (an untagged title/description) isn't
  # part of any chunk.
  tag_chunks <- list()
  for (i in seq_along(body_text)) {
    if (grepl("^@[A-Za-z]", body_text[i])) {
      tag_chunks[[length(tag_chunks) + 1]] <- list(
        tag = sub("^@([A-Za-z][A-Za-z0-9]*).*$", "\\1", body_text[i]),
        text = body_text[i],
        lines = roxygen_lines[i]
      )
    } else if (length(tag_chunks) > 0) {
      n <- length(tag_chunks)
      tag_chunks[[n]]$text  <- c(tag_chunks[[n]]$text, body_text[i])
      tag_chunks[[n]]$lines <- c(tag_chunks[[n]]$lines, roxygen_lines[i])
    }
  }
  tag_chunks <- lapply(tag_chunks, function(ch) {
    last_content <- max(which(nzchar(trimws(ch$text))))
    list(tag = ch$tag, lines = ch$lines[seq_len(last_content)])
  })

  list(
    lines = lines, fn_start = fn_start, fn_name = fn_name, params = params,
    has_roxygen = has_roxygen,
    roxygen_start = roxygen_start,
    roxygen_end = roxygen_end,
    roxygen_lines = roxygen_lines,
    pre_end = pre_end,
    gap_lines = gap_lines,
    is_exported = is_exported,
    tag_chunks = tag_chunks
  )
}
