# The check's report in Markdown: how many user-facing arguments already
# follow the rules, the proposed renames per package (from `entries`,
# after merging decisions), what needs a person (unresolved, conflicts),
# and the report-only findings in `checks` (function names, argument
# order, test file names; one element per package). Returns list(full,
# summary): the full report is committed next to the transformation file,
# the summary (no tables) goes into the PR description, which GitHub caps
# in length.
format_naming_report <- function(rows, entries, checks, file_path, rules_version) {
  es <- unname(entries)
  field <- function(f) vapply(es, function(e) as.character(e[[f]] %||% ""), character(1))
  status <- field("status")
  pct <- function(n, d) {
    if (d == 0) {
      return("–")
    }
    sprintf("%d %%", round(100 * n / d))
  }
  code_list <- function(x) {
    if (length(x) == 0) {
      return("none")
    }
    paste(sprintf("`%s`", x), collapse = ", ")
  }
  open <- vapply(es, function(e) isTRUE(e$rule_open), logical(1))

  counts <- vapply(split(rows, rows$package), function(r) {
    ok <- sum(r$match %in% c("canonical", "exception"))
    sprintf("| %s | %s | %d | %d | %s |", r$package[1], r$side[1], length(unique(r$`function`)), nrow(r), pct(ok, nrow(r)))
  }, character(1))
  summary <- c(
    "## DataSHIELD argument names",
    "",
    sprintf("Checked against the naming rules (version %s).", rules_version),
    "",
    "| Package | Side | Functions | Arguments | Already following the rules |",
    "|---|---|---|---|---|",
    counts,
    "",
    sprintf("- **%d renames proposed** (%d of them under a rule that is still open), %d approved, %d skipped, %d applied.",
            sum(status == "proposed"), sum(open & status == "proposed"), sum(status == "approved"), sum(status == "skip"), sum(status == "applied")),
    sprintf("- **%d need a decision** (unresolved or conflicting): fill in `proposed` and approve, or skip.", sum(status == "unresolved")),
    sprintf("- %d of the entries were classified by Claude (arguments the code could not place).", sum(field("source") == "claude")),
    "",
    "### How to review",
    "",
    sprintf("Edit `%s` in this PR: set `status: approved` for renames to make (you may change `proposed`), `status: skip` for names to keep. Merge the PR; the apply workflow then renames the approved entries in code, tests and docs and opens a PR per package. Later checks keep your decisions.", file_path),
    "",
    sprintf("The full list is in `%s`.", sub("[^/]+$", "report.md", file_path))
  )

  table <- function(sel) {
    if (!any(sel)) {
      return("None.")
    }
    row <- function(x) {
      proposed <- "–"
      if (nzchar(x$proposed %||% "")) {
        proposed <- sprintf("`%s`", x$proposed)
      }
      rule <- x$rule
      if (isTRUE(x$rule_open)) {
        rule <- paste(rule, "(open)")
      }
      reason <- gsub("\\|", "/", paste(c(x$reason, x$note), collapse = " "))
      sprintf("| `%s` | `%s` | %s | %s | %s | %s |", x$`function`, x$current, proposed, rule, x$confidence %||% "", reason)
    }
    c("| Function | Current | Proposed | Rule | Confidence | Reason |", "|---|---|---|---|---|---|",
      vapply(es[sel], row, character(1)))
  }
  full <- c(summary[seq_len(which(summary == "### How to review") - 1)])
  for (pkg in unique(field("package"))) {
    in_pkg <- field("package") == pkg
    full <- c(full, sprintf("## %s", pkg), "",
              "### Need a decision", "", table(in_pkg & status == "unresolved"), "",
              "### Proposed renames", "", table(in_pkg & status %in% c("proposed", "approved")), "",
              "### Skipped", "", table(in_pkg & status == "skip"), "")
  }
  for (ch in checks) {
    test_lines <- "None."
    if (nrow(ch$tests) > 0) {
      test_lines <- sprintf("- `%s`: %s", ch$tests$file, ch$tests$problem)
    }
    full <- c(full, sprintf("## %s: other findings (report only)", ch$package), "",
              paste0("**Function names not following the pattern:** ", code_list(ch$function_names)), "",
              paste0("**`datasources` not last:** ", code_list(ch$order)), "",
              "**Test file names:**", "",
              test_lines, "")
  }
  list(full = paste(full, collapse = "\n"), summary = paste(summary, collapse = "\n"))
}
