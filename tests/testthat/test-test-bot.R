# Pieces of the test bot that run code or touch the package: generated
# tests without credentials, packages added to Suggests, the summary line,
# and fetching the bot branch.

local_mini_package <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  dir.create(file.path(dir, "R"))
  dir.create(file.path(dir, "tests", "testthat"), recursive = TRUE)
  writeLines(c("Package: minipkg", "Version: 0.1", "Title: t", "Description: t.", "License: MIT",
               "Imports: jsonlite", "Suggests: testthat (>= 3.0.0)"), file.path(dir, "DESCRIPTION"))
  writeLines("export(add1)", file.path(dir, "NAMESPACE"))
  writeLines("add1 <- function(x) x + 1", file.path(dir, "R", "add1.R"))
  dir
}

test_that("run_test_blocks() runs tests in a separate process without credentials", {
  dir <- local_mini_package()
  writeLines(c(
    'test_that("adds one", { expect_equal(add1(1), 2) })',
    'test_that("sees no token", { expect_equal(Sys.getenv("ANTHROPIC_API_KEY"), ""); expect_equal(Sys.getenv("GH_TOKEN"), "") })',
    'test_that("fails on purpose", { expect_equal(add1(1), 3) })',
    'leaked <- TRUE'
  ), file.path(dir, "tests", "testthat", "test-add1.R"))
  withr::local_dir(dir)
  withr::local_envvar(ANTHROPIC_API_KEY = "secret", GH_TOKEN = "ghs_secret")
  res <- run_test_blocks("tests/testthat/test-add1.R", "minipkg")
  expect_equal(vapply(res, function(r) r$passed, logical(1)), c(TRUE, TRUE, FALSE))
  expect_match(res[[3]]$message, "3")
  expect_false(exists("leaked", envir = globalenv()))
  expect_equal(Sys.getenv("ANTHROPIC_API_KEY"), "secret")  # the bot keeps its own
})

test_that("declare_test_packages() adds undeclared packages to Suggests, once", {
  dir <- local_mini_package()
  writeLines(c('test_that("a", {', '  d <- withr::local_tempdir()', '  library(mockery)',
               '  requireNamespace("digest", quietly = TRUE)', '  stats::sd(1:2); jsonlite::toJSON(1); minipkg::add1(1)', '})'),
             file.path(dir, "tests", "testthat", "test-a.R"))
  withr::local_dir(dir)
  expect_setequal(declare_test_packages("minipkg", "tests/testthat/test-a.R"), c("withr", "mockery", "digest"))
  expect_length(declare_test_packages("minipkg", "tests/testthat/test-a.R"), 0)
  state <- merge_test_findings(list(entries = list(), next_id = 1L), "", list(dependencies = c("withr")), sha = "abc")$state
  expect_match(format_test_summary(state), "added to Suggests: `withr`")
})

test_that("fetch_bot_branch() fetches without a token, and builds a one-line header with one", {
  dir <- withr::local_tempdir()
  bare <- file.path(dir, "remote.git")
  git <- function(...) system2("git", c(...), stdout = FALSE, stderr = FALSE)
  git("init", "-q", "--bare", shQuote(bare))
  git("clone", "-q", shQuote(bare), shQuote(file.path(dir, "work")))
  withr::local_dir(file.path(dir, "work"))
  writeLines("x", "f.txt")
  git("add", "f.txt")
  git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "c")
  git("push", "-q", "origin", "HEAD:refs/heads/bot-suggest/tests/dev")
  withr::local_envvar(GH_TOKEN = "")
  expect_equal(fetch_bot_branch("bot-suggest/tests/dev"), "refs/remotes/origin/bot-suggest/tests/dev")
  withr::local_envvar(GH_TOKEN = strrep("a", 93))  # a local remote ignores the header
  expect_equal(fetch_bot_branch("bot-suggest/tests/dev"), "refs/remotes/origin/bot-suggest/tests/dev")
})

test_that("obvious_failure_classification() decides parse errors, missing functions and packages", {
  expect_equal(obvious_failure_classification("<text>:2:5: unexpected symbol")$category, "bad_test")
  expect_match(obvious_failure_classification('could not find function "ds.nothing"')$explanation, "ds.nothing")
  expect_equal(obvious_failure_classification("there is no package called 'dsX'")$category, "env_misconfiguration")
  expect_null(obvious_failure_classification("Expected `x` to equal 3."))
})

