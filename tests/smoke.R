# The smoke test with real Claude calls (tests/smoke/), separate from the
# unit tests because it costs subscription usage:
#   CLAUDE_CODE_OAUTH_TOKEN=... Rscript tests/smoke.R
# from the repository root, with Claude Code installed (claude on the PATH,
# or CLAUDE_BIN). Needs the packages of tests/testthat.R plus processx.
testthat::test_dir("tests/smoke", stop_on_failure = TRUE)
