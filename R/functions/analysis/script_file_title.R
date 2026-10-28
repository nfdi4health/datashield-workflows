# The title part of a script file name: the step title in CamelCase ASCII
# ("Descriptive statistics" -> "DescriptiveStatistics"), cut to
# `max_chars` characters (settings) so long titles don't give unwieldy
# file names.
script_file_title <- function(title, max_chars) {
  words <- strsplit(iconv(title, to = "ASCII//TRANSLIT", sub = ""), "[^A-Za-z0-9]+")[[1]]
  words <- words[nzchar(words)]
  if (length(words) == 0) {
    return("Step")
  }
  substr(paste0(toupper(substr(words, 1, 1)), substr(words, 2, nchar(words)), collapse = ""), 1, max_chars)
}
