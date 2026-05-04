#!/usr/bin/env node
/**
 * SessionStart briefing — render a one-screen workboard summary for the current git user.
 *
 * Toggle: ~/.claude/workboard.json must have `"session_brief": true`. Default is off.
 *
 * Usage:
 *   node scripts/session-brief.js                # auto-resolve from `git config user.name`
 *   node scripts/session-brief.js --user {id}    # force a specific id
 *
 * Always exits 0 — SessionStart hooks must never block.
 */

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execSync } = require('node:child_process');
const { parseAll } = require('../dashboard/lib/parser');

const ROOT = path.resolve(__dirname, '..');

// ── Toggle gate ───────────────────────────────────────────
// Resolve workboard config: local (<git-root>/.workboard.json) wins over global.
function loadConfig() {
  const { execSync } = require('node:child_process');
  let projectRoot;
  try {
    projectRoot = execSync('git rev-parse --show-toplevel', {
      encoding: 'utf-8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    projectRoot = process.cwd();
  }
  const candidates = [
    path.join(projectRoot, '.workboard.json'),
    path.join(os.homedir(), '.claude', 'workboard.json'),
  ];
  for (const file of candidates) {
    try {
      return JSON.parse(fs.readFileSync(file, 'utf-8'));
    } catch {
      // try next
    }
  }
  return null;
}
function isEnabled() {
  const cfg = loadConfig();
  return !!(cfg && cfg.session_brief === true);
}
if (!isEnabled()) process.exit(0);

// ── Load team mapping from .workboard/team.yaml ──────────
// Minimal YAML reader for the fields we need: members[].id / name / keywords / active.
// Assumes inline-array form for keywords (`keywords: [a, b, c]`), which the plugin's
// template generates; falls back gracefully on other shapes.
function loadTeam(rootDir) {
  const teamFile = path.join(rootDir, '.workboard', 'team.yaml');
  if (!fs.existsSync(teamFile)) return [];
  const content = fs.readFileSync(teamFile, 'utf-8');
  const members = [];
  let cur = null;
  const flush = () => { if (cur) members.push(cur); cur = null; };
  for (const raw of content.split('\n')) {
    const idMatch = raw.match(/^\s*-\s*id:\s*(.+?)\s*$/);
    if (idMatch) {
      flush();
      cur = { id: idMatch[1].replace(/['"]/g, ''), name: '', keys: [], active: true };
      continue;
    }
    if (!cur) continue;
    const nameMatch = raw.match(/^\s*name:\s*(.+?)\s*$/);
    if (nameMatch) { cur.name = nameMatch[1].replace(/['"]/g, ''); continue; }
    const kwMatch = raw.match(/^\s*keywords:\s*\[(.+)\]\s*$/);
    if (kwMatch) {
      cur.keys = kwMatch[1].split(',').map(s => s.trim().replace(/['"]/g, '')).filter(Boolean);
      continue;
    }
    const actMatch = raw.match(/^\s*active:\s*(.+?)\s*$/);
    if (actMatch) { cur.active = actMatch[1].trim() === 'true'; continue; }
  }
  flush();
  return members
    .filter(m => m.active)
    .map(m => ({ id: m.id, keys: [m.id, m.name, ...m.keys].filter(Boolean) }));
}

function resolveUser(team) {
  const idx = process.argv.indexOf('--user');
  if (idx >= 0 && process.argv[idx + 1]) return process.argv[idx + 1];
  let gitUser = '';
  try {
    gitUser = execSync('git config user.name', { encoding: 'utf-8' }).trim();
  } catch {
    return '';
  }
  const lower = gitUser.toLowerCase();
  for (const m of team) {
    if (m.keys.some(k => k && lower.includes(k.toLowerCase()))) return m.id;
  }
  return '';
}

function isoWeek(d) {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  const day = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
}
const WEEKDAY = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

function daysUntilDeadline(s, today) {
  if (!s) return null;
  let m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  let target;
  if (m) target = new Date(+m[1], +m[2] - 1, +m[3]);
  else if ((m = s.match(/^(\d{1,2})-(\d{1,2})/))) target = new Date(today.getFullYear(), +m[1] - 1, +m[2]);
  else return null;
  const t0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  return Math.round((target - t0) / 86400000);
}

function dLabel(daysLeft) {
  if (daysLeft === null) return '';
  if (daysLeft < 0) return ` 🔴overdue ${-daysLeft}d`;
  if (daysLeft === 0) return ' 🟠today';
  if (daysLeft <= 2) return ` 🟠D-${daysLeft}`;
  if (daysLeft <= 7) return ` 🟡D-${daysLeft}`;
  return '';
}

function ballOnUser(r, userId) {
  if (r.to !== userId) return false;
  if (!r.pingpong) return true;
  // "changes-requested → @{other} in-progress" means ball is on the other party.
  const m = r.pingpong.match(/changes-requested\s*→\s*@(\S+)/i);
  if (m && m[1] !== userId) return false;
  return true;
}

function brief() {
  const team = loadTeam(ROOT);
  const userId = resolveUser(team);
  if (!userId) return;

  const data = parseAll(ROOT);
  const me = data.people.find(p => p.id === userId);
  if (!me) return;

  const today = new Date();
  const week = isoWeek(today);
  const dow = today.getDay() === 0 ? 7 : today.getDay();
  const dayLabel = WEEKDAY[today.getDay()];

  const tree = me.tree || [];
  const topTotal = tree.length;
  const topDone = tree.filter(t => t.checked).length;
  const todays = me.doing || [];
  const waits = me.waiting || [];

  const incoming = data.requests.filter(r => ballOnUser(r, userId));
  const handoffsIn = incoming.filter(r => r.reqType === 'handoff');
  const reviewsIn = incoming.filter(r => r.reqType === 'review');
  const worksIn = incoming.filter(r => r.reqType === 'work');

  const lines = [];
  lines.push('');
  lines.push(`📋 ${userId} — W${week} D${dow} (${dayLabel})`);
  lines.push('');
  lines.push(`This week: ${topDone}/${topTotal} top-level done`);

  if (todays.length > 0) {
    lines.push(`Today (@today): ${todays.length}`);
    for (const t of todays.slice(0, 4)) {
      const proj = t.project ? `[${t.project}] ` : '';
      lines.push(`  · ${proj}${t.task}`);
    }
  } else {
    lines.push('Today (@today): none picked — run /start-day to choose');
  }

  if (waits.length > 0) {
    lines.push(`Waiting on: ${waits.length}`);
    for (const w of waits.slice(0, 3)) {
      const proj = w.project ? `[${w.project}] ` : '';
      lines.push(`  · ${proj}${w.task} — wait: ${w.detail}`);
    }
  }

  if (incoming.length > 0) {
    lines.push('');
    lines.push(`📨 Incoming requests (${incoming.length}: review ${reviewsIn.length} / work ${worksIn.length} / handoff ${handoffsIn.length})`);
    for (const r of incoming.slice(0, 5)) {
      const proj = r.project ? `[${r.project}] ` : '';
      const d = r.deadline ? dLabel(daysUntilDeadline(r.deadline, today)) : '';
      const cat = r.reqType === 'handoff' ? '🚀' : r.reqType === 'work' ? '🔧' : '👀';
      lines.push(`  ${cat} ${proj}${r.content} (from @${r.from})${d}`);
    }
    if (incoming.length > 5) lines.push(`  · …and ${incoming.length - 5} more`);
  }

  const outgoingPending = data.requests.filter(r =>
    r.from === userId && r.to !== userId && !ballOnUser(r, r.from)
  );
  if (outgoingPending.length > 0) {
    lines.push(`📤 Outgoing requests — awaiting reply: ${outgoingPending.length}`);
  }

  if (data.blockers && data.blockers.length > 0) {
    const myBlockers = data.blockers.filter(b => b.from === userId);
    if (myBlockers.length > 0) {
      lines.push('');
      lines.push(`🚨 My blockers (${myBlockers.length})`);
      for (const b of myBlockers.slice(0, 3)) {
        lines.push(`  · ${b.content}${b.target ? ' → ' + b.target : ''}`);
      }
    }
  }

  lines.push('');
  process.stdout.write(lines.join('\n') + '\n');
}

try {
  brief();
} catch {
  // SessionStart must never block the session — swallow failures silently.
}
