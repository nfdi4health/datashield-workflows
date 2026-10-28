# Loads every function of R/functions/ into the global environment, the
# way the entry scripts do (they source their folders with purrr::walk()),
# and offers helpers for the made-up fixtures in tests/fixtures/.
suppressPackageStartupMessages({
  library(httr2)     # attached by the entry scripts, used without httr2::
  library(jsonlite)
  library(purrr)
})
repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/")
# Config defaults come from this repository (read_config_yaml()), wherever
# a test runs.
options(bot.shared_root = repo_root)
for (f in list.files(file.path(repo_root, "R", "functions"), pattern = "\\.R$", recursive = TRUE, full.names = TRUE)) {
  sys.source(f, envir = globalenv())
}

# A fresh copy of a fixture (tests/fixtures/<name>) in a temporary folder,
# removed when the calling test ends.
local_fixture <- function(name, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  file.copy(file.path(repo_root, "tests", "fixtures", name), dir, recursive = TRUE)
  file.path(dir, basename(name))
}

# Runs one of this repository's entry scripts in `dir` as a separate
# Rscript process, with the shared repository copied into
# .shared-workflows as in CI. `env` is a named character vector of
# environment variables. Returns list(status, output).
run_entry_script <- function(script, dir, env = character(0)) {
  shared <- file.path(dir, ".shared-workflows")
  dir.create(shared, showWarnings = FALSE)
  for (part in c("R", "config", "prompts")) {
    file.copy(file.path(repo_root, part), shared, recursive = TRUE)
  }
  out <- withr::with_dir(dir, withr::with_envvar(env, suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), shQuote(file.path(".shared-workflows", "R", script)),
    stdout = TRUE, stderr = TRUE
  ))))
  list(status = attr(out, "status") %||% 0L, output = out)
}

# Runs an entry script in this R process, in `dir` (with the shared
# repository copied into .shared-workflows as in CI), with every HTTP
# request answered by a stand-in: a Claude request gets the next recorded
# answer for its tool (`answers`: tool name -> list of tool inputs, in
# call order, e.g. from tests/fixtures/claude-answers/), a GitHub API
# request the body `github` gives for its path (e.g. "/users/bea"; a
# named list), anything else a 404. In-process, because httr2's mocking
# doesn't reach a separate Rscript. Objects the script leaves in the
# global environment are removed afterwards. Returns the Claude request
# bodies, in order.
run_entry_script_mocked <- function(script, dir, env = character(0), answers = list(), github = list()) {
  shared <- file.path(dir, ".shared-workflows")
  dir.create(shared, showWarnings = FALSE)
  for (part in c("R", "config", "prompts")) {
    file.copy(file.path(repo_root, part), shared, recursive = TRUE)
  }
  queue <- answers
  requests <- list()
  mock <- function(req) {
    path <- sub("^https://api.github.com", "", req$url)
    if (!is.null(github[[path]])) {
      return(httr2::response(status_code = 200, headers = list("content-type" = "application/json"),
                             body = charToRaw(jsonlite::toJSON(github[[path]], auto_unbox = TRUE, null = "null"))))
    }
    if (!grepl("api.anthropic.com", req$url, fixed = TRUE)) {
      return(httr2::response(status_code = 404))
    }
    body <- request_body(req)
    tool <- body$tools[[1]]$name
    requests[[length(requests) + 1]] <<- body
    if (length(queue[[tool]]) == 0) {
      stop("No recorded answer left for ", tool)
    }
    input <- queue[[tool]][[1]]
    queue[[tool]] <<- queue[[tool]][-1]
    claude_response(list(list(type = "tool_use", id = "toolu_1", name = tool, input = input)))
  }
  before <- ls(globalenv(), all.names = TRUE)
  on.exit(rm(list = setdiff(ls(globalenv(), all.names = TRUE), before), envir = globalenv()), add = TRUE)
  withr::with_dir(dir, withr::with_envvar(env, httr2::with_mocked_responses(mock, {
    source(file.path(".shared-workflows", "R", script), local = globalenv())
  })))
  requests
}

# Replaces functions of R/functions/ (which live in the global
# environment, not a package, so testthat's local_mocked_bindings() can't
# reach them) for the rest of the calling test: local_global_mock(f = fn).
local_global_mock <- function(..., env = parent.frame()) {
  mocks <- list(...)
  originals <- mget(names(mocks), envir = globalenv())
  for (n in names(mocks)) {
    assign(n, mocks[[n]], envir = globalenv())
  }
  withr::defer(for (n in names(originals)) {
    assign(n, originals[[n]], envir = globalenv())
  }, envir = env)
}

# A response of the Messages API for httr2::with_mocked_responses().
claude_response <- function(content, stop_reason = "tool_use") {
  httr2::response(
    status_code = 200,
    headers = list("content-type" = "application/json"),
    body = charToRaw(jsonlite::toJSON(list(content = content, stop_reason = stop_reason,
                                           usage = list(input_tokens = 10, output_tokens = 5)),
                                      auto_unbox = TRUE, null = "null"))
  )
}

# The JSON body of a request as the API receives it.
request_body <- function(req) {
  body <- httr2::req_get_body(req)
  if (is.raw(body)) {
    body <- rawToChar(body)
  }
  if (is.list(body)) {
    body <- jsonlite::toJSON(body, auto_unbox = TRUE, null = "null", digits = 22)
  }
  jsonlite::fromJSON(body, simplifyVector = FALSE)
}
