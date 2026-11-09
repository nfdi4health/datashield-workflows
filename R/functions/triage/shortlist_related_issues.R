# The first of the triage's two Claude calls: a cheap model reads the new
# issue and the other issues, open and recently closed, by title and the
# start of their text (settings$shortlist_body_chars), and names those that
# may be about the same thing. At most settings$max_related_issues numbers,
# only listed ones (any other is dropped: it must be real, since the issues
# are read and may become a link). No other issues, or a failed call: none,
# and the triage goes on without them.
shortlist_related_issues <- function(claude, issue, settings) {
  listed <- c(issue$open_issues$number, issue$closed_issues$number)
  if (length(listed) == 0) {
    return(integer(0))
  }
  body <- issue$body
  if (nchar(body) > settings$max_body_chars) {
    body <- paste0(substr(body, 1, settings$max_body_chars), "\n[... rest cut]")
  }
  prompt <- fill_template(claude$prompt, list(
    REPOSITORY = repo,
    OPEN_ISSUES = format_issue_list(issue$open_issues, settings$shortlist_body_chars),
    CLOSED_ISSUES = format_issue_list(issue$closed_issues, settings$shortlist_body_chars),
    MAX_RELATED = settings$max_related_issues,
    TITLE = issue$title,
    BODY = if (nzchar(body)) body else "(empty)"
  ))
  answer <- tryCatch(call_claude_tool(claude, build_shortlist_tool(), prompt), error = function(e) {
    message(sprintf("The shortlist failed, the triage goes on without related issues: %s", conditionMessage(e)))
    NULL
  })
  numbers <- suppressWarnings(as.integer(unlist(answer$candidates)))
  numbers <- unique(numbers[!is.na(numbers) & numbers %in% listed])
  utils::head(numbers, settings$max_related_issues)
}
