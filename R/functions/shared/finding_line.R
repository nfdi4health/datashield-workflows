# One report list item for a stored finding (merge_roxygen_findings(),
# merge_test_findings()):
# "- <text> _(1b4922c)_", with the commit it came from. A crossed-out
# finding shows only `short`, struck through, with when and why:
# "- ~~<short>~~ _(1b4922c · superseded in ed1fbb9: the code changed)_".
finding_line <- function(e, text, short = text) {
  origin <- character(0)
  if (nzchar(e$sha)) {
    origin <- e$sha
  }

  if (identical(e$status, "active")) {
    if (length(origin) > 0) {
      return(sprintf("- %s _(%s)_", text, origin))
    }
    return(paste("-", text))
  }

  change <- e$status
  if (nzchar(e$status_sha)) {
    change <- paste(change, "in", e$status_sha)
  }
  if (nzchar(e$status_note)) {
    change <- paste0(change, ": ", e$status_note)
  }
  sprintf("- ~~%s~~ _(%s)_", short, paste(c(origin, change), collapse = " · "))
}
