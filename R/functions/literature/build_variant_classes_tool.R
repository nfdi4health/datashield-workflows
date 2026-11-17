# The tool of the vocabulary's variant classification
# (prompts/methods-variants-prompt.md): per wording its variant key (and
# name, for a new one), or the method it is in its own right, or that it
# isn't a variant.
build_variant_classes_tool <- function() {
  s <- function(d) list(type = "string", description = d)
  list(
    description = "What each new variant wording is.",
    input_schema = list(
      type = "object",
      properties = list(variants = list(type = "array", items = list(
        type = "object",
        properties = list(
          variant = s("The wording exactly as given."),
          not_a_variant = list(type = "boolean"),
          own_method = list(type = "boolean", description = "TRUE when it would need its own DataSHIELD function."),
          variant_key = s("If not own_method: an existing variant key or a new one (lower case, hyphens); else ''."),
          variant_name = s("For a new variant key: two to four words; else ''."),
          method_key = s("If own_method: an existing method key or a new one; else ''."),
          method_name = s("For a new method key: its usual name; else ''."),
          description = s("For a new method key: one plain sentence; else ''."),
          keywords = list(type = "array", items = list(type = "string"),
            description = "For a new method key: three to eight lower-case words; else empty.")
        ),
        required = list("variant", "not_a_variant", "own_method", "variant_key", "variant_name", "method_key",
          "method_name", "description", "keywords"),
        additionalProperties = FALSE
      ))),
      required = list("variants"),
      additionalProperties = FALSE
    )
  )
}
