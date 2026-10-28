# Sends the script request to Claude and returns the tool call's steps.
# `context` holds what every request shares: the prompt template
# (prompts/analysis-script-prompt.md), plan text, symbol, connections,
# servers, function reference, catalogue text, package and function
# names, open gap issues, the run's step ids (`all_step_ids`, for a tool
# schema that is the same for every call), line limit and file number per
# step — and, per step (draft_steps_in_order()), the scripts that run
# before it and the objects on the servers. `step_ids` are the steps to
# write; `previous_attempt` is empty on the first call and, in a repair
# round, describes the failed attempt (code and errors) for those steps.
# The part of the prompt up to "<!-- per request -->" is the same for all
# calls of a run and is sent with a cache marker (split_cached_prompt()):
# a run makes a call per step plus repair rounds, minutes apart.
ask_claude_for_scripts <- function(context, step_ids, previous_attempt = "") {
  gap_issues <- "(none)"
  if (nrow(context$gap_issues) > 0) {
    gap_issues <- paste(sprintf("- #%s: %s", context$gap_issues$number, context$gap_issues$title), collapse = "\n")
  }
  prompt <- fill_template(context$prompt_template, list(
    CONNECTIONS        = context$connections,
    SYMBOL             = context$symbol,
    SERVERS            = paste(sprintf("`%s`", context$servers), collapse = ", "),
    FUNCTION_REFERENCE = context$function_reference,
    EXCLUDED_FUNCTIONS = context$excluded_functions %||% "(none)",
    CATALOGUE          = context$catalogue_text,
    GAP_ISSUES         = gap_issues,
    EXISTING_STEPS     = context$existing_steps,
    CREATED_OBJECTS    = context$created_objects %||% "(none known yet)",
    PLAN               = context$plan_text,
    REQUESTED_STEPS    = paste(sprintf("`%s` (%s)", step_ids, unlist(context$numbers[step_ids])), collapse = ", "),
    MAX_LINES          = as.character(context$max_lines),
    PREVIOUS_ATTEMPT   = previous_attempt
  ))
  tool <- build_analysis_tool(context$all_step_ids %||% step_ids, context$catalogue_names, context$catalogue_functions, context$gap_issues$number)
  result <- call_claude_tool(context$claude, tool, split_cached_prompt(prompt, "<!-- per request -->"))
  # The tool is strict (call_claude_tool()), so `steps` is an array of
  # step objects; the check stays for profiles with `strict: false`.
  steps <- result$steps
  if (!is.list(steps) || !all(vapply(steps, is.list, logical(1)))) {
    stop(sprintf("Claude's answer has an unexpected shape for 'steps': %s",
                 paste(utils::capture.output(utils::str(steps, max.level = 1)), collapse = " ")), call. = FALSE)
  }
  Filter(function(s) s$step_id %in% step_ids, steps)
}
