local_project_with_shared <- function(shared, own = NULL, path = "config/x.yml", env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  dir.create(file.path(dir, ".shared-workflows", dirname(path)), recursive = TRUE)
  writeLines(shared, file.path(dir, ".shared-workflows", path))
  if (!is.null(own)) {
    dir.create(file.path(dir, dirname(path)), recursive = TRUE, showWarnings = FALSE)
    writeLines(own, file.path(dir, path))
  }
  withr::local_options(bot.shared_root = ".shared-workflows", .local_envir = env)
  withr::local_dir(dir, .local_envir = env)
}

test_that("read_config_yaml() merges a project's copy key by key; lists are replaced", {
  local_project_with_shared(
    c("a:", "  keep: 1", "  change: old", "list: [x, y]", "added_later: yes"),
    c("a:", "  change: new", "list: [z]")
  )
  cfg <- read_config_yaml("config/x.yml")
  expect_equal(cfg$a, list(keep = 1L, change = "new"))
  expect_equal(cfg$list, "z")
  expect_true(cfg$added_later)
})

test_that("read_config_yaml(): missing file stops, unless not required", {
  local_project_with_shared("a: 1")
  expect_null(read_config_yaml("config/missing.yml", required = FALSE))
  expect_error(read_config_yaml("config/missing.yml"), "Config not found")
})

test_that("claude_settings() merges default, profile and the project's copy", {
  local_project_with_shared(
    c("default:", "  anthropic:", "    model: base-model", "    max_tokens: 100",
      "review:", "  anthropic:", "    max_tokens: 200", "    tool_name: submit"),
    c("review:", "  anthropic:", "    model: own-model"),
    path = "config/claude.yml"
  )
  s <- claude_settings("review")$anthropic
  expect_equal(s$model, "own-model")
  expect_equal(s$max_tokens, 200L)
  expect_equal(s$tool_name, "submit")
  expect_error(claude_settings("nope"), "No profile 'nope'")
  expect_error(claude_settings("model_rules"), "No profile 'model_rules'")
})

test_that("the inputs model and max-tokens replace the profile's; empty or 0 keep it", {
  local_project_with_shared(
    c("default:", "  anthropic:", "    model: base-model", "    max_tokens: 100",
      "review:", "  anthropic:", "    tool_name: submit"),
    path = "config/claude.yml"
  )
  withr::local_envvar(CLAUDE_MODEL = "input-model", CLAUDE_MAX_TOKENS = "9000")
  s <- claude_settings("review")$anthropic
  expect_equal(s$model, "input-model")
  expect_equal(s$max_tokens, 9000L)
  withr::local_envvar(CLAUDE_MODEL = "", CLAUDE_MAX_TOKENS = "0")
  s <- claude_settings("review")$anthropic
  expect_equal(s$model, "base-model")
  expect_equal(s$max_tokens, 100L)
})

test_that("a profile is fitted to what its model accepts", {
  rules <- list(no_forced_tool_choice = list("new-model"), no_disabled_thinking = list("new-model"),
                server_side_fallbacks = list("big-model"))
  profile <- list(model = "new-model", tool_choice_type = "tool", thinking = list(type = "disabled"),
                  fallbacks = "default", betas = list("server-side-fallback-2026-07-01", "other-beta"))
  expect_message(fitted <- adapt_to_model(profile, rules), "rejects forced tool calls")
  expect_equal(fitted$tool_choice_type, "auto")
  expect_equal(fitted$thinking, list(type = "adaptive"))
  expect_null(fitted$fallbacks)
  expect_equal(fitted$betas, "other-beta")

  big <- adapt_to_model(utils::modifyList(profile, list(model = "big-model", thinking = list(type = "adaptive"))), rules)
  expect_equal(big$tool_choice_type, "tool")
  expect_equal(big$fallbacks, "default")
  expect_length(big$betas, 2)

  # A model in no list is sent as the profile says.
  old <- utils::modifyList(profile, list(model = "old-model", fallbacks = NULL, betas = NULL))
  expect_identical(suppressMessages(adapt_to_model(old, rules)), old)
})

test_that("the shared config's profiles all fit their models, and the rules exist", {
  cfg <- yaml::read_yaml(file.path(repo_root, "config", "claude.yml"))
  expect_true(all(c("no_forced_tool_choice", "no_disabled_thinking", "server_side_fallbacks") %in% names(cfg$model_rules)))
  for (profile in setdiff(names(cfg), c("default", "model_rules"))) {
    s <- utils::modifyList(cfg$default, cfg[[profile]])$anthropic
    expect_identical(suppressMessages(adapt_to_model(s, cfg$model_rules)), s, info = profile)
  }
})
