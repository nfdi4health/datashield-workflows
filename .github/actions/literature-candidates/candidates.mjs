// The literature watch's candidate pull requests in the hub
// (literature-candidates.yml): `check` keeps the pull request's status red
// until every candidate has exactly one of its three boxes ticked; `apply`,
// once it is merged, opens an idea issue for each "Open an issue" (with
// the candidate's brief and a hidden marker of its key, so it is never
// proposed again) and records every decision in decisions.json on the
// data branch, which the literature watch reads. No Claude, no checkout of
// anything but the hub. Commands: node candidates.mjs check | apply.
import { readFileSync, appendFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const BOXES = { "open an issue": "issue", "not now": "not-now", "don't suggest again": "dont-suggest" };

// Per candidate key (from its marker) the ticked boxes' decisions.
export function parseDecisions(body) {
  const out = {};
  let key = null;
  for (const line of (body ?? "").split(/\r?\n/)) {
    const marker = line.match(/<!--\s*candidate:\s*([^\s]+)\s*-->/);
    if (marker) {
      key = marker[1];
      out[key] = [];
      continue;
    }
    if (!key) continue;
    if (/^#{1,6}\s/.test(line)) { key = null; continue; }
    const box = line.match(/^\s*[-*]\s*\[([ xX])\]\s*(.+?)\s*$/);
    if (box && BOXES[box[2].toLowerCase()] && box[1] !== " ") out[key].push(BOXES[box[2].toLowerCase()]);
  }
  return out;
}

// Keys without exactly one ticked box.
export function undecided(decisions) {
  return Object.entries(decisions).filter(([, d]) => d.length !== 1).map(([k, d]) => ({ key: k, ticked: d.length }));
}

export function candidatesMonth(body) {
  return (body ?? "").match(/<!--\s*literature-watch-candidates:\s*(\d{4}-\d{2})\s*-->/)?.[1] ?? null;
}

// A public issue's text: no @-mentions, no HTML comments.
export function plain(x) {
  return String(x ?? "").replace(/<!--|-->/g, "").replace(/@/g, "@​").replace(/\s+/g, " ").trim();
}

export function issueTitle(c) {
  return `Method: ${plain(c.name)}${c.variant_name ? ` (${plain(c.variant_name)})` : ""}`;
}

export function issueBody(c, prUrl) {
  const r = c.research;
  const lines = [
    `Proposed by the literature watch (${prUrl})${c.list === "rising" ? " as a method on the rise" : ""}: used in ${(100 * c.share).toFixed(1)}% of the sampled health research papers of all years read (${c.papers} papers)` +
      (c.recent_share != null ? `, ${(100 * c.recent_share).toFixed(1)}% in the last years` : "") +
      `, trend ${c.trend}, mostly in ${plain(c.fields)}.`,
    "",
    `**In DataSHIELD:** ${c.verdict === "partial" ? `partly (\`${plain(c.function)}\`)` : "no"}. ${plain(c.note)}`,
  ];
  if (r) {
    const pk = (r.r_packages ?? []).map((p) => `\`${plain(p.package)}::${plain(p.function)}\` (${plain(p.note)})`).join("; ");
    lines.push("", `**What it is:** ${plain(r.description)}`, "", `**In R:** ${pk || "no package found."}`, "",
      `**Federated:** ${plain(r.federated)}`, "", `**Disclosure, a first view:** ${plain(r.disclosure)}`, "",
      `**Would fit:** ${plain(r.fit)}`);
    if ((r.sources ?? []).length) lines.push("", `Sources: ${r.sources.map((s) => `<${plain(s)}>`).join(", ")}`);
  }
  const ex = (c.examples ?? []).map((e) => `[${plain(e.title)}](https://pubmed.ncbi.nlm.nih.gov/${encodeURIComponent(e.pmid)}/)`);
  if (ex.length) lines.push("", `Example papers: ${ex.join("; ")}`);
  lines.push("", "_The brief is Claude's, with web search: a starting point, not a verdict._", "",
    `<!-- literature-watch-method: ${c.key} -->`);
  return lines.join("\n");
}

// decisions.json after this pull request: one entry per decided key.
export function mergeDecisions(existing, decisions, record, { pr, date, issues }) {
  const papers = {};
  for (const c of record.candidates ?? []) papers[c.key] = c.papers;
  for (const d of record.deferred ?? []) papers[d.key] = d.papers;
  const out = { ...existing };
  for (const [key, [decision]] of Object.entries(decisions)) {
    if (!decision) continue;
    out[key] = { decision, date, papers: papers[key] ?? null, pr, ...(issues[key] ? { issue: issues[key] } : {}) };
  }
  return out;
}

function api(token, fetchImpl = fetch) {
  return async (path, { method = "GET", body } = {}) => {
    const res = await fetchImpl(`https://api.github.com/${path}`, {
      method,
      headers: { authorization: `Bearer ${token}`, accept: "application/vnd.github+json", "x-github-api-version": "2022-11-28" },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`${method} ${path}: HTTP ${res.status} ${await res.text()}`);
    return res.status === 204 ? {} : res.json();
  };
}

async function existingMarkers(gh, repo) {
  const found = {};
  for (let page = 1; ; page++) {
    const items = await gh(`repos/${repo}/issues?state=all&per_page=100&page=${page}`);
    if (!items?.length) break;
    for (const i of items) {
      if (i.pull_request) continue;
      for (const m of (i.body ?? "").matchAll(/<!--\s*literature-watch-method:\s*([^\s]+)\s*-->/g)) found[m[1]] = i.number;
    }
    if (items.length < 100) break;
  }
  return found;
}

function summary(lines) {
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${lines.join("\n")}\n`);
  console.log(lines.join("\n"));
}

const commands = {
  async check() {
    const event = JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, "utf8"));
    const decisions = parseDecisions(event.pull_request?.body);
    const keys = Object.keys(decisions);
    const open = undecided(decisions);
    if (open.length) {
      summary(["### Candidates not decided yet", "", ...open.map((o) => `- \`${o.key}\`: ${o.ticked} boxes ticked`),
        "", "Tick exactly one box per candidate."]);
      console.log(`::error::${open.length} of ${keys.length} candidates need exactly one ticked box.`);
      process.exit(1);
    }
    summary([`All ${keys.length} candidates have a decision.`]);
  },

  async apply() {
    const event = JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, "utf8"));
    const pr = event.pull_request;
    if (!pr?.merged) return console.log("Not merged: nothing to apply.");
    const repo = process.env.GITHUB_REPOSITORY;
    const month = candidatesMonth(pr.body);
    if (!month) return console.log("No candidates marker: nothing to apply.");
    const file = join(process.env.CANDIDATES_FOLDER, `${month}.json`);
    if (!existsSync(file)) throw new Error(`${file} isn't on the merged branch.`);
    const record = JSON.parse(readFileSync(file, "utf8"));
    const decisions = parseDecisions(pr.body);
    const gh = api(process.env.GH_TOKEN);
    const markers = await existingMarkers(gh, repo);
    const issues = {};
    for (const c of record.candidates ?? []) {
      if ((decisions[c.key] ?? [])[0] !== "issue") continue;
      if (markers[c.key]) { issues[c.key] = markers[c.key]; continue; }
      const labels = (process.env.ISSUE_LABELS ?? "").split(/[,\s]+/).filter(Boolean);
      const issue = await gh(`repos/${repo}/issues`, { method: "POST", body: { title: issueTitle(c), body: issueBody(c, pr.html_url), labels } });
      issues[c.key] = issue.number;
      console.log(`Opened #${issue.number} for ${c.key}.`);
    }
    const path = process.env.DECISIONS_PATH;
    const branch = process.env.DATA_BRANCH;
    const current = await gh(`repos/${repo}/contents/${path}?ref=${encodeURIComponent(branch)}`);
    const existing = current ? JSON.parse(Buffer.from(current.content, "base64").toString("utf8")) : {};
    const merged = mergeDecisions(existing, decisions, record, { pr: pr.number, date: new Date().toISOString().slice(0, 10), issues });
    await gh(`repos/${repo}/contents/${path}`, { method: "PUT", body: {
      message: `data: decisions of candidate pull request #${pr.number}`, branch, ...(current ? { sha: current.sha } : {}),
      content: Buffer.from(`${JSON.stringify(merged, null, 2)}\n`).toString("base64") } });
    summary([`Recorded ${Object.keys(decisions).length} decisions; opened ${Object.keys(issues).length} issue(s).`]);
  },
};

if (import.meta.url === `file://${process.argv[1]}`) {
  const command = commands[process.argv[2]];
  if (!command) { console.error("Usage: candidates.mjs check | apply"); process.exit(2); }
  command().catch((e) => { console.error(`::error::${e.message}`); process.exit(1); });
}
