# Uploads a built package to CRAN through its submission form, the two
# steps devtools::submit_cran() takes, without its interactive questions:
# the upload (tarball, maintainer, comments), then the confirmation that
# the CRAN policies were checked. CRAN then emails the maintainer, who has
# to confirm before the submission is reviewed: that step stays a person's.
# `maintainer` is list(name, email). Returns the submission's id.
upload_to_cran <- function(tarball, maintainer, comments, url = "https://xmpp.r-project.org/CRAN/submit.php") {
  first <- httr2::request(url) |>
    httr2::req_body_multipart(
      pkg_id = "",
      name = maintainer$name,
      email = maintainer$email,
      uploaded_file = curl::form_file(tarball, type = "application/x-gzip"),
      comment = comments,
      upload = "Upload package"
    ) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(first) != 200) {
    stop(sprintf("The upload to CRAN failed (HTTP %s).", httr2::resp_status(first)), call. = FALSE)
  }
  pkg_id <- httr2::url_parse(httr2::resp_url(first))$query$pkg_id
  if (is.null(pkg_id) || !nzchar(pkg_id)) {
    stop("CRAN accepted the upload but returned no submission id; check the form at https://cran.r-project.org/submit.html.", call. = FALSE)
  }
  second <- httr2::request(url) |>
    httr2::req_body_multipart(
      pkg_id = pkg_id,
      name = maintainer$name,
      email = maintainer$email,
      policy_check = "1/",
      submit = "Submit package"
    ) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(second) != 200) {
    stop(sprintf("Confirming the submission failed (HTTP %s).", httr2::resp_status(second)), call. = FALSE)
  }
  pkg_id
}
