# The first of the triage's two Claude calls: a cheap model reads the new
# issue, the other issues, open and recently closed, by title and the
# start of their text (settings$shortlist_body_chars), and the names of the
# package's R files (issue$r_files). It names the issues that may be about
# the same thing (at most settings$max_related_issues) and the files whose
# functions the issue is about (at most settings$max_documented_functions),
# both read afterwards. Only listed numbers and files are kept: anything
# else is dropped, since it is fetched and may become a link. Nothing to
# choose from, or a failed call: none, and the triage goes on without them.
# Returns list(issues, files).
shortlist_related_issues <- function(claude, issue, settings) {
  none <- list(issues = integer(0), files = character(0))
  listed <- c(issue$open_issues$number, issue$closed_issues$number)
  files <- issue$r_files %||% character(0)
  if (length(listed) == 0 && length(files) == 0) {
    return(none)
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
    R_FILES = if (length(files) > 0) paste(files, collapse = ", ") else "(none)",
    MAX_FUNCTIONS = settings$max_documented_functions,
    TITLE = issue$title,
    BODY = if (nzchar(body)) body else "(empty)"
  ))
  answer <- tryCatch(call_claude_tool(claude, build_shortlist_tool(), prompt), error = function(e) {
    message(sprintf("The shortlist failed, the triage goes on without related issues: %s", conditionMessage(e)))
    NULL
  })
  if (is.null(answer)) {
    return(none)
  }
  numbers <- suppressWarnings(as.integer(unlist(answer$candidates)))
  numbers <- unique(numbers[!is.na(numbers) & numbers %in% listed])
  chosen <- unique(as.character(unlist(answer$files)))
  chosen <- chosen[chosen %in% files]
  list(
    issues = utils::head(numbers, settings$max_related_issues),
    files = utils::head(chosen, settings$max_documented_functions)
  )
}
