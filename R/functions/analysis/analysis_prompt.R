# The script prompt for `step_ids` (prompts/analysis-script-prompt.md,
# filled from `context`, see ask_claude_for_scripts()); the same text goes
# to the Messages API and to the agent.
analysis_prompt <- function(context, step_ids, previous_attempt = "") {
  gap_issues <- "(none)"
  if (nrow(context$gap_issues) > 0) {
    gap_issues <- paste(sprintf("- #%s: %s", context$gap_issues$number, context$gap_issues$title), collapse = "\n")
  }
  fill_template(context$prompt_template, list(
    CONNECTIONS        = context$connections,
    SYMBOL             = context$symbol,
    SERVERS            = paste(sprintf("`%s`", context$servers), collapse = ", "),
    FUNCTION_REFERENCE = context$function_reference,
    EXCLUDED_FUNCTIONS = context$excluded_functions %||% "(none)",
    UNTESTABLE_FUNCTIONS = context$untestable_functions %||% "(none)",
    CODE_STYLE         = context$code_style %||% "(none)",
    CATALOGUE          = context$catalogue_text,
    GAP_ISSUES         = gap_issues,
    EXISTING_STEPS     = context$existing_steps,
    CREATED_OBJECTS    = context$created_objects %||% "(none known yet)",
    PLAN               = context$plan_text,
    REQUESTED_STEPS    = paste(sprintf("`%s` (%s)", step_ids, unlist(context$numbers[step_ids])), collapse = ", "),
    MAX_LINES          = as.character(context$max_lines),
    PREVIOUS_ATTEMPT   = previous_attempt
  ))
}
