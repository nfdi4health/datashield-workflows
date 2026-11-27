# The function catalogue: the catalogue's packages.json (since
# 2026-11-18) and the older table of functions.

test_that("client functions are read from packages.json; unread packages are skipped", {
  pk <- list(
    dsBaseClient = list(input = list(status = "production"), repo = list(function_info = list(roxygen_tags = list(
      list(`function` = "ds.glm", tags = list(title = list("Fits a generalised\n linear model"), description = list("Pooled."))),
      list(`function` = "ds.mean", tags = list(`_intro` = list("Computes the mean. Of a vector."))),
      list(`function` = "ds.todo", tags = list(title = list("XXXX"), description = list("XXX"))),
      list(`function` = "internal_helper", tags = list(title = list("A helper"), export = list(""))))))),
    dsBase = list(input = list(status = "production"), repo = list(function_info = list(roxygen_tags = list(
      list(`function` = "glmDS2", tags = list(title = list("Server side"))),
      list(`function` = "ds.oddDS", tags = list(title = list("Odd server name"))))))),
    dsUnread = list(input = list(status = "development"), repo = "Error"),
    dsBroken = list(input = list(status = "development"), repo = list(function_info = "Error")))
  file <- withr::local_tempfile(fileext = ".json")
  writeLines(jsonlite::toJSON(pk, auto_unbox = TRUE), file)
  fns <- read_function_catalogue(file)
  expect_equal(fns$package, rep("dsBaseClient", 3))
  expect_equal(fns$function_name, c("ds.glm", "ds.mean", "ds.todo"))
  expect_equal(fns$title, c("Fits a generalised linear model", "Computes the mean.", ""))
  expect_equal(fns$description, c("Pooled.", "Of a vector.", ""))
})

test_that("the older table of functions is still read", {
  table <- data.frame(package = c("dsBaseClient", "dsBase"), function_name = c("ds.mean", "meanDS"),
    architecture_type = c("client", "server"), title = c("Mean", "Server"), description = c("XXXX", "x"))
  file <- withr::local_tempfile(fileext = ".json")
  writeLines(jsonlite::toJSON(table), file)
  fns <- read_function_catalogue(file)
  expect_equal(fns$function_name, "ds.mean")
  expect_equal(fns$description, "")
})

test_that("a catalogue that can't be read gives no functions, with a message", {
  expect_message(fns <- read_function_catalogue(file.path(tempdir(), "no-such-catalogue.json")), "could not be read")
  expect_equal(nrow(fns), 0)
})
