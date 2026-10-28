# Synthetic data for the DSLite test run, built only from the plan's
# variable descriptions: one data frame per study, with exactly the
# variable names, types, categories and ranges of the plan, so the
# generated scripts run unchanged. Values are random (uniform within the
# range, equal category shares) with a share of missing values; the seed
# makes the same plan give the same data. No real data is involved.
generate_mock_data <- function(plan, settings) {
  n <- as.integer(settings$rows_per_study)
  missing_share <- as.numeric(settings$missing_share)

  studies <- lapply(seq_along(plan$studies), function(i) {
    set.seed(as.integer(settings$seed) + i)
    columns <- lapply(plan$variables, function(v) {
      values <- switch(v$kind,
        continuous = {
          r <- as.numeric(unlist(v$range))
          round(stats::runif(n, r[1], r[2]), as.integer(settings$decimals))
        },
        integer = {
          r <- as.integer(unlist(v$range))
          sample(seq(r[1], r[2]), n, replace = TRUE)
        },
        categorical = {
          levels <- if (!is.null(names(v$categories))) {
            names(v$categories)
          } else {
            as.character(unlist(v$categories))
          }
          factor(sample(levels, n, replace = TRUE), levels = levels)
        }
      )
      values[stats::runif(n) < missing_share] <- NA
      values
    })
    names(columns) <- vapply(plan$variables, function(v) v$name, character(1))
    as.data.frame(columns, stringsAsFactors = FALSE)
  })
  names(studies) <- vapply(plan$studies, function(s) s$server, character(1))
  studies
}
