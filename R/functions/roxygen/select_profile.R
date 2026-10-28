# Picks the exported/internal style guidance profile from roxygen-style.yml
# based on whether the parsed function has an @export tag.
select_profile <- function(parsed) {
  if (parsed$is_exported) {
    style$exported
  } else {
    style$internal
  }
}
