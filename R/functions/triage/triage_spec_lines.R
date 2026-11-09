# The spec part of a triage comment, for the categories in
# settings$spec_categories: goal, what was reported, acceptance criteria,
# open questions. Later the implementer's only source, so that outsiders'
# text never reaches an agent that runs commands
# (dev-notes/implementer-plan.md). Every field goes through
# plain_comment_text(), lists are cut to settings$max_spec_items, and a
# field left empty gets no heading. No lines for other categories.
triage_spec_lines <- function(answer, settings) {
  if (!answer$category %in% unlist(settings$spec_categories)) {
    return(character(0))
  }
  text <- function(x) plain_comment_text(x, settings$max_text_chars)
  section <- function(heading, items) {
    items <- utils::head(unlist(items), settings$max_spec_items)
    if (length(items) == 0) {
      return(character(0))
    }
    c("", sprintf("**%s:**", heading), paste("-", vapply(items, text, character(1), USE.NAMES = FALSE)))
  }
  goal <- answer$goal %||% ""
  c(
    if (nzchar(goal)) c("", sprintf("**Goal:** %s", text(goal))),
    section("What was reported", answer$reported),
    section("Acceptance criteria", answer$acceptance_criteria),
    section("Open questions", answer$open_questions),
    triage_disclosure_lines(answer, settings, text)
  )
}
