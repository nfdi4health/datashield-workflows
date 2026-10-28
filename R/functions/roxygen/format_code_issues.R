# "Possible bugs in the code (n)": defects Claude noticed while reviewing
# the documentation, one collapsible group per file; n counts the open
# ones, crossed-out ones (finding_line()) stay visible below them. A
# medium-confidence finding is labelled as such. Nothing is changed in the
# code. `entries` are stored findings (merge_roxygen_findings()); only
# those of kind "bug" are used. `style` from report_style().
format_code_issues <- function(entries, style = report_style()) {
  bugs <- Filter(function(e) identical(e$kind, "bug"), entries)
  if (length(bugs) == 0) {
    return(character(0))
  }
  is_active <- function(e) identical(e$status, "active")
  n <- sum(vapply(bugs, is_active, logical(1)))
  paths <- unique(vapply(bugs, function(e) e$file, character(1)))

  c(
    report_heading(sprintf("Possible bugs in the code (%d)", n), style),
    "",
    "Noticed while reviewing the documentation — nothing in the code was changed. Please check.",
    "",
    report_groups(lapply(paths, function(p) {
      of_file <- Filter(function(e) identical(e$file, p), bugs)
      of_file <- c(Filter(is_active, of_file), Filter(Negate(is_active), of_file))
      list(title = group_title(p, of_file), lines = vapply(of_file, function(e) {
        label <- if (identical(e$confidence, "medium")) {
          " _(medium confidence)_"
        } else {
          ""
        }
        finding_line(e, sprintf("**%s**%s %s", e$summary, label, e$explanation), sprintf("**%s**", e$summary))
      }, character(1)))
    }), style)
  )
}
