// Turns the agent's result into what the issue shows (dev-notes/
// implementer-plan.md, "Labels and what the issue shows"). Runs on a clean
// machine that never ran the agent: the bundle is only fetched, never checked
// out or run, and the agent's files are only text.

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { safeText } from "./lib.mjs";
import { mustFix, readJson } from "./outcome.mjs";

const git = (...args) => execFileSync("git", args, { encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });

// Disclosure control is decided by people, so these never pass unmarked.
export function reviewChanges(files, diff) {
  const forbidden = files.filter((file) => file.startsWith(".github/"));
  const disclosure = files.filter((file) => file === "inst/DATASHIELD");
  const touchesFilters = diff
    .split("\n")
    .some((line) => /^[-+](?![-+])/.test(line) && /nfilter|privacyLevel|privacyControlLevel/.test(line));
  return { forbidden, needsDisclosureReview: disclosure.length > 0 || touchesFilters };
}

const read = (dir, name) => {
  const file = join(dir, name);
  return existsSync(file) ? readFileSync(file, "utf8").trim() : "";
};

export function readResult(dir) {
  return {
    summary: read(dir, "summary.md"),
    disclosure: read(dir, "review-disclosure.md"),
    checks: read(dir, "checks.md"),
    needsInput: read(dir, "needs-input.md"),
    review: readJson(join(dir, "review-maintainability.json"), {}),
  };
}

