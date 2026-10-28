# Suggestion thresholds

When is a change by the roxygen or test suggestion workflow worth a pull
request? This note records the current answer. It is a **revisable
decision** (made 2026-09-25), expected to be tuned once there is data on
which suggestions get merged.

## Principle

Same as everywhere in these workflows: don't trust prompt wording where a
structural rule is possible.

1. **Claude states a reason for every change, from a fixed list** (tool
   schema enum). The list includes honest "not really an improvement"
   options (`clarity`, `style`, `other`): a model with a place for that
   case uses it more reliably than one told "don't make style changes".
2. **R keeps only accepted reasons.** The default accept lists live in
   `config/suggestion-policy.yml` (`accept: true` per reason; until v1:
   `accept_reasons` in `config/claude.yml`). A repository tunes
   them with the `accept-reasons` input of `roxygen-suggest.yml` /
   `test-suggest.yml` (added 2026-10-02, user's request, e.g. to also get
   `style` or `clarity` changes), or by overriding that file, without
   touching prompts. An unknown reason stops the run
   (`accepted_reasons()`).
3. **Mechanical filters in R** on top, independent of what Claude says.

## Current settings

### Roxygen (`roxygen-review`)

| Reason | Meaning | Proposed? |
|---|---|---|
| `missing` | Field absent or a placeholder | yes |
| `inaccurate` | Contradicts the code | yes |
| `incomplete` | Misses something the code does | yes |
| `clarity` | Correct and complete, could be clearer | no |
| `style` | Formatting or wording only | no |

Mechanical filter: a change whose text differs from the existing one only
in whitespace, punctuation or case is dropped. A field Claude changed
without listing it in `changes` is not applied either. Rejected fields
keep their **original lines byte for byte**; a file is only rewritten if at
least one change is accepted. (`accepted_roxygen_fields()`,
`build_roxygen_block()`.) An untagged title/description (roxygen's
implicit first paragraphs) counts as existing too and is kept with its
text unchanged, made explicit as `@title`/`@description` — before this
fix a dropped title change was applied anyway (dsSupportClient PR #25).

Every change carries a one-sentence explanation. The suggestion PR's
description lists the applied changes with reason and explanation, and —
collapsed — the changes that were *not* applied, with Claude's proposed
text, so a reviewer can adopt one by hand. Only written when there is a
PR; notes alone never open one.

*First real sweep (2026-09-25, dsSupportClient #52 → PR #25):* 12 of 17
changes were dropped as `clarity`/`style` — including one correcting a
false claim (a documented default the function doesn't have) that Claude
labelled `style`. So the prompt now requires checking every claim against
the code and defines `inaccurate` to include small-wording fixes of false
statements. `clarity` stays off; decide on it from the "Not applied"
sections of the next runs.

### Tests (`test-review`)

| Reason | Meaning | Proposed? |
|---|---|---|
| `uncovered_branch` | A code path no existing test reaches | yes |
| `error_handling` | An error or warning the function raises | yes |
| `edge_case` | Unusual but valid input (NA, empty, boundaries) | yes |
| `regression` | Pins down behaviour likely to break on change | yes |
| `other` | None of these | no |

Mechanical filter: a test whose assertions already exist verbatim in the
test file (ignoring whitespace) is dropped. And, as before, only tests that
pass a real run are proposed. (`filter_generated_tests()`.)

**Every function is reviewed**, in PRs and in sweeps, whether it already
has tests or not — the old "test file mentions the function name → skip"
heuristic is gone. Claude decides whether new tests add value; the
threshold above decides what is proposed. At most ~~5~~ `max_new_tests`
(default 10, `config/suggestion-policy.yml`) new tests per function and run — 5 was
too few to check real behavior.

### ~~Existing tests that could be deleted~~ Existing tests

*Revised 2026-09-25.* Originally existing tests were never touched, and
deletion candidates only reported. dsSupportClient PR #21 showed the cost:
the PR changed a function's contract, its old test failed, R CMD check was
red, and only a human could fix it. Now Claude decides on existing tests,
using their current results and the history evidence
(`build_test_evidence()`: which of function and test changed later; in a
PR, whether the PR changed the function without its test, and the diff).

| Action | Reason | Effect |
|---|---|---|
| `update` | `contract_changed` — behavior changed on purpose, test expects the old | Body replaced, description kept |
| `delete` | `duplicate`, `behavior_removed`, `trivial` | Test removed |
| `report` | `possible_code_bug` — test describes sensible behavior the code no longer delivers | Test unchanged, reported |

Safeguards in R (`review_existing_tests()`), whatever Claude says:

- action and reason must fit together as in the table;
- **only a currently failing test is updated** — passing tests are never
  rewritten;
- **a failing test is never adapted to output that may be wrong**: the
  bug case is `report`, not `update`;
- the test must exist and be editable (unique name, own lines);
- an update is only kept if it passes a real run; otherwise the original
  stays and the failed attempt is reported;
- failing tests Claude left without a decision are reported too.

Everything arrives only as a suggestion PR; changes to existing tests are
listed in its description with reason and explanation, reported tests
under "Existing tests to look at" (without a suggestion PR: a PR comment,
in a sweep one issue).

## Revisit when

- Suggestions of an accepted category keep getting closed, or rejected
  categories are missed in review → change the accept lists.
- Sweeps keep adding tests to the same functions month after month → the
  bar for tests is too low.

## Ideas not implemented yet

- **Log the reason of every suggestion** and compare with merged vs. closed
  suggestion PRs after a few weeks, to set the accept lists from data
  instead of guesses.
- **Coverage gain per generated test** (`covr`), shown in the suggestion PR
  — an objective signal. Not a hard filter: edge-case tests often add no
  line coverage and are still valuable.
- ~~**Give Claude the diff of the changed function** in PR runs, if
  suggestions turn out to be unfocused.~~ Done with the existing-test
  review (part of `build_test_evidence()`).
