# Lets Claude Code write the requested step(s) as an agent: the same
# prompt as the API call plus the agent's part (prompts/analysis-agent.md),
# the answer in the same shape (`tool$input_schema` via --json-schema).
# Unlike the single call, the agent can try its code first: the only
# command it may run is the try helper (R/try_analysis_code.R), which runs
# the DSLite setup, the scripts before this step and the agent's file, and
# prints what happens. Everything runs in Claude Code's sandbox (no network;
# agent_settings()), without the checkout's settings, hooks, plugins or MCP
# servers (claude_code_isolation_args(); not --bare, which reads neither
# the OAuth token nor ANTHROPIC_AUTH_TOKEN).
#
# `context$agent` holds: bin (the claude command), model, effort,
# max_turns, timeout_seconds, deny (paths no tool may read), env (the
# auth variable for Claude Code only), login_file, profile, connections,
# helper (path of the try helper), template (the agent part).
ask_agent_for_scripts <- function(context, prompt, tool) {
  a <- context$agent
  dir <- ".agent"
  dir.create(dir, showWarnings = FALSE)
  dir.create("results", showWarnings = FALSE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  jsonlite::write_json(tool$input_schema, file.path(dir, "schema.json"), auto_unbox = TRUE, null = "null")
  jsonlite::write_json(agent_settings(a$deny), file.path(dir, "settings.json"), auto_unbox = TRUE, pretty = TRUE)
  jsonlite::write_json(list(login_file = a$login_file, profile = a$profile, scripts_before = as.list(context$scripts_before %||% character(0))),
    file.path(dir, "try-context.json"), auto_unbox = TRUE)
  agent_part <- fill_template(a$template, list(HELPER = a$helper, CONNECTIONS = context$connections))
  writeLines(c(prompt, "", agent_part), file.path(dir, "prompt.md"))

  args <- c("-p", claude_code_isolation_args(), "--output-format", "json", "--no-session-persistence",
    "--json-schema", paste(readLines(file.path(dir, "schema.json"), warn = FALSE), collapse = ""),
    "--settings", file.path(dir, "settings.json"),
    "--tools", "Read,Write,Edit,Glob,Grep,Bash",
    "--allowedTools", sprintf("Read,Glob,Grep,Edit(./%1$s/**),Bash(Rscript %2$s:*)", dir, a$helper),
    "--permission-mode", "dontAsk",
    "--max-turns", as.character(a$max_turns))
  if (nzchar(a$model %||% "")) args <- c(args, "--model", a$model)
  if (nzchar(a$effort %||% "")) args <- c(args, "--effort", a$effort)

  # Claude Code gets only its own credential; the try helper's R session
  # gets none (CLAUDE_CODE_SUBPROCESS_ENV_SCRUB, and the blanked list).
  blank_names <- setdiff(credential_variables(), names(a$env))
  blank <- setNames(rep("", length(blank_names)), blank_names)
  env <- c(blank, a$env, CLAUDE_CODE_SUBPROCESS_ENV_SCRUB = "1", "current")
  run <- processx::run(a$bin, args, stdin = file.path(dir, "prompt.md"), env = env,
    timeout = a$timeout_seconds, error_on_status = FALSE)
  if (isTRUE(run$timeout)) {
    stop(sprintf("Claude Code took longer than %s seconds and was stopped.", a$timeout_seconds), call. = FALSE)
  }
  if (nzchar(run$stderr)) {
    message(substr(run$stderr, 1, 2000))
  }
  result <- read_claude_code_result(run$stdout)
  log_claude_code_usage(result, "analysis agent")
  result$structured_output
}
