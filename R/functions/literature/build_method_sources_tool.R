# The tool of the literature watch's Claude call: per paper the
# statistical methods it uses, each with its variant (a deviation from the
# plain method, e.g. time-varying covariates; "" for none), whether the
# abstract and the methods section name it, and whether it is the paper's
# main analysis or a secondary one.
build_method_sources_tool <- function() {
  list(
    description = "The statistical methods of each paper, with where they are named.",
    input_schema = list(
      type = "object",
      properties = list(papers = list(type = "array", items = list(
        type = "object",
        properties = list(
          id = list(type = "string", description = "The paper's id as given."),
          methods = list(type = "array", items = list(
            type = "object",
            properties = list(
              name = list(type = "string", description = "The method, in its usual short name, e.g. 'Cox regression', 'multiple imputation'."),
              variant = list(type = "string",
                description = "How the paper's use deviates from the plain method, in a few words, e.g. 'time-varying covariates', 'stratified', 'penalised (lasso)', 'random slopes'; '' for the plain method."),
              role = list(type = "string", enum = list("main", "secondary"),
                description = "main: the analysis answering the research question; secondary: e.g. imputation, sensitivity analyses, adjustment, weighting, descriptive tests."),
              in_abstract = list(type = "boolean"),
              in_methods_section = list(type = "boolean")
            ),
            required = list("name", "variant", "role", "in_abstract", "in_methods_section"),
            additionalProperties = FALSE
          ))
        ),
        required = list("id", "methods"),
        additionalProperties = FALSE
      ))),
      required = list("papers"),
      additionalProperties = FALSE
    )
  )
}
