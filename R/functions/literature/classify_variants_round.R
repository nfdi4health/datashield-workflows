# The vocabulary's variant round: per classified method its variant
# wordings not classified yet (methods with the most used wordings first),
# one call per method and batch, at most `calls` calls. Returns
# list(vocab, calls, limit, classified).
classify_variants_round <- function(vocab, reg, claude, settings, today, by, calls) {
  new <- unclassified_variants(reg, vocab)
  size <- settings$vocabulary$batch %||% 60
  made <- 0
  done <- 0
  limit <- FALSE
  order_methods <- names(sort(tapply(new$papers, new$method, sum), decreasing = TRUE))
  for (method in order_methods) {
    rows <- new[new$method == method, , drop = FALSE]
    for (batch in split(seq_len(nrow(rows)), ceiling(seq_len(nrow(rows)) / size))) {
      if (made >= calls || limit) break
      b <- rows[batch, , drop = FALSE]
      m <- vocab$methods[[method]]
      list_of <- function(x, empty) if (length(x) == 0) empty else
        paste(sprintf("- %s: %s", names(x), vapply(x, function(e) e$name %||% "", "")), collapse = "\n")
      res <- call_watch_claude(claude, build_variant_classes_tool(),
        fill_template(claude$prompt, list(METHOD_NAME = m$name %||% method, METHOD_DESCRIPTION = m$description %||% "",
          KNOWN_VARIANTS = list_of(m$variants, "(none yet)"), KNOWN_METHODS = list_of(vocab$methods, "(none yet)"),
          NEW_VARIANTS = paste(sprintf("- %s (%d papers)", b$variant, b$papers), collapse = "\n"))),
        sprintf("%d variants of %s", nrow(b), method))
      made <- made + 1
      if (res$limit) {
        limit <- TRUE
        break
      }
      if (is.null(res$answer)) next
      before <- length(vocab$variant_names[[method]])
      vocab <- apply_variant_classes(vocab, method, res$answer, b$variant, today, by)
      done <- done + length(vocab$variant_names[[method]]) - before
    }
    if (made >= calls || limit) break
  }
  list(vocab = vocab, calls = made, limit = limit, classified = done)
}
