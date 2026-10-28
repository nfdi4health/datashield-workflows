# Finds the scripts this workflow wrote earlier, by their first line:
#   #### bot-suggest: step=<id> plan=<hash> content=<hash>
# Returns a data frame with one row per file: path, number (e.g. "03"),
# step id, plan hash, and whether the analyst edited it (the rest of the
# file no longer matches the content hash).
find_bot_step_files <- function(dir = "R") {
  files <- list.files(dir, pattern = "^[0-9]{2}[a-z]?_.*\\.R$", full.names = TRUE)
  pattern <- "^#### bot-suggest: step=(\\S+) plan=([0-9a-f]+) content=([0-9a-f]+)$"
  rows <- lapply(files, function(f) {
    lines <- readLines(f, warn = FALSE)
    if (length(lines) == 0 || !grepl(pattern, lines[1])) {
      return(NULL)
    }
    data.frame(
      path = f,
      number = substr(basename(f), 1, 2),
      step = sub(pattern, "\\1", lines[1]),
      plan_hash = sub(pattern, "\\2", lines[1]),
      edited = !identical(text_hash(lines[-1]), sub(pattern, "\\3", lines[1]))
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0) {
    return(data.frame(path = character(0), number = character(0), step = character(0), plan_hash = character(0), edited = logical(0)))
  }
  do.call(rbind, rows)
}
