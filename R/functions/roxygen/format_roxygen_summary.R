# One-line statistic of the open roxygen findings, e.g. "8 changes applied
# · 3 not applied · 1 possible bug" — for the link comment on the
# originating PR (suggestion_summary.md) and the top of the suggestion
# PR's description. Crossed-out findings and zero counts are left out.
# `state` from merge_roxygen_findings(). Same role as
# format_test_summary() for the test workflow.
format_roxygen_summary <- function(state) {
  plural <- function(n, one, many) {
    if (n == 1) {
      return(sprintf("%d %s", n, one))
    }
    sprintf("%d %s", n, many)
  }
  n <- function(kind) {
    sum(vapply(state$entries, function(e) identical(e$kind, kind) && identical(e$status, "active"), logical(1)))
  }

  parts <- character(0)
  if (n("applied") > 0) {
    parts <- c(parts, plural(n("applied"), "change applied", "changes applied"))
  }
  if (n("dropped") > 0) {
    parts <- c(parts, sprintf("%d not applied", n("dropped")))
  }
  if (n("bug") > 0) {
    parts <- c(parts, plural(n("bug"), "possible bug", "possible bugs"))
  }
  if (length(parts) == 0) {
    return("no changes")
  }
  paste(parts, collapse = " · ")
}
