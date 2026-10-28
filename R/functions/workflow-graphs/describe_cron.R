# A cron schedule in words, for the diagrams: "daily", "weekly (Mon)",
# "monthly (day 1)", or "on a schedule" for anything more unusual. The time
# of day is left out (it's UTC and rarely matters for understanding the
# repository); the cron text stays in the workflow file.
describe_cron <- function(cron) {
  f <- strsplit(trimws(cron), "\\s+")[[1]]
  if (length(f) != 5) {
    return("on a schedule")
  }
  dom <- f[3]; month <- f[4]; dow <- f[5]
  days <- c("0" = "Sun", "1" = "Mon", "2" = "Tue", "3" = "Wed", "4" = "Thu", "5" = "Fri", "6" = "Sat", "7" = "Sun")

  if (month != "*") {
    return("on a schedule")
  }
  if (dom == "*" && dow == "*") {
    return("daily")
  }
  if (dom == "*" && all(strsplit(dow, ",")[[1]] %in% names(days))) {
    return(sprintf("weekly (%s)", paste(days[strsplit(dow, ",")[[1]]], collapse = ", ")))
  }
  if (dow == "*" && grepl("^[0-9,]+$", dom)) {
    return(sprintf("monthly (day %s)", dom))
  }
  "on a schedule"
}
