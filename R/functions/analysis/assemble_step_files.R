# Builds a step's script files from Claude's sections: a marker line, a
# short header (`texts$script$header`), then each section as
# "#### <purpose>" plus its code, in `settings$paths$scripts`. Files hold
# at most `settings$max_script_lines` lines; longer steps are split
# between sections into 02a_, 02b_, ... A single section longer than the
# limit gets a file of its own (and a note), never cut in half.
# A step with no sections (nothing possible with the installed packages)
# still gets a file, with its `step_notes` as comments only: the analyst
# sees the gap where the code would go, and the marker line keeps the step
# from being requested again until its plan entry changes.
# Returns list(files = list of list(path, lines), notes).
assemble_step_files <- function(step, sections, number, plan_hash, header_values, step_notes, settings, texts) {
  max_lines <- settings$max_script_lines
  header <- c(
    vapply(texts$script$header, function(line) fill_template(line, c(list(TITLE = step$title), header_values)), character(1)),
    ""
  )
  blocks <- lapply(sections, function(s) {
    code <- sub("\\s+$", "", strsplit(sub("\\n+$", "", s$code), "\n", fixed = TRUE)[[1]])
    c(sprintf("#### %s", gsub("\\s+", " ", trimws(s$purpose))), code, "")
  })
  if (length(blocks) == 0) {
    blocks <- list(c(
      texts$script$notes_only,
      vapply(step_notes, function(n) sprintf("#### - %s", gsub("\\s+", " ", n$text)), character(1))
    ))
  }

  budget <- max_lines - 1 - length(header)  # marker line and header count too
  parts <- list()
  current <- character(0)
  notes <- character(0)
  for (b in blocks) {
    if (length(current) > 0 && length(current) + length(b) > budget) {
      parts[[length(parts) + 1]] <- current
      current <- character(0)
    }
    if (length(b) > budget) {
      notes <- c(notes, fill_template(texts$step$long_section, list(STEP = step$id, MAX_LINES = max_lines)))
    }
    current <- c(current, b)
  }
  if (length(current) > 0) {
    parts[[length(parts) + 1]] <- current
  }

  letters_used <- if (length(parts) > 1) {
    letters[seq_along(parts)]
  } else {
    ""
  }
  title <- script_file_title(step$title, settings$max_file_title_chars)
  files <- lapply(seq_along(parts), function(i) {
    body <- c(header, parts[[i]])
    while (length(body) > 0 && body[length(body)] == "") {
      body <- body[-length(body)]
    }
    marker <- sprintf("#### bot-suggest: step=%s plan=%s content=%s", step$id, plan_hash, text_hash(body))
    list(path = file.path(settings$paths$scripts, sprintf("%s%s_%s.R", number, letters_used[i], title)), lines = c(marker, body))
  })
  list(files = files, notes = notes)
}
