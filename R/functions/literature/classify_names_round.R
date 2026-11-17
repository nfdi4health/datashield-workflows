# The vocabulary's name round: the names not classified yet (most used
# first), in batches of `vocabulary$batch`, at most `calls` calls. Returns
# list(vocab, calls = calls made, limit = TRUE at the usage limit,
# classified = names classified).
classify_names_round <- function(vocab, reg, claude, settings, today, by, calls) {
  new <- unclassified_names(reg, vocab)
  size <- settings$vocabulary$batch %||% 60
  made <- 0
  done <- 0
  limit <- FALSE
  for (batch in split(seq_len(nrow(new)), ceiling(seq_len(nrow(new)) / size))) {
    if (made >= calls) break
    b <- new[batch, , drop = FALSE]
    known <- if (length(vocab$methods) == 0) "(none yet)" else
      paste(sprintf("- %s: %s", names(vocab$methods), vapply(vocab$methods, function(m) m$name %||% "", "")), collapse = "\n")
    names_text <- paste(sprintf("- %s (%d papers%s)", b$name, b$papers,
      ifelse(nzchar(b$variants), paste0("; variants: ", b$variants), "")), collapse = "\n")
    res <- call_watch_claude(claude, build_method_classes_tool(),
      fill_template(claude$prompt, list(KNOWN_METHODS = known, NEW_NAMES = names_text)), sprintf("%d method names", nrow(b)))
    made <- made + 1
    if (res$limit) {
      limit <- TRUE
      break
    }
    if (is.null(res$answer)) next
    before <- length(vocab$names)
    vocab <- apply_method_classes(vocab, res$answer, b$name, today, by)
    done <- done + length(vocab$names) - before
  }
  list(vocab = vocab, calls = made, limit = limit, classified = done)
}
