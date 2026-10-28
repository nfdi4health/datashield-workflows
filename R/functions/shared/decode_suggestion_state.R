# Reads the findings an open bot PR (roxygen or tests) carries in its
# description: a hidden comment "<!-- bot-suggest-state: <base64 JSON> -->"
# written by encode_suggestion_state(). Returns list(entries, next_id,
# legacy): entries as stored (see merge_roxygen_findings(),
# merge_test_findings()), and `legacy` — the
# description without the reviewed-up-to marker — when the PR has a
# description but no state yet (opened before this report format), or the
# collapsed copy of it from an earlier run, so its text isn't lost. A
# missing or unreadable state gives an empty one.
decode_suggestion_state <- function(body) {
  empty <- list(entries = list(), next_id = 1L, legacy = NULL)
  if (is.null(body) || !nzchar(body)) {
    return(empty)
  }

  found <- regmatches(body, regexec("<!-- bot-suggest-state: ([A-Za-z0-9+/=]+) -->", body))[[1]]
  if (length(found) < 2) {
    legacy <- trimws(gsub("<!-- bot-suggest: reviewed up to [0-9a-f]+ -->", "", body))
    if (nzchar(legacy)) {
      empty$legacy <- legacy
    }
    return(empty)
  }
  state <- tryCatch(
    jsonlite::fromJSON(rawToChar(jsonlite::base64_dec(found[2])), simplifyVector = FALSE),
    error = function(e) {
      message("Could not read the suggestion state in the bot PR: ", conditionMessage(e), " — starting fresh.")
      NULL
    }
  )
  if (is.null(state)) {
    return(empty)
  }
  # Text of a pre-format description, shown collapsed by
  # format_roxygen_report(), is carried forward run after run.
  kept <- regmatches(body, regexec("(?s)<summary>Earlier reports \\(before this report format\\)</summary>\n\n(.*?)\n\n</details>", body, perl = TRUE))[[1]]
  legacy <- NULL
  if (length(kept) == 2) {
    legacy <- kept[2]
  }
  list(entries = state$entries, next_id = as.integer(state$next_id), legacy = legacy)
}
