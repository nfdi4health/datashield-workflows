# Lints on the lines the agent added: with the package's own lintr
# configuration (`.lintr`) if it has one, else only the layout linters below
# (spacing, braces, blank lines) — naming and assignment style are left to
# the package's own habits, which the default linters would contradict
# (dsBaseClient's `ds.mean`, `=`). Matches the layout part of the
# `r-code-style` skill in datashield-skills. Lines the change didn't touch
# are left out: old lints aren't the agent's to fix. Writes .agent/lint.md, which the maintainability reviewer reads
# (dev-notes/implementer-plan.md, "The agents' definitions"). Never fails.
# Usage: Rscript lint-changes.R <base branch>

# Added line numbers per file from `git diff -U0`.
added_lines <- function(diff) {
  out <- list()
  file <- NULL
  for (line in diff) {
    if (startsWith(line, "+++ ")) {
      file <- if (identical(line, "+++ /dev/null")) NULL else sub("^\\+\\+\\+ b/", "", line)
    } else if (!is.null(file) && startsWith(line, "@@")) {
      m <- regmatches(line, regexec("\\+([0-9]+)(,([0-9]+))?", line))[[1]]
      count <- if (nzchar(m[4])) as.integer(m[4]) else 1L
      if (count > 0) {
        out[[file]] <- c(out[[file]], seq(as.integer(m[2]), length.out = count))
      }
    }
  }
  out
}

layout_linters <- function() {
  list(
    brace = lintr::brace_linter(),
    commas = lintr::commas_linter(),
    infix_spaces = lintr::infix_spaces_linter(),
    paren_body = lintr::paren_body_linter(),
    spaces_inside = lintr::spaces_inside_linter(),
    spaces_left_parentheses = lintr::spaces_left_parentheses_linter(),
    function_left_parentheses = lintr::function_left_parentheses_linter(),
    trailing_whitespace = lintr::trailing_whitespace_linter(),
    trailing_blank_lines = lintr::trailing_blank_lines_linter(),
    whitespace = lintr::whitespace_linter()
  )
}

lint_changes <- function(base, max_lints = 50) {
  own <- file.exists(".lintr")
  source_name <- if (own) "the package's `.lintr`" else "layout linters only (the package has no `.lintr`)"
  lint_file <- function(file) {
    if (own) lintr::lint(file) else lintr::lint(file, linters = layout_linters(), parse_settings = FALSE)
  }
  diff <- system2("git", c("diff", "-U0", "--no-color", "--no-ext-diff", sprintf("origin/%s...HEAD", base), "--", "*.R", "*.r"),
                  stdout = TRUE)
  lines <- added_lines(diff)
  found <- character(0)
  for (file in names(lines)) {
    if (!file.exists(file)) next
    lints <- tryCatch(as.data.frame(lint_file(file)), error = function(e) NULL)
    if (is.null(lints) || nrow(lints) == 0) next
    lints <- lints[lints$line_number %in% lines[[file]], , drop = FALSE]
    found <- c(found, sprintf("- `%s:%d`: %s (%s)", file, lints$line_number, lints$message, lints$linter))
  }
  text <- if (length(found) == 0) {
    sprintf("lintr, %s: no lints on the changed lines.", source_name)
  } else {
    c(sprintf("lintr, %s: %d lint(s) on the changed lines.", source_name, length(found)), "",
      utils::head(found, max_lints),
      if (length(found) > max_lints) sprintf("- … and %d more.", length(found) - max_lints))
  }
  writeLines(text, ".agent/lint.md")
  invisible(found)
}

if (!interactive() && sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  tryCatch(lint_changes(args[1]), error = function(e) {
    writeLines(c("lintr could not run:", "", "```", conditionMessage(e), "```"), ".agent/lint.md")
  })
}
