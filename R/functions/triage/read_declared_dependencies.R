# What the package declares it needs, from DESCRIPTION on the default
# branch: the fields in settings$description_fields (Depends, Imports,
# Suggests, …), one per line, for the triage to recognise a dependency a
# function uses (its @import lines, an error such as "there is no package
# called …") but the package doesn't declare. Installing only installs
# declared packages, so such a package installs and then fails when used.
# One call; "" when there is no DESCRIPTION (not an R package) or it can't
# be read.
read_declared_dependencies <- function(settings) {
  content <- get_github_json(sprintf("/repos/%s/contents/DESCRIPTION", repo))
  if (is.null(content$content)) {
    return("")
  }
  local <- tempfile()
  on.exit(unlink(local), add = TRUE)
  writeBin(jsonlite::base64_dec(gsub("\\s", "", content$content)), local)
  fields <- tryCatch(read.dcf(local), error = function(e) NULL)
  if (is.null(fields) || nrow(fields) == 0) {
    return("")
  }
  wanted <- intersect(unlist(settings$description_fields), colnames(fields))
  lines <- vapply(wanted, function(f) {
    sprintf("%s: %s", f, trimws(gsub("[[:space:]]+", " ", fields[1, f])))
  }, character(1))
  paste(lines, collapse = "\n")
}
