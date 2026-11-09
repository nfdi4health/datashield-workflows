# Tool schema for the shortlist: the numbers of the listed issues that may
# be about the same thing, and the listed R files whose functions the issue
# is about. How many, and that they were listed, is checked in R
# (shortlist_related_issues()), since strict tools don't take maxItems.
build_shortlist_tool <- function() {
  list(
    description = "Submit the issues that may be about the same thing as the new one.",
    input_schema = list(
      type = "object",
      properties = list(
        candidates = list(
          type = "array",
          description = "Numbers of listed issues that may report or ask for the same thing, most likely first. Empty if none.",
          items = list(type = "integer")
        ),
        files = list(
          type = "array",
          description = "Names of listed R files whose functions the new issue is about, as listed (e.g. ds.table.R). Empty if none.",
          items = list(type = "string")
        )
      ),
      required = list("candidates", "files")
    )
  )
}
