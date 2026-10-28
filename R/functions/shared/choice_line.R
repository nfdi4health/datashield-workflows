# A report line for a finding that is a choice (suggestion_choice()): a
# checkbox the user ticks or unticks, with the hidden id the choices
# workflow reads back (read_suggestion_choices()):
# "- [x] <text> _(1b4922c)_ <!-- choice:E12 -->"; a declined one says so:
# "- [ ] <text> _(1b4922c · declined)_ <!-- choice:E12 -->". Any other
# finding is a plain line (finding_line()).
choice_line <- function(e, text, short = text) {
  choice <- suggestion_choice(e)
  if (identical(choice, "none")) {
    return(finding_line(e, text, short))
  }
  notes <- character(0)
  if (nzchar(e$sha)) {
    notes <- c(notes, e$sha)
  }
  if (identical(choice, "declined")) {
    notes <- c(notes, "declined")
  }

  box <- " "
  if (identical(choice, "ticked")) {
    box <- "x"
  }
  suffix <- ""
  if (length(notes) > 0) {
    suffix <- sprintf(" _(%s)_", paste(notes, collapse = " · "))
  }
  sprintf("- [%s] %s%s <!-- choice:E%d -->", box, text, suffix, as.integer(e$id))
}
