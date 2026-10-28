# The roxygen lines of one managed field (keys as in
# original_roxygen_field(): "title", "description", "details", "return",
# "examples", "param:<name>") with the given text, written as
# build_roxygen_block() writes them.
roxygen_field_lines <- function(key, text) {
  text_lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  if (identical(key, "examples")) {
    return(c("#' @examples", "#' \\dontrun{", paste0("#' ", text_lines), "#' }"))
  }
  tag <- if (startsWith(key, "param:")) {
    paste("param", sub("^param:", "", key))
  } else if (identical(key, "return")) {
    "return"
  } else {
    key
  }
  paste0("#' ", c(paste0("@", tag, " ", text_lines[1]), text_lines[-1]))
}
