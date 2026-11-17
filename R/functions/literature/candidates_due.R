# Whether this run proposes candidates: `mode` "always" or "never" as
# given; "auto" once a round is complete or an earlier month's candidates
# exist on the hub (then monthly), and not when this month's file is
# there already (`folder` in the hub's checkout).
candidates_due <- function(mode, folder, month, complete) {
  if (identical(mode, "always")) return(TRUE)
  if (!identical(mode, "auto")) return(FALSE)
  files <- list.files(folder, pattern = "^[0-9]{4}-[0-9]{2}\\.json$")
  if (paste0(month, ".json") %in% files) return(FALSE)
  complete || length(files) > 0
}
