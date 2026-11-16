# The "Open issue" link for a missing function (gap_issue_link()): the
# hub's issue form with its fields filled, and nothing of the plan.

texts <- function() read_config_yaml("config/analysis-texts.yml")

test_that("gap_issue_link() opens the hub's issue form with the note only", {
  link <- gap_issue_link("nfdi4health/datashield-function-ideas", "BMI and diabetes in cohort Z",
    "k-medoids clustering (cluster::pam)", texts())
  expect_match(link, "^https://github.com/nfdi4health/datashield-function-ideas/issues/new\\?template=analysis-method.yml&")
  query <- utils::URLdecode(sub("^[^?]*\\?", "", link))
  expect_match(query, "title=Missing DataSHIELD function: k-medoids clustering (cluster::pam)", fixed = TRUE)
  expect_match(query, "what=k-medoids clustering (cluster::pam)", fixed = TRUE)
  expect_match(query, "source=Reported from the DataSHIELD analysis starter", fixed = TRUE)
  # the step's title can reveal a research question: it stays out
  expect_false(grepl("cohort Z", query, fixed = TRUE))
})

test_that("gap_issue_link() falls back to a plain issue without a template", {
  t <- texts()
  t$issue$template <- ""
  link <- gap_issue_link("owner/repo", "Step", "a missing method & more", t)
  expect_match(link, "^https://github.com/owner/repo/issues/new\\?title=")
  expect_match(link, "&body=")
  # values are encoded, so an & in the note can't start another field
  expect_false(grepl("method & more", link, fixed = TRUE))
  expect_match(utils::URLdecode(link), "**What is missing:** a missing method & more", fixed = TRUE)
})
