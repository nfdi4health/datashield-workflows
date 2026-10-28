# Records the user's checkbox choices (read_suggestion_choices()) in the
# findings state: `choice` TRUE/FALSE on each finding that is a choice
# (suggestion_choice() not "none"). Run by both bots before they rebuild
# the description, so a choice made in between isn't lost, and by
# apply_suggestion_choices.R, which then makes the files match. Returns
# the state.
record_suggestion_choices <- function(state, choices) {
  if (length(choices) == 0) {
    return(state)
  }
  state$entries <- lapply(state$entries, function(e) {
    id <- as.character(e$id)
    if (!identical(suggestion_choice(e), "none") && id %in% names(choices)) {
      e$choice <- unname(choices[[id]])
    }
    e
  })
  state
}
