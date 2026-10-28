# The analysis bot's step-by-step drafting: dependencies, the plan check,
# order, blocking, restoring a failed step's previous version, and the
# statuses — with the Claude call and test run replaced by a stub.

texts <- yaml::read_yaml(file.path(repo_root, "config", "analysis-texts.yml"))
plan <- list(steps = list(
  list(id = "data_management", title = "Data management"),
  list(id = "descriptives", title = "Descriptives"),
  list(id = "main_model", title = "Main model"),
  list(id = "figures", title = "Figures", depends_on = list("data_management")),
  list(id = "sensitivity", title = "Sensitivity", depends_on = list("main_model"))
))

test_that("step_dependencies() uses depends_on, else all earlier steps", {
  deps <- step_dependencies(plan)
  expect_equal(deps$data_management, character(0))
  expect_equal(deps$main_model, c("data_management", "descriptives"))
  expect_equal(deps$figures, "data_management")
})

test_that("validate_analysis_plan() rejects depends_on pointing at a later step", {
  bad <- plan
  bad$steps[[2]]$depends_on <- list("figures")
  problems <- validate_analysis_plan(c(bad, list(symbol = "D")), "x", texts)
  expect_true(any(grepl("depends_on", problems)))
})

test_that("draft_steps_in_order() blocks dependents of a failed step and restores its old version", {
  dir <- withr::local_tempdir()
  withr::local_dir(dir)
  writeLines("old main model", "03_main_model.R")
  existing <- data.frame(path = "03_main_model.R", step = "main_model")
  seen <- list()
  # Stub: every step passes except main_model.
  stub <- function(to_write, plan, steps, existing, context, checks, settings, texts) {
    id <- to_write
    seen[[id]] <<- list(objects = context$created_objects, ids = context$all_step_ids)
    path <- sprintf("new_%s.R", id)
    writeLines(id, path)
    unlink(existing$path[existing$step == id])
    problems <- list()
    if (id == "main_model") {
      problems <- setNames(list("still fails"), id)
    }
    list(answers = setNames(list(list(step_id = id, sections = list("x"), notes = list())), id),
         candidate = setNames(list(path), id), notes = character(0), attempts = 3L,
         outcome = list(problems = problems, broken_other = character(0), objects = sprintf("- `%s_obj`", id)))
  }
  original <- draft_and_test_steps
  assign("draft_and_test_steps", stub, envir = globalenv())
  withr::defer(assign("draft_and_test_steps", original, envir = globalenv()))

  to_write <- c("data_management", "descriptives", "main_model", "figures", "sensitivity")
  d <- suppressMessages(capture.output(res <- draft_steps_in_order(to_write, plan, NULL, existing, list(), list(), list(), texts,
                                                                   existing, list("03_main_model.R" = "old main model"))))
  expect_equal(names(seen), c("data_management", "descriptives", "main_model", "figures"))
  expect_equal(res$blocked, list(sensitivity = "main_model"))
  expect_equal(seen$figures$objects, "- `descriptives_obj`")       # objects of the last passing run
  expect_identical(seen$figures$ids, seen$data_management$ids)      # one tool schema for the run
  expect_equal(readLines("03_main_model.R"), "old main model")      # previous version back
  expect_false(file.exists("new_main_model.R"))

  steps <- lapply(setNames(to_write, to_write), function(id) list(title = id, status = "new"))
  settled <- settle_step_results(steps, to_write, res, existing, list("03_main_model.R" = "old main model"), texts)
  expect_equal(vapply(settled$steps, function(s) s$status, ""),
               c(data_management = "written", descriptives = "written", main_model = "failed", figures = "written", sensitivity = "blocked"))
  expect_match(settled$steps$sensitivity$error, "main_model")
})

test_that("excluded functions reach the prompt with their reasons; a project can allow one again", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "config"))
  writeLines(c("excluded_functions:", "  ds.glmSLMA: ~", "  ds.rep: use ds.make instead"), file.path(dir, "config", "analysis-suggest.yml"))
  withr::local_dir(dir)
  excluded <- read_config_yaml("config/analysis-suggest.yml")$excluded_functions
  expect_false("ds.glmSLMA" %in% names(excluded))
  text <- format_excluded_functions(excluded)
  expect_match(text, "`ds.rep` (use ds.make instead)", fixed = TRUE)
  expect_match(text, "`datashield.login` (the login has already run)", fixed = TRUE)
  expect_equal(format_excluded_functions(list()), "(none)")
})
