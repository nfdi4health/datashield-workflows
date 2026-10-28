# Which roxygen block a function is reviewed from. With an open bot PR,
# its branch (`bot_ref`, fetch_bot_branch()) may already propose a better
# block for this function; reviewing the branch's own block again would
# make Claude suggest the same fixes again (seen on dsSurvivalClient
# PR #37). So the bot's block is used — unless the user edited the
# documentation since the last review (their block differs from the one at
# `base_rev`), in which case their version wins, as in the bot branch's
# merge. Nothing is written: with the bot's block, the file is assembled
# in a temporary copy and parsed from there, so write_in_place() later
# writes the user's file with the bot's block plus this run's changes.
# Returns list(parsed, from_bot, user_edited).
review_source_block <- function(path, parsed, bot_ref, base_rev) {
  out <- list(parsed = parsed, from_bot = FALSE, user_edited = FALSE)
  if (is.null(bot_ref)) {
    return(out)
  }

  parse_at <- function(rev) {
    lines <- suppressWarnings(system2("git", shQuote(c("show", sprintf("%s:%s", rev, path))), stdout = TRUE, stderr = FALSE))
    if (!is.null(attr(lines, "status")) || length(lines) == 0) {
      return(NULL)
    }
    tmp <- tempfile(fileext = ".R")
    writeLines(lines, tmp)
    tryCatch(suppressWarnings(parse_r_file(tmp)), error = function(e) NULL)
  }

  if (nzchar(base_rev)) {
    before <- parse_at(base_rev)
    if (!is.null(before) && !identical(before$roxygen_lines, parsed$roxygen_lines)) {
      out$user_edited <- TRUE
      return(out)
    }
  }

  bot <- parse_at(bot_ref)
  if (is.null(bot) || !identical(bot$fn_name, parsed$fn_name) || !bot$has_roxygen ||
      identical(bot$roxygen_lines, parsed$roxygen_lines)) {
    return(out)
  }

  before <- if (parsed$pre_end >= 1) {
    parsed$lines[seq_len(parsed$pre_end)]
  } else {
    character(0)
  }
  after <- parsed$lines[seq(parsed$fn_start, length(parsed$lines))]
  tmp <- tempfile(fileext = ".R")
  writeLines(c(before, bot$roxygen_lines, parsed$gap_lines, after), tmp)
  out$parsed <- suppressWarnings(parse_r_file(tmp))
  out$from_bot <- TRUE
  out
}
