# Classifies the failed generated tests of one function (`items`: list of
# list(block, message)): first by R where the message alone decides
# (obvious_failure_classification()), the rest in one Claude call with the
# function's source sent once (ask_claude_to_classify_failures()).
# Returns a list parallel to `items`: a classification (explanation,
# category, confidence) each, or NULL where the Claude call failed.
classify_failures <- function(claude, items, function_source, function_name) {
  out <- lapply(items, function(it) obvious_failure_classification(it$message))
  open <- which(vapply(out, is.null, logical(1)))
  if (length(open) == 0) {
    return(out)
  }
  answers <- tryCatch(ask_claude_to_classify_failures(claude, function_source, items[open]), error = function(e) {
    message(sprintf("Failure classification call failed for %s: %s", function_name, conditionMessage(e)))
    list()
  })
  for (a in answers) {
    k <- suppressWarnings(as.integer(sub("^F", "", a$failure)))
    if (!is.na(k) && k >= 1 && k <= length(open)) {
      out[[open[k]]] <- a[c("explanation", "category", "confidence")]
    }
  }
  out
}
