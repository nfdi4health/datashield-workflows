# Title of a collapsible report group: "<name> (n)" with n open findings,
# plus "· k crossed out" when some of `entries` are crossed out.
group_title <- function(name, entries) {
  active <- sum(vapply(entries, function(e) identical(e$status, "active"), logical(1)))
  crossed <- length(entries) - active
  suffix <- ""
  if (crossed > 0) {
    suffix <- sprintf(" · %d crossed out", crossed)
  }
  sprintf("%s (%d%s)", name, active, suffix)
}
