# The object class an argument's documentation text names first (e.g.
# "a character string naming a data frame" -> "data.frame"), with a
# confidence: "high" when the text names one class (vector and factor
# together count as one), "medium" when it names several. Class names are
# the keys of `classes` in config/ds-naming-rules.yml; "" when none.
ds_object_class <- function(doc) {
  patterns <- c(
    data.frame = "data[ ._-]?frames?\\b|dataframes?\\b|\\bdf\\b|phenotypes? table|\\bdata ?sets?\\b",
    tibble     = "\\btibbles?\\b",
    matrix     = "\\bmatri(x|ces)\\b",
    list       = "\\blists?\\b(?! of \\\\code\\{\\\\link\\[DSI\\])",
    formula    = "\\bformulae?\\b|\\bformulas\\b",
    model      = "\\bmodels?\\b|\\bglm(er)?\\b|\\blmer\\b|coxph object|survfit|regression object|fitted object|\\bfit\\b",
    factor     = "\\bfactors?\\b|categorical",
    vector     = "\\bvectors?\\b|\\bvariables?\\b|\\bcolumns?\\b|\\bcovariates?\\b",
    resource   = "\\bresources?\\b",
    omics      = "ExpressionSet|SummarizedExperiment|ExposomeSet|\\bGDS\\b|\\bVCF\\b|eSet|SNP|genotype|imaging|image"
  )
  pos <- vapply(patterns, function(p) {
    m <- regexpr(p, doc, perl = TRUE, ignore.case = TRUE)
    if (m > 0) {
      as.integer(m)
    } else {
      NA_integer_
    }
  }, integer(1))
  hits <- pos[!is.na(pos)]
  if (length(hits) == 0) {
    return(list(class = "", confidence = ""))
  }
  first <- names(hits)[which.min(hits)]
  others <- setdiff(names(hits), c("vector", "factor"))
  confidence <- if (length(others) <= 1 && length(hits) <= 2) {
    "high"
  } else {
    "medium"
  }
  # A factor counts as a vector.
  if (first == "factor") {
    first <- "vector"
  }
  list(class = first, confidence = confidence)
}
