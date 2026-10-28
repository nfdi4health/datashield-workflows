# The "Latest review" line of a bot PR's merged report (roxygen and tests):
# what the run reviewing commit `latest$sha` changed — "3 new · 1 crossed
# out · 2 repeats of earlier findings skipped" (`latest$stats`, from
# merge_roxygen_findings() / merge_test_findings()). NULL without a commit
# (a sweep), so the caller leaves the line out.
format_latest_review <- function(latest) {
  if (is.null(latest) || !nzchar(latest$sha)) {
    return(NULL)
  }
  s <- latest$stats
  parts <- sprintf("%d new", s[["new"]])
  if (s[["crossed"]] > 0) {
    parts <- c(parts, sprintf("%d crossed out", s[["crossed"]]))
  }
  if (s[["repeats"]] == 1) {
    parts <- c(parts, "1 repeat of earlier findings skipped")
  } else if (s[["repeats"]] > 1) {
    parts <- c(parts, sprintf("%d repeats of earlier findings skipped", s[["repeats"]]))
  }
  sprintf("**Latest review** (`%s`): %s", latest$sha, paste(parts, collapse = " · "))
}
