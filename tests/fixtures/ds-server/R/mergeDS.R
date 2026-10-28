mergeDS <- function(x.name, y.name, by.x.names) {
  x <- eval(parse(text = x.name), envir = parent.frame())
  merge(x, eval(parse(text = y.name), envir = parent.frame()), by.x = by.x.names)
}
