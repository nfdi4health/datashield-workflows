# The literature watch's vocabulary (vocabulary.yml in the data folder,
# written by R/classify_literature.R, never by hand): `methods` by key
# (name, description, keywords, variants by key, and the "Exists in
# DataSHIELD?" verdicts), `names` (each name the papers gave -> its method
# key and the variant the name implies; method "" for a name that isn't a
# method) and `variant_names` (per method key, each variant wording -> its
# variant key, another method's key, or "" for no variant). Empty lists
# when the file doesn't exist yet.
read_vocabulary <- function(dir) {
  path <- file.path(dir, "vocabulary.yml")
  vocab <- if (file.exists(path)) yaml::read_yaml(path) else list()
  for (part in c("methods", "names", "variant_names")) {
    if (is.null(vocab[[part]])) vocab[[part]] <- list()
  }
  vocab
}
