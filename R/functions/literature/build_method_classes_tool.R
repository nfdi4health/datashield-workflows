# The tool of the vocabulary's name classification
# (prompts/methods-classification-prompt.md): per name its method key, the
# variant the name implies, and for a new key its name, description and
# keywords; or that it isn't a method.
build_method_classes_tool <- function() {
  s <- function(d) list(type = "string", description = d)
  list(
    description = "Which method each new name is.",
    input_schema = list(
      type = "object",
      properties = list(names = list(type = "array", items = list(
        type = "object",
        properties = list(
          name = s("The name exactly as given."),
          not_a_method = list(type = "boolean"),
          method_key = s("An existing key, or a new one (lower case, hyphens); '' if not a method."),
          implied_variant = s("The variant the name itself carries, two to four words; '' for none."),
          method_name = s("For a new key: the method's usual name; else ''."),
          description = s("For a new key: one plain sentence on what the method does; else ''."),
          keywords = list(type = "array", items = list(type = "string"),
            description = "For a new key: three to eight lower-case words a function implementing it would likely use; else empty.")
        ),
        required = list("name", "not_a_method", "method_key", "implied_variant", "method_name", "description", "keywords"),
        additionalProperties = FALSE
      ))),
      required = list("names"),
      additionalProperties = FALSE
    )
  )
}
