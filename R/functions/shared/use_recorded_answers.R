# Self-test mode of the bot workflows (input self-test-fixture, this
# repository's own CI only): when CLAUDE_RECORDED_ANSWERS names a file of
# recorded answers (tests/fixtures/claude-answers/<fixture>.json), every
# HTTP request of the run is answered locally, so nothing leaves the
# runner and nothing is written to GitHub:
# - a Claude request gets the next recorded answer for its tool (tool
#   name -> list of tool inputs, in call order);
# - GitHub: a commit (/repos/<repo>/commits/<sha>) is answered from the
#   local git history, with the author's login from `github.logins`
#   (author name -> login; none: no GitHub account); a user
#   (/users/<login>) from `github.users`; anything else gets 404.
# Does nothing otherwise. Called at the start of the entry scripts.
use_recorded_answers <- function(path = Sys.getenv("CLAUDE_RECORDED_ANSWERS"), env = globalenv()) {
  if (!nzchar(path)) {
    return(invisible(FALSE))
  }
  answers <- jsonlite::read_json(path)
  github <- answers$github
  queue <- new.env()
  queue$answers <- answers[!names(answers) %in% c("_about", "github")]
  json_response <- function(x) {
    httr2::response(status_code = 200, headers = list("content-type" = "application/json"),
                    body = charToRaw(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null")))
  }
  github_response <- function(url) {
    route <- sub("^https://api.github.com", "", url)
    if (grepl("^/repos/[^/]+/[^/]+/commits/[0-9a-f]+$", route)) {
      sha <- sub("^.*/", "", route)
      who <- suppressWarnings(system2("git", c("log", "-1", "--format=%an%x09%ae", sha), stdout = TRUE, stderr = FALSE))
      if (length(who) == 0) {
        return(httr2::response(status_code = 404))
      }
      parts <- strsplit(who, "\t", fixed = TRUE)[[1]]
      login <- github$logins[[parts[1]]]
      author <- NULL
      if (!is.null(login)) {
        author <- list(login = login)
      }
      commit <- list(author = list(name = parts[1], email = parts[2]))
      return(json_response(list(commit = commit, author = author)))
    }
    if (grepl("^/users/[^/]+$", route)) {
      user <- github$users[[sub("^/users/", "", route)]]
      if (!is.null(user)) {
        return(json_response(user))
      }
    }
    httr2::response(status_code = 404)
  }
  mock <- function(req) {
    if (!grepl("api.anthropic.com", req$url, fixed = TRUE)) {
      return(github_response(req$url))
    }
    body <- httr2::req_get_body(req)
    if (is.raw(body)) {
      body <- rawToChar(body)
    }
    if (is.character(body)) {
      body <- jsonlite::fromJSON(body, simplifyVector = FALSE)
    }
    tool <- body$tools[[1]]$name
    if (length(queue$answers[[tool]]) == 0) {
      stop("Self-test: no recorded answer left for ", tool, call. = FALSE)
    }
    input <- queue$answers[[tool]][[1]]
    queue$answers[[tool]] <- queue$answers[[tool]][-1]
    json_response(list(
      content = list(list(type = "tool_use", id = "toolu_self_test", name = tool, input = input)),
      stop_reason = "tool_use", usage = list(input_tokens = 0, output_tokens = 0)
    ))
  }
  httr2::local_mocked_responses(mock, env = env)
  message("Self-test: answers from ", path, " (Claude, GitHub); nothing is sent.")
  invisible(TRUE)
}
