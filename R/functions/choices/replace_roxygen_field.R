# A function's roxygen lines with one field replaced by `new_lines`
# (empty: removed), all other lines unchanged. The field is found as
# original_roxygen_field() finds it: its tag's lines (parse_r_file()'s
# tag_chunks), or an untagged title/description paragraph. A field the
# block doesn't have yet is inserted by `tag_order` (roxygen-style.yml):
# a parameter after the last @param, anything else before the first tag
# that comes later in the order, else at the end.
replace_roxygen_field <- function(parsed, key, new_lines, tag_order) {
  lines <- parsed$roxygen_lines
  body <- sub("^\\s*#'\\s?", "", lines)
  starts <- which(grepl("^@[A-Za-z]", body))
  chunk_range <- function(i) starts[i] + seq_along(parsed$tag_chunks[[i]]$lines) - 1

  is_param <- startsWith(key, "param:")
  tag <- if (is_param) {
    "param"
  } else {
    key
  }
  range <- integer(0)
  for (i in seq_along(parsed$tag_chunks)) {
    ch <- parsed$tag_chunks[[i]]
    if (!identical(ch$tag, tag)) {
      next
    }
    if (is_param && !identical(sub("^\\s*#'\\s*@param\\s+(\\S+).*$", "\\1", ch$lines[1]), sub("^param:", "", key))) {
      next
    }
    range <- chunk_range(i)
    break
  }
  if (length(range) == 0 && key %in% c("title", "description")) {
    # An untagged paragraph before the first tag.
    implicit <- implicit_roxygen_field(parsed, key)
    if (!is.null(implicit)) {
      target <- strsplit(implicit$text, "\n", fixed = TRUE)[[1]]
      intro_end <- if (length(starts) > 0) {
        starts[1] - 1
      } else {
        length(lines)
      }
      for (s in seq_len(max(0, intro_end - length(target) + 1))) {
        if (identical(body[s:(s + length(target) - 1)], target)) {
          range <- s:(s + length(target) - 1)
          break
        }
      }
    }
  }

  if (length(range) > 0) {
    out <- c(lines[seq_len(range[1] - 1)], new_lines, lines[seq_along(lines) > range[length(range)]])
  } else if (length(new_lines) == 0) {
    return(lines)
  } else {
    order <- unlist(tag_order)
    chunk_tags <- vapply(parsed$tag_chunks, function(ch) ch$tag, character(1))
    position <- NULL
    if (is_param && any(chunk_tags == "param")) {
      position <- max(chunk_range(max(which(chunk_tags == "param"))))
    } else {
      later <- which(vapply(chunk_tags, function(t) isTRUE(match(t, order) > match(tag, order)), logical(1)))
      if (length(later) > 0) {
        position <- starts[later[1]] - 1
      }
    }
    if (is.null(position)) {
      position <- length(lines)
    }
    out <- append(lines, new_lines, after = position)
  }
  # No doubled empty #' lines where a field was removed.
  empty <- grepl("^\\s*#'\\s*$", out)
  out[!(empty & c(FALSE, empty[-length(empty)]))]
}
