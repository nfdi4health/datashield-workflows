# With an open bot PR, puts the test files its branch (`bot_ref`,
# fetch_bot_branch()) changes into the working tree before the run — the
# tests it already proposes, a generated setup file, new category files.
# They then count as existing: they are run and shown to Claude, so the
# same tests aren't generated again (the roxygen counterpart is
# review_source_block()). A file the user changed since the last review
# (`base_rev`) keeps their version, as in the bot branch's merge
# (`-X theirs`). "Changed by the bot" means changed on the bot branch since
# its merge base with the reviewed branch. Returns list(materialized,
# user_edited) — paths; restore_unproposed_files() puts back the ones
# this run doesn't propose.
materialize_bot_tests <- function(bot_ref, base_rev) {
  out <- list(materialized = character(0), user_edited = character(0))
  if (is.null(bot_ref)) {
    return(out)
  }
  git <- function(...) suppressWarnings(system2("git", shQuote(c(...)), stdout = TRUE, stderr = FALSE))

  base <- git("merge-base", "HEAD", bot_ref)
  if (length(base) == 0) {
    return(out)
  }
  for (path in git("diff", "--name-only", base[1], bot_ref, "--", "tests")) {
    if (nzchar(base_rev) && length(git("diff", "--name-only", base_rev, "HEAD", "--", path)) > 0) {
      out$user_edited <- c(out$user_edited, path)
      next
    }
    content <- git("show", sprintf("%s:%s", bot_ref, path))
    if (!is.null(attr(content, "status"))) {
      if (file.exists(path)) {
        file.remove(path)
      }
    } else {
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      writeLines(content, path)
    }
    out$materialized <- c(out$materialized, path)
  }
  out
}
