# One stretch of the literature watch's reading, up to `budget` papers:
# months newest first (watch_months()), within each month the fields in
# order. A field's month is searched again when its sample isn't complete
# for the current search and target, or when it is one of the newest
# `recheck_months` and wasn't searched today (late papers arrive there).
# Its sample is the first `target_per_month` papers in the field's random
# order (sample_keys()); papers already in the register only get this
# field added to their record, the rest are fetched and read by Claude in
# batches. The register and the sampling state are written after every
# fetch of up to `fetch_size` papers, so a stop loses nothing written.
# Returns list(read = papers read (or found unusable), stopped = "budget",
# "limit" (the subscription's usage limit) or "done" (nothing left)).
run_watch_chunk <- function(settings, fields, dir, claude, today, budget, reader, fetch_size = 25) {
  s <- settings$sampling
  target <- s$target_per_month %||% 25
  months <- watch_months(today, s$lag_months %||% 2, s$years_back %||% 5)
  recent <- utils::head(months, s$recheck_months %||% 6)
  today <- as.character(today)
  reg <- read_register(dir)
  state <- read_months_state(dir)
  read <- 0
  save <- function() {
    write_register(reg, dir)
    write_months_state(state, dir)
  }
  set_row <- function(field_name, month, values) {
    i <- which(state$field == field_name & state$month == month)
    if (length(i) == 0) {
      state[nrow(state) + 1, ] <<- NA
      i <- nrow(state)
      state$field[i] <<- field_name
      state$month[i] <<- month
    }
    for (k in names(values)) state[[k]][i] <<- values[[k]]
  }
  for (month in months) {
    for (field in fields) {
      query <- hash_keys(field_search(field, settings))
      row <- state[state$field == field$name & state$month == month, , drop = FALSE]
      if (nrow(row) == 0) row <- NULL
      due <- !month_complete(row, query, target) || (month %in% recent && !identical(row$checked, today))
      if (!due) next
      found <- search_month_ids(field_search(field, settings), month, settings)
      keys <- sample_keys(field$name, found$ids)
      ord <- order(keys)
      n <- min(target, length(found$ids))
      sample <- found$ids[ord][seq_len(n)]
      sample_key <- keys[ord][seq_len(n)]
      names(sample_key) <- sample
      # Papers already read (for another field, or an earlier version of
      # this field's search) join this field's sample without a new read.
      for (pmid in intersect(sample, names(reg$papers))) {
        current <- reg$papers[[pmid]]$found_by[[field$name]]
        if (!identical(current$key, sample_key[[pmid]]) || !identical(current$query, query)) {
          reg$papers[[pmid]]$found_by[[field$name]] <- list(key = sample_key[[pmid]], query = query)
          reg$dirty <- c(reg$dirty, reg$papers[[pmid]]$month)
        }
      }
      unread <- setdiff(sample, names(reg$papers))
      threshold <- if (n > 0) sample_key[[n]] else ""
      set_row(field$name, month, list(query = query, total = found$count, target = target, threshold = threshold,
        sample_read = sum(sample %in% names(reg$papers)), checked = today))
      while (length(unread) > 0 && read < budget) {
        chunk <- utils::head(unread, min(fetch_size, budget - read))
        unread <- setdiff(unread, chunk)
        papers <- fetch_paper_texts(chunk, settings)
        usable <- nzchar(papers$pmcid) & nzchar(papers$abstract) & nzchar(papers$methods)
        for (i in which(!usable)) {
          p <- papers[i, ]
          reg$papers[[p$pmid]] <- paper_record(p, month, field$name, sample_key[[p$pmid]], query, reader, today)
          read <- read + 1
        }
        # A paper PubMed didn't return at all is recorded as unusable too,
        # so it isn't asked for every night.
        for (pmid in setdiff(chunk, papers$pmid)) {
          reg$papers[[pmid]] <- paper_record(list(pmid = pmid), month, field$name, sample_key[[pmid]], query, reader, today)
          read <- read + 1
        }
        stopped <- FALSE
        if (any(usable)) {
          answers <- ask_claude_for_method_sources(claude, papers[usable, , drop = FALSE], settings)
          for (pmid in attr(answers, "answered")) {
            p <- papers[papers$pmid == pmid, ][1, ]
            mine <- answers[answers$id == pmid, , drop = FALSE]
            reg$papers[[pmid]] <- paper_record(p, month, field$name, sample_key[[pmid]], query, reader, today, found = mine)
            read <- read + 1
          }
          stopped <- isTRUE(attr(answers, "stopped"))
        }
        reg$dirty <- c(reg$dirty, month)
        set_row(field$name, month, list(sample_read = sum(sample %in% names(reg$papers))))
        save()
        if (stopped) return(list(read = read, stopped = "limit"))
      }
      save()
      if (read >= budget) return(list(read = read, stopped = "budget"))
    }
  }
  save()
  list(read = read, stopped = "done")
}
