# Tool schema for the analysis scripts. Claude returns each requested step
# as sections of plain code plus notes; R assembles the script files,
# checks the calls and runs them. Enums keep the answer inside what exists:
# step ids from the plan (`step_ids`, only the steps asked for) and, for
# "possible with another package" notes, package names from the catalogue
# (`catalogue_names`, retired packages already removed) and client
# function names from the function catalogue (`catalogue_functions`).
# Whether the function belongs to that package is checked afterwards
# (verify_note_functions()). For "missing_function" notes, the numbers of
# the open gap issues (`gap_issue_numbers`) let Claude point to an issue
# that already requests it (checked by verify_note_issues()).
build_analysis_tool <- function(step_ids, catalogue_names, catalogue_functions, gap_issue_numbers) {
  note_package <- list(type = "string", description = "For kind other_package: the catalogue package that would make this possible (server package name). Empty string otherwise.")
  if (length(catalogue_names) > 0) {
    note_package$enum <- as.list(c("", unname(catalogue_names)))
  }
  note_function <- list(type = "string", description = "For kind other_package: the client function of that package, from the catalogue list, that would do it. Empty string if none fits or for other kinds.")
  if (length(catalogue_functions) > 0) {
    note_function$enum <- as.list(c("", catalogue_functions))
  }
  note_issue <- list(type = "string", description = "For kind missing_function: the number of an open issue from the list that already requests the same missing function (same method, not just a similar topic). Empty string if none matches or for other kinds.")
  note_issue$enum <- as.list(c("", as.character(gap_issue_numbers)))

  list(
    description = "Submit the analysis script steps as plain code sections and notes. Never assemble files, headers or markers yourself; R does that.",
    input_schema = list(
      type = "object",
      properties = list(
        steps = list(
          type = "array",
          description = "One entry per requested step, in plan order.",
          items = list(
            type = "object",
            properties = list(
              step_id = list(type = "string", enum = as.list(unname(step_ids)), description = "The step's id from the plan."),
              sections = list(
                type = "array",
                description = "The step's code, split into self-contained sections of a few related calls each. Empty if nothing in the step is possible with the installed packages.",
                items = list(
                  type = "object",
                  properties = list(
                    purpose = list(type = "string", description = "One line: what this section does, for a comment above it."),
                    code = list(type = "string", description = "Plain, runnable R code. No comment header, no login or logout.")
                  ),
                  required = list("purpose", "code")
                )
              ),
              notes = list(
                type = "array",
                description = "What could not be written with the installed packages, and limitations the analyst should know.",
                items = list(
                  type = "object",
                  properties = list(
                    kind = list(type = "string", enum = list("other_package", "missing_function", "limitation"), description = "other_package: a catalogue package would make it possible. missing_function: no known DataSHIELD package offers it. limitation: possible, but restricted (e.g. no individual-level diagnostics because of disclosure control)."),
                    package = note_package,
                    `function` = note_function,
                    existing_issue = note_issue,
                    text = list(type = "string", description = "One or two sentences for the analyst: what is affected and why.")
                  ),
                  required = list("kind", "package", "function", "existing_issue", "text")
                )
              )
            ),
            required = list("step_id", "sections", "notes")
          )
        )
      ),
      required = list("steps")
    )
  )
}
