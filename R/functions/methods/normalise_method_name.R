# A method's name for counting: lower case, single spaces, no trailing
# punctuation. Synonyms ("proportional hazards model") stay apart until the
# vocabulary (config/methods.yml, a later phase) maps them.
normalise_method_name <- function(x) {
  x <- tolower(trimws(gsub("[[:space:]]+", " ", x)))
  sub("[.,;:]+$", "", x)
}
