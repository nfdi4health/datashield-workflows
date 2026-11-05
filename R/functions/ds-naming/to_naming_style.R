# An argument name in the rules' general style: words split at ".", "_"
# and camelCase boundaries, joined by `separator`, in lower case when
# `case` (`style$case` in the rules) says "lowercase" (e.g. idCol ->
# id.col, time_col -> time.col with "."). Leading dots (internal
# names) are kept.
to_naming_style <- function(name, separator, case) {
  lead <- regmatches(name, regexpr("^\\.*", name))
  core <- sub("^\\.*", "", name)
  core <- gsub("([a-z0-9])([A-Z])", "\\1 \\2", core)
  # an acronym before a word (CIlevel -> ci level), not a plural (NAs -> nas)
  core <- gsub("([A-Z]+)([A-Z][a-z]{2,})", "\\1 \\2", core)
  words <- strsplit(core, "[._ ]+")[[1]]
  if (identical(case, "lowercase")) {
    words <- tolower(words)
  }
  paste0(lead, paste(words[nzchar(words)], collapse = separator))
}
