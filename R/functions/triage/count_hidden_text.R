# How many places in `texts` hold something the page doesn't show: HTML
# comments, also unclosed ones, and runs of invisible characters (zero-width
# space, word joiner, byte order mark, text direction controls). Claude reads
# these, the person approving doesn't see them. Zero-width joiners are left
# out: emoji use them.
#
# A count only. The text is never repeated: a bot comment may become the
# implementer's source. Harmless cases exist, such as the hints in issue
# templates, so this informs and blocks nothing.
count_hidden_text <- function(texts) {
  texts <- unlist(texts)
  texts <- texts[!is.na(texts)]
  # Real characters, not \x{...}: that needs PCRE's UTF mode, which R only
  # turns on for marked strings, so it fails depending on the platform.
  invisible <- intToUtf8(c(0x200B, 0x2060, 0xFEFF, 0x202A:0x202E, 0x2066:0x2069))
  hidden <- paste0("<!--[\\s\\S]*?(?:-->|\\z)|[", invisible, "]+")
  sum(vapply(texts, function(x) {
    found <- gregexpr(hidden, enc2utf8(x), perl = TRUE)[[1]]
    sum(found > 0)
  }, numeric(1), USE.NAMES = FALSE))
}
