# The object class Claude gave for an argument, with "none" (the enum's
# value for arguments that aren't objects) stored as "".
no_class_as_empty <- function(class) {
  if (identical(class, "none")) {
    return("")
  }
  class
}
