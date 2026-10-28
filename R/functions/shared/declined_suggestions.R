# The suggestions the user declined for one reviewed file (`file`: the R
# file for roxygen, matched by `fn` for tests), which this run must not
# propose again — as long as the code is unchanged. A declined finding
# whose fingerprint (code_fingerprint(), stored as `code`) differs from
# `fingerprint` is crossed out ("superseded: the code changed"), so the
# suggestion may come back. `match` picks the findings of this file:
# function(e) TRUE/FALSE. Returns list(state, declined): the declined
# findings still in force.
declined_suggestions <- function(state, match, fingerprint, sha) {
  declined <- list()
  state$entries <- lapply(state$entries, function(e) {
    if (!identical(suggestion_choice(e), "declined") || !isTRUE(match(e))) {
      return(e)
    }
    if (!is.null(e$code) && !identical(e$code, fingerprint)) {
      e$status <- "superseded"
      e$status_sha <- sha
      e$status_note <- "declined, but the code changed since"
      return(e)
    }
    declined[[length(declined) + 1]] <<- e
    e
  })
  list(state = state, declined = declined)
}
