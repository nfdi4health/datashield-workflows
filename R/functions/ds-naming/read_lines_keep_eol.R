# A text file's lines plus its line ending ("\r\n" or "\n"), so a file
# written back with write_lines_keep_eol() differs only where it was
# edited.
read_lines_keep_eol <- function(path) {
  raw <- readBin(path, "raw", file.size(path))
  eol <- if (length(raw) > 0 && any(raw == as.raw(13))) {
    "\r\n"
  } else {
    "\n"
  }
  list(lines = readLines(path, warn = FALSE, encoding = "UTF-8"), eol = eol,
       final_newline = length(raw) == 0 || raw[length(raw)] == as.raw(10))
}
