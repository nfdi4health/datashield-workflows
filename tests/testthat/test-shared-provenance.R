# Provenance of a bot's report: models, prompts, configs and commit, as a
# visible line and a hidden marker.

test_that("provenance_footer() reports what the run recorded", {
  withr::local_options(bot.provenance = NULL, bot.shared_root = withr::local_tempdir())
  writeLines(strrep("a", 40), file.path(getOption("bot.shared_root"), ".commit"))
  record_provenance("model", "roxygen-review", "claude-sonnet-5")
  record_provenance("prompt", "prompts/x.md", short_hash("text"))
  record_provenance("config", "config/y.yml", short_hash(list(a = 1)))
  out <- provenance_footer()
  expect_length(out, 2)
  expect_match(out[1], "claude-sonnet-5")
  expect_match(out[1], "datashield-workflows aaaaaaa")
  data <- jsonlite::fromJSON(sub("^<!-- bot-suggest-provenance: (.*) -->$", "\\1", out[2]))
  expect_equal(data$commit, strrep("a", 40))
  expect_equal(data$model$`roxygen-review`, "claude-sonnet-5")
  expect_equal(data$prompt$`prompts/x.md`, short_hash("text"))
})

test_that("short_hash() tells versions apart and keeps no '--' in the marker", {
  expect_false(identical(short_hash("a"), short_hash("b")))
  expect_equal(nchar(short_hash(list(1, 2))), 10)
  withr::local_options(bot.provenance = NULL, bot.shared_root = withr::local_tempdir())
  record_provenance("config", "a--b.yml", "x")
  expect_false(grepl("--", sub("^<!-- bot-suggest-provenance: (.*) -->$", "\\1", provenance_footer()[2]), fixed = TRUE))
})

test_that("reading a prompt or config records it", {
  withr::local_options(bot.provenance = NULL)
  read_config_yaml("config/claude.yml")
  expect_true("config/claude.yml" %in% names(getOption("bot.provenance")$config))
})
