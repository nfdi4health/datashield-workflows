# The one short comment a PR run posts on the author's PR when this run
# found possible bugs in the code (`bugs`: the bug entries of the run,
# merge_test_findings()) while a suggestion PR carries the report
# (`sub_branch`, its branch): which functions, how sure, the issue where
# one was opened — no test code, which stays in the report. NULL when
# there is nothing to say. Failed tests that are the test's own fault are
# never commented (user, 2026-11-12: comments with code don't get read).
possible_bugs_comment <- function(bugs, sub_branch) {
  if (length(bugs) == 0) {
    return(NULL)
  }
  lines <- vapply(bugs, function(b) {
    issue <- if (nzchar(b$issue %||% "")) sprintf(", issue %s", b$issue) else ""
    sprintf("- `%s()` (%s confidence%s): \"%s\"", b$fn, b$confidence, issue, b$description)
  }, character(1))
  where <- if (nzchar(sub_branch)) sprintf("the description of the test suggestions pull request (`%s`)", sub_branch) else "the test report"
  paste(c(
    sprintf("**Test suggestions:** %d possible %s in the code, found while testing. Nothing in the code was changed.",
            length(bugs), if (length(bugs) == 1) "bug" else "bugs"),
    "",
    lines,
    "",
    sprintf("Details in %s.", where)
  ), collapse = "\n")
}
