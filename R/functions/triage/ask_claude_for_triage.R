# Asks Claude to triage one issue. Returns the tool input. A very long body
# is cut first (settings$max_body_chars), which bounds what one issue can
# cost. An answer outside the categories stops the run, and no comment is
# posted: the next edit tries again.
ask_claude_for_triage <- function(claude, issue, settings) {
  body <- issue$body
  if (nchar(body) > settings$max_body_chars) {
    body <- paste0(substr(body, 1, settings$max_body_chars), "\n[... rest cut]")
  }
  meanings <- vapply(settings$categories, function(x) x$meaning, character(1))
  prompt <- fill_template(claude$prompt, list(
    REPOSITORY = repo,
    DESCRIPTION = if (nzchar(issue$repository_description)) issue$repository_description else "(none given)",
    CATEGORIES = paste(sprintf("- `%s`: %s", names(meanings), meanings), collapse = "\n"),
    OPEN_ISSUES = format_issue_list(issue$open_issues),
    CLOSED_ISSUES = format_issue_list(issue$closed_issues),
    RELATED_ISSUES = format_related_issues(issue$related),
    DOCUMENTATION = format_documentation(issue$documentation),
    DEPENDENCIES = if (nzchar(issue$dependencies %||% "")) issue$dependencies else "(no DESCRIPTION)",
    TITLE = issue$title,
    BODY = if (nzchar(body)) body else "(empty)",
    HISTORY = format_triage_history(issue, settings)
  ))
  answer <- call_claude_tool(claude, build_triage_tool(settings), prompt)
  if (!is.null(answer$documentation) && !answer$documentation %in% names(settings$documentation_verdicts)) {
    stop(sprintf("Unknown documentation verdict: %s", answer$documentation), call. = FALSE)
  }
  if (!answer$category %in% names(settings$categories)) {
    stop(sprintf("Unknown triage category: %s", answer$category), call. = FALSE)
  }
  answer
}
