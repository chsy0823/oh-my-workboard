#!/usr/bin/env node
/**
 * Workboard data-model linter.
 *
 * Validates the invariants defined in the workboard-model skill:
 *   R1  Every entry in board/requests.md has a [project] prefix.
 *   R2  No @wait(user: action) form in people/*.md — cross-member deps go to requests.md.
 *   R3  No workboard @today leaf duplicates a requests.md entry's content.
 *   R4  Every status.md team-plan sub matches the named owner's workboard top-level.
 *   R5  @today only on leaves (never on a node with children).
 *   R6  @done <-> [x] consistency. [x] leaves should carry @done(YYYY-MM-DD).
 *   R7  Only allowed tags: today, done, wait, block, handoff.
 *   R8  @done(YYYY-MM-DD) date is parseable in YYYY-MM-DD format.
 *
 * Usage:
 *   node scripts/lint-workboard.js              # all findings; exit 1 on errors
 *   node scripts/lint-workboard.js --quiet      # suppress success message
 *   node scripts/lint-workboard.js --errors-only # warnings hidden, errors only
 *
 * Exit:
 *   0 = no errors
 *   1 = errors found (warnings do not affect exit)
 */

const path = require('node:path');
const { parseAll } = require('../dashboard/lib/parser');

const ROOT = path.resolve(__dirname, '..');
const QUIET = process.argv.includes('--quiet');
const ERRORS_ONLY = process.argv.includes('--errors-only');

const ALLOWED_TAGS = new Set(['today', 'done', 'wait', 'block', 'handoff']);
const KNOWN_PROJECT_LABELS = new Set(['misc', 'new', 'workboard']);

const findings = [];
function report(severity, file, message, hint) {
  findings.push({ severity, file, message, hint });
}

function walkTree(items, callback) {
  for (const item of items) {
    callback(item);
    if (item.children && item.children.length > 0) walkTree(item.children, callback);
  }
}

function hasTopLevelMatch(person, text) {
  return person.tree.some(top => {
    const full = (top.project ? `[${top.project}] ` : '') + top.text;
    return full === text || top.text === text;
  });
}

