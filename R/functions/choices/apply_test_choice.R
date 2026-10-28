# Makes a test file match the user's checkbox for one finding
# (merge_test_findings(): kind "new", "updated" or "deleted", its file and
# test name), checking what the file actually contains, so it doesn't
# matter which runs first, this or a bot run:
# - new: ticked → the block is in the file (put back from the bot branch's
#   history, test_block_from_history()); unticked → it isn't;
# - updated: ticked → the bot's version of the block; unticked → the base
#   branch's version (`base_rev`);
# - deleted: ticked → the block is gone; unticked → the base branch's block
#   is back.
# A test file the bot created that has no test left is removed. Returns
# list(changed, ok, note): `ok` FALSE with a note if the choice can't be
# applied (the block can't be found any more).
apply_test_choice <- function(e, ticked, base_rev) {
  path <- e$file
  name <- e$description
  current <- if (file.exists(path)) {
    paste(readLines(path, warn = FALSE), collapse = "\n")
  } else {
    ""
  }
  blocks <- parse_test_file(current)
  present <- test_block_text(current, name)
  base_block <- test_block_text(git_file_at(base_rev, path), name)
  done <- function(changed = FALSE, ok = TRUE, note = "") list(changed = changed, ok = ok, note = note)
  missing <- function() done(ok = FALSE, note = sprintf("the test \"%s\" could not be found any more", name))

  new_content <- NULL
  if (identical(e$kind, "new")) {
    if (ticked && is.null(present)) {
      block <- test_block_from_history(path, name)
      if (is.null(block)) {
        return(missing())
      }
      new_content <- rewrite_test_content(current, blocks, appended = block, insert_after = test_insert_line(current, blocks))
    } else if (!ticked && !is.null(present)) {
      new_content <- rewrite_test_content(current, blocks, deletes = name)
    }
  } else if (identical(e$kind, "updated")) {
    if (is.null(present)) {
      return(missing())
    }
    if (ticked && identical(present, base_block)) {
      block <- test_block_from_history(path, name, except = base_block)
      if (is.null(block)) {
        return(missing())
      }
      new_content <- rewrite_test_content(current, blocks, updates = stats::setNames(block, name))
    } else if (!ticked && !is.null(base_block) && !identical(present, base_block)) {
      new_content <- rewrite_test_content(current, blocks, updates = stats::setNames(base_block, name))
    }
  } else if (identical(e$kind, "deleted")) {
    if (ticked && !is.null(present)) {
      new_content <- rewrite_test_content(current, blocks, deletes = name)
    } else if (!ticked && is.null(present)) {
      if (is.null(base_block)) {
        return(missing())
      }
      new_content <- rewrite_test_content(current, blocks, appended = base_block, insert_after = test_insert_line(current, blocks))
    }
  }
  if (is.null(new_content)) {
    return(done())
  }

  if (length(parse_test_file(new_content)) == 0 && is.null(git_file_at(base_rev, path))) {
    file.remove(path)
  } else {
    writeLines(new_content, path)
  }
  done(changed = TRUE)
}
