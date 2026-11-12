# Lints on the lines the agent added, with the package's own lintr
# configuration (`.lintr`; run-checks.sh only calls this when the package
# has one, so no style is imposed on a package that hasn't chosen one).
# Lines the change didn't touch are left out: old lints aren't the agent's
# to fix. Writes .agent/lint.md, which the maintainability reviewer reads
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

lint_changes <- function(base, max_lints = 50) {
  diff <- system2("git", c("diff", "-U0", "--no-color", "--no-ext-diff", sprintf("origin/%s...HEAD", base), "--", "*.R", "*.r"),
                  stdout = TRUE)
  lines <- added_lines(diff)
  found <- character(0)
  for (file in names(lines)) {
    if (!file.exists(file)) next
    lints <- tryCatch(as.data.frame(lintr::lint(file)), error = function(e) NULL)
    if (is.null(lints) || nrow(lints) == 0) next
    lints <- lints[lints$line_number %in% lines[[file]], , drop = FALSE]
    found <- c(found, sprintf("- `%s:%d`: %s (%s)", file, lints$line_number, lints$message, lints$linter))
  }
  text <- if (length(found) == 0) {
    "lintr, with the package's `.lintr`: no lints on the changed lines."
  } else {
    c(sprintf("lintr, with the package's `.lintr`: %d lint(s) on the changed lines.", length(found)), "",
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
