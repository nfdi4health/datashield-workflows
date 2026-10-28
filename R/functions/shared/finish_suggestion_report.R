# Ends a bot PR's merged report (roxygen and tests): the report's lines
# (`body`), then `legacy` — the description of a bot PR from before this
# report format — collapsed, and the hidden state for the next run
# (encode_suggestion_state()). The visible part is cut to fit GitHub's
# 65536-character limit together with the state.
finish_suggestion_report <- function(body, state, legacy = NULL) {
  hidden <- encode_suggestion_state(state)
  body <- paste(body, collapse = "\n")
  room <- 62000 - nchar(hidden)
  if (!is.null(legacy)) {
    legacy <- substr(legacy, 1, max(0, min(20000, room - nchar(body) - 200)))
    if (nzchar(legacy)) {
      body <- paste0(body, "\n\n<details><summary>Earlier reports (before this report format)</summary>\n\n", legacy, "\n\n</details>")
    }
  }
  if (nchar(body) > room) {
    body <- paste0(substr(body, 1, room), "\n\n… truncated — see the job log for the rest.")
  }
  paste0(body, "\n\n", hidden)
}
