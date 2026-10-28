# End-to-end runs of the roxygen and test bots' entry scripts on a
# made-up package (tests/fixtures/r-package) with recorded Claude answers
# (tests/fixtures/claude-answers/r-package.json): what the workflow's
# "Run" step does, minus the real API. No PR and no bot branch, as in a
# push run without an open bot PR.

recorded_answers <- function(name) {
  answers <- jsonlite::read_json(file.path(repo_root, "tests", "fixtures", "claude-answers", paste0(name, ".json")))
  answers[names(answers) != "_about"]
}

bot_env <- function(profile) c(
  ANTHROPIC_API_KEY = "test-key", GH_TOKEN = "", GITHUB_REPOSITORY = "me/fixturepkg",
  PR_NUMBER = "", SUB_BRANCH = "", REVIEWED_SHA = "abc1234def", BASE_REV = "", DATASHIELD_TYPE = "none"
)

test_that("suggest_roxygen.R documents add1's return value and reports clamp's possible bug", {
  dir <- local_fixture("r-package")
  writeLines(c("R/add1.R", "R/clamp.R"), file.path(dir, "files_to_check.txt"))
  requests <- run_entry_script_mocked("suggest_roxygen.R", dir, bot_env("roxygen-review"), recorded_answers("r-package"))

  expect_length(requests, 2)
  expect_equal(requests[[1]]$tool_choice$name, "submit_review")
  expect_match(requests[[1]]$messages[[1]]$content[[1]]$text, "add1 <- function(x)", fixed = TRUE)

  expect_equal(readLines(file.path(dir, "updated_files.txt")), "R/add1.R")
  add1 <- readLines(file.path(dir, "R", "add1.R"))
  expect_true(any(grepl("@return A numeric vector of the same length", add1, fixed = TRUE)))
  expect_true("#' @export" %in% add1)
  expect_equal(readLines(file.path(dir, "R", "clamp.R")), readLines(file.path(repo_root, "tests", "fixtures", "r-package", "R", "clamp.R")))

  report <- paste(readLines(file.path(dir, "suggestion_report.md")), collapse = "\n")
  expect_match(report, "returns hi everywhere when lo > hi", fixed = TRUE)
  expect_match(report, "bot-suggest-state", fixed = TRUE)
  expect_true(file.exists(file.path(dir, "suggestion_summary.md")))
})

test_that("suggest_tests.R proposes the passing tests and reports the failing one as a possible bug", {
  dir <- local_fixture("r-package")
  writeLines(c("R/add1.R", "R/clamp.R"), file.path(dir, "files_to_check.txt"))
  requests <- run_entry_script_mocked("suggest_tests.R", dir, bot_env("test-review"), recorded_answers("r-package"))

  tools <- vapply(requests, function(r) r$tools[[1]]$name, "")
  expect_equal(tools, c("submit_tests", "submit_tests", "submit_failure_classification"))

  expect_setequal(readLines(file.path(dir, "updated_files.txt")), c("tests/testthat/test-add1.R", "tests/testthat/test-clamp.R"))
  add1_tests <- readLines(file.path(dir, "tests", "testthat", "test-add1.R"))
  expect_true(any(grepl("add1 adds one", add1_tests, fixed = TRUE)))  # the existing test stays
  expect_true(any(grepl("add1 works element-wise on vectors", add1_tests, fixed = TRUE)))
  clamp_tests <- readLines(file.path(dir, "tests", "testthat", "test-clamp.R"))
  expect_true(any(grepl("clamp keeps values inside the range", clamp_tests, fixed = TRUE)))
  expect_false(any(grepl("clamp stops when lo is above hi", clamp_tests, fixed = TRUE)))

  report <- paste(readLines(file.path(dir, "suggestion_report.md")), collapse = "\n")
  expect_match(report, "clamp stops when lo is above hi", fixed = TRUE)
})

test_that("suggest_authors.R credits an R-code author as aut and a tests-only one as ctb, skipping bots", {
  dir <- local_fixture("r-package")
  git <- function(..., name = "Ada Example", email = "ada@example.org") {
    withr::with_dir(dir, system2("git", shQuote(c("-c", paste0("user.name=", name), "-c", paste0("user.email=", email), ...)), stdout = TRUE, stderr = TRUE))
  }
  git("init", "-q")
  git("add", "-A")
  git("commit", "-qm", "init")
  commit <- function(file, text, name, email) {
    cat(text, file = file.path(dir, file), append = TRUE)
    git("add", "-A")
    git("commit", "-qm", paste("change", file), name = name, email = email)
    git("rev-parse", "HEAD")
  }
  bea <- commit("R/clamp.R", "# note\n", "Bea M", "bea@example.org")
  carl <- commit("tests/testthat/test-add1.R", "# note\n", "Carl Test", "carl@example.org")
  bot <- commit("R/add1.R", "# bump\n", "dependabot[bot]", "bot@example.org")
  writeLines(c(bea, carl, bot), file.path(dir, "commits.txt"))
  github <- list()
  github[[paste0("/repos/me/fixturepkg/commits/", bea)]] <- list(commit = list(author = list(name = "Bea M", email = "bea@example.org")), author = list(login = "bea"))
  github[[paste0("/repos/me/fixturepkg/commits/", carl)]] <- list(commit = list(author = list(name = "Carl Test", email = "carl@example.org")), author = NULL)
  github[[paste0("/repos/me/fixturepkg/commits/", bot)]] <- list(commit = list(author = list(name = "dependabot[bot]", email = "bot@example.org")), author = list(login = "dependabot[bot]"))
  github[["/users/bea"]] <- list(login = "bea", name = "Beatrice van Muster")

  run_entry_script_mocked("suggest_authors.R", dir, c(GH_TOKEN = "", GITHUB_REPOSITORY = "me/fixturepkg", PR_NUMBER = ""), github = github)

  expect_equal(readLines(file.path(dir, "updated_files.txt")), "DESCRIPTION")
  authors <- desc::desc_get_authors(file.path(dir, "DESCRIPTION"))
  by_name <- function(given) Find(function(p) identical(p$given, given), authors)
  expect_equal(by_name("Beatrice")$family, "van Muster")
  expect_equal(by_name("Beatrice")$role, "aut")
  expect_equal(by_name("Carl")$role, "ctb")
  expect_null(by_name("Beatrice")$email)  # e-mails are never written
  expect_length(authors, 3)
  expect_match(paste(readLines(file.path(dir, "suggestion_report.md")), collapse = "\n"), "Beatrice van Muster", fixed = TRUE)
})

test_that("self-test mode: the script itself serves the recorded answers (separate Rscript, as in the workflow)", {
  dir <- local_fixture("r-package")
  writeLines(c("R/add1.R", "R/clamp.R"), file.path(dir, "files_to_check.txt"))
  env <- c(bot_env("roxygen-review"), ANTHROPIC_API_KEY = "",
           CLAUDE_RECORDED_ANSWERS = file.path(repo_root, "tests", "fixtures", "claude-answers", "r-package.json"))
  run <- run_entry_script("suggest_roxygen.R", dir, env)
  expect_equal(run$status, 0L, info = paste(run$output, collapse = "\n"))
  expect_true(any(grepl("Self-test: answers from", run$output, fixed = TRUE)))
  expect_equal(readLines(file.path(dir, "updated_files.txt")), "R/add1.R")
  expect_match(paste(readLines(file.path(dir, "suggestion_report.md")), collapse = "\n"), "returns hi everywhere when lo > hi", fixed = TRUE)
})
