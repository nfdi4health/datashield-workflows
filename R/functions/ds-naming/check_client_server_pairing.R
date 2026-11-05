# Whether client and server fit together, by the calls the client makes
# (client_server_calls()), not by comparing names: one client function can
# call several server functions, and some call none. Returns the problems
# as sentences: called but not declared by the server, declared but called
# by no client function. Report only.
check_client_server_pairing <- function(client, server) {
  declared <- names(server$methods)
  calls <- client_server_calls(client, declared)
  undeclared <- calls[!calls$method %in% declared, ]
  problems <- character(0)
  if (nrow(undeclared) > 0) {
    problems <- c(problems, sprintf("`%s` calls `%s`, which `%s` doesn't declare.", undeclared$client_fn, undeclared$method, server$name))
  }
  # Methods of other packages (sum=base::sum) are general tools, not the
  # server side of a client function.
  unused <- setdiff(setdiff(declared, attr(server$methods, "other_package")), calls$method)
  if (length(unused) > 0) {
    problems <- c(problems, sprintf("Declared, but no client function calls it: %s.", paste(sprintf("`%s`", unused), collapse = ", ")))
  }
  problems
}
