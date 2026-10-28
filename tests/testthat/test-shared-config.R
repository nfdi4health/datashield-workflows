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
})