function openPoints(review) {
  const items = mustFix(review).map((item) => (typeof item === "string" ? item : `${item.file ? `\`${item.file}\`: ` : ""}${item.problem}`));
  const comments = (Array.isArray(review?.comments) ? review.comments : []).map((c) => (typeof c === "string" ? c : c.text ?? JSON.stringify(c)));
  return { items, comments };
}

const section = (title, text) => (text ? [`## ${title}`, "", text, ""] : []);
const bullets = (list) => list.map((x) => `- ${x}`).join("\n");

export function pullRequestBody({ issue, failed, needsDisclosureReview, result, runUrl }) {
  const { items, comments } = openPoints(result.review);
  return safeText([
    needsDisclosureReview
      ? "> [!WARNING]\n> **Disclosure review needed.** This changes disclosure settings, checks or registered methods. People decide these, so read them line by line.\n"
      : "",
    failed
      ? `> [!CAUTION]\n> **Failed attempt, kept as a draft.** The checks still fail after the correction rounds. See the comment on #${issue}.\n`
      : "",
    `Refs #${issue}. Built by the agent from the approved spec on that issue. Change \`Refs\` to \`Closes\` once the work is done; the issue then closes with the release.`,
    "",
    ...section("Summary from the agent", result.summary || "The agent left no summary."),
    ...section("Disclosure review", result.disclosure),
    ...section("Open points from the maintainability review", bullets(items)),
    ...section("Comments from the maintainability review", bullets(comments)),
    ...section("Checks", result.checks),
    runUrl ? `Run: ${runUrl}` : "",
  ].join("\n").trim());
}

export function failureComment({ reason, result, prUrl, runUrl }) {
  const { items } = openPoints(result.review);
  return safeText([
    `The agent could not finish this issue. ${reason}`,
    "",
    ...section("What it tried", result.summary || "It left no summary."),
    ...section("Checks", result.checks),
    ...section("Open points from the review", bullets(items)),
    prUrl ? `The partial work is in the draft pull request ${prUrl}.` : "Nothing was published.",
    runUrl ? `Run (private): ${runUrl}` : "",
  ].join("\n").trim());
}

export function needsInputComment({ result, label }) {
  return safeText([
    "> [!IMPORTANT]",
    "> **The agent needs a decision before it can go on.**",
    ">",
    ...(result.needsInput || "It didn't say what it needs.").split("\n").map((line) => `> ${line}`),
    "",
    `Answer in a comment; a new triage then updates the spec, and \`${label}\` can be set again.`,
  ].join("\n"));
}

export async function setLabels(api, repository, issue, { add = [], remove = [] }) {
  for (const name of remove) {
    await api(`repos/${repository}/issues/${issue}/labels/${encodeURIComponent(name)}`, { method: "DELETE" });
  }
  if (add.length > 0) await api(`repos/${repository}/issues/${issue}/labels`, { method: "POST", body: { labels: add } });
}

export const comment = (api, repository, issue, body) =>
  api(`repos/${repository}/issues/${issue}/comments`, { method: "POST", body: { body } });

// Fetches the bundle as the branch, rewrites closing keywords in its commit
// messages, and returns what it changes. Run in a checkout of the target.
export function prepareBranch({ bundle, branch, base }) {
  git("fetch", bundle, `HEAD:refs/heads/${branch}`);
  const sed = "sed -E 's/\\b([Cc]lose[sd]?|[Ff]ix(e[sd])?|[Rr]esolve[sd]?)(:?[[:space:]]+)(([A-Za-z0-9_.-]+\\/[A-Za-z0-9_.-]+)?#[0-9]+)/refs \\4/g'";
  execFileSync("git", ["filter-branch", "-f", "--msg-filter", sed, `origin/${base}..${branch}`], {
    env: { ...process.env, FILTER_BRANCH_SQUELCH_WARNING: "1" },
    stdio: "ignore",
  });
  const range = `origin/${base}...refs/heads/${branch}`;
  const files = git("diff", "--name-only", range).split("\n").filter(Boolean);
  return reviewChanges(files, git("diff", range));
}

// Publishes one result. Returns what the log records.
export async function publish(api, ctx) {
  const { repository, issue, branch, base, type, title, labels, outcome, result, runUrl, existingPr, openPullRequest = true } = ctx;
  const done = [labels.inProgress, labels.proceed];

  if (outcome.result === "limit") {
    await setLabels(api, repository, issue, { remove: [labels.inProgress] });
    const reset = outcome.resetAt ? new Date(outcome.resetAt) : null;
    const wait = reset ? (reset - ctx.now) / 60000 : Infinity;
    if (reset && wait <= ctx.timerMaxMinutes && ctx.timerEvent) {
      await api(`repos/${repository}/dispatches`, {
        method: "POST",
        body: { event_type: ctx.timerEvent, client_payload: { reset_at: reset.toISOString() } },
      });
      return { result: "limit", paused_until: reset.toISOString(), timer: true };
    }
    return { result: "limit", paused_until: outcome.resetAt, timer: false };
  }

  if (outcome.result === "needs-input") {
    await comment(api, repository, issue, needsInputComment({ result, label: labels.proceed }));
    await setLabels(api, repository, issue, { remove: done, add: [labels.needsInput] });
    return { result: "needs-input" };
  }

  let failed = outcome.result !== "completed";
  let reason = outcome.reason;
  let prUrl = "";
  if (ctx.bundleExists) {
    const changes = ctx.prepare();
    if (changes.forbidden.length > 0) {
      failed = true;
      reason = `Its work changes files it may not change (${changes.forbidden.map((f) => `\`${f}\``).join(", ")}), so it was not published.`;
    } else {
      ctx.push();
      const body = pullRequestBody({ issue, failed, needsDisclosureReview: changes.needsDisclosureReview, result, runUrl });
      // Without a pull request (open-pull-request: false): the branch is
      // pushed, and its comparison link and the report go to the issue.
      if (!openPullRequest) {
        const compare = `https://github.com/${repository}/compare/${base}...${branch}`;
        await comment(api, repository, issue, `Branch \`${branch}\` is pushed (no pull request opened): ${compare}\n\n${body}`);
        const labelsNow = failed ? { remove: done, add: [labels.failed] } : { remove: [...done, labels.failed], add: [labels.completed] };
        await setLabels(api, repository, issue, labelsNow);
        return failed ? { result: "failed", reason, branch } : { result: "completed", branch };
      }
      const prTitle = safeText(`${type}: ${title}`).slice(0, 200);
      const pull = existingPr
        ? await api(`repos/${repository}/pulls/${existingPr}`, { method: "PATCH", body: { title: prTitle, body } })
        : await api(`repos/${repository}/pulls`, { method: "POST", body: { title: prTitle, head: branch, base, draft: failed, body } });
      if (!pull) throw new Error("The pull request could not be created.");
      // A retry that now succeeds turns the old draft into a normal pull request.
      if (existingPr && !failed && pull.node_id) {
        await api("graphql", {
          method: "POST",
          body: { query: "mutation($id: ID!) { markPullRequestReadyForReview(input: {pullRequestId: $id}) { clientMutationId } }", variables: { id: pull.node_id } },
        });
      }
      prUrl = pull.html_url;
    }
  }

  if (failed) {
    await comment(api, repository, issue, failureComment({ reason, result, prUrl, runUrl }));
    await setLabels(api, repository, issue, { remove: done, add: [labels.failed] });
    return { result: "failed", reason, pr: prUrl };
  }
  await comment(api, repository, issue, `Pull request: ${prUrl}`);
  await setLabels(api, repository, issue, { remove: [...done, labels.failed], add: [labels.completed] });
  return { result: "completed", pr: prUrl };
}
