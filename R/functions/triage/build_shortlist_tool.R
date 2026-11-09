# Tool schema for the shortlist: the numbers of the listed issues that may
# be about the same thing. How many is checked in R (shortlist_related_issues()),
# since strict tools don't take maxItems.
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
        )
      ),
      required = list("candidates")
    )
  )
}
