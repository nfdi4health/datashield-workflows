# The roxygen suggestion PR's description, rebuilt on every run from all
# findings the PR carries (merge_roxygen_findings()), so it stays one
# report instead of growing an update per run:
# - "Applied changes (n)", one group per file, each change with reason,
#   explanation and the commit it came from;
# - "No changes applied (n)", one group per reason, each suggestion with
#   Claude's proposed text, so a reviewer can adopt one by hand;
# - "Possible bugs in the code (n)" (format_code_issues()).
# Counts are open findings; crossed-out ones stay visible, struck through
# with when and why (finding_line()). On top: the summary line and, when
# `latest` is given (list(sha, stats)), what the latest review changed.
# Then `legacy` (the description of a bot PR opened before this format) in
# a collapsed section, and the hidden state for the next run
# (encode_suggestion_state()). Heading levels and spacing come from
# config/report-style.yml. Kept below GitHub's body limit. `open`: ids of
# findings whose group is shown expanded (the choices workflow passes the
# ones whose box just changed).
format_roxygen_report <- function(state, latest = NULL, legacy = NULL, open = integer(0)) {
  style <- report_style()
  entries <- state$entries
  is_active <- function(e) identical(e$status, "active")
  active_first <- function(x) c(Filter(is_active, x), Filter(Negate(is_active), x))
  of_kind <- function(kind) Filter(function(e) identical(e$kind, kind), entries)
  # Counted: open findings, not the ones the user declined.
  count <- function(x) sum(vapply(x, function(e) is_active(e) && !identical(suggestion_choice(e), "declined"), logical(1)))
  quote <- function(text) {
    if (is.null(text) || !nzchar(trimws(text))) {
      return(character(0))
    }
    paste0("  > ", strsplit(text, "\n", fixed = TRUE)[[1]])
  }
  is_open <- function(x) any(vapply(x, function(e) as.integer(e$id) %in% open, logical(1)))

  applied <- of_kind("applied")
  applied_groups <- report_groups(lapply(unique(vapply(applied, function(e) e$file, character(1))), function(p) {
    of_file <- active_first(Filter(function(e) identical(e$file, p), applied))
    list(title = group_title(p, of_file), lines = vapply(of_file, function(e) {
      choice_line(e, sprintf("`%s` — `%s`: %s", e$field, e$reason, e$explanation), sprintf("`%s` — `%s`: %s", e$field, e$reason, e$explanation))
    }, character(1)), open = is_open(of_file))
  }), style)

  dropped <- of_kind("dropped")
  dropped_groups <- report_groups(lapply(unique(vapply(dropped, function(e) e$reason, character(1))), function(r) {
    of_reason <- Filter(function(e) identical(e$reason, r), dropped)
    lines <- unlist(lapply(unique(vapply(of_reason, function(e) e$file, character(1))), function(p) {
      c(sprintf("**`%s`**", p), unlist(lapply(active_first(Filter(function(e) identical(e$file, p), of_reason)), function(e) {
        line <- choice_line(e, sprintf("`%s`: %s", e$field, e$explanation), sprintf("`%s`: %s", e$field, e$explanation))
        if (is_active(e)) {
          line <- c(line, quote(e$proposed))
        }
        line
      })), "")
    }))
    list(title = group_title(r, of_reason), lines = lines, open = is_open(of_reason))
  }), style)

  latest_line <- format_latest_review(latest)

  body <- paste("**Summary:**", format_roxygen_summary(state))
  if (!is.null(latest_line)) {
    body <- c(body, "", latest_line)
  }
  body <- c(body, "")
  if (length(applied) > 0) {
    body <- c(body,
      report_heading(sprintf("Applied changes (%d)", count(applied)), style),
      "",
      "Untick what you don't want: the branch follows within a minute, and an unticked change isn't suggested again while the function's code stays the same.",
      "",
      applied_groups
    )
  }
  if (length(dropped) > 0) {
    body <- c(body,
      report_heading(sprintf("No changes applied (%d)", count(dropped)), style),
      "",
      "Suggestions whose reason isn't on the accepted list (the `accept-reasons` input, or the reasons marked `accept: true` in `config/suggestion-policy.yml`). Tick one to apply it: the branch follows within a minute.",
      "",
      dropped_groups
    )
  }
  body <- c(body, format_code_issues(entries, style))
  finish_suggestion_report(body, state, legacy)
}
