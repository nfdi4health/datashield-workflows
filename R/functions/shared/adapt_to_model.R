# Fits the `anthropic` settings of a profile to what its model accepts,
# from `rules` (`model_rules` in config/claude.yml): a model that rejects a
# forced tool call gets tool_choice "auto" (call_claude_tool() then asks
# for the tool in the prompt; the tool stays strict, so its fields still
# match the schema); one that can't run with thinking disabled gets
# adaptive thinking; server-side fallbacks (and their beta header) are
# dropped for a model that doesn't offer them, and so is effort for a model
# that rejects it. A model in no list is sent
# as the profile says. Each change is logged, since it changes the cost.
adapt_to_model <- function(anthropic, rules) {
  model <- anthropic$model %||% ""
  listed <- function(key) model %in% unlist(rules[[key]])
  if (listed("no_forced_tool_choice") && !identical(anthropic$tool_choice_type, "auto")) {
    anthropic$tool_choice_type <- "auto"
    message(sprintf("%s rejects forced tool calls: tool_choice auto.", model))
  }
  if (listed("no_disabled_thinking") && identical(anthropic$thinking$type, "disabled")) {
    anthropic$thinking <- list(type = "adaptive")
    message(sprintf("%s can't run with thinking disabled: adaptive thinking.", model))
  }
  if (listed("no_effort") && !is.null(anthropic$effort)) {
    anthropic$effort <- NULL
    message(sprintf("%s takes no effort setting: sent without one.", model))
  }
  if (!is.null(anthropic$fallbacks) && length(rules$server_side_fallbacks) > 0 && !listed("server_side_fallbacks")) {
    anthropic$fallbacks <- NULL
    anthropic$betas <- Filter(function(b) !startsWith(b, "server-side-fallback"), unlist(anthropic$betas))
    if (length(anthropic$betas) == 0) {
      anthropic$betas <- NULL
    }
    message(sprintf("%s has no server-side fallback: sent without one.", model))
  }
  anthropic
}
