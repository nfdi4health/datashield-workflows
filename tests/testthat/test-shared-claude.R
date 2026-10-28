# The Claude call mechanics shared by every workflow: prompt templates,
# the cached prompt split, strict schemas and call_claude_tool() in both
# modes (forced tool call; auto with strict tool and one retry), against a
# mocked Messages API.

test_that("fill_template() fills placeholders once and refuses missing ones", {
  expect_equal(fill_template("a {{X}} b {{Y}}", list(X = "1", Y = "{{X}}")), "a 1 b {{X}}")
  expect_error(fill_template("a {{X}} {{Z}}", list(X = "1")), "Z")
})

test_that("split_cached_prompt() splits at the marker, or returns the prompt as is", {
  p <- split_cached_prompt("shared part\n<!-- per function -->\nthis one")
  expect_equal(p, list(cached = "shared part", rest = "this one"))
  expect_equal(split_cached_prompt("no marker here"), "no marker here")
  expect_equal(split_cached_prompt("a\n<!-- per request -->\nb", "<!-- per request -->")$rest, "b")
})

test_that("strict_tool_schema() closes every object and drops unsupported keywords", {
  schema <- list(type = "object", properties = list(
    tests = list(type = "array", maxItems = 3, items = list(type = "object", properties = list(code = list(type = "string", minLength = 1))))
  ))
  s <- strict_tool_schema(schema)
  expect_true(s$ok)
  expect_false(s$schema$additionalProperties)
  expect_false(s$schema$properties$tests$items$additionalProperties)
  expect_null(s$schema$properties$tests$maxItems)
  expect_null(s$schema$properties$tests$items$properties$code$minLength)
  expect_false(strict_tool_schema(list(type = "object"))$ok)  # a free-form map can't be strict
})

# A client as claude_client() builds it, without reading config files.
claude_config <- function(choice = "tool", model = "claude-opus-5", strict = NULL) {
  config <- list(model = model, max_tokens = 1000, api_version = "2023-06-01", thinking = list(type = "adaptive"),
                 tool_name = "submit_x", tool_choice_type = choice, strict = strict)
  list(config = config, auth = claude_auth("test"))
}
x_tool <- list(description = "d", input_schema = list(type = "object", properties = list(
  items = list(type = "array", maxItems = 2, items = list(type = "string"))
)))
tool_use <- list(list(type = "tool_use", id = "t1", name = "submit_x", input = list(ok = TRUE)))
text_only <- list(list(type = "thinking", thinking = "", signature = "sig"), list(type = "text", text = "prose"))

# Mocked API: answers in turn, records each request body.
mock_api <- function(answers, sent) {
  i <- 0
  function(req) {
    i <<- i + 1
    sent$bodies[[i]] <- request_body(req)
    claude_response(answers[[i]]$content, answers[[i]]$stop_reason)
  }
}

test_that("a forced call names the tool and sends it strict", {
  sent <- new.env()
  res <- httr2::with_mocked_responses(mock_api(list(list(content = tool_use, stop_reason = "tool_use")), sent),
                                      call_claude_tool(claude_config("tool"), x_tool, "the prompt"))
  b <- sent$bodies[[1]]
  expect_true(res$ok)
  expect_equal(b$tool_choice, list(type = "tool", name = "submit_x"))
  expect_true(b$tools[[1]]$strict)
  expect_null(b$tools[[1]]$input_schema$properties$items$maxItems)
  expect_length(b$messages[[1]]$content, 1)   # no extra instruction when the call is forced
})

test_that("strict: false in a profile sends the schema unchanged", {
  sent <- new.env()
  httr2::with_mocked_responses(mock_api(list(list(content = tool_use, stop_reason = "tool_use")), sent),
                               call_claude_tool(claude_config("tool", strict = FALSE), x_tool, "p"))
  expect_null(sent$bodies[[1]]$tools[[1]]$strict)
  expect_equal(sent$bodies[[1]]$tools[[1]]$input_schema$properties$items$maxItems, 2)
})

test_that("auto mode sends a strict tool, an instruction, and keeps the cache marker", {
  sent <- new.env()
  httr2::with_mocked_responses(mock_api(list(list(content = tool_use, stop_reason = "tool_use")), sent),
                               call_claude_tool(claude_config("auto", "claude-opus-5-5"), x_tool, list(cached = "shared", rest = "mine")))
  b <- sent$bodies[[1]]
  expect_equal(b$tool_choice, list(type = "auto"))
  expect_true(b$tools[[1]]$strict)
  expect_null(b$tools[[1]]$input_schema$properties$items$maxItems)
  expect_false(b$tools[[1]]$input_schema$additionalProperties)
  content <- b$messages[[1]]$content
  expect_length(content, 3)
  expect_equal(content[[1]]$cache_control$type, "ephemeral")
  expect_match(content[[3]]$text, "submit_x tool")
})

test_that("auto mode asks once more after a text answer, appending to the conversation", {
  sent <- new.env()
  res <- httr2::with_mocked_responses(
    mock_api(list(list(content = text_only, stop_reason = "end_turn"), list(content = tool_use, stop_reason = "tool_use")), sent),
    suppressMessages(call_claude_tool(claude_config("auto"), x_tool, "p"))
  )
  expect_true(res$ok)
  second <- sent$bodies[[2]]
  expect_equal(vapply(second$messages, function(m) m$role, ""), c("user", "assistant", "user"))
  expect_equal(second$messages[[1]], sent$bodies[[1]]$messages[[1]])  # first turn unchanged
  expect_equal(second$messages[[2]]$content[[1]]$signature, "sig")    # thinking replayed as is
})

test_that("two text answers in auto mode, max_tokens and a refusal stop with clear errors", {
  expect_error(httr2::with_mocked_responses(
    mock_api(list(list(content = text_only, stop_reason = "end_turn"), list(content = text_only, stop_reason = "end_turn")), new.env()),
    suppressMessages(call_claude_tool(claude_config("auto"), x_tool, "p"))), "No tool_use")
  expect_error(httr2::with_mocked_responses(mock_api(list(list(content = tool_use, stop_reason = "max_tokens")), new.env()),
                                            suppressMessages(call_claude_tool(claude_config(), x_tool, "p"))), "max_tokens")
  expect_error(httr2::with_mocked_responses(mock_api(list(list(content = list(), stop_reason = "refusal")), new.env()),
                                            suppressMessages(call_claude_tool(claude_config(), x_tool, "p"))), "declined")
})

test_that("claude_client() reads a profile and its prompt; clients share a renewed token", {
  withr::local_dir(repo_root)
  auth <- claude_auth("old")
  a <- claude_client("test-review", "prompts/test-review-prompt.md", auth)
  b <- claude_client("test-failure-classification", NULL, auth)
  expect_equal(a$config$tool_name, "submit_tests")
  expect_equal(b$config$tool_name, "submit_failure_classification")
  expect_match(a$prompt, "testthat tests")
  a$auth$api_key <- "renewed"
  expect_equal(b$auth$api_key, "renewed")
})
