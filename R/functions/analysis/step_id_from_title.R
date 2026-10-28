# A step id derived from its title ("Data management" -> "data_management"),
# for plans whose steps have no explicit id.
step_id_from_title <- function(title) {
  id <- tolower(iconv(title, to = "ASCII//TRANSLIT", sub = ""))
  id <- gsub("[^a-z0-9]+", "_", id)
  id <- gsub("^_+|_+$", "", id)
  if (!nzchar(id)) {
    "step"
  } else {
    id
  }
}
