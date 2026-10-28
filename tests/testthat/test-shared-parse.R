test_that("parse_r_file finds the function, its arguments and roxygen block", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "# a plain comment",
    "#' Title",
    "#'",
    "#' @param x a value,",
    "#'   continued",
    "#' @export",
    "",
    "my.fun <- function(x,",
    "                   y = c(1, 2),",
    "                   ...) {",
    "  x",
    "}"
  ), path)
  p <- parse_r_file(path)
  expect_equal(p$fn_name, "my.fun")
  expect_equal(p$fn_start, 8)
  expect_equal(p$params, c("x", "y", "..."))
  expect_true(p$has_roxygen)
  expect_equal(c(p$roxygen_start, p$roxygen_end, p$pre_end), c(2, 6, 1))
  expect_equal(p$gap_lines, "")
  expect_true(p$is_exported)
  expect_equal(vapply(p$tag_chunks, `[[`, "", "tag"), c("param", "export"))
  expect_length(p$tag_chunks[[1]]$lines, 2)
})

test_that("parse_r_file: no roxygen, = assignment, several functions, no function", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(c("f = function() NULL", "g <- function(a) a"), path)
  expect_warning(p <- parse_r_file(path), "2 function definitions")
  expect_equal(p$fn_name, "f")
  expect_length(p$params, 0)
  expect_false(p$has_roxygen)
  expect_equal(c(p$roxygen_start, p$roxygen_end), c(1, 0))

  writeLines(c("#' @keywords internal", "\"_PACKAGE\""), path)
  expect_null(parse_r_file(path))

  writeLines("f <- function( {", path)
  expect_warning(expect_null(parse_r_file(path)), "does not parse")
})

test_that("package_function_names lists top-level functions of R/", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "R"))
  writeLines(c("a <- function() 1", "b = function() 2", "x <- 3", "  nested <- function() 4"), file.path(dir, "R", "a.R"))
  writeLines("c <- function() 5", file.path(dir, "R", "c.r"))
  withr::local_dir(dir)
  expect_setequal(package_function_names(), c("a", "b", "nested", "c"))
})
