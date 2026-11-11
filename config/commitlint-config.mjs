// Commit message rules for all callers of commitlint.yml. Only what
// versioning needs is enforced (user, 2026-11-11): a known type in lower
// case (semantic-release recognises `feat`, not `Feat`) and a subject after
// `type(scope)!: `. Case of the subject, length and blank lines are free.
export default {
  extends: ['@commitlint/config-conventional'],
  // Dependabot writes "chore(deps): Bump …" with long body lines; its
  // messages are generated, not written by people, so they aren't linted.
  ignores: [(message) => /^Signed-off-by: dependabot\[bot\]/m.test(message)],
  rules: {
    'subject-case': [0],
    'subject-full-stop': [0],
    'header-max-length': [0],
    'body-max-line-length': [0],
    'footer-max-line-length': [0],
    'body-leading-blank': [0],
    'footer-leading-blank': [0]
  }
};
