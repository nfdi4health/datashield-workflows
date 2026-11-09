# The triage comment. Its first line is the marker the gate reads
# (.github/actions/issue-triage-gate), so a change here has to go there too.
# Claude's fields go through plain_comment_text(); `bug` and `idea` get a
# spec (triage_spec_lines()), which is what gets approved. A duplicate is only
# named if it is one of the open or closed issues Claude was shown (the
# related ones are among them): the number has to be real, since it
# becomes a link. How the report compares with the documentation of the
# functions it is about gets its own line, with the files read.
format_triage_comment <- function(answer, issue, settings) {
  text <- function(x) plain_comment_text(x, settings$max_text_chars)
  lines <- c(
    sprintf("<!-- bot-triage: %s -->", answer$category),
    sprintf("**Triage: %s.** %s", settings$categories[[answer$category]]$label, text(answer$summary)),
    triage_spec_lines(answer, settings),
    "",
    sprintf("Why: %s", text(answer$reason))
  )
  verdict <- settings$documentation_verdicts[[answer$documentation %||% "none"]]
  docs <- Filter(Negate(is.null), issue$documentation %||% list())
  if (!is.null(verdict) && nzchar(verdict) && length(docs) > 0) {
    files <- paste(vapply(docs, function(x) sprintf("`%s`", x$file), character(1)), collapse = ", ")
    note <- text(answer$documentation_note %||% "")
    lines <- c(lines, "", sprintf("Documentation (%s): %s.%s", files, verdict, if (nzchar(note)) paste0(" ", note) else ""))
  }
  duplicate <- as.integer(answer$duplicate_of %||% 0L)
  if (duplicate %in% c(issue$open_issues$number, issue$closed_issues$number)) {
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
