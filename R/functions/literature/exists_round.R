# "Exists in DataSHIELD?" for the methods and variants named in at least
# `exists$min_papers` usable papers (most used first): R picks each one's
# candidate functions (preselect_functions()); those without any get
# `none` from R; the rest are asked in batches of `exists$batch`, at most
# `calls` calls, and the answers checked (check_exists_answer()). A stored
# verdict is asked again only when its candidates change (their hash).
# Returns list(vocab, calls, limit, checked).
exists_round <- function(vocab, reg, claude, inventory, settings, today, by, calls) {
  e <- settings$exists
  counts <- method_paper_counts(reg, vocab)
  counts <- counts[counts$papers >= (e$min_papers %||% 3), , drop = FALSE]
  get_rec <- function(method, variant) {
    if (nzchar(variant)) vocab$methods[[method]]$variants[[variant]]$exists else vocab$methods[[method]]$exists
  }
  set_rec <- function(method, variant, rec) {
    if (nzchar(variant)) {
      if (is.null(vocab$methods[[method]]$variants[[variant]])) vocab$methods[[method]]$variants[[variant]] <<- list(name = variant)
      vocab$methods[[method]]$variants[[variant]]$exists <<- rec
    } else {
      vocab$methods[[method]]$exists <<- rec
    }
  }
  pending <- list()
  for (i in seq_len(nrow(counts))) {
    method <- counts$method[i]
    variant <- counts$variant[i]
    m <- vocab$methods[[method]]
    words <- c(m$name, unlist(m$keywords), if (nzchar(variant)) method_label(vocab, method, variant))
    cand <- preselect_functions(inventory, words, e$candidates %||% 15)
    hash <- hash_keys(paste(c(method, variant, paste(cand$package, cand$fn, cand$title, cand$description, cand$status)), collapse = "\n"))
    if (identical(get_rec(method, variant)$candidates, hash)) next
    if (nrow(cand) == 0) {
      set_rec(method, variant, list(verdict = "none", `function` = "", quote = "",
        note = "No function's name or documentation shares a word with the method.", checked = as.character(today),
        candidates = hash, by = "R"))
      next
    }
    pending[[length(pending) + 1]] <- list(method = method, variant = variant, cand = cand, hash = hash)
  }
  size <- e$batch %||% 5
  made <- 0
  done <- 0
  limit <- FALSE
  for (batch in split(seq_along(pending), ceiling(seq_along(pending) / size))) {
    if (made >= calls) break
    items <- pending[batch]
    ids <- paste0("m", seq_along(items))
    text <- paste(vapply(seq_along(items), function(k) {
      it <- items[[k]]
      m <- vocab$methods[[it$method]]
      c_lines <- sprintf("- %s::%s (status: %s): %s. %s", it$cand$package, it$cand$fn,
        ifelse(nzchar(it$cand$status), it$cand$status, "unknown"), it$cand$title, it$cand$description)
      sprintf("<method id=\"%s\">\nMethod: %s. %s\nVariant: %s\nCandidate functions:\n%s\n</method>", ids[k],
        m$name %||% it$method, m$description %||% "",
        if (nzchar(it$variant)) method_label(vocab, it$method, it$variant) else "none (the plain method)",
        paste(c_lines, collapse = "\n"))
    }, ""), collapse = "\n\n")
    res <- call_watch_claude(claude, build_exists_tool(), fill_template(claude$prompt, list(METHODS = text)),
      sprintf("%d methods' existence", length(items)))
    made <- made + 1
    if (res$limit) {
      limit <- TRUE
      break
    }
    if (is.null(res$answer)) next
    for (a in res$answer$methods %||% list()) {
      k <- match(a$id, ids)
      if (is.na(k)) next
      it <- items[[k]]
      set_rec(it$method, it$variant, check_exists_answer(a, it$cand, it$hash, today, by))
      done <- done + 1
    }
  }
  list(vocab = vocab, calls = made, limit = limit, checked = done)
}
