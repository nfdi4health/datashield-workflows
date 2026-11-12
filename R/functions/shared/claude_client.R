# Everything a Claude call of one kind needs, passed explicitly instead of
# read from global variables: the `anthropic` settings of a profile of
# config/claude.yml (model, tool name, thinking, effort, …), the prompt
# template (optional; a repository's own copy wins, resolve_shared_path()),
# and the run's access token (`auth`, claude_auth(), shared by the run's
# clients). Used by call_claude_tool() and the ask_claude_*() functions.
claude_client <- function(profile, prompt_file = NULL, auth = claude_auth()) {
  prompt <- NULL
  if (!is.null(prompt_file)) {
    prompt <- read_text_file(prompt_file)
  }
  config <- claude_settings(profile)$anthropic
  record_provenance("model", profile, config$model %||% "")
  list(
    config = config,
    prompt = prompt,
    auth = auth
  )
}