function lint() {
  const data = parseAll(ROOT);
  const teamIds = new Set(data.people.map(p => p.id));

  // Enrich known project labels with discovered project directories.
  for (const ms of data.milestones) {
    if (ms.project) KNOWN_PROJECT_LABELS.add(ms.project);
  }

  // ── R1 — requests.md must have [project] prefix ──────────
  for (const r of data.requests) {
    if (!r.project) {
      report('error', 'board/requests.md',
        `Request is missing a [project] prefix: "${r.from} -> ${r.to}: ${r.content}"`,
        'Add a known project label or use [misc].');
    } else if (!KNOWN_PROJECT_LABELS.has(r.project)) {
      report('warn', 'board/requests.md',
        `Request label [${r.project}] is not a known project: "${r.from} -> ${r.to}: ${r.content}"`,
        `Typo, or a new project — create projects/${r.project}/ or use [misc].`);
    }
  }

  // ── R2 — @wait(user: action) is forbidden when user is a teammate ──
  for (const person of data.people) {
    for (const w of person.waiting) {
      if (w.gateUser && teamIds.has(w.gateUser)) {
        report('error', `people/${person.id}.md`,
          `@wait(${w.gateUser}: ...) is forbidden — cross-member deps go to board/requests.md (single-channel rule).`,
          `Drop the @wait tag and add a request: ${person.id} -> ${w.gateUser} in board/requests.md.`);
      }
    }
  }

  // ── R3 — workboard @today must not duplicate a requests.md entry ──
  for (const r of data.requests) {
    if (!r.to || !teamIds.has(r.to)) continue;
    const target = data.people.find(p => p.id === r.to);
    if (!target) continue;
    walkTree(target.tree, (item) => {
      if (item.checked) return;
      if (item.tags.today === undefined) return;
      const itemFull = (item.project ? `[${item.project}] ` : '') + item.text;
      const reqFull = (r.project ? `[${r.project}] ` : '') + r.content;
      if (item.text === r.content || itemFull === reqFull) {
        report('warn', `people/${r.to}.md`,
          `@today leaf duplicates a requests.md entry: "${item.text}"`,
          'requests.md already tracks this. Remove the workboard leaf, or drop the @today tag.');
      }
    });
  }

  // ── R4 — status.md sub text must match the owner's workboard top-level ──
  if (data.teamPlan && data.teamPlan.goals) {
    for (const g of data.teamPlan.goals) {
      for (const sub of g.subs) {
        if (!sub.owner || !teamIds.has(sub.owner)) continue;
        if (sub.checked) continue;
        const target = data.people.find(p => p.id === sub.owner);
        if (!target) continue;
        if (!hasTopLevelMatch(target, sub.text)) {
          report('warn', 'board/status.md',
            `Team-plan sub for @${sub.owner} does not match any workboard top-level: "${sub.text}"`,
            'Align text on /start-week mirror; drift breaks /end-day auto-sync.');
        }
      }
    }
  }

  // ── R5 / R6 / R7 / R8 — per-tree validation ──────────────
  const datePattern = /^\d{4}-\d{2}-\d{2}$/;
  for (const person of data.people) {
    walkTree(person.tree, (item) => {
      // R5: @today must only be on leaves
      if (item.tags.today !== undefined && item.children && item.children.length > 0) {
        report('error', `people/${person.id}.md`,
          `@today must only be on leaves: "${item.text}"`,
          'Remove @today from this parent and put it on the smallest sub leaf you intend to do today.');
      }

      // R6: @done <-> [x] consistency
      if (item.tags.done !== undefined && !item.checked) {
        report('error', `people/${person.id}.md`,
          `@done is set but the box is not checked: "${item.text}"`,
          'Either mark the leaf [x] or drop the @done tag.');
      }
      const isLeaf = !item.children || item.children.length === 0;
      if (item.checked && isLeaf && item.tags.done === undefined) {
        report('warn', `people/${person.id}.md`,
          `[x] leaf is missing @done(YYYY-MM-DD): "${item.text}"`,
          'Record the completion date — add @done(YYYY-MM-DD).');
      }

      // R7: unknown tags
      for (const tag of Object.keys(item.tags)) {
        if (!ALLOWED_TAGS.has(tag)) {
          report('warn', `people/${person.id}.md`,
            `Unknown tag @${tag}: "${item.text}"`,
            'Allowed: today, done, wait, block, handoff. If new, update the workboard-model skill first.');
        }
      }

      // R8: @done date format
      if (typeof item.tags.done === 'string' && !datePattern.test(item.tags.done)) {
        report('warn', `people/${person.id}.md`,
          `@done date format is invalid (@done(${item.tags.done})): "${item.text}"`,
          'Use YYYY-MM-DD (e.g. 2026-04-22).');
      }
    });
  }
}

lint();

const errors = findings.filter(f => f.severity === 'error');
const warnings = findings.filter(f => f.severity === 'warn');

if (findings.length === 0) {
  if (!QUIET) console.log('workboard lint: clean');
} else {
  if (errors.length > 0) {
    console.error(`\n${errors.length} error${errors.length === 1 ? '' : 's'}`);
    for (const f of errors) {
      console.error(`  [error] ${f.file}: ${f.message}`);
      console.error(`    -> ${f.hint}`);
    }
  }
  if (warnings.length > 0 && !ERRORS_ONLY) {
    console.error(`\n${warnings.length} warning${warnings.length === 1 ? '' : 's'}`);
    for (const f of warnings) {
      console.error(`  [warn] ${f.file}: ${f.message}`);
      console.error(`    -> ${f.hint}`);
    }
  }
}

process.exit(errors.length > 0 ? 1 : 0);
