# The hub's "Exists?" check of new issues (R/check_ideas.R): Claude and
# the inventory as stand-ins.

idea_settings <- function() read_config_yaml("config/idea-check.yml")
idea_inventory <- function() data.frame(
  package = c("dsBaseClient", "dsClusterClient", "dsBaseClient"),
  fn = c("ds.glm", "ds.kmedoids", "ds.mean"),
  title = c("Fits a generalized linear model", "K-medoids clustering of the pooled data", "Computes the mean"),
  description = c("Pooled GLM over studies.", "Partitions participants into k clusters around medoids.", "Mean of a vector."),
  status = c("production", "development", "production"), stringsAsFactors = FALSE)
idea_client <- function(prompt) list(config = list(model = "m"), prompt = prompt, auth = NULL)
reader <- idea_client("{{NUMBER}} {{TITLE}} {{BODY}} {{OTHERS}}")
judge <- idea_client("{{METHODS}}")
issue <- list(number = 7, title = "Missing DataSHIELD function: k-medoids", body = "Cluster participants with PAM.")
others <- list(list(number = 7, title = "self"), list(number = 3, title = "PAM clustering"), list(number = 4, title = "Other"))

answers <- function(read, judged) {
  local_global_mock(call_claude_tool = function(claude, tool, prompt) {
    if (identical(tool$input_schema$properties$is_method$type, "boolean")) read else judged
  }, env = parent.frame())
}

test_that("check_idea() keeps a checked development match and only listed similar issues", {
  answers(list(is_method = TRUE, method = "k-medoids clustering", description = "Clusters around medoids.",
      keywords = list("medoids", "pam"), similar = list(3L, 99L, 7L)),
    list(methods = list(list(id = "m1", verdict = "yes", `function` = "dsClusterClient::ds.kmedoids",
      quote = "K-medoids clustering", note = ""))))
  x <- check_idea(issue, others, idea_inventory(), reader, judge, idea_settings(), as.Date("2026-11-17"))
  expect_false(x$limit)
  expect_equal(x$result$verdict$verdict, "development")
  expect_equal(x$result$verdict[["function"]], "dsClusterClient::ds.kmedoids")
  expect_equal(x$result$similar, 3L)
  c <- format_idea_comment(x$result, idea_settings(), as.Date("2026-11-17"))
  expect_equal(c$label, "in-development")
  expect_match(c$body, "Only in development: `dsClusterClient::ds.kmedoids`", fixed = TRUE)
  expect_match(c$body, "Similar ideas here: #3.", fixed = TRUE)
  expect_match(c$body, "<!-- idea-check: development -->", fixed = TRUE)
})

test_that("an invented quote becomes unconfirmed, without a label", {
  answers(list(is_method = TRUE, method = "k-medoids clustering", description = "", keywords = list("medoids"), similar = list()),
    list(methods = list(list(id = "m1", verdict = "yes", `function` = "dsClusterClient::ds.kmedoids",
      quote = "does everything you want", note = ""))))
  x <- check_idea(issue, others, idea_inventory(), reader, judge, idea_settings(), as.Date("2026-11-17"))
  expect_equal(x$result$verdict$verdict, "unconfirmed")
  expect_equal(format_idea_comment(x$result, idea_settings(), as.Date("2026-11-17"))$label, "")
})

test_that("a production match is labelled exists, partly exists-partly", {
  s <- idea_settings()
  inv <- idea_inventory()
  r <- list(number = 7, method = "pooled GLM", similar = integer(0), candidates = inv[1, ],
    verdict = list(verdict = "yes", `function` = "dsBaseClient::ds.glm", quote = "generalized linear model", note = ""))
  expect_equal(format_idea_comment(r, s, Sys.Date())$label, "exists")
  r$verdict$verdict <- "partial"
  r$verdict$note <- "No random effects."
  c <- format_idea_comment(r, s, Sys.Date())
  expect_equal(c$label, "exists-partly")
  expect_match(c$body, "Note: No random effects.", fixed = TRUE)
})

