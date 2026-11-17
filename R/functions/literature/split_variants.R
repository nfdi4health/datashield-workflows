# The variant wordings of one method entry of a paper: the extraction puts
# several deviations into one entry, separated by commas or semicolons.
# Normalised like method names, empty ones dropped.
split_variants <- function(x) {
  if (is.null(x) || !nzchar(x)) return(character(0))
  parts <- normalise_method_name(strsplit(x, "[,;]")[[1]])
  unique(parts[nzchar(parts)])
}
