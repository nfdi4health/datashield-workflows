# The variables file written by dsAnalysis's initVariables()
# (config/variables.yml): merged with the plan's own variables, per-study
# availability in the mock data, missing-value codes, and the notes.

texts <- yaml::read_yaml(file.path(repo_root, "config", "analysis-texts.yml"))
settings <- read_config_yaml("config/analysis-suggest.yml")
types <- settings$variable_types

write_plan_and_variables <- function(dir, plan_variables) {
  writeLines(yaml::as.yaml(list(
    symbol = "D",
    studies = list(list(server = "s1", packages = list(dsBase = "6.3.5")),
                   list(server = "s2", packages = list(dsBase = "6.3.5"))),
    variables = plan_variables,
    steps = list(list(id = "a", title = "A"))
  )), file.path(dir, "plan.yml"))
  writeLines(c(
    "variables:",
    "  - name: \"BMI\"",
    "    label: \"Body mass index\"",
    "    type: continuous",
    "    range: [18.5, 35.2]",
    "    studies: [\"s1\"]",
    "  - name: \"SMOKE\"",
    "    label: \"\"",
    "    type: categorical",
    "    categories:",
    "      \"0\": \"never\"",
    "      \"1\": \"ever\"",
    "    missing_codes: [\"99\"]",
    "    studies: [\"s1\", \"s2\"]",
    "  - name: \"CONSTANT\"",
    "    label: \"\"",
    "    type: categorical",
    "    categories:",
    "      \"1\": \"\"",
    "    studies: [\"s1\", \"s2\"]"
  ), file.path(dir, "variables.yml"))
}

test_that("read_analysis_plan() takes the variables file with the plan's entries on top", {
  dir <- withr::local_tempdir()
  write_plan_and_variables(dir, list(list(name = "SMOKE", role = "exposure"),
                                     list(name = "AGE", type = "integer", range = list(18, 80))))
  plan <- read_analysis_plan(file.path(dir, "plan.yml"), types, texts, file.path(dir, "variables.yml"))

  names <- vapply(plan$variables, function(v) v$name, character(1))
  expect_equal(names, c("BMI", "SMOKE", "AGE"))           # file order, plan-only ones last
  smoke <- plan$variables[[2]]
  expect_equal(smoke$role, "exposure")                     # from the plan
  expect_equal(smoke$kind, "categorical")                  # from the file's type
  expect_equal(plan$variables_left_out, "CONSTANT")         # one category: left out, not fatal
  expect_true(plan$variables_from_file)

  # without the file, the plan alone must be complete
  expect_error(read_analysis_plan(file.path(dir, "plan.yml"), types, texts, file.path(dir, "none.yml")), "variable")
})

test_that("a plan entry fixes a variable the file would leave out", {
  dir <- withr::local_tempdir()
  write_plan_and_variables(dir, list(list(name = "CONSTANT", categories = list(`1` = "yes", `2` = "no"))))
  plan <- read_analysis_plan(file.path(dir, "plan.yml"), types, texts, file.path(dir, "variables.yml"))
  expect_length(plan$variables_left_out, 0)
  expect_equal(names(Find(function(v) v$name == "CONSTANT", plan$variables)$categories), c("1", "2"))
})

test_that("generate_mock_data() leaves a variable out where a study lacks it, and uses missing codes", {
  dir <- withr::local_tempdir()
  write_plan_and_variables(dir, list())
  plan <- read_analysis_plan(file.path(dir, "plan.yml"), types, texts, file.path(dir, "variables.yml"))
  mock <- generate_mock_data(plan, list(rows_per_study = 400, missing_share = 0.2, seed = 1, decimals = 2))

  expect_true("BMI" %in% names(mock$s1))
  expect_false("BMI" %in% names(mock$s2))
  expect_true("99" %in% as.character(mock$s1$SMOKE))
  expect_true(anyNA(mock$s1$SMOKE))
  expect_equal(sort(levels(mock$s1$SMOKE)), c("0", "1", "99"))
})

test_that("variable_in_study() ignores a studies list naming none of the plan's servers", {
  expect_true(variable_in_study(list(studies = list("sim1")), "s1", c("s1", "s2")))
  expect_false(variable_in_study(list(studies = list("s2")), "s1", c("s1", "s2")))
  expect_true(variable_in_study(list(name = "x"), "s1", c("s1", "s2")))
})

test_that("check_variable_availability() notes a used variable some of the step's studies lack", {
  variables <- list(list(name = "BMI", studies = list("s1")), list(name = "SMOKE", studies = list("s1", "s2")))
  code <- 'ds.mean("D$BMI", datasources = conns)\nds.table("D$SMOKE", datasources = conns)'
  notes <- check_variable_availability("a", code, character(0), variables, "D", c("s1", "s2"), texts)
  expect_length(notes, 1)
  expect_match(notes, "`BMI`, which `s2`", fixed = TRUE)
  expect_length(check_variable_availability("a", code, "s1", variables, "D", c("s1", "s2"), texts), 0)
})
