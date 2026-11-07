# The triage comment. Its first line is the marker the gate reads
# (.github/actions/issue-triage-gate), so a change here has to go there too.
# Claude's fields go through plain_comment_text(); `bug` and `idea` get a
# spec (triage_spec_lines()), which is what gets approved. A duplicate is only
# named if it is one of the open issues Claude was shown: the number has
# to be real, since it becomes a link.
format_triage_comment <- function(answer, issue, settings) {
  text <- function(x) plain_comment_text(x, settings$max_text_chars)
  lines <- c(
    sprintf("<!-- bot-triage: %s -->", answer$category),
    sprintf("**Triage: %s.** %s", settings$categories[[answer$category]]$label, text(answer$summary)),
    triage_spec_lines(answer, settings),
    "",
    sprintf("Why: %s", text(answer$reason))
  )
  duplicate <- as.integer(answer$duplicate_of %||% 0L)
  if (duplicate %in% issue$open_issues$number) {
    lines <- c(lines, "", sprintf("Possibly the same as #%d.", duplicate))
  }
  missing <- unlist(answer$missing_information)
  if (identical(answer$category, "needs-info") && length(missing) > 0) {
    missing <- utils::head(missing, settings$max_missing_items)
    lines <- c(lines, "", "Still needed:", paste("-", vapply(missing, text, character(1), USE.NAMES = FALSE)))
  }
  hidden <- issue$hidden_text %||% 0L
  if (hidden > 0) {
    places <- if (hidden == 1) "1 place" else sprintf("%d places", hidden)
    lines <- c(lines, "", sprintf("**Note:** %s", sprintf(settings$hidden_text_note, places)))
  }
  paste(c(lines, "", sprintf("_%s_", settings$footer)), collapse = "\n")
}
