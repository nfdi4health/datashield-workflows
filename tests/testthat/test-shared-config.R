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

test_that("read_config_yaml(): a project's list of mappings replaces the default list", {
  local_project_with_shared(
    c("groups:", "  - name: a", "    size: 1", "  - name: b", "    size: 2", "other: 1"),
    c("groups:", "  - name: c", "    size: 3")
  )
  cfg <- read_config_yaml("config/x.yml")
  expect_equal(cfg$groups, list(list(name = "c", size = 3L)))
  expect_equal(cfg$other, 1L)
})

test_that("read_config_yaml(): an empty default list is replaced, and `[]` empties a default list", {
  local_project_with_shared(
    c("queries: []", "pairs:", "  - server: x", "    client: y"),
    c("queries:", "  - name: q", "    term: t", "pairs: []")
  )
  cfg <- read_config_yaml("config/x.yml")
  expect_equal(cfg$queries, list(list(name = "q", term = "t")))
  expect_equal(cfg$pairs, list())
})

test_that("read_config_yaml(): nested mappings still merge key by key, scalar lists are replaced", {
  local_project_with_shared(
    c("package:", "  exceptions:", "    names: [a, b]", "    keep: yes",
      "  rules:", "    max: 3", "    min: 1", "drop: 1"),
    c("package:", "  exceptions:", "    names: [c]", "  rules:", "    max: 5",
      "  new: x", "drop: ~")
  )
  cfg <- read_config_yaml("config/x.yml")
  expect_equal(cfg$package$exceptions, list(names = "c", keep = TRUE))
  expect_equal(cfg$package$rules, list(max = 5L, min = 1L))
  expect_equal(cfg$package$new, "x")
  expect_false("drop" %in% names(cfg))
})

test_that("merge_config() replaces unnamed lists where modifyList() kept the default", {
  expect_equal(merge_config(list(a = list(list(x = 1))), list(a = list(list(x = 2)))),
               list(a = list(list(x = 2))))
  expect_equal(merge_config(list(a = list()), list(a = list(list(x = 2)))),
               list(a = list(list(x = 2))))
  expect_equal(merge_config(list(a = list(b = 1, c = 2)), list(a = list(c = 3), d = 4)),
               list(a = list(b = 1, c = 3), d = 4))
  expect_equal(merge_config(list(a = c("x", "y")), list(a = "z")), list(a = "z"))
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

test_that("a call's inputs (model, max-tokens, effort) replace its profile's; empty or 0 keep it", {
  local_project_with_shared(
    c("default:", "  anthropic:", "    model: base-model", "    max_tokens: 100",
      "test-review:", "  anthropic:", "    tool_name: submit", "    effort: high",
      "other:", "  anthropic:", "    tool_name: other"),
    path = "config/claude.yml"
  )
  withr::local_envvar(CLAUDE_MODEL_TEST_REVIEW = "input-model", CLAUDE_MAX_TOKENS_TEST_REVIEW = "9000",
                      CLAUDE_EFFORT_TEST_REVIEW = "Low")
  s <- claude_settings("test-review")$anthropic
  expect_equal(s$model, "input-model")
  expect_equal(s$max_tokens, 9000L)
  expect_equal(s$effort, "low")
  # Another call of the same run keeps its own settings.
  expect_equal(claude_settings("other")$anthropic$model, "base-model")

  withr::local_envvar(CLAUDE_MODEL_TEST_REVIEW = "", CLAUDE_MAX_TOKENS_TEST_REVIEW = "0", CLAUDE_EFFORT_TEST_REVIEW = "")
  s <- claude_settings("test-review")$anthropic
  expect_equal(s$model, "base-model")
  expect_equal(s$max_tokens, 100L)
  expect_equal(s$effort, "high")

  withr::local_envvar(CLAUDE_EFFORT_TEST_REVIEW = "extreme")
  expect_error(claude_settings("test-review"), "Unknown effort 'extreme'")
})

test_that("a profile is fitted to what its model accepts", {
  rules <- list(no_forced_tool_choice = list("new-model"), no_disabled_thinking = list("new-model"),
                server_side_fallbacks = list("big-model"), no_effort = list("old-model"))
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
  plain <- utils::modifyList(profile, list(model = "plain-model", fallbacks = NULL, betas = NULL, effort = "low"))
  expect_identical(suppressMessages(adapt_to_model(plain, rules)), plain)
  expect_null(suppressMessages(adapt_to_model(utils::modifyList(plain, list(model = "old-model")), rules))$effort)
})

test_that("the shared config's profiles all fit their models, and the rules exist", {
  cfg <- yaml::read_yaml(file.path(repo_root, "config", "claude.yml"))
  expect_true(all(c("no_forced_tool_choice", "no_disabled_thinking", "server_side_fallbacks", "no_effort") %in% names(cfg$model_rules)))
  for (profile in setdiff(names(cfg), c("default", "model_rules"))) {
    s <- utils::modifyList(cfg$default, cfg[[profile]])$anthropic
    expect_identical(suppressMessages(adapt_to_model(s, cfg$model_rules)), s, info = profile)
  }
})
