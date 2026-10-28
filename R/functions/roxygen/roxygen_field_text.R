# Claude's new text for one managed field, by the same keys as
# original_roxygen_field().
roxygen_field_text <- function(result, key) {
  if (startsWith(key, "param:")) {
    return(result$params[[sub("^param:", "", key)]])
  }
  switch(key,
    title = result$title,
    description = result$description,
    details = result$details,
    return = result$return_doc,
    examples = result$examples_body
  )
}
