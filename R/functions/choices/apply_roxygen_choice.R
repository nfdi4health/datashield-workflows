# Makes an R file's roxygen block match the user's checkbox for one
# finding (merge_roxygen_findings(): kind "applied" or "dropped", its file
# and field), checking what the block actually contains:
# - ticked → the field has the suggested text (`proposed`);
# - unticked → the field as on the base branch (`base_rev`), or no such
#   field if the base branch has none.
# Texts are compared ignoring whitespace, punctuation and case, as the
# bot's threshold does. Returns list(changed, ok, note): `ok` FALSE with a
# note if the choice can't be applied.
apply_roxygen_choice <- function(e, ticked, base_rev, tag_order) {
  done <- function(changed = FALSE, ok = TRUE, note = "") list(changed = changed, ok = ok, note = note)
  if (!file.exists(e$file)) {
    return(done(ok = FALSE, note = sprintf("%s doesn't exist any more", e$file)))
  }
  parsed <- parse_r_file(e$file)
  if (is.null(parsed)) {
    return(done(ok = FALSE, note = sprintf("no function found in %s", e$file)))
  }

  normalize <- function(x) trimws(gsub("[[:space:][:punct:]]+", " ", tolower(paste(x, collapse = " "))))
  current <- original_roxygen_field(parsed, e$field)

  if (ticked) {
    if (is.null(e$proposed) || !nzchar(trimws(e$proposed))) {
      return(done(ok = FALSE, note = "the suggested text isn't stored for this change"))
    }
    if (!is.null(current) && identical(normalize(current$text), normalize(e$proposed))) {
      return(done())
    }
    new_lines <- roxygen_field_lines(e$field, e$proposed)
  } else {
    base_content <- git_file_at(base_rev, e$file)
    base_field <- NULL
    if (!is.null(base_content)) {
      tmp <- tempfile(fileext = ".R")
      writeLines(base_content, tmp)
      base_parsed <- tryCatch(suppressWarnings(parse_r_file(tmp)), error = function(err) NULL)
      if (!is.null(base_parsed)) {
        base_field <- original_roxygen_field(base_parsed, e$field)
      }
    }
    if (is.null(base_field) && is.null(current)) {
      return(done())
    }
    if (!is.null(base_field) && !is.null(current) && identical(normalize(current$text), normalize(base_field$text))) {
      return(done())
    }
    new_lines <- if (is.null(base_field)) {
      character(0)
    } else {
      base_field$lines
    }
  }

  new_block <- replace_roxygen_field(parsed, e$field, new_lines, tag_order)
  write_in_place(e$file, parsed, paste(new_block, collapse = "\n"))
  done(changed = TRUE)
}
