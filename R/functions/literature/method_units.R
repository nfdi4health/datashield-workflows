# Everything that can be ranked as a candidate: each method of the
# vocabulary and each of its variants, as key ("method" or
# "method/variant"), method and variant. Whether DataSHIELD has it is
# checked later, down the ranking (exists_for_ranked()).
method_units <- function(vocab) {
  rows <- list(data.frame(key = character(0), method = character(0), variant = character(0)))
  for (method in names(vocab$methods)) {
    rows[[length(rows) + 1]] <- data.frame(key = method, method = method, variant = "")
    for (variant in names(vocab$methods[[method]]$variants)) {
      rows[[length(rows) + 1]] <- data.frame(key = paste(method, variant, sep = "/"), method = method, variant = variant)
    }
  }
  do.call(rbind, rows)
}
