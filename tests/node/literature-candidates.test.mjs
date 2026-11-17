// The hub's candidate pull requests (.github/actions/literature-candidates).
import assert from "node:assert/strict";
import test from "node:test";
import { candidatesMonth, issueBody, issueTitle, mergeDecisions, parseDecisions, undecided } from "../../.github/actions/literature-candidates/candidates.mjs";

const body = `Intro
- [x] Open an issue

### 1. Fine-Gray
<!-- candidate: fine-gray -->
- [x] Open an issue
- [ ] Not now
- [ ] Don't suggest again

text
### 2. Cox: tvc
<!-- candidate: cox-regression/time-varying -->
- [ ] Open an issue
- [X] Not now
- [x] Don't suggest again
## Deferred
**Splines**
<!-- candidate: splines -->
- [ ] Open an issue
- [ ] Not now
- [ ] Don't suggest again
<!-- literature-watch-candidates: 2026-11 -->`;

test("boxes are read per candidate, outside them nothing counts", () => {
  const d = parseDecisions(body);
  assert.deepEqual(d, { "fine-gray": ["issue"], "cox-regression/time-varying": ["not-now", "dont-suggest"], splines: [] });
  assert.deepEqual(undecided(d), [{ key: "cox-regression/time-varying", ticked: 2 }, { key: "splines", ticked: 0 }]);
  assert.equal(candidatesMonth(body), "2026-11");
  assert.equal(candidatesMonth("none"), null);
});

const record = {
  candidates: [{ key: "fine-gray", name: "Fine-Gray regression", variant_name: "", verdict: "none", function: "", note: "Nothing.",
    papers: 41, share: 0.12, trend: "rising", fields: "cancer", examples: [{ pmid: "1", title: "A @paper" }],
    research: { description: "Competing risks.", r_packages: [{ package: "cmprsk", function: "crr", note: "classic" }],
      federated: "Pooled scores.", disclosure: "Risk sets.", fit: "dsSurvival.", sources: ["https://x.org"] } }],
  deferred: [{ key: "splines", papers: 9 }],
};

test("an issue carries the brief, a marker, and no mentions", () => {
  const c = record.candidates[0];
  assert.equal(issueTitle(c), "Method: Fine-Gray regression");
  assert.equal(issueTitle({ name: "Cox", variant_name: "tvc" }), "Method: Cox (tvc)");
  const b = issueBody(c, "https://github.com/o/hub/pull/3");
  assert.match(b, /<!-- literature-watch-method: fine-gray -->$/);
  assert.match(b, /`cmprsk::crr`/);
  assert.match(b, /A @​paper/);
  assert.match(b, /12% of the sampled/);
});

test("decisions are recorded with their papers, the pull request and the issue", () => {
  const merged = mergeDecisions({ old: { decision: "not-now" } }, { "fine-gray": ["issue"], splines: ["dont-suggest"], x: [] }, record,
    { pr: 3, date: "2026-12-01", issues: { "fine-gray": 12 } });
  assert.deepEqual(merged, {
    old: { decision: "not-now" },
    "fine-gray": { decision: "issue", date: "2026-12-01", papers: 41, pr: 3, issue: 12 },
    splines: { decision: "dont-suggest", date: "2026-12-01", papers: 9, pr: 3 },
  });
});
