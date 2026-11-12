# Checks against unnecessary code in the analysis bot's scripts, modelled
# on the first trial run (DataSHIELD_CONF_DEMO): inspection calls whose
# output nobody uses, and objects no script uses.

texts <- yaml::read_yaml(file.path(repo_root, "config", "analysis-texts.yml"))
inspection <- unlist(yaml::read_yaml(file.path(repo_root, "config", "analysis-suggest.yml"))$inspection_functions)

test_that("check_inspection_calls() flags unassigned top-level inspection calls only", {
  code <- paste(
    'ds.class(x = "D$x", datasources = conns)',
    'ds.class(x = "D$y", datasources = conns)',
    'cols <- ds.colnames(x = "D", datasources = conns)',
    'dsBaseClient::ds.dim(x = "D", datasources = conns)',
    'ds.mean(x = "D$x", datasources = conns)',
    sep = "\n")
  problems <- check_inspection_calls(code, inspection, texts)
  expect_length(problems, 2)
  expect_match(problems[1], "^ds.class\\(\\)")
  expect_match(problems[2], "^ds.dim\\(\\)")
  expect_length(check_inspection_calls(code, character(0), texts), 0)
})

test_that("find_unused_objects() follows uses across scripts and ignores prints", {
  dir <- withr::local_tempdir()
  a <- file.path(dir, "02_a.R")
  b <- file.path(dir, "03_b.R")
  writeLines(c(
    'ds.Boole(V1 = "D$bmi", V2 = "25", Boolean.operator = ">=", newobj = "bmi_ge25", datasources = conns)',
    'ds.make(toAssign = "1 + bmi_ge25", newobj = "BMI_CAT", datasources = conns)',
    'ds.asFactorSimple(input.var.name = "D$sex", newobj.name = "SEX_F", datasources = conns)',
    'ds.levels(x = "SEX_F", datasources = conns)',
    'n_all <- ds.dim(x = "D", datasources = conns)',
    'n_all',
    'helper <- function(m) m$coefficients',
    'fit_list <- list()'
  ), a)
  writeLines(c(
    'fit <- ds.glm(formula = "y ~ BMI_CAT", data = "D", family = "binomial", datasources = conns)',
    'est <- helper(fit)',
    'write.csv(est, "out.csv")',
    'fit_list'
  ), b)
  unused <- find_unused_objects(c(a, b), inspection)
  expect_setequal(unused[[a]], c("SEX_F", "n_all", "fit_list"))
  expect_null(unused[[b]])
})
