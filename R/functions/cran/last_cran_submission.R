# When the package last went to CRAN: the later of its publication date on
# CRAN (`crandb`, the CRAN package database, NULL if the package isn't on
# CRAN yet) and the newest `<tag_prefix><version>` tag, which cran-submit.yml
# sets on every submission (a submission that isn't published yet counts
# too). `tags` is a named vector tag -> ISO date (git's creator dates),
# `cran_date` the publication date as text. Returns a Date, or NULL if the
# package has never been submitted.
last_cran_submission <- function(cran_date = NULL, tags = character(0)) {
  dates <- c(
    if (!is.null(cran_date) && nzchar(cran_date)) as.Date(substr(cran_date, 1, 10)),
    if (length(tags) > 0) as.Date(substr(unname(tags), 1, 10))
  )
  dates <- dates[!is.na(dates)]
  if (length(dates) == 0) {
    return(NULL)
  }
  max(dates)
}
