# A prefilled "Open issue" link for a function no known DataSHIELD package
# offers. The analyst opens the issue under their own account, after
# seeing what gets published, so no token is needed and nothing about the
# project is posted automatically. Only the note on what is missing goes
# into the issue by default (`texts$issue`), not the plan and not the
# step's title, which can reveal a research question (the hub
# nfdi4health/datashield-function-ideas asks for the method only).
# With `texts$issue$template` set, the link opens that issue form and
# fills its fields by id (`texts$issue$fields`); without it, a plain issue
# with `texts$issue$body`.
gap_issue_link <- function(repo, step_title, note_text, texts) {
  values <- list(STEP = step_title, NOTE = note_text)
  title <- fill_template(texts$issue$title, list(STEP = step_title, NOTE = substr(note_text, 1, 80)))
  enc <- function(x) utils::URLencode(x, reserved = TRUE)
  template <- texts$issue$template %||% ""
  query <- if (nzchar(template)) {
    fields <- vapply(texts$issue$fields %||% list(), function(f) fill_template(f, values), character(1))
    c(template = template, title = title, fields)
  } else {
    c(title = title, body = fill_template(texts$issue$body, values))
  }
  sprintf("https://github.com/%s/issues/new?%s", repo, paste(names(query), vapply(query, enc, character(1)), sep = "=", collapse = "&"))
}
