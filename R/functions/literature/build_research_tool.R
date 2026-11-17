# The tool of the research step (prompts/methods-research-prompt.md): a
# short brief on one candidate.
build_research_tool <- function() {
  s <- function(d) list(type = "string", description = d)
  list(
    description = "A short brief on the method.",
    input_schema = list(
      type = "object",
      properties = list(
        description = s("Two or three plain sentences: what it does and what it is used for in health research."),
        r_packages = list(type = "array", items = list(type = "object",
          properties = list(package = s("The package's name."), `function` = s("Its main function."), note = s("A short note.")),
          required = list("package", "function", "note"), additionalProperties = FALSE)),
        federated = s("Published or possible federated approaches and what they need from the servers."),
        disclosure = s("A first view: what would leave the servers and where the disclosure risks are."),
        fit = s("Where it would fit, in one sentence."),
        sources = list(type = "array", items = list(type = "string"), description = "The URLs relied on, at most six.")
      ),
      required = list("description", "r_packages", "federated", "disclosure", "fit", "sources"),
      additionalProperties = FALSE
    )
  )
}
