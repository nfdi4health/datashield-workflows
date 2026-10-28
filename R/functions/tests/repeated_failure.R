# Whether a failed generated test (`fail`, with Claude's fields `test`)
# repeats one the bot reported before for this function (`earlier`: its
# open findings) — same name, or the earlier finding Claude says it
# repeats. Repeats aren't classified, commented or filed again.
repeated_failure <- function(fail, test, earlier) {
  repeated_id <- if (!is.null(test$repeats_earlier) && nzchar(test$repeats_earlier)) {
    suppressWarnings(as.integer(sub("^E", "", test$repeats_earlier)))
  } else {
    NA_integer_
  }
  failed_before <- function(e) identical(e$kind, "failed") || (identical(e$kind, "bug") && identical(e$origin, "failure"))
  any(vapply(earlier, function(e) failed_before(e) && (identical(as.integer(e$id), repeated_id) || identical(e$description, fail$description)), logical(1)))
}
