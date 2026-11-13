# The pilot's Claude calls: papers in batches of settings$pilot$batch,
# each with its abstract and methods section; Claude lists the methods and
# where each is named. Only methods of the given papers are kept. A failed
# batch is left out with a message, the run goes on. Returns a data frame:
# id, name, role, in_abstract, in_methods_section.
ask_claude_for_method_sources <- function(claude, papers, settings) {
  rows <- list()
  size <- settings$pilot$batch %||% 5
  for (batch in split(seq_len(nrow(papers)), ceiling(seq_len(nrow(papers)) / size))) {
    p <- papers[batch, ]
    text <- paste(sprintf("<paper id=\"%s\">\n<abstract>\n%s\n</abstract>\n<methods_section>\n%s\n</methods_section>\n</paper>",
      p$pmid, p$abstract, p$methods), collapse = "\n\n")
    answer <- tryCatch(call_claude_tool(claude, build_method_sources_tool(), fill_template(claude$prompt, list(PAPERS = text))),
      error = function(e) {
        message(sprintf("A batch of %d papers failed and is left out: %s", nrow(p), conditionMessage(e)))
        NULL
      })
    for (paper in answer$papers %||% list()) {
      if (!paper$id %in% p$pmid) next
      for (m in paper$methods %||% list()) {
        rows[[length(rows) + 1]] <- data.frame(id = paper$id, name = normalise_method_name(m$name), role = m$role,
          in_abstract = isTRUE(m$in_abstract), in_methods_section = isTRUE(m$in_methods_section))
      }
    }
  }
  if (length(rows) == 0) {
    return(data.frame(id = character(0), name = character(0), role = character(0),
      in_abstract = logical(0), in_methods_section = logical(0)))
  }
  do.call(rbind, rows)
}
