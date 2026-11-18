# "Exists in DataSHIELD?" down the ranking (R/candidates_literature.R): a
# method is checked only once it is among the most used ones still in
# question, not every night for every method. `ranked` is
# rank_candidates()'s table, best first. Walking it, rows with status
# `new` are looked at in order: R picks each one's candidate functions
# (preselect_functions()); a stored verdict counts while those candidates
# are unchanged (their hash), a row without candidates is `none` from R,
# the others are asked in batches of `exists$batch`, at most `calls` calls,
# and checked (check_exists_answer()). A variant is looked at only once
# its method has a verdict; a variant of a method DataSHIELD lacks
# (`none`) is covered by the method. The walk stops once `want` gaps
# (`none` or `partial`; `development` doesn't count, user 2026-11-16) are
# found. Deferred rows keep the verdict they have. `exclude`: keys left
# out with their variants (the other list's candidates). Returns list(vocab,
# ranked with verdict, function and note, gaps = the keys in order, calls,
# limit, checked, complete = FALSE when the calls ran out first).
exists_for_ranked <- function(ranked, vocab, claude, inventory, settings, today, by, calls, want, exclude = character(0)) {
  e <- settings$exists
  gap <- c("none", "partial")
  cands <- new.env()
  candidates_of <- function(method, variant) {
    key <- if (nzchar(variant)) paste(method, variant, sep = "/") else method
    if (is.null(cands[[key]])) {
      m <- vocab$methods[[method]]
      words <- c(m$name, unlist(m$keywords), if (nzchar(variant)) method_label(vocab, method, variant))
      cand <- preselect_functions(inventory, words, e$candidates %||% 15)
      hash <- hash_keys(paste(c(method, variant, paste(cand$package, cand$fn, cand$title, cand$description, cand$status)), collapse = "\n"))
      assign(key, list(cand = cand, hash = hash), envir = cands)
    }
    cands[[key]]
  }
  current <- function(method, variant) {
    rec <- exists_record(vocab, method, variant)
    if (!is.null(rec) && identical(rec$candidates, candidates_of(method, variant)$hash)) rec else NULL
  }
  set_rec <- function(method, variant, rec) {
    if (nzchar(variant)) {
      if (is.null(vocab$methods[[method]]$variants[[variant]])) vocab$methods[[method]]$variants[[variant]] <<- list(name = variant)
      vocab$methods[[method]]$variants[[variant]]$exists <<- rec
    } else {
      vocab$methods[[method]]$exists <<- rec
    }
  }
  made <- 0
  done <- 0
  limit <- FALSE
  complete <- TRUE
  # Keys already proposed (the other list) and their variants are left out.
  excluded <- ranked$key %in% exclude | ranked$method %in% exclude
  rows <- which(ranked$status == "new" & !excluded)
  if (want <= 0) rows <- integer(0)
  repeat {
    gaps <- character(0)
    needed <- list()
    for (i in rows) {
      method <- ranked$method[i]
      variant <- ranked$variant[i]
      if (nzchar(variant)) {
        parent <- current(method, "")
        if (is.null(parent)) {
          needed[[method]] <- list(method = method, variant = "")
          if (length(gaps) + length(needed) >= want) break
          next
        }
        if (identical(parent$verdict, "none")) next
      }
      rec <- current(method, variant)
      if (is.null(rec)) {
        needed[[ranked$key[i]]] <- list(method = method, variant = variant)
      } else if (rec$verdict %in% gap) {
        gaps <- c(gaps, ranked$key[i])
      }
      if (length(gaps) + length(needed) >= want) break
    }
    if (length(needed) == 0) break
    if (made >= calls || limit) {
      complete <- FALSE
      break
    }
    # R answers what has no candidate functions; Claude the rest, one batch.
    ask <- list()
    for (it in needed) {
      cand <- candidates_of(it$method, it$variant)
      if (nrow(cand$cand) == 0) {
        set_rec(it$method, it$variant, list(verdict = "none", `function` = "", quote = "",
          note = "No function's name or documentation shares a word with the method.", checked = as.character(today),
          candidates = cand$hash, by = "R"))
      } else {
        ask[[length(ask) + 1]] <- it
      }
    }
    ask <- utils::head(ask, e$batch %||% 5)
    if (length(ask) == 0) next
    ids <- paste0("m", seq_along(ask))
    text <- paste(vapply(seq_along(ask), function(k) {
      it <- ask[[k]]
      m <- vocab$methods[[it$method]]
      cand <- candidates_of(it$method, it$variant)$cand
      c_lines <- sprintf("- %s::%s (status: %s): %s. %s", cand$package, cand$fn,
        ifelse(nzchar(cand$status), cand$status, "unknown"), cand$title, cand$description)
      sprintf("<method id=\"%s\">\nMethod: %s. %s\nVariant: %s\nCandidate functions:\n%s\n</method>", ids[k],
        m$name %||% it$method, m$description %||% "",
        if (nzchar(it$variant)) method_label(vocab, it$method, it$variant) else "none (the plain method)",
        paste(c_lines, collapse = "\n"))
    }, ""), collapse = "\n\n")
    res <- call_watch_claude(claude, build_exists_tool(), fill_template(claude$prompt, list(METHODS = text)),
      sprintf("%d methods' existence", length(ask)))
    made <- made + 1
    if (res$limit) {
      limit <- TRUE
      next
    }
    answered <- 0
    for (a in res$answer$methods %||% list()) {
      k <- match(a$id, ids)
      if (is.na(k)) next
      it <- ask[[k]]
      c <- candidates_of(it$method, it$variant)
      set_rec(it$method, it$variant, check_exists_answer(a, c$cand, c$hash, today, by))
      done <- done + 1
      answered <- answered + 1
    }
    # A failed call leaves its methods unanswered; without an answer the
    # walk can't go on past them in this run.
    if (answered == 0) {
      complete <- FALSE
      break
    }
  }
  ranked <- annotate_verdicts(ranked, vocab)
  list(vocab = vocab, ranked = ranked, gaps = gaps, calls = made, limit = limit, checked = done, complete = complete)
}
