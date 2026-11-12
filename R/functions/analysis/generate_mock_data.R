# Synthetic data for the DSLite test run, built only from the plan's
# variable descriptions: one data frame per study, with exactly the
# variable names, types, categories and ranges of the plan, so the
# generated scripts run unchanged. Values are random (uniform within the
# range, equal category shares) with a share of missing values; the seed
# makes the same plan give the same data. No real data is involved.
# A variable with a `studies` list (the variables file) is only in those
# studies' data (variable_in_study()); missing-value codes
# (`missing_codes`) fill some of the gaps of a categorical variable.
generate_mock_data <- function(plan, settings) {
  n <- as.integer(settings$rows_per_study)
  missing_share <- as.numeric(settings$missing_share)

  servers <- vapply(plan$studies, function(s) s$server, character(1))
  studies <- lapply(seq_along(plan$studies), function(i) {
    set.seed(as.integer(settings$seed) + i)
    held <- Filter(function(v) variable_in_study(v, servers[i], servers), plan$variables)
    columns <- lapply(held, function(v) {
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
      gaps <- stats::runif(n) < missing_share
      codes <- as.character(unlist(v$missing_codes))
      if (v$kind == "categorical" && length(codes) > 0) {
        # Missing-value codes (e.g. 99 = unknown) stand in for some gaps,
        # as they do in the real data.
        values <- factor(values, levels = c(levels(values), codes))
        coded <- gaps & stats::runif(n) < 0.5
        values[coded] <- sample(codes, sum(coded), replace = TRUE)
        gaps <- gaps & !coded
      }
      values[gaps] <- NA
      values
    })
    names(columns) <- vapply(held, function(v) v$name, character(1))
    as.data.frame(columns, stringsAsFactors = FALSE)
  })
  names(studies) <- vapply(plan$studies, function(s) s$server, character(1))
  studies
}
