# Collapsible groups of the suggestion reports, styled per
# config/report-style.yml (report_style()). `groups` is a list of
# list(title, lines, open): `open` TRUE shows the group expanded (the
# choices workflow does that for the groups whose boxes were just changed,
# so they don't collapse under the user). Always ends with a blank line:
# without it, Markdown after the last `</details>` would be swallowed into
# the HTML block.
report_groups <- function(groups, style = report_style()) {
  summary <- function(title) {
    h <- style$group_heading
    if (identical(h, "bold")) {
      sprintf("<b>%s</b>", title)
    } else if (identical(h, "plain")) {
      title
    } else {
      sprintf("<h%d>%s</h%d>", as.integer(h), title, as.integer(h))
    }
  }

  out <- character(0)
  for (i in seq_along(groups)) {
    g <- groups[[i]]
    open <- ""
    if (isTRUE(g$open)) {
      open <- " open"
    }
    out <- c(out, sprintf("<details%s><summary>%s</summary>", open, summary(g$title)), "", g$lines, "", "</details>")
    if (i < length(groups) && isTRUE(style$blank_line_between_groups)) {
      out <- c(out, "")
    }
  }
  c(out, "")
}
