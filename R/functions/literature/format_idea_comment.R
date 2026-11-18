# The comment of the hub's "Exists?" check on one issue (check_idea()'s
# result), with the hidden marker `<!-- idea-check: VERDICT -->` that
# tells later runs the issue is done. Everything Claude wrote (the method's
# name, the note) and the catalogue's texts pass plain_comment_text(), so
# the comment can mention, link or show nothing. A method the literature
# watch knows (`result$literature`) gets its paper count and the watch's
# marker <!-- literature-watch-method: KEY -->, which the candidate list
# reads from bots' comments as tracked. Returns list(body, label).
format_idea_comment <- function(result, settings, today) {
  s <- settings
  t <- s$texts
  plain <- function(x, n = s$max_note_chars %||% 300) plain_comment_text(x %||% "", n)
  lines <- t$heading
  rec <- result$verdict
  verdict <- if (is.null(rec)) "not-method" else rec$verdict
  if (is.null(rec)) {
    lines <- c(lines, "", t$not_method)
  } else {
    lines <- c(lines, "", sprintf(t$read_as, plain(result$method, 120)))
    template <- t$verdicts[[verdict]] %||% t$verdicts$unclear
    line <- if (verdict %in% c("yes", "partial", "development")) {
      sprintf(template, gsub("`", "", rec[["function"]]), plain(rec$quote))
    } else {
      template
    }
    lines <- c(lines, line)
    if (nzchar(trimws(rec$note %||% ""))) lines <- c(lines, sprintf(t$note, plain(rec$note)))
    cand <- utils::head(result$candidates, s$closest %||% 5)
    if (nrow(cand) > 0) {
      lines <- c(lines, "", t$closest, sprintf("- `%s::%s`%s: %s", cand$package, cand$fn,
        ifelse(nzchar(cand$status), sprintf(" (%s)", cand$status), ""), vapply(cand$title, plain, "", n = 160)))
    }
  }
  lit <- result$literature
  if (!is.null(lit)) {
    lines <- c(lines, "", sprintf(t$literature, lit$papers, lit$usable))
  }
  if (length(result$similar)) {
    lines <- c(lines, "", sprintf(t$similar, paste0("#", result$similar, collapse = ", ")))
  }
  lines <- c(lines, "", sprintf("<sub>%s</sub>", sprintf(t$footer, format(today))), "",
    sprintf("<!-- idea-check: %s -->", verdict),
    if (!is.null(lit)) sprintf("<!-- literature-watch-method: %s -->", lit$key))
  list(body = paste(lines, collapse = "\n"), label = s$labels[[verdict]] %||% "")
}
