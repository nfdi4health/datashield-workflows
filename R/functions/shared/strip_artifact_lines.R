# Defense in depth for Claude-supplied fields: drops every line matching
# `pattern` — syntax the model was told not to produce (roxygen comment
# markers/tag labels in doc fields, markdown code fences in test code) —
# before assembly, and says so, since it means the model echoed context
# instead of following the field's instructions. Callers hard-fail on
# required fields that end up empty.
strip_artifact_lines <- function(text, pattern, what, field_name, context) {
  if (is.null(text)) {
    return("")
  }
  lines <- strsplit(text, "\n")[[1]]
  is_artifact <- grepl(pattern, lines)
  if (any(is_artifact)) {
    message(sprintf("%s: field '%s' contained %s — stripping before assembly.", context, field_name, what))
    lines <- lines[!is_artifact]
  }
  paste(lines, collapse = "\n")
}
