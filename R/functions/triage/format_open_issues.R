# The open issues for the prompt, so that duplicates are spotted from their
# content. Each one's text is cut to settings$max_open_issue_chars, and
# once settings$max_open_issues_chars are used up the rest get their title
# only. Newest first, as the API lists them: a small repository's issues
# all arrive whole, and a large one's cost stays bounded.
format_open_issues <- function(open_issues, settings) {
  if (nrow(open_issues) == 0) {
    return("(none)")
  }
  left <- settings$max_open_issues_chars
  lines <- character(nrow(open_issues))
  for (i in seq_len(nrow(open_issues))) {
    lines[i] <- sprintf("- #%d: %s", open_issues$number[i], open_issues$title[i])
    body <- open_issues$body[i]
    if (is.null(body) || !nzchar(body)) {
      next
    }
    if (nchar(body) > settings$max_open_issue_chars) {
      body <- paste0(substr(body, 1, settings$max_open_issue_chars), "\n[... rest cut]")
    }
    if (nchar(body) <= left) {
      left <- left - nchar(body)
      lines[i] <- sprintf("%s\n<open_issue_text>\n%s\n</open_issue_text>", lines[i], body)
    }
  }
  paste(lines, collapse = "\n")
}
