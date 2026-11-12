# The test run of the analysis scripts against real DSLite (skipped where
# DSLite, dsBase or dsBaseClient aren't installed; the analysis self-test
# runs it in CI): a statement calling a function DSLite can't run
# (settings dslite_untestable) is skipped with what depends on it, instead
# of failing the script.

test_that("ds.glmSLMA and what uses its result are skipped and listed, other failures still count", {
  skip_if_not_installed("DSLite")
  skip_if_not_installed("dsBase")
  skip_if_not_installed("dsBaseClient")
  skip_if_not_installed("callr")
  dir <- withr::local_tempdir()
  withr::local_dir(dir)
  writeLines(c(
    "library(DSLite); library(dsBaseClient)",
    "data(\"CNSIM1\", package = \"DSLite\"); data(\"CNSIM2\", package = \"DSLite\")",
    "dslite.server <<- newDSLiteServer(tables = list(CNSIM1 = CNSIM1, CNSIM2 = CNSIM2), config = defaultDSConfiguration(include = \"dsBase\"))",
    "b <- DSI::newDSLoginBuilder()",
    "b$append(server = \"s1\", url = \"dslite.server\", table = \"CNSIM1\", driver = \"DSLiteDriver\")",
    "b$append(server = \"s2\", url = \"dslite.server\", table = \"CNSIM2\", driver = \"DSLiteDriver\")",
    "conns <<- DSI::datashield.login(b$build(), assign = TRUE, symbol = \"D\")"
  ), "setup.R")
  writeLines(c(
    "slma <- ds.glmSLMA(formula = \"LAB_TSC ~ LAB_HDL\", family = \"gaussian\", dataName = \"D\", datasources = conns)",
    "est <- slma$SLMA.pooled.ests.matrix",
    "m <- ds.mean(\"D$LAB_HDL\", datasources = conns)"
  ), "02_slma.R")
  writeLines("x <- no_such_function(conns)", "03_broken.R")

  run <- run_analysis_scripts("setup.R", c("02_slma.R", "03_broken.R"), "testing", 300, "conns", c("ds.glmSLMA"))
  expect_true(is.na(run$login_error))
  expect_true(is.na(run$errors[["02_slma.R"]]))
  expect_length(run$untested[["02_slma.R"]], 2)
  expect_match(run$untested[["02_slma.R"]][2], "slma$SLMA.pooled.ests.matrix", fixed = TRUE)
  expect_false(is.na(run$errors[["03_broken.R"]]))

  without <- run_analysis_scripts("setup.R", "02_slma.R", "testing", 300, "conns")
  expect_false(is.na(without$errors[["02_slma.R"]]))
})
