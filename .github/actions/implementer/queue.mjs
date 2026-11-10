// Which approved issue runs next, and whether its approval holds. Nothing in
// a dispatch is trusted: every fact is read back from GitHub.
//
// The approved issues are the work list (dev-notes/implementer-plan.md,
// "Queue"): open issues with the approval label and without the running
// label, oldest approval first. A dispatch naming an issue only puts it first.

import { createHash } from "node:crypto";
import { Refusal, hasLabel, listAll, sameLabel } from "./lib.mjs";

export const TRIAGE_MARKER = /^<!-- bot-triage: ([a-z-]+) -->/;

export function parseRequest(targets, repository, issue) {
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repository ?? "")) {
    throw new Refusal("The repository must look like owner/name.");
  }
  if (!/^[1-9][0-9]{0,8}$/.test(String(issue ?? ""))) throw new Refusal("The issue must be a number.");
  // Own properties only, so that a name like __proto__ isn't found.
  const key = Object.keys(targets).find((name) => name.toLowerCase() === repository.toLowerCase());
  if (!key || !Object.hasOwn(targets, key)) throw new Refusal(`${repository} is not one of the target repositories.`);
  const [owner, name] = key.split("/");
  const { base = "dev", setup = "r", server = "" } = targets[key];
  return { repository: key, owner, name, issue: String(issue), base, setup, server };
}

// The latest time the label was set, with who set it.
export function latestApproval(events, label) {
  return events.filter((e) => e.event === "labeled" && sameLabel(e.label?.name, label)).at(-1) ?? null;
}

// The newest triage comment. It is the spec only if its category gets one.
export function newestTriage(comments, author) {
  return comments.filter((c) => c.user?.login === author && TRIAGE_MARKER.test(c.body ?? "")).at(-1) ?? null;
}

// The commit type comes from the issue's label, never from Claude: it
// decides the version. The label is how a person corrects triage.
export function commitType(issue, typeLabels) {
  const types = Object.entries(typeLabels).filter(([label]) => hasLabel(issue, label)).map(([, type]) => type);
  const unique = [...new Set(types)];
  if (unique.length === 0) {
    throw new Refusal(`The issue carries none of the labels ${Object.keys(typeLabels).join(", ")}, so it is unclear whether this is a fix or a feature.`);
  }
  if (unique.length > 1) throw new Refusal(`The issue carries labels for both ${unique.join(" and ")}. Keep one.`);
  return unique[0];
}

export async function verifyIssue(api, cfg, request) {
  const { repository, issue } = request;
  const path = `repos/${repository}/issues/${issue}`;
  const found = await api(path);
  if (!found) throw new Refusal(`Issue ${issue} doesn't exist in ${repository}.`);
  if (found.pull_request) throw new Refusal(`#${issue} is a pull request, not an issue.`);
  if (found.state !== "open") throw new Refusal(`Issue ${issue} is not open.`);
  if (!hasLabel(found, cfg.labels.proceed)) throw new Refusal(`Issue ${issue} doesn't carry ${cfg.labels.proceed}.`);
  if (hasLabel(found, cfg.labels.suspicious)) {
    throw new Refusal(`Issue ${issue} carries ${cfg.labels.suspicious}: a person has to look at it and remove that label first.`);
  }

  // The most recent approval decides, so an old one can't vouch for a new label.
  const approval = latestApproval(await listAll(api, `${path}/events`), cfg.labels.proceed);
  if (!approval) throw new Refusal(`No record of who set ${cfg.labels.proceed} on issue ${issue}.`);
  if (!cfg.allowedLogins.includes(approval.actor?.login)) {
    throw new Refusal(`${cfg.labels.proceed} on issue ${issue} was set by ${approval.actor?.login}, who is not allowed to approve.`, { cause: "not-allowed" });
  }

  const triage = newestTriage(await listAll(api, `${path}/comments`), cfg.triageAuthor);
  if (!triage) throw new Refusal(`Issue ${issue} has no triage comment, so there is no spec.`);
  const category = triage.body.match(TRIAGE_MARKER)[1];
  if (!cfg.specCategories.includes(category)) {
    throw new Refusal(`The newest triage of issue ${issue} is "${category}", which has no spec. Ask for a new triage first.`);
  }
  if (new Date(triage.updated_at) > new Date(approval.created_at)) {
    throw new Refusal(`The spec of issue ${issue} changed after it was approved. Read it and approve again.`);
  }

  const type = commitType(found, cfg.typeLabels);
  const branch = `${cfg.branchPrefix}${type}/issue-${issue}`;
  // A failed attempt leaves a draft pull request, which a new run replaces.
  // Anything else on that branch means the work is done or taken over.
  const pulls = await listAll(api, `repos/${repository}/pulls?state=all&head=${encodeURIComponent(`${request.owner}:${branch}`)}`);
  const blocking = pulls.find((p) => p.merged_at || (p.state === "open" && !p.draft));
  if (blocking) throw new Refusal(`${branch} already has pull request #${blocking.number}, so this issue seems done.`);
  const draft = pulls.find((p) => p.state === "open" && p.draft);

  return {
    title: found.title,
    spec: triage.body,
    sha: createHash("sha256").update(triage.body).digest("hex"),
    approvedAt: approval.created_at,
    type,
    branch,
    existingPr: draft ? String(draft.number) : "",
  };
}

