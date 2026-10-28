# Asks Claude to classify the unclear arguments (`rows`) of one function
# (`def`, from read_r_definitions()). `linked` names the client/server
# counterparts, as context. Returns the tool input's `arguments` list.
# With `cache` (the run makes more than one call) the rules part of the
# prompt is sent with a cache marker (split_cached_prompt()).
ask_claude_for_naming <- function(claude, def, rows, rules, linked = character(0), cache = FALSE) {
  bullet <- function(items) paste(sprintf("- `%s`: %s", names(items), vapply(items, function(x) x$description %||% "", character(1))), collapse = "\n")
  source <- def$source
  if (nchar(source) > 12000) {
    source <- paste0(substr(source, 1, 12000), "\n# ... (rest cut)")
  }
  args_text <- paste(sprintf("- `%s` (default: %s): %s", rows$arg, ifelse(nzchar(rows$default), rows$default, "none"),
                             ifelse(nzchar(rows$doc), rows$doc, "(undocumented)")), collapse = "\n")
  linked_text <- ""
  if (length(linked) > 0) {
    linked_text <- paste0("\nServer/client counterparts: ", paste(linked, collapse = "; "), "\n")
  }
  prompt <- fill_template(claude$prompt, list(
    ROLES = bullet(rules$roles),
    CLASSES = bullet(rules$classes),
    PACKAGE = rows$package[1],
    SIDE = rows$side[1],
    FUNCTION_SOURCE = source,
    ARGUMENTS = args_text,
    LINKED = linked_text
  ))
  sent <- if (cache) {
    split_cached_prompt(prompt)
  } else {
    sub("<!-- per function -->\n", "", prompt, fixed = TRUE)
  }
  call_claude_tool(claude, build_naming_classification_tool(rules), sent)$arguments
}
