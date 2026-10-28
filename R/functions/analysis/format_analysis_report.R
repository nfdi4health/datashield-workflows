# The suggestion PR's description (and the job summary): what was written,
# how to try it, what else the plan would need, and what wasn't proposed.
# `r` is the run record built by the entry script: steps (per step: title,
# status, files, notes, error), general notes, tested versions, the
# repository for issue links, `names` (MAIN, DEPENDENCIES, TESTING,
# PRODUCTION) for the texts that mention files and profiles, and
# `package_status` (package -> catalogue status) for "other package"
# notes, and `gap_issues` (fetch_gap_issues()): a missing function already
# requested links to that issue instead of offering a new one. Wording
# from `texts$report`.
format_analysis_report <- function(r, texts) {
  t <- texts$report
  out <- c(t$intro, "", fill_template(t$tested_with, list(TESTED_WITH = r$tested_with)))

  written <- Filter(function(s) s$status %in% c("written", "not_possible"), r$steps)
  if (length(written) > 0) {
    out <- c(out, "", t$scripts_heading, "")
    for (s in written) {
      suffix <- ""
      if (identical(s$status, "not_possible")) {
        suffix <- t$notes_only_suffix
      }
      out <- c(out, sprintf("- **%s**: %s%s", s$title, paste(sprintf("`%s`", s$files), collapse = ", "), suffix))
    }
    out <- c(out, "", fill_template(t$try_it, r$names))
  }

  by_kind <- function(kind) {
    unlist(lapply(r$steps, function(s) lapply(Filter(function(n) identical(n$kind, kind), s$notes), function(n) c(n, step_title = s$title))), recursive = FALSE)
  }
  other <- by_kind("other_package")
  if (length(other) > 0) {
    out <- c(out, "", t$other_package_heading, "", fill_template(t$other_package_intro, r$names), "")
    for (n in other) {
      # The package's catalogue status next to it, so a development package
      # isn't mistaken for an established one.
      pkg <- sprintf("`%s` (%s)", n$package, r$package_status[[n$package]] %||% "unknown")
      where <- if (nzchar(n[["function"]] %||% "")) {
        sprintf("%s, `%s()`", pkg, n[["function"]])
      } else {
        pkg
      }
      out <- c(out, sprintf("- **%s** — %s: %s", n$step_title, where, n$text))
    }
  }
  gaps <- by_kind("missing_function")
  if (length(gaps) > 0) {
    out <- c(out, "", t$gaps_heading, "", t$gaps_intro, "")
    for (n in gaps) {
      issue <- r$gap_issues[as.character(r$gap_issues$number) == (n$existing_issue %||% ""), ]
      link <- if (nrow(issue) == 1) {
        fill_template(t$already_requested, list(LINK = sprintf("[#%s](%s)", issue$number, issue$url)))
      } else {
        sprintf("[%s](%s)", t$open_issue, gap_issue_link(r$gap_issue_repo, n$step_title, n$text, texts))
      }
      out <- c(out, sprintf("- **%s**: %s %s", n$step_title, n$text, link))
    }
  }
  limits <- by_kind("limitation")
  if (length(limits) > 0) {
    out <- c(out, "", t$limitations_heading, "")
    for (n in limits) {
      out <- c(out, sprintf("- **%s**: %s", n$step_title, n$text))
    }
  }

  reported <- Filter(function(s) s$status %in% c("failed", "blocked", "edited", "removed"), r$steps)
  if (length(reported) + length(r$notes) > 0) {
    out <- c(out, "", t$other_notes_heading, "")
    for (s in reported) {
      out <- c(out, sprintf("- **%s**: %s", s$title, s$error))
    }
    for (n in r$notes) {
      out <- c(out, sprintf("- %s", n))
    }
  }
  out
}
