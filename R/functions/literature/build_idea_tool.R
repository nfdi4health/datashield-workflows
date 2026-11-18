# The tool of the hub's issue reading (prompts/idea-reading-prompt.md):
# whether the issue asks for a method at all, its name, a sentence on it,
# keywords for preselecting functions and similar hub issues.
build_idea_tool <- function(max_similar = 3) {
  s <- function(d) list(type = "string", description = d)
  list(
    description = "The method a hub issue asks for.",
    input_schema = list(
      type = "object",
      properties = list(
        is_method = list(type = "boolean", description = "False if the issue asks for no statistical method or analysis."),
        method = s("The method's usual name in a few words."),
        description = s("One plain sentence on what the method does."),
        keywords = list(type = "array", maxItems = 8, items = s("A word or short phrase.")),
        similar = list(type = "array", maxItems = max_similar,
          items = list(type = "integer", description = "Number of a listed issue asking for the same method."))
      ),
      required = list("is_method", "method", "description", "keywords", "similar"),
      additionalProperties = FALSE
    )
  )
}
