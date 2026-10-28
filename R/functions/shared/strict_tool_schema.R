# A tool's input schema in the form strict tool use accepts (`strict: true`,
# needed on models without forced tool calls, see call_claude_tool()):
# every object gets `additionalProperties: false`, and keywords strict mode
# doesn't support (array sizes, string lengths, number ranges) are removed —
# R checks those itself (e.g. ask_claude_for_tests() caps new tests).
# Returns list(schema, ok); ok is FALSE when an object has no declared
# properties (a free-form map strict mode can't express), and the tool is
# then sent without `strict`.
strict_tool_schema <- function(schema) {
  unsupported <- c("maxItems", "minItems", "maxLength", "minLength", "minimum", "maximum",
                   "exclusiveMinimum", "exclusiveMaximum", "multipleOf")
  ok <- TRUE
  convert <- function(x) {
    if (!is.list(x)) {
      return(x)
    }
    if (!is.null(names(x))) {
      x <- x[setdiff(names(x), unsupported)]
      if (identical(x$type, "object")) {
        if (is.null(x$properties)) {
          ok <<- FALSE
        }
        x$additionalProperties <- FALSE
      }
    }
    for (i in seq_along(x)) {
      if (is.list(x[[i]])) {
      x[[i]] <- convert(x[[i]])
    }
    }
    x
  }
  list(schema = convert(schema), ok = ok)
}
