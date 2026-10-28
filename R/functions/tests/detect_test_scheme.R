# How the package names its test files. Some repositories (dsBaseClient,
# dsBase) use test-<category>-<function>.R, with several files per
# function (`arg`, `smk`, `disc`, …). A file counts as categorised when its
# name is test-<category>-<function>.R for a function the package defines
# and a category of letters, digits and underscores — unless the whole
# name is itself a function (test-read-config.R belongs to read_config()
# or read.config(), not to config()). The repository counts as
# categorised when at least 3 test files and at least half of them are
# (see dev-notes/test-suggest.md); only then are new tests placed by
# category. The categorised files are found in either case, so a plain
# repository's occasional test-arg-<function>.R is still reviewed.
# Returns list(categorised, categories — ordered by how often they
# occur —, files: data frame of path, category, fn).
detect_test_scheme <- function(function_names) {
  files <- list.files(file.path("tests", "testthat"), pattern = "^test-.*\\.[Rr]$")
  parts <- regmatches(files, regexec("^test-([A-Za-z0-9_]+)-(.+)\\.[Rr]$", files))
  is_categorised <- vapply(parts, function(p) {
    if (length(p) != 3 || !p[3] %in% function_names) {
      return(FALSE)
    }
    whole <- paste(p[2], p[3], sep = "-")
    !any(c(gsub("-", "_", whole), gsub("-", ".", whole)) %in% function_names)
  }, logical(1))

  matched <- parts[is_categorised]
  found <- data.frame(
    path = file.path("tests", "testthat", files[is_categorised]),
    category = vapply(matched, function(p) p[2], character(1)),
    fn = vapply(matched, function(p) p[3], character(1)),
    stringsAsFactors = FALSE
  )
  list(
    categorised = nrow(found) >= 3 && nrow(found) >= length(files) / 2,
    categories = names(sort(table(found$category), decreasing = TRUE)),
    files = found
  )
}
