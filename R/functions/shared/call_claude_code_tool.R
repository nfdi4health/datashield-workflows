# The same tool call as call_claude_tool(), through Claude Code on a
# Claude subscription (CLAUDE_CODE_OAUTH_TOKEN) instead of the Messages
# API: one source of truth for the work (prompt, tool schema, profile),
# two transports (dev-notes/claude-subscription-auth.md, "Subscription
# pathway"). Claude Code runs locked down so it behaves like one call: no
# tools at all (--tools ""), no CLAUDE.md, hooks or plugins (--bare), an
# empty working directory, its answer checked against the tool's schema
# (--json-schema). It gets only its own credential. What doesn't carry
# over: the cache marker (the prompt is sent as one text), server-side
# fallback, our retry rules; a usage limit ends the call with an error,
# which the callers treat like any failed call (a retry note).
call_claude_code_tool <- function(claude, tool, prompt, bin = Sys.getenv("CLAUDE_BIN", "claude"),
                                  timeout = 900) {
  config <- claude$config
  text <- if (is.list(prompt)) paste(prompt$cached, prompt$rest, sep = "\n\n") else prompt
  text <- paste0(text, "\n\nAnswer with the structured output only: ", tool$description %||% "")
  dir <- tempfile("claude-call-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  schema_file <- file.path(dir, "schema.json")
  jsonlite::write_json(tool$input_schema, schema_file, auto_unbox = TRUE, null = "null")
  prompt_file <- file.path(dir, "prompt.md")
  writeLines(text, prompt_file, useBytes = TRUE)

  args <- c("-p", "--bare", "--output-format", "json", "--no-session-persistence",
    "--tools", "", "--max-turns", "3",
    "--json-schema", paste(readLines(schema_file, warn = FALSE), collapse = ""))
  if (nzchar(config$model %||% "")) args <- c(args, "--model", config$model)
  if (nzchar(config$effort %||% "")) args <- c(args, "--effort", config$effort)
  token <- Sys.getenv("CLAUDE_CODE_OAUTH_TOKEN")
  blank <- setdiff(credential_variables(), "CLAUDE_CODE_OAUTH_TOKEN")
  env <- c(setNames(rep("", length(blank)), blank), CLAUDE_CODE_OAUTH_TOKEN = token, "current")
  run <- processx::run(bin, args, stdin = prompt_file, env = env, wd = dir,
    timeout = timeout, error_on_status = FALSE)
  if (isTRUE(run$timeout)) {
    stop(sprintf("Claude Code took longer than %s seconds.", timeout), call. = FALSE)
  }
  result <- read_claude_code_result(run$stdout)
  log_claude_code_usage(result, config$tool_name %||% "call")
  result$structured_output
}
