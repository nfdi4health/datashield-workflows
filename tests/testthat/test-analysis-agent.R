# The analysis agent: Claude Code's settings, reading its JSON result, and
# one call through ask_agent_for_scripts() with a stand-in for `claude`
# that records its arguments, prompt and environment.

test_that("agent_settings() denies the login file and .Renviron to tools and sandbox", {
  s <- agent_settings(c("R/01_DS_Login.R", ".Renviron", ""))
  expect_setequal(unlist(s$permissions$deny), c("Read(./R/01_DS_Login.R)", "Read(./.Renviron)", "Edit(./R/01_DS_Login.R)", "Edit(./.Renviron)"))
  expect_true(s$sandbox$enabled)
  expect_false(s$sandbox$allowUnsandboxedCommands)
  expect_length(s$sandbox$network$allowedDomains, 0)
  expect_length(s$sandbox$filesystem$denyRead, 2)
  expect_length(s$sandbox$filesystem$allowWrite, 2)
})

test_that("read_agent_result() returns the structured output or stops", {
  ok <- '{"type":"result","subtype":"success","is_error":false,"num_turns":3,"usage":{"input_tokens":10,"output_tokens":5},"structured_output":{"steps":[{"step_id":"a"}]}}'
  expect_equal(read_agent_result(ok)$steps[[1]]$step_id, "a")
  expect_error(read_agent_result('{"type":"result","subtype":"error_max_turns","is_error":true,"result":"limit"}'), "error_max_turns")
  expect_error(read_agent_result('{"type":"result","subtype":"success","is_error":false}'), "without an answer")
  expect_error(read_agent_result("You've hit your limit"), "no JSON")
})

test_that("ask_agent_for_scripts() calls claude locked down and without other credentials", {
  dir <- withr::local_tempdir()
  withr::local_dir(dir)
  log <- file.path(dir, "claude-call.txt")
  fake <- file.path(dir, "fake-claude")
  writeLines(c(
    "#!/bin/sh",
    sprintf("printf '%%s\\n' \"$@\" > %s", log),
    sprintf("echo \"OAUTH=$CLAUDE_CODE_OAUTH_TOKEN GH=$GH_TOKEN SCRUB=$CLAUDE_CODE_SUBPROCESS_ENV_SCRUB\" >> %s", log),
    sprintf("cat >> %s", log),
    "echo '{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"structured_output\":{\"steps\":[{\"step_id\":\"a\"}]}}'"
  ), fake)
  Sys.chmod(fake, "755")
  withr::local_envvar(GH_TOKEN = "secret-gh")
  context <- list(connections = "conns", scripts_before = "R/02_x.R", agent = list(
    bin = fake, model = "claude-opus-5", effort = "high", max_turns = 7, timeout_seconds = 60,
    deny = c("R/01_DS_Login.R", ".Renviron"), env = c(CLAUDE_CODE_OAUTH_TOKEN = "sub-token"),
    login_file = "utils/setup/01_DSLite_Setup.R", profile = "testing",
    helper = ".shared-workflows/R/try_analysis_code.R", template = "Run Rscript {{HELPER}} with {{CONNECTIONS}}."))
  tool <- list(input_schema = list(type = "object", properties = list(steps = list(type = "array"))))
  out <- ask_agent_for_scripts(context, "THE PROMPT", tool)
  expect_equal(out$steps[[1]]$step_id, "a")
  call <- readLines(log)
  expect_true(all(c("-p", "--bare", "--no-session-persistence", "dontAsk", "7", "claude-opus-5", "high") %in% call))
  expect_true(any(grepl("Bash(Rscript .shared-workflows/R/try_analysis_code.R:*)", call, fixed = TRUE)))
  expect_true("OAUTH=sub-token GH= SCRUB=1" %in% call)
  expect_true("THE PROMPT" %in% call)
  expect_true(any(grepl("Run Rscript .shared-workflows/R/try_analysis_code.R with conns.", call, fixed = TRUE)))
  # The temporary files are gone afterwards.
  expect_false(dir.exists(".agent"))
})