test_that("classify_failures() sends only the open failures, in one call, and maps the answers back", {
  claude <- list(config = list(model = "claude-opus-5", max_tokens = 1000, api_version = "2023-06-01",
                               thinking = list(type = "adaptive"), tool_name = "submit_failure_classification",
                               tool_choice_type = "tool"),
                 prompt = paste(readLines(file.path(repo_root, "prompts", "test-failure-classification-prompt.md")), collapse = "\n"),
                 auth = claude_auth("test"))
  items <- list(list(block = "t1", message = "Expected 2, got 3"),
                list(block = "t2", message = "<text>:1:3: unexpected symbol"),
                list(block = "t3", message = "Expected TRUE"))
  calls <- 0
  prompt_text <- ""
  answer <- list(list(type = "tool_use", id = "x", name = "submit_failure_classification", input = list(failures = list(
    list(failure = "F2", explanation = "e3", category = "real_bug", confidence = "high"),
    list(failure = "F1", explanation = "e1", category = "bad_test", confidence = "medium")))))
  res <- httr2::with_mocked_responses(function(req) {
    calls <<- calls + 1
    prompt_text <<- request_body(req)$messages[[1]]$content[[1]]$text
    claude_response(answer)
  }, suppressMessages(classify_failures(claude, items, "f <- function() 1", "f")))
  expect_equal(calls, 1)
  expect_match(prompt_text, "### F2")
  expect_false(grepl("t2", prompt_text))                # the obvious one isn't sent
  expect_equal(res[[1]]$category, "bad_test")
  expect_equal(res[[2]]$category, "bad_test")           # from R
  expect_equal(res[[3]][c("category", "confidence")], list(category = "real_bug", confidence = "high"))
})

test_that("review_test_file() keeps passing new tests, classifies failing ones once, and records both", {
  dir <- local_mini_package()
  withr::local_dir(dir)
  calls <- 0
  local_global_mock(
    ask_claude_for_tests = function(...) list(
      needs_tests = TRUE, existing_tests = list(), earlier_findings = list(),
      tests = list(
        list(description = "adds one to a number", reason = "edge_case", setup_code = "", assertions_code = "expect_equal(add1(1), 2)"),
        list(description = "adds one to zero", reason = "edge_case", setup_code = "", assertions_code = "expect_equal(add1(0), 5)")
      )
    ),
    classify_failures = function(claude, items, ...) {
      calls <<- calls + 1
      lapply(items, function(i) list(category = "bad_test", confidence = "high", explanation = "wrong expectation"))
    }
  )
  ctx <- list(
    review_claude = NULL, classification_claude = NULL, bot_tests = list(materialized = character(0), user_edited = character(0)),
    reviewed_sha = "abc1234", base_rev = "", datashield = FALSE, ds_type = "", may_use_dslite = FALSE,
    dslite_setup_mode = "auto", dslite_datasets = NULL,
    test_role_guidance = yaml::read_yaml(file.path(repo_root, "config", "test-role-guidance.yml")),
    scheme = detect_test_scheme("add1"), category_meanings = NULL, test_data = "", cache_prompt = FALSE,
    max_new_tests = 10L, accept_reasons = suggestion_reasons("tests"), code_issue_confidence = c("high", "medium"),
    package_name = "minipkg", issue_confidence = "high", comment_failures = FALSE
  )
  out <- review_files("R/add1.R", decode_suggestion_state(NULL), function(f, parsed, state) review_test_file(f, parsed, state, ctx))
  expect_equal(out$updated, "tests/testthat/test-add1.R")
  expect_equal(out$results[[1]]$new_kept, 1)
  expect_equal(calls, 1)
  written <- readLines("tests/testthat/test-add1.R")
  expect_true(any(grepl("adds one to a number", written, fixed = TRUE)))
  expect_false(any(grepl("adds one to zero", written, fixed = TRUE)))
  kinds <- vapply(out$state$entries, `[[`, "", "kind")
  expect_setequal(kinds, c("new", "failed"))
})

test_that("a function's real-bug tests go into its issue together; an open issue only gets the test names", {
  posted <- list()
  local_global_mock(post_issue_once = function(title, body, context, comment = body) {
    posted[[length(posted) + 1]] <<- list(title = title, body = body, comment = comment)
    "https://github.com/o/r/issues/42"
  })
  findings <- list(
    list(description = "counts for Study1", block = "test_that('a', {})", message = "Error A", explanation = "Bad predicate."),
    list(description = "levels of Study3", block = "test_that('b', {})", message = "Error B", explanation = "Same cause.")
  )
  url <- create_bug_issue("ds.tableBatch", findings)

  expect_equal(url, "https://github.com/o/r/issues/42")
  expect_length(posted, 1)
  p <- posted[[1]]
  expect_equal(p$title, "Possible bug found by generated test: ds.tableBatch")
  expect_match(p$body, "^2 tests written by the test suggestion workflow failed against `ds.tableBatch`")
  expect_equal(lengths(regmatches(p$body, gregexpr("written by the test suggestion workflow", p$body))), 1)
  expect_match(p$body, "### counts for Study1", fixed = TRUE)
  expect_match(p$body, "<details><summary>Generated test and failure output</summary>", fixed = TRUE)
  expect_equal(p$comment, "Still failing in a later review (2 tests):\n\n- counts for Study1\n- levels of Study3")
})
