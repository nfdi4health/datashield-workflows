You are working on the package checked out in the current directory, on the
branch you committed to before. This is correction round {{ROUND}}.

The task is still `.agent/spec.md`. Read what came back:

- `.agent/checks.md`: the result of R CMD check (tests included) on your
  commits;
- `.agent/review-maintainability.json`: `must_fix` lists problems a reviewer
  found that have to be fixed; `comments` are matters of taste, which you
  leave alone;
- `.agent/review-disclosure.json`: `deviations` lists where the code goes
  beyond the disclosure choice of the approved spec. Bring the code back to
  what the spec allows. The rest of the disclosure review
  (`.agent/review-disclosure.md`) is for a person, not for you.

Fix the failing checks, every `must_fix` point and every deviation, and
nothing else. If a
check fails for a reason outside your change (the check environment, a
test that already failed before), don't change the package to work around
it: say so under "Not changed" in `.agent/summary.md`. If a
point is wrong, don't change the code for it: say why under "Not changed" in
`.agent/summary.md`. Never bend a test to pass, and keep every rule of the
first round: the sandbox, nothing under `.github/`, disclosure checks only as
the spec says, `Refs #<n>` only, stop and ask in `.agent/needs-input.md` when
the answer needs a person.

Commit your fixes with conventional commit messages, then update
`.agent/summary.md` so it describes the work as it is now.
