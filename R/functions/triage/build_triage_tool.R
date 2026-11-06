# Tool schema for the triage: a category from config/issue-triage.yml and
# short fields. Claude only fills these in; the comment is written in R
# (format_triage_comment()), and its limits are checked there.
build_triage_tool <- function(settings) {
  list(
    description = "Submit the triage of the issue.",
    input_schema = list(
      type = "object",
      properties = list(
        category = list(type = "string", enum = as.list(names(settings$categories))),
        summary = list(type = "string", description = "One sentence: what the issue asks for, in your own words."),
        reason = list(type = "string", description = "One sentence: why this category."),
        missing_information = list(
          type = "array",
          description = "For needs-info: what is missing, as short questions. Otherwise empty.",
          items = list(type = "string")
        ),
        duplicate_of = list(type = "integer", description = "For duplicate: the number of the open issue. Otherwise 0.")
      ),
      required = list("category", "summary", "reason", "missing_information", "duplicate_of")
    )
  )
}
