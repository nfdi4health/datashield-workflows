# Tool schema for Claude's classification of unclear arguments: per
# argument a role and (for objects) a class from the rules file, plus a
# one-sentence reason. Names are never Claude's: propose_ds_name() derives
# them from the classification. The schema is the same for every function
# of a run (no per-function enums; R ignores entries for arguments it
# didn't ask about), so the shared prompt part can be cached.
build_naming_classification_tool <- function(rules) {
  roles <- c(names(rules$roles), "object", "column", "value", "plumbing", "unclear")
  list(
    description = "Submit the classification of the listed arguments.",
    input_schema = list(
      type = "object",
      properties = list(
        arguments = list(
          type = "array",
          description = "One entry per listed argument.",
          items = list(
            type = "object",
            properties = list(
              arg = list(type = "string", description = "The argument name, exactly as listed."),
              role = list(type = "string", enum = as.list(roles)),
              class = list(type = "string", enum = as.list(c(names(rules$classes), "none")),
                           description = "Object class for role object; none otherwise."),
              reason = list(type = "string", description = "One sentence: what in the code or documentation shows this.")
            ),
            required = list("arg", "role", "class", "reason")
          )
        )
      ),
      required = list("arguments")
    )
  )
}
