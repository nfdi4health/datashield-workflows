# Builds the Claude tool-call JSON schema for submit_failure_classification
# — forces the 3-way classification from dev-notes/test-suggest.md
# into a structural enum rather than trusting free text to stay on-category.
# One entry per failed test of the function (`failure`: its label, "F1",
# "F2", … as listed; R checks it), with a short explanation for the
# report, the category and how sure Claude is. The profile thinks
# (adaptive thinking), so the explanation is not asked to carry the
# reasoning (dev-notes/prompt-audit.md, finding 3). The confidence decides whether a real_bug is reported as a possible bug, and
# whether it gets an issue (code-issue-confidence; issues only for "high").
build_submit_failure_classification_tool <- function() {
  list(
    description = "Classify why each listed generated test failed, each as exactly one of three distinct categories.",
    input_schema = list(
      type = "object",
      properties = list(
        failures = list(
          type = "array",
          description = "One entry per listed failure; `failure` names which.",
          items = list(
            type = "object",
            properties = list(
              failure = list(type = "string", description = "The failure's label as listed, e.g. \"F1\"."),
              explanation = list(type = "string", description = "1-3 sentences why, citing the actual failure output and the function's code."),
              category = list(
                type = "string",
                enum = list("bad_test", "real_bug", "env_misconfiguration"),
                description = paste(
                  "bad_test: the test itself is wrong (bad assertion, misunderstood",
                  "behavior). real_bug: the test is correct and caught a genuine",
                  "defect in the function under test. env_misconfiguration: the",
                  "test environment itself is broken (wrong dataset, unregistered",
                  "DataSHIELD server method) rather than the test or the function",
                  "being wrong."
                )
              ),
              confidence = list(type = "string", enum = list("high", "medium", "low"), description = "How sure you are of the category.")
            ),
            required = list("failure", "explanation", "category", "confidence")
          )
        )
      ),
      required = list("failures")
    )
  )
}
