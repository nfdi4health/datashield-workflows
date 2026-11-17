# The tool of "Exists in DataSHIELD?" (prompts/methods-exists-prompt.md):
# per method its verdict, the function and a quote from its documentation
# that shows it, and a note.
build_exists_tool <- function() {
  s <- function(d) list(type = "string", description = d)
  list(
    description = "Whether DataSHIELD offers each method, with the evidence.",
    input_schema = list(
      type = "object",
      properties = list(methods = list(type = "array", items = list(
        type = "object",
        properties = list(
          id = s("The method's id as given."),
          verdict = list(type = "string", enum = list("yes", "partial", "none", "unclear")),
          `function` = s("For yes and partial: the candidate as package::function, exactly as listed; else ''."),
          quote = s("For yes and partial: words copied exactly from that function's title or description; else ''."),
          note = s("One plain sentence: what is missing (partial), what was looked for (none, unclear); may be '' for yes.")
        ),
        required = list("id", "verdict", "function", "quote", "note"),
        additionalProperties = FALSE
      ))),
      required = list("methods"),
      additionalProperties = FALSE
    )
  )
}
