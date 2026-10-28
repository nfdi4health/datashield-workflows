# Writes `lines` with the line ending and final newline of `file`
# (read_lines_keep_eol()), as UTF-8 bytes.
write_lines_keep_eol <- function(lines, file, path) {
  text <- paste(enc2utf8(lines), collapse = file$eol)
  if (file$final_newline) {
    text <- paste0(text, file$eol)
  }
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(text), con)
}