// Open issues with the approval label and without the running label, oldest
// approval first, over all target repositories.
export async function listQueue(api, cfg, targets) {
  const queue = [];
  for (const repository of Object.keys(targets)) {
    const issues = await listAll(api, `repos/${repository}/issues?state=open&labels=${encodeURIComponent(cfg.labels.proceed)}`);
    for (const issue of issues) {
      if (issue.pull_request || hasLabel(issue, cfg.labels.inProgress)) continue;
      const approval = latestApproval(await listAll(api, `repos/${repository}/issues/${issue.number}/events`), cfg.labels.proceed);
      queue.push({ repository, issue: String(issue.number), approvedAt: approval?.created_at ?? issue.created_at });
    }
  }
  return queue.sort((a, b) => new Date(a.approvedAt) - new Date(b.approvedAt));
}

// A refused issue leaves the list with the reason on it, so the next run
// doesn't refuse it again. One whose label someone else set stays as it is:
// the label check removes that label itself.
export async function refuse(api, cfg, request, reason) {
  const path = `repos/${request.repository}/issues/${request.issue}`;
  await api(`${path}/labels/${encodeURIComponent(cfg.labels.proceed)}`, { method: "DELETE" });
  await api(`${path}/comments`, {
    method: "POST",
    body: { body: `Not started: ${reason}\n\nRemoved \`${cfg.labels.proceed}\`; set it again once this is sorted out.` },
  });
}

// The next issue to work on: the requested one first, then the list.
export async function pickNext(api, cfg, targets, requested, log = console.log) {
  const candidates = [];
  if (requested?.repository && requested?.issue) candidates.push(requested);
  for (const item of await listQueue(api, cfg, targets)) {
    if (!candidates.some((c) => c.repository.toLowerCase() === item.repository.toLowerCase() && c.issue === item.issue)) {
      candidates.push(item);
    }
  }
  for (const candidate of candidates) {
    let request;
    try {
      request = parseRequest(targets, candidate.repository, candidate.issue);
      const verified = await verifyIssue(api, cfg, request);
      return { ...request, ...verified };
    } catch (error) {
      if (!(error instanceof Refusal)) throw error;
      log(`${candidate.repository}#${candidate.issue}: ${error.message}`);
      const listed = request && error.cause !== "not-allowed" && !/doesn't carry|not open|pull request|doesn't exist/.test(error.message);
      if (listed) await refuse(api, cfg, request, error.message);
    }
  }
  return null;
}
