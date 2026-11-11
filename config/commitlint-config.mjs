export default {
  extends: ['@commitlint/config-conventional'],
  // Dependabot writes "chore(deps): Bump …" with long body lines; its
  // messages are generated, not written by people, so they aren't linted.
  ignores: [(message) => /^Signed-off-by: dependabot\[bot\]/m.test(message)],
  rules: {
    'header-max-length': [2, 'always', 150]
  }
};
