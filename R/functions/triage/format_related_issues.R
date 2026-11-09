# The shortlisted issues for the triage prompt, each with its discussion
# (read_related_issue()). "(none)" when the shortlist found nothing.
format_related_issues <- function(related) {
  related <- Filter(Negate(is.null), related)
  if (length(related) == 0) {
    return("(none)")
  }
  paste(vapply(related, function(x) {
    sprintf("<related_issue number=\"%d\" state=\"%s\">\n%s\n\n%s\n</related_issue>", x$number, x$state, x$title, x$text)
  }, character(1)), collapse = "\n\n")
}
