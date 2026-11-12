# The subscription transport: the same tool call through Claude Code, with
# a stand-in for `claude` that records its arguments and environment.

test_that("call_claude_tool() goes through Claude Code with a subscription token and no API token", {
  dir <- withr::local_tempdir()
  log <- file.path(dir, "call.txt")
  fake <- file.path(dir, "fake-claude")
  writeLines(c(
    "#!/bin/sh",
    sprintf("printf '%%s\\n' \"$@\" > %s", log),
    sprintf("echo \"OAUTH=$CLAUDE_CODE_OAUTH_TOKEN GH=$GH_TOKEN KEY=$ANTHROPIC_API_KEY PWD=$(pwd)\" >> %s", log),
    sprintf("cat >> %s", log),
    "echo '{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"num_turns\":1,\"structured_output\":{\"title\":\"A title\"}}'"
  ), fake)
  Sys.chmod(fake, "755")
  withr::local_envvar(CLAUDE_CODE_OAUTH_TOKEN = "sub", GH_TOKEN = "gh-secret", CLAUDE_BIN = fake)
  claude <- list(config = list(tool_name = "submit_x", model = "claude-sonnet-5-5", effort = "medium"), auth = claude_auth(""))
  tool <- list(description = "Submit the review.", input_schema = list(type = "object", properties = list(title = list(type = "string")), required = list("title")))
  out <- call_claude_tool(claude, tool, list(cached = "SHARED PART", rest = "PER FUNCTION"))
  expect_equal(out$title, "A title")
  call <- readLines(log)
  expect_true(all(c("-p", "--setting-sources", "--strict-mcp-config", "--no-session-persistence", "claude-sonnet-5-5", "medium") %in% call))
  expect_false("--bare" %in% call)   # --bare ignores the OAuth token
  expect_true("--tools" %in% call && call[which(call == "--tools") + 1] == "")
  expect_true(any(grepl("^OAUTH=sub GH= KEY= PWD=.*claude-call-", call)))
  expect_true("SHARED PART" %in% call && "PER FUNCTION" %in% call)
})

test_that("read_claude_code_result() stops on errors and limits", {
  expect_error(read_claude_code_result('{"type":"result","subtype":"success","is_error":true,"result":"You have hit your limit"}'), "hit your limit")
  expect_error(read_claude_code_result("not json"), "no JSON")
})
