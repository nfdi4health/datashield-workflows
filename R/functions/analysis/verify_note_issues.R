# Checks the existing issue a "missing_function" note points to: it must
# be one of the open gap issues fetched for this run (`gap_issues`,
# fetch_gap_issues()); otherwise, or for other kinds of notes, the
# reference is cleared and the report offers a new issue instead.
# Returns `steps` with checked notes.
verify_note_issues <- function(steps, gap_issues) {
  lapply(steps, function(s) {
    s$notes <- lapply(s$notes, function(n) {
      issue <- if (is.null(n$existing_issue)) {
        ""
      } else {
        as.character(n$existing_issue)
      }
      if (nzchar(issue) && !identical(n$kind, "missing_function")) {
        message(sprintf("A %s note points to issue #%s; only missing_function notes may. Cleared.", n$kind, issue))
        n$existing_issue <- ""
      } else if (nzchar(issue) && !issue %in% as.character(gap_issues$number)) {
        message(sprintf("A note points to issue #%s, which isn't an open gap issue. Cleared.", issue))
        n$existing_issue <- ""
      }
      n
    })
    s
  })
}
