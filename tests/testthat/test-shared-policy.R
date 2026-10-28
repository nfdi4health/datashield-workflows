test_that("the policy's defaults: reasons, accepted reasons, thresholds", {
  expect_equal(suggestion_reasons("roxygen"), c("missing", "inaccurate", "incomplete", "clarity", "style"))
  expect_equal(suggestion_reasons("roxygen", accepted = TRUE), c("missing", "inaccurate", "incomplete"))
  expect_equal(suggestion_reasons("tests", accepted = TRUE), c("uncovered_branch", "error_handling", "edge_case", "regression"))
  expect_error(suggestion_reasons("nope"), "Unknown suggestion task")
  p <- suggestion_policy()
  expect_equal(unlist(p$possible_bugs$report), c("high", "medium"))
  expect_equal(p$tests$max_new_tests, 10L)
})

test_that("a project's policy overrides single keys; the reasons reach schema and prompt", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "config"))
  writeLines(c("roxygen:", "  reasons:", "    clarity:", "      accept: true",
               "authors:", "  family_name_particles: [zu]"), file.path(dir, "config", "suggestion-policy.yml"))
  withr::local_dir(dir)
  expect_equal(suggestion_reasons("roxygen", accepted = TRUE), c("missing", "inaccurate", "incomplete", "clarity"))
  expect_equal(split_person_name("Anna van Berg")$family, "Berg")       # van no longer a particle
  expect_equal(split_person_name("Karl zu Guttenberg")$family, "zu Guttenberg")
  expect_match(format_reason_meanings("roxygen", bullets = TRUE), "- clarity: correct and complete, but could be clearer;", fixed = TRUE)
  expect_match(format_reason_meanings("tests"), "edge_case: unusual but valid input", fixed = TRUE)
})

test_that("an empty report list means no possible bugs; check_routing() rejects impossible destinations", {
  expect_equal(code_issue_confidence_levels("", list()), character(0))
  expect_equal(code_issue_confidence_levels("high", list()), "high")
  expect_equal(check_routing(list(on_pr = "comment", without_pr = "issue"), "x"), list(on_pr = "comment", without_pr = "issue"))
  expect_error(check_routing(list(without_pr = "comment"), "tests report"), "without_pr is 'comment'")
  expect_error(check_routing(list(on_pr = "issue"), "authors", allowed = c("comment", "log")), "use one of: comment, log")
})

test_that("credit_contributor() uses the configured roles", {
  dir <- withr::local_tempdir()
  writeLines(c("Package: p", "Version: 0.1", "Title: t", "Description: t.", "License: MIT",
               "Authors@R: person(\"Ada\", \"Example\", role = c(\"aut\", \"cre\"))"), file.path(dir, "DESCRIPTION"))
  d <- desc::description$new(file.path(dir, "DESCRIPTION"))
  out <- credit_contributor(d, "Bea Muster", "R/a.R", "bea@example.org", roles = list(changed_r_code = "ctb", otherwise = "ctb"))
  expect_true(out$changed)
  expect_match(out$line, "added as `ctb`", fixed = TRUE)
})
