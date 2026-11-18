# The "Exists?" check of one hub issue (R/check_ideas.R): Claude reads what
# method the issue asks for (`reader`, build_idea_tool()); R preselects the
# inventory's functions by the method's name and keywords
# (preselect_functions()); Claude judges them with the literature watch's
# prompt and tool (`judge`, build_exists_tool()), and check_exists_answer()
# keeps only a function and quote that are really there. Similar issues
# are kept only if they are among `others`. Returns list(limit, failed,
# result): result is NULL at the usage limit or after a failed call, which
# leave the issue for the next run.
check_idea <- function(issue, others, inventory, reader, judge, settings, today) {
  s <- settings
  body <- issue$body %||% ""
  if (nchar(body) > (s$max_issue_chars %||% 4000)) body <- paste0(substr(body, 1, s$max_issue_chars %||% 4000), " ...")
  others <- Filter(function(o) !identical(as.integer(o$number), as.integer(issue$number)), others)
  other_lines <- vapply(others, function(o) sprintf("#%s %s", o$number, o$title), "")
  read <- call_watch_claude(reader, build_idea_tool(s$similar %||% 3), fill_template(reader$prompt, list(
    NUMBER = issue$number, TITLE = issue$title %||% "", BODY = body,
    OTHERS = if (length(other_lines)) paste(other_lines, collapse = "\n") else "(none)")),
    sprintf("issue #%s", issue$number))
  if (read$limit || is.null(read$answer)) return(list(limit = read$limit, failed = !read$limit, result = NULL))
  a <- read$answer
  numbers <- vapply(others, function(o) as.integer(o$number), integer(1))
  similar <- intersect(as.integer(unlist(a$similar)), numbers)
  similar <- utils::head(similar, s$similar %||% 3)
  if (!isTRUE(a$is_method) || !nzchar(trimws(a$method %||% ""))) {
    return(list(limit = FALSE, failed = FALSE,
      result = list(number = issue$number, method = "", verdict = NULL, candidates = inventory[0, , drop = FALSE], similar = similar)))
  }
  cand <- preselect_functions(inventory, c(a$method, unlist(a$keywords)), s$candidates %||% 15)
  if (nrow(cand) == 0) {
    rec <- list(verdict = "none", `function` = "", quote = "", note = "")
  } else {
    c_lines <- sprintf("- %s::%s (status: %s): %s. %s", cand$package, cand$fn,
      ifelse(nzchar(cand$status), cand$status, "unknown"), cand$title, cand$description)
    text <- sprintf("<method id=\"m1\">\nMethod: %s. %s\nVariant: none (the plain method)\nCandidate functions:\n%s\n</method>",
      a$method, a$description %||% "", paste(c_lines, collapse = "\n"))
    judged <- call_watch_claude(judge, build_exists_tool(), fill_template(judge$prompt, list(METHODS = text)),
      sprintf("issue #%s's method", issue$number))
    if (judged$limit || is.null(judged$answer)) return(list(limit = judged$limit, failed = !judged$limit, result = NULL))
    answer <- Filter(function(x) identical(x$id, "m1"), judged$answer$methods %||% list())
    rec <- if (length(answer)) check_exists_answer(answer[[1]], cand, "", today, "") else
      list(verdict = "unclear", `function` = "", quote = "", note = "")
  }
  list(limit = FALSE, failed = FALSE,
    result = list(number = issue$number, method = a$method, verdict = rec, candidates = cand, similar = similar))
}
