# The checkboxes of a bot PR's description (choice_line()): a named
# logical vector, finding id ("12" for E12) -> ticked. Only lines carrying
# the hidden marker "<!-- choice:E12 -->" count, so other task lists in
# the description are ignored. Empty if there are none.
read_suggestion_choices <- function(body) {
  if (is.null(body) || !nzchar(body)) {
    return(logical(0))
  }
  lines <- strsplit(body, "\r?\n")[[1]]
  hits <- regmatches(lines, regexec("^\\s*[-*] \\[([ xX])\\] .*<!-- choice:E([0-9]+) -->\\s*$", lines))
  hits <- Filter(function(h) length(h) == 3, hits)
  stats::setNames(vapply(hits, function(h) h[2] != " ", logical(1)), vapply(hits, function(h) h[3], character(1)))
}
