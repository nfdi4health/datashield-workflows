# Whether a finding of a bot PR is a choice the user makes by checkbox
# (dev-notes/suggestion-choices.md), and how it is ticked:
# - "ticked": applied — a new, updated or deleted test, an applied roxygen
#   change, unless the user unticked it; a not-applied roxygen suggestion
#   the user ticked;
# - "declined": the user unticked an applied one (the bots remember it,
#   declined_suggestions());
# - "unticked": a roxygen suggestion that wasn't applied (reason not
#   accepted) and wasn't ticked;
# - "none": not a choice (a note, a possible bug, a failed test, or a
#   crossed-out finding).
# `e$choice` (TRUE/FALSE) is the user's choice, recorded from the boxes by
# record_suggestion_choices(); without it, the default applies.
suggestion_choice <- function(e) {
  if (!identical(e$status, "active") || !isTRUE(e$kind %in% c("new", "updated", "deleted", "applied", "dropped"))) {
    return("none")
  }
  applied_by_default <- !identical(e$kind, "dropped")
  ticked <- if (is.null(e$choice)) {
    applied_by_default
  } else {
    isTRUE(e$choice)
  }
  if (ticked) {
    "ticked"
  } else if (applied_by_default) {
    "declined"
  } else {
    "unticked"
  }
}
