# regenerate_man_pages(): man/ follows the roxygen blocks the bot changed,
# and nothing else.

local_roxygen_package <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  dir.create(file.path(dir, "R"))
  writeLines(c("Package: rdpkg", "Version: 0.1", "Title: t", "Description: t.", "License: MIT",
               "Encoding: UTF-8", "Roxygen: list(markdown = TRUE)", "RoxygenNote: 7.0.0"), file.path(dir, "DESCRIPTION"))
  writeLines("export(a)", file.path(dir, "NAMESPACE"))
  writeLines(c("#' Add one", "#' @param x A number.", "#' @return x plus one.", "#' @export", "a <- function(x) x + 1"), file.path(dir, "R", "a.R"))
  writeLines(c("#' Double", "#' @param x A number.", "#' @return Twice x.", "b <- function(x) x * 2"), file.path(dir, "R", "b.R"))
  withr::with_dir(dir, suppressMessages(roxygen2::roxygenise(roclets = "rd", load_code = roxygen2::load_source)))
  dir
}

test_that("regenerate_man_pages() rewrites only the pages of the changed R files", {
  skip_if_not_installed("roxygen2")
  dir <- local_roxygen_package()
  b_before <- readLines(file.path(dir, "man", "b.Rd"))
  desc_before <- readLines(file.path(dir, "DESCRIPTION"))
  # The bot changed a's block; b's block changed too, but by someone else
  # and without the bot: its page stays as it was.
  writeLines(c("#' Add one to a number", "#' @param x A numeric vector.", "#' @return `x` plus one.", "#' @export",
               "a <- function(x) x + 1"), file.path(dir, "R", "a.R"))
  writeLines(c("#' Double it", "#' @param x A number.", "#' @return Twice x.", "b <- function(x) x * 2"), file.path(dir, "R", "b.R"))
  withr::local_envvar(GH_TOKEN = "ghs_secret")
  kept <- withr::with_dir(dir, regenerate_man_pages(c("R/a.R", "README.md")))
  expect_equal(kept, "man/a.Rd")
  expect_true(any(grepl("A numeric vector.", readLines(file.path(dir, "man", "a.Rd")), fixed = TRUE)))
  expect_equal(readLines(file.path(dir, "man", "b.Rd")), b_before)
  expect_equal(readLines(file.path(dir, "DESCRIPTION")), desc_before)
})

test_that("regenerate_man_pages() leaves packages without roxygen man pages alone", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "R"))
  writeLines(c("Package: x", "Version: 0.1"), file.path(dir, "DESCRIPTION"))
  expect_length(regenerate_man_pages("R/a.R", dir), 0)
  expect_length(regenerate_man_pages(character(0), dir), 0)
})
