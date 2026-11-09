# The issue an earlier triage called this one a duplicate of, in full and
# with its discussion (read_related_issue()), so that an objection can be
# checked against what that issue really says and where its discussion
# ended. Found through the line format_triage_comment() writes. NULL if the
# last verdict was something else, no issue was named, or it can't be read;
# the triage still works.
read_disputed_issue <- function(category, comment, settings) {
  if (!identical(category, "duplicate") || is.null(comment)) {
    return(NULL)
  }
  found <- regmatches(comment, regexec("Possibly the same as #([0-9]+)\\.", comment))[[1]]
  if (length(found) < 2) {
    return(NULL)
  }
  read_related_issue(found[2], settings)
}
