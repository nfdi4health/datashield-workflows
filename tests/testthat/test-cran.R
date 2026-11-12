# The CRAN guardrail and submission: the date of the last submission, the
# waiting-time verdict, and the two-step upload with stand-in answers.

test_that("last_cran_submission() takes the later of CRAN's date and the cran-* tags", {
  expect_null(last_cran_submission(NULL, character(0)))
  expect_equal(last_cran_submission("2026-08-01 10:00:00 UTC", c(`cran-1.2.0` = "2026-09-15T08:00:00+02:00")), as.Date("2026-09-15"))
  expect_equal(last_cran_submission("2026-10-01 10:00:00 UTC", character(0)), as.Date("2026-10-01"))
})

test_that("cran_wait_verdict() needs min_days, unless overridden or never submitted", {
  today <- as.Date("2026-11-12")
  expect_true(cran_wait_verdict(NULL, today, 60)$ok)
  expect_true(cran_wait_verdict(as.Date("2026-09-01"), today, 60)$ok)
  early <- cran_wait_verdict(as.Date("2026-10-20"), today, 60)
  expect_false(early$ok)
  expect_match(early$message, "wait until 2026-12-19")
  expect_true(cran_wait_verdict(as.Date("2026-10-20"), today, 60, override = TRUE)$ok)
  expect_false(cran_wait_verdict(as.Date("2026-09-01"), today, 90)$ok)
})

test_that("upload_to_cran() uploads, then confirms with the submission id", {
  tarball <- withr::local_tempfile(fileext = ".tar.gz")
  writeLines("x", tarball)
  seen <- list()
  httr2::local_mocked_responses(function(req) {
    seen[[length(seen) + 1]] <<- req
    if (length(seen) == 1) {
      httr2::response(status_code = 200, url = "https://xmpp.r-project.org/CRAN/submit.php?pkg_id=abc123")
    } else {
      httr2::response(status_code = 200)
    }
  })
  id <- upload_to_cran(tarball, list(name = "A B", email = "a@example.org"), "comments")
  expect_equal(id, "abc123")
  expect_length(seen, 2)
  expect_equal(seen[[2]]$body$data$pkg_id, "abc123")
  expect_equal(seen[[2]]$body$data$policy_check, "1/")
})
