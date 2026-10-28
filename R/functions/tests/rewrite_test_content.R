# Rebuilds a test file's content from the original: blocks named in
# `updates` (a named character vector, description -> complete new
# test_that() text) are replaced in place, blocks named in `deletes` are
# removed, `appended` (new test_that() texts) go after line
# `insert_after` of the original (test_insert_line()), or at the end when
# it is NULL. All other lines stay exactly as they were. `blocks` comes
# from parse_test_file().
rewrite_test_content <- function(original, blocks, updates = character(0), deletes = character(0), appended = character(0), insert_after = NULL) {
  lines <- if (nzchar(original)) {
    strsplit(original, "\n", fixed = TRUE)[[1]]
  } else {
    character(0)
  }
  targets <- Filter(function(b) b$description %in% c(names(updates), deletes), blocks)
  starts <- vapply(targets, function(b) b$first_line, numeric(1))
  inserted <- c("", unlist(strsplit(paste(appended, collapse = "\n\n"), "\n", fixed = TRUE)))

  out <- character(0)
  i <- 1
  while (i <= length(lines)) {
    k <- match(i, starts)
    if (is.na(k)) {
      out <- c(out, lines[i])
      if (length(appended) > 0 && identical(as.numeric(i), as.numeric(insert_after))) {
        out <- c(out, inserted)
      }
      i <- i + 1
      next
    }
    b <- targets[[k]]
    i <- b$last_line + 1
    if (b$description %in% names(updates)) {
      out <- c(out, strsplit(updates[[b$description]], "\n", fixed = TRUE)[[1]])
    } else if (length(out) == 0 || !nzchar(trimws(out[length(out)]))) {
      # Deleted: also drop the blank line that separated it from the next block.
      while (i <= length(lines) && !nzchar(trimws(lines[i]))) {
        i <- i + 1
      }
    }
    if (length(appended) > 0 && identical(as.numeric(b$last_line), as.numeric(insert_after))) {
      out <- c(out, inserted)
    }
  }

  content <- sub("\\s+$", "", paste(out, collapse = "\n"))
  if (length(appended) > 0 && is.null(insert_after)) {
    parts <- appended
    if (nzchar(content)) {
      parts <- c(content, appended)
    }
    content <- paste(parts, collapse = "\n\n")
  }
  content
}
