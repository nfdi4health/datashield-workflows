# The ranked table with each row's stored "Exists in DataSHIELD?" verdict
# (exists_record()): columns verdict, function and note ("" where not
# checked).
annotate_verdicts <- function(ranked, vocab) {
  ranked$verdict <- rep("", nrow(ranked))
  ranked$`function` <- rep("", nrow(ranked))
  ranked$note <- rep("", nrow(ranked))
  for (i in seq_len(nrow(ranked))) {
    rec <- exists_record(vocab, ranked$method[i], ranked$variant[i])
    if (is.null(rec)) next
    ranked$verdict[i] <- rec$verdict
    ranked$`function`[i] <- rec[["function"]] %||% ""
    ranked$note[i] <- rec$note %||% ""
  }
  ranked
}
