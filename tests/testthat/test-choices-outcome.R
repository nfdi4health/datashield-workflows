# The outcome record of a closed bot PR: per finding the final box, the
# outcome, and whether an accepted suggestion was edited before merging.

local_git_repo <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  withr::local_dir(dir, .local_envir = env)
  system2("git", c("init", "-q", "-b", "main"))
  system2("git", c("config", "user.email", "t@example.org"))
  system2("git", c("config", "user.name", "t"))
  dir
}
commit <- function(file, lines) {
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  writeLines(lines, file)
  system2("git", c("add", "-A"))
  system2("git", c("commit", "-q", "-m", "x"))
  trimws(system2("git", c("rev-parse", "HEAD"), stdout = TRUE))
}

test_that("finding_outcome() sees a test edited before merging", {
  local_git_repo()
  bot <- commit("tests/testthat/test-f.R", c('test_that("f works", {', '  expect_equal(f(1), 2)', '})'))
  final <- commit("tests/testthat/test-f.R", c('test_that("f works", {', '  expect_equal(f(1), 2)', '  expect_equal(f(2), 3)', '})'))
  e <- list(id = 4L, kind = "new", fn = "f", file = "tests/testthat/test-f.R", description = "f works", reason = "untested")
  out <- finding_outcome(e, "ticked", TRUE, final, bot)
  expect_equal(out$outcome, "accepted")
  expect_true(out$edited)
  expect_match(out$final, "f\\(2\\)")
  unchanged <- finding_outcome(e, "ticked", TRUE, bot, bot)
  expect_false(unchanged$edited)
  expect_null(unchanged$final)
  expect_equal(finding_outcome(e, "declined", TRUE, final, bot)$outcome, "declined")
  expect_equal(finding_outcome(e, "ticked", FALSE, final, bot)$outcome, "closed")
})

test_that("finding_outcome() compares a roxygen field with the proposed text", {
  local_git_repo()
  rev <- commit("R/f.R", c("#' @title Add one", "#' @param x A number, rounded first.", "#' @export", "f <- function(x) x + 1"))
  e <- list(id = 1L, kind = "applied", file = "R/f.R", field = "param:x", proposed = "A number.", reason = "missing")
  out <- finding_outcome(e, "ticked", TRUE, rev, rev)
  expect_true(out$edited)
  expect_equal(out$proposed, "A number.")
  expect_match(out$final, "rounded")
  e$proposed <- "A number, rounded first."
  expect_false(finding_outcome(e, "ticked", TRUE, rev, rev)$edited)
})

test_that("match_review_comments() attaches people's comments by file", {
  entries <- list(list(id = 1L, file = "R/a.R"), list(id = 2L, file = "R/b.R"))
  comments <- list(
    list(path = "R/a.R", line = 3, body = "wrong: x can be NA", user = list(login = "ana", type = "User")),
    list(path = "R/a.R", line = 4, body = "auto", user = list(login = "bot", type = "Bot")))
  out <- match_review_comments(comments, entries)
  expect_equal(names(out), "1")
  expect_equal(out[["1"]][[1]]$author, "ana")
})

test_that("encode_outcome_record() stays within its limit", {
  big <- list(findings = list(list(id = 1L, proposed = strrep("a", 30000), final = strrep("b", 30000))),
              comments = list(`1` = list(list(body = "c"))))
  out <- encode_outcome_record(big, max_chars = 20000)
  expect_lte(nchar(out), 20000)
  json <- rawToChar(jsonlite::base64_dec(sub("^<!-- bot-suggest-outcome: (.*) -->$", "\\1", out)))
  expect_true(jsonlite::fromJSON(json)$texts_dropped)
})
