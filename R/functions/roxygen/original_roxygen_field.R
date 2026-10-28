# The existing block's content for one Claude-managed field ("title",
# "description", "details", "return", "examples" or "param:<name>"):
# `lines` are the raw roxygen lines to carry forward unchanged, `text` the
# plain prose for comparison (markers, tag label and \dontrun wrapper
# removed). An untagged title/description (roxygen's implicit first
# paragraphs) is found too, via implicit_roxygen_field(). NULL if the
# existing block has no such field.
original_roxygen_field <- function(parsed, key) {
  is_param <- startsWith(key, "param:")
  if (is_param) {
    tag <- "param"
    tag_label <- "^@param\\s+\\S+\\s*"
  } else {
    tag <- key
    tag_label <- "^@[A-Za-z]+\\s*"
  }
  chunks <- Filter(function(ch) ch$tag == tag, parsed$tag_chunks)
  if (is_param) {
    name <- sub("^param:", "", key)
    chunks <- Filter(function(ch) identical(sub("^\\s*#'\\s*@param\\s+(\\S+).*$", "\\1", ch$lines[1]), name), chunks)
  }
  if (length(chunks) == 0) {
    # No explicit tag: title and description may be roxygen's implicit
    # first paragraphs.
    if (key %in% c("title", "description")) {
      return(implicit_roxygen_field(parsed, key))
    }
    return(NULL)
  }

  lines <- chunks[[1]]$lines
  text <- sub("^\\s*#'\\s?", "", lines)
  text[1] <- sub(tag_label, "", text[1])
  text <- text[!grepl("^\\s*(\\\\dontrun\\{|\\})\\s*$", text)]
  list(lines = lines, text = paste(text, collapse = "\n"))
}
