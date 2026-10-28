# This bot's earlier findings on a function that are still open — not
# applied suggestions and possible bugs from its open suggestion PR — for
# the prompt, each with the id Claude uses to mark repeats and judge them
# (build_submit_review_tool()). Applied changes aren't listed: they are
# already in the block Claude reviews (review_source_block()).
format_earlier_findings <- function(earlier) {
  if (length(earlier) == 0) {
    return("(none)")
  }
  lines <- vapply(earlier, function(e) {
    if (identical(e$kind, "bug")) {
      sprintf("- E%d — possible bug in the code: %s %s", e$id, e$summary, e$explanation)
    } else {
      proposed <- if (nzchar(e$proposed)) {
        sprintf(" Proposed text: \"%s\"", gsub("\\s+", " ", e$proposed))
      } else {
        ""
      }
      sprintf("- E%d — suggestion not applied, field `%s` (%s): %s%s", e$id, e$field, e$reason, e$explanation, proposed)
    }
  }, character(1))
  paste(lines, collapse = "\n")
}
