# One section of the literature watch's report for a set of papers (a
# field, or all fields with each paper once): the top methods by share
# over the recent years with their shares per year and trend, a trend
# chart for the first `charts` of them (Mermaid, drawn by GitHub), and the
# variants named in at least `min_variant_papers` papers. Names and the
# "Exists in DataSHIELD?" column from the vocabulary.
format_method_section <- function(title, papers, years, recent, top = 20, charts = 0, min_variant_papers = 2, vocab = list()) {
  pct <- function(x) ifelse(is.na(x), "–", sprintf("%.0f%%", 100 * x))
  usable <- Filter(function(p) isTRUE(p$usable), papers)
  lines <- c(sprintf("## %s", title), "")
  table <- method_table(papers, years, recent, top, vocab)
  if (is.null(table)) return(c(lines, "No papers read yet.", ""))
  per_year <- attr(table, "papers_year")
  lines <- c(lines, sprintf("Papers read: %d, %d of them usable (%d of these in the last %d months, which the order below is based on).",
    length(papers), length(usable), attr(table, "papers_recent"), length(recent)), "",
    paste0("| Method | Share, last ", if (length(recent) <= 12) "year" else paste(length(recent) %/% 12, "years"), " | Papers | ",
      paste(years, collapse = " | "), " | Trend | In DataSHIELD |"),
    paste0("|---|---|---|", paste(rep("---", length(years)), collapse = "|"), "|---|---|"),
    vapply(seq_len(nrow(table)), function(i) {
      r <- table[i, ]
      paste0("| ", method_label(vocab, r$method), " | ", pct(r$share), " | ", r$papers, " | ",
        paste(pct(unlist(r[as.character(years)])), collapse = " | "), " | ", r$trend, " | ",
        exists_label(vocab, r$method), " |")
    }, ""),
    paste0("| *papers read* | | | ", paste(per_year, collapse = " | "), " | | |"), "")
  for (i in seq_len(min(charts, nrow(table)))) {
    r <- table[i, ]
    shares <- 100 * unlist(r[as.character(years)])
    keep <- !is.na(shares)
    if (sum(keep) < 2) next
    lines <- c(lines, "```mermaid", "xychart-beta",
      sprintf("  title \"%s: share of papers per year\"", gsub("\"", "'", method_label(vocab, r$method))),
      sprintf("  x-axis [%s]", paste(years[keep], collapse = ", ")),
      sprintf("  y-axis \"%%\" 0 --> %d", max(5, ceiling(max(shares[keep]) / 5) * 5)),
      sprintf("  line [%s]", paste(sprintf("%.1f", shares[keep]), collapse = ", ")), "```", "")
  }
  variants <- variant_table(papers, min_variant_papers, vocab = vocab)
  if (!is.null(variants)) {
    lines <- c(lines, sprintf("**Variants named in at least %d papers** (DataSHIELD may have the method but not the variant):", min_variant_papers), "",
      "| Method | Variant | Papers | In DataSHIELD |", "|---|---|---|---|",
      sprintf("| %s | %s | %d | %s |", vapply(variants$method, function(m) method_label(vocab, m), ""),
        vapply(seq_len(nrow(variants)), function(i) method_label(vocab, variants$method[i], variants$variant[i]), ""),
        variants$papers, vapply(seq_len(nrow(variants)), function(i) exists_label(vocab, variants$method[i], variants$variant[i]), "")), "")
  }
  lines
}
