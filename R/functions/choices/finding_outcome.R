# What became of one finding of a bot PR when the PR was closed or merged
# (the outcome record, dev-notes/feedback-loop.md). `e` is a state entry
# (merge_roxygen_findings() / merge_test_findings()), `choice` its final
# box (suggestion_choice()), `merged` whether the PR was merged,
# `final_rev` the revision with the merged result (the base branch after
# the merge), `bot_rev` the bot branch's last commit. For an accepted
# suggestion of a merged PR it compares what the bot proposed with what
# was merged: `edited` TRUE when a person changed it before merging, with
# both texts (each cut to `max_chars`). Returns a list for the record.
finding_outcome <- function(e, choice, merged, final_rev, bot_rev, max_chars = 3000) {
  outcome <- if (!merged) {
    "closed"
  } else if (identical(choice, "ticked")) {
    "accepted"
  } else {
    "declined"
  }
  out <- list(id = as.integer(e$id), kind = e$kind, file = e$file %||% "", reason = e$reason %||% "",
              choice = choice, outcome = outcome, edited = NA)
  if (!is.null(e$field) && nzchar(e$field)) out$field <- e$field
  if (!is.null(e$fn) && nzchar(e$fn)) out$fn <- e$fn
  if (!is.null(e$description) && nzchar(e$description)) out$description <- e$description
  if (!identical(outcome, "accepted")) {
    return(out)
  }
  normalize <- function(x) trimws(gsub("[[:space:][:punct:]]+", " ", tolower(paste(x, collapse = " "))))
  cut <- function(x) if (is.null(x)) "" else substr(x, 1, max_chars)

  if (!is.null(e$field) && nzchar(e$field %||% "")) {
    # roxygen: the field as merged against the proposed text
    content <- git_file_at(final_rev, e$file)
    final <- NULL
    if (!is.null(content)) {
      tmp <- tempfile(fileext = ".R")
      on.exit(unlink(tmp), add = TRUE)
      writeLines(content, tmp)
      parsed <- tryCatch(suppressWarnings(parse_r_file(tmp)), error = function(err) NULL)
      if (!is.null(parsed)) final <- original_roxygen_field(parsed, e$field)$text
    }
    proposed <- e$proposed %||% ""
  } else if (identical(e$kind, "deleted")) {
    final <- test_block_text(git_file_at(final_rev, e$file), e$description)
    out$edited <- !is.null(final)  # the deletion was undone by hand
    return(out)
  } else {
    # tests: the block as merged against the bot branch's block
    final <- test_block_text(git_file_at(final_rev, e$file), e$description)
    proposed <- test_block_text(git_file_at(bot_rev, e$file), e$description) %||% ""
  }
  out$edited <- !identical(normalize(final %||% ""), normalize(proposed))
  if (isTRUE(out$edited)) {
    out$proposed <- cut(proposed)
    out$final <- cut(final)
  }
  out
}