test_that("no candidates gives none without asking the judge; not a method gives a short comment", {
  calls <- 0
  local_global_mock(call_claude_tool = function(claude, tool, prompt) {
    calls <<- calls + 1
    list(is_method = TRUE, method = "zzz quux", description = "", keywords = list("qqq"), similar = list())
  })
  x <- check_idea(issue, others, idea_inventory(), reader, judge, idea_settings(), Sys.Date())
  expect_equal(calls, 1)
  expect_equal(x$result$verdict$verdict, "none")
  local_global_mock(call_claude_tool = function(claude, tool, prompt) {
    list(is_method = FALSE, method = "", description = "", keywords = list(), similar = list())
  })
  x <- check_idea(issue, others, idea_inventory(), reader, judge, idea_settings(), Sys.Date())
  c <- format_idea_comment(x$result, idea_settings(), Sys.Date())
  expect_match(c$body, "doesn't read as a statistical method", fixed = TRUE)
  expect_match(c$body, "<!-- idea-check: not-method -->", fixed = TRUE)
  expect_equal(c$label, "")
})

test_that("Claude's text in the comment can't mention or link", {
  r <- list(number = 7, method = "ping @alice https://evil.example", similar = integer(0),
    candidates = idea_inventory()[0, ], verdict = list(verdict = "none", `function` = "", quote = "", note = "see @bob"))
  body <- format_idea_comment(r, idea_settings(), Sys.Date())$body
  expect_false(grepl("@alice", body, fixed = TRUE))
  expect_false(grepl("@bob", body, fixed = TRUE))
  expect_false(grepl("https://evil", body, fixed = TRUE))
})

test_that("a usage limit or a failed call leaves the issue for the next run", {
  local_global_mock(call_claude_tool = function(claude, tool, prompt) stop("Claude AI usage limit reached|1763400000"))
  x <- check_idea(issue, others, idea_inventory(), reader, judge, idea_settings(), Sys.Date())
  expect_true(x$limit)
  expect_null(x$result)
  local_global_mock(call_claude_tool = function(claude, tool, prompt) stop("HTTP 500"))
  x <- check_idea(issue, others, idea_inventory(), reader, judge, idea_settings(), Sys.Date())
  expect_true(x$failed)
  expect_null(x$result)
})

test_that("match_vocabulary_method() matches only exact names, keys and method names", {
  v <- list(methods = list(), names = list(), variant_names = list())
  v$methods[["k-medoids"]] <- list(name = "k-medoids clustering")
  v$methods[["cox-regression"]] <- list(name = "Cox regression", variants = list(stratified = list(name = "stratified")))
  v$names[["pam clustering"]] <- list(method = "k-medoids")
  v$names[["stratified cox model"]] <- list(method = "cox-regression", variant = "stratified")
  v$names[["p-value"]] <- list(method = "")
  v$variant_names[["cox-regression"]][["stratified"]] <- list(variant = "stratified")
  expect_equal(match_vocabulary_method(v, "PAM clustering."), "k-medoids")
  expect_equal(match_vocabulary_method(v, "K-Medoids Clustering"), "k-medoids")
  expect_equal(match_vocabulary_method(v, "k-medoids"), "k-medoids")
  expect_equal(match_vocabulary_method(v, "Stratified Cox model"), "cox-regression/stratified")
  expect_equal(match_vocabulary_method(v, "p-value"), "")
  expect_equal(match_vocabulary_method(v, "medoids"), "")
  expect_equal(match_vocabulary_method(v, "clustering around medoids"), "")
})

test_that("a matched method gets its paper count and the literature watch's marker", {
  v <- list(methods = list(`k-medoids` = list(name = "k-medoids clustering")), names = list(`pam` = list(method = "k-medoids")),
    variant_names = list())
  reg <- new.env()
  reg$papers <- list(
    `1` = list(pmid = "1", usable = TRUE, methods = list(list(name = "pam"))),
    `2` = list(pmid = "2", usable = TRUE, methods = list(list(name = "lasso"))),
    `3` = list(pmid = "3", usable = FALSE, methods = list()))
  lit <- idea_literature("PAM", v, reg)
  expect_equal(lit, list(key = "k-medoids", papers = 1L, usable = 2L))
  expect_null(idea_literature("lasso regression", v, reg))
  expect_null(idea_literature("PAM", NULL, reg))
  r <- list(number = 7, method = "PAM", similar = integer(0), candidates = idea_inventory()[0, ], literature = lit,
    verdict = list(verdict = "none", `function` = "", quote = "", note = ""))
  body <- format_idea_comment(r, idea_settings(), Sys.Date())$body
  expect_match(body, "named in 1 of the 2 usable papers", fixed = TRUE)
  expect_match(body, "<!-- literature-watch-method: k-medoids -->", fixed = TRUE)
  r$literature <- NULL
  expect_false(grepl("literature-watch-method", format_idea_comment(r, idea_settings(), Sys.Date())$body))
})
