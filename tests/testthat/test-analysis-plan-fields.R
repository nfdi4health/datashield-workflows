# The plan's `mock-data` and per-step `studies` fields: validation, the
# analyst's own mock data, and the datasources check for subset steps.

texts <- yaml::read_yaml(file.path(repo_root, "config", "analysis-texts.yml"))
base_plan <- list(
  symbol = "D",
  studies = list(list(server = "s1", packages = list(dsBase = "6.3.5")),
                 list(server = "s2", packages = list(dsBase = "6.3.5"))),
  variables = list(list(name = "x", type = "numeric", kind = "continuous", range = list(0, 1))),
  steps = list(list(id = "a", title = "A"))
)

test_that("validate_analysis_plan() accepts and rejects step studies", {
  ok <- base_plan
  ok$steps[[1]]$studies <- list("s2")
  expect_length(validate_analysis_plan(ok, "numeric", texts), 0)
  bad <- base_plan
  bad$steps[[1]]$studies <- list("s3")
  expect_true(any(grepl("studies must list", validate_analysis_plan(bad, "numeric", texts))))
  dup <- base_plan
  dup$steps[[1]]$studies <- list("s1", "s1")
  expect_true(any(grepl("studies must list", validate_analysis_plan(dup, "numeric", texts))))
})

test_that("validate_analysis_plan() checks mock-data", {
  ok <- base_plan
  ok$`mock-data` <- "MockData_New"
  expect_length(validate_analysis_plan(ok, "numeric", texts), 0)
  bad <- base_plan
  bad$`mock-data` <- "../elsewhere"
  expect_true(any(grepl("mock-data must be", validate_analysis_plan(bad, "numeric", texts))))
})

test_that("check_project_mock_data() needs one object per server", {
  root <- withr::local_tempdir()
  folder <- file.path(root, "Mine")
  dir.create(folder)
  s1 <- data.frame(x = 1)
  save(s1, file = file.path(folder, "s1.rda"))
  expect_error(check_project_mock_data("Mine", base_plan, root, "bot-suggest", texts), "missing: s2.rda")
  wrong <- data.frame(x = 2)
  save(wrong, file = file.path(folder, "s2.rda"))
  expect_error(check_project_mock_data("Mine", base_plan, root, "bot-suggest", texts), "s2.rda must hold one data frame named s2")
  s2 <- data.frame(x = 2)
  save(s2, file = file.path(folder, "s2.rda"))
  expect_equal(check_project_mock_data("Mine", base_plan, root, "bot-suggest", texts), "Mine")
  expect_error(check_project_mock_data("bot-suggest", base_plan, root, "bot-suggest", texts), "workflow's own folder")
  expect_error(check_project_mock_data("Nope", base_plan, root, "bot-suggest", texts), "doesn't exist")
})

test_that("check_step_datasources() flags calls on all connections in a subset step", {
  reference <- list(functions = list(
    ds.mean = list(args = c("x", "type", "datasources"), dots = FALSE),
    ds.ls = list(args = c("search.filter", "datasources"), dots = FALSE)
  ))
  code <- paste(
    'ds.mean(x = "D$x", datasources = conns[c("s2")])',
    'ds.mean(x = "D$x", datasources = conns)',
    'ds.ls()',
    sep = "\n")
  problems <- check_step_datasources(code, "s2", "conns", reference, texts)
  expect_length(problems, 2)
  expect_match(problems[1], "ds.mean")
  expect_length(check_step_datasources(code, NULL, "conns", reference, texts), 0)
})
