// How the agent's steps ended: done, another correction round, stopped at
// the subscription's limit, or failed. Reads only files the job wrote; their
// text is data.

import { existsSync, readFileSync } from "node:fs";

// Claude Code's message at a subscription limit. It has said "Claude AI
// usage limit reached|<epoch>" and "You've hit your limit · resets 3pm
// (Europe/Berlin)"; checked against the last result only, so text the agent
// wrote about limits in code can't pass for one.
const LIMIT = /usage limit|hit your (?:usage )?limit|limit reached|out of (?:extra )?usage|weekly limit/i;

// The UTC time at which the clock in `zone` shows hour:minute next, after now.
function nextLocalTime(hour, minute, zone, now) {
  for (let days = 0; days <= 1; days += 1) {
    const guess = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + days, hour, minute));
    let offset = 0;
    try {
      const parts = Object.fromEntries(new Intl.DateTimeFormat("en-US", {
        timeZone: zone, hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit",
      }).formatToParts(guess).map((p) => [p.type, p.value]));
      const shown = Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour, +parts.minute);
      offset = shown - guess.getTime();
    } catch {
      return null;
    }
    const at = new Date(guess.getTime() - offset);
    if (at > now) return at;
  }
  return null;
}

export function parseLimit(text, now = new Date()) {
  const message = String(text ?? "");
  if (!LIMIT.test(message)) return null;
  const epoch = message.match(/\|(\d{10})\b/);
  if (epoch) return { resetAt: new Date(Number(epoch[1]) * 1000).toISOString() };
  const clock = message.match(/resets?\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?(?:\s*\(([^)]+)\))?/i);
  if (clock) {
    let hour = Number(clock[1]) % 12;
    if (!clock[3]) hour = Number(clock[1]);
    else if (clock[3].toLowerCase() === "pm") hour += 12;
    const at = nextLocalTime(hour, Number(clock[2] ?? 0), clock[4] ?? "UTC", now);
    if (at) return { resetAt: at.toISOString() };
  }
  return { resetAt: "" };
}

// The final result of one claude-code-action run, from its execution file.
export function readExecution(file) {
  if (!file || !existsSync(file)) return { found: false, isError: true, text: "" };
  let messages;
  try {
    messages = JSON.parse(readFileSync(file, "utf8"));
  } catch {
    return { found: true, isError: true, text: "" };
  }
  const list = Array.isArray(messages) ? messages : [messages];
  const result = list.filter((m) => m?.type === "result").at(-1);
  if (result) return { found: true, isError: Boolean(result.is_error) || result.subtype !== "success", text: String(result.result ?? result.error ?? "") };
  const last = list.slice(-3).map((m) => JSON.stringify(m)).join("\n");
  return { found: true, isError: true, text: last };
}

// checks.json is written by run-checks.sh; review JSON by the maintainability
// reviewer. Missing or broken files count as "nothing found".
export function readJson(file, fallback) {
  try {
    return JSON.parse(readFileSync(file, "utf8"));
  } catch {
    return fallback;
  }
}

export function mustFix(review) {
  return Array.isArray(review?.must_fix) ? review.must_fix.filter((item) => item && (item.problem || typeof item === "string")) : [];
}

// Findings of the disclosure review that deviate from the approved spec
// (review-disclosure.json, saveDisclosureReview()).
export function deviations(disclosure) {
  return Array.isArray(disclosure?.deviations) ? disclosure.deviations.filter((d) => typeof d === "string" && d.trim()) : [];
}

// Another correction round when a check failed, the reviewer found
// something that must be fixed, or (after round 0, the only disclosure
// review before the re-check at the end) the disclosure review found a
// deviation from the spec — while rounds are left.
export function nextRound({ checks, review, disclosure = {}, round, maxRounds }) {
  if (round >= maxRounds) return false;
  return checks?.ok === false || mustFix(review).length > 0 || (round === 0 && deviations(disclosure).length > 0);
}

// The disclosure reviewer's answer: Markdown ending in a fenced JSON block
// {"deviations": [...]}. Returns the Markdown without the block, and the
// deviations (none if the block is missing or unreadable: then the review
// is still shown, nothing goes back to the writer).
export function splitDisclosureReview(text) {
  const raw = String(text ?? "").trim();
  const match = raw.match(/```json\s*(\{[\s\S]*?\})\s*```\s*$/);
  if (!match) return { markdown: raw, deviations: [] };
  let parsed = {};
  try {
    parsed = JSON.parse(match[1]);
  } catch {
    parsed = {};
  }
  return { markdown: raw.slice(0, match.index).trim(), deviations: deviations(parsed) };
}

// The run's result from the agent steps (in order), the last checks, and
// the files the writer left.
export function finalOutcome({ steps, checks, needsInput, hasCommits, now = new Date() }) {
  for (const step of steps) {
    if (!step.ran) continue;
    if (step.conclusion === "success") continue;
    const execution = readExecution(step.executionFile);
    const limit = parseLimit(execution.text, now);
    if (limit) return { result: "limit", resetAt: limit.resetAt, reason: "The subscription's usage limit was reached." };
    // A failed reviewer doesn't sink the writer's work; a failed writer does.
    if (step.role === "writer") {
      if (!execution.found) {
        return { result: "failed", reason: "The agent didn't start (Claude Code left no log); the run's log says why." };
      }
      return { result: "failed", reason: `The agent stopped with an error${execution.text ? `: ${execution.text.slice(0, 300)}` : "."}` };
    }
  }
  if (needsInput) return { result: "needs-input", reason: "The agent needs a decision before it can go on." };
  if (!hasCommits) return { result: "failed", reason: "The agent made no commit." };
  if (checks && checks.ok === false) return { result: "failed", reason: "Checks still fail after the correction rounds." };
  return { result: "completed", reason: "" };
}
