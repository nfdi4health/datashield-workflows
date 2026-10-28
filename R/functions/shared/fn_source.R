# Extracts a parsed function's full source text (header through closing
# brace) via brace-depth counting, for feeding to Claude as review context.
fn_source <- function(parsed) {
  lines <- parsed$lines
  start <- parsed$fn_start
  depth <- 0; started <- FALSE; end <- start
  for (i in start:length(lines)) {
    opens  <- lengths(regmatches(lines[i], gregexpr("\\{", lines[i])))
    closes <- lengths(regmatches(lines[i], gregexpr("\\}", lines[i])))
    if (opens > 0) {
      started <- TRUE
    }
    depth <- depth + opens - closes
    if (started && depth <= 0) { end <- i; break }
    end <- i
  }
  paste(lines[start:end], collapse = "\n")
}
