# The first and last day of a publication month ("YYYY-MM") in PubMed's
# date format ("YYYY/MM/DD").
month_range <- function(month) {
  start <- as.Date(paste0(month, "-01"))
  end <- seq(start, by = "1 month", length.out = 2)[2] - 1
  c(format(start, "%Y/%m/%d"), format(end, "%Y/%m/%d"))
}
