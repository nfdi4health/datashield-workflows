# Threshold for roxygen suggestions (see dev-notes/suggestion-thresholds.md):
# a field Claude changed is accepted only if its stated reason is in
# accept_reasons AND its text differs from the existing one by more than
# whitespace, punctuation or case. Fields Claude changed without listing
# them aren't accepted either, nor are listed changes without text (Claude
# returns only the changed fields, build_submit_review_tool()). Returns `accepted` (field keys), plus
# `applied` and `dropped` change records (field, reason, explanation,
# proposed text, for dropped ones why, and the earlier finding a change
# repeats) for the PR description; every
# dropped change is also logged.
accepted_roxygen_fields <- function(result, parsed, accept_reasons, path) {
  normalize <- function(x) trimws(gsub("[[:space:][:punct:]]+", " ", tolower(paste(x, collapse = " "))))
  record <- function(change, why = NULL) {
    list(field = change$field, reason = change$reason, explanation = change$explanation %||% "",
         proposed = roxygen_field_text(result, change$field), why = why,
         repeats_earlier = change$repeats_earlier %||% "")
  }
  out <- list(accepted = character(0), applied = list(), dropped = list())

  for (change in result$changes) {
    key <- change$field
    # Claude returns only the fields it changes; a change listed without
    # its text would otherwise empty the field (or delete an optional one).
    if (is.null(roxygen_field_text(result, key))) {
      message(sprintf("%s: dropping change to '%s' — listed as changed, but no text was returned.", path, key))
      next
    }
    if (!isTRUE(change$reason %in% accept_reasons)) {
      message(sprintf("%s: dropping change to '%s' — reason '%s' is not accepted.", path, key, change$reason))
      out$dropped[[length(out$dropped) + 1]] <- record(change, sprintf("reason `%s` is not accepted", change$reason))
      next
    }
    original <- original_roxygen_field(parsed, key)
    if (!is.null(original) && identical(normalize(original$text), normalize(roxygen_field_text(result, key)))) {
      message(sprintf("%s: dropping change to '%s' — only whitespace, punctuation or case differ.", path, key))
      next
    }
    if (!key %in% out$accepted) {
      out$accepted <- c(out$accepted, key)
      out$applied[[length(out$applied) + 1]] <- record(change)
    }
  }
  out
}
