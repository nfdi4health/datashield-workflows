# Whether a release to CRAN may go ahead: at least `min_days` since the
# last submission (CRAN policy: updates "no more than every 1–2 months"
# once a package is established). `override` (a label on the pull request)
# lets an urgent fix through, which the policy allows. Returns
# list(ok, message).
cran_wait_verdict <- function(last, today, min_days, override = FALSE) {
  if (is.null(last)) {
    return(list(ok = TRUE, message = "Not on CRAN yet: the first submission needs no waiting time."))
  }
  days <- as.integer(today - last)
  next_date <- last + min_days
  if (days >= min_days) {
    return(list(ok = TRUE, message = sprintf("Last CRAN submission %s, %d days ago (at least %d needed).", format(last), days, min_days)))
  }
  if (isTRUE(override)) {
    return(list(ok = TRUE, message = sprintf(
      "Last CRAN submission %s, only %d days ago, but the override label is set: an urgent fix may go earlier.", format(last), days)))
  }
  list(ok = FALSE, message = sprintf(
    "Last CRAN submission %s, %d days ago. CRAN asks for at least %d days between updates: wait until %s, or set the override label for an urgent fix.",
    format(last), days, min_days, format(next_date)))
}
