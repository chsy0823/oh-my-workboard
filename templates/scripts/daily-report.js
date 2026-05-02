#!/usr/bin/env node
/**
 * Daily Report
 * Usage: node scripts/daily-report.js [--text|--blocks|--mrkdwn]
 *   --blocks (default): Slack blocks JSON
 *   --text: plain text (CLI preview)
 *   --mrkdwn: mrkdwn single block (Slack mentions resolved)
 */

const path = require('node:path');
const { parseAll, computeTeamGoalProgress } = require('../dashboard/lib/parser');

const ROOT = path.resolve(__dirname, '..');
const MODE = process.argv.includes('--text') ? 'text'
           : process.argv.includes('--mrkdwn') ? 'mrkdwn'
           : 'blocks';

function nowLocal() { return new Date(); }
function fmtDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${dd}`;
}
function isoWeek(d) {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  const day = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
}
function dayOfWeek1to7(d) { return d.getDay() === 0 ? 7 : d.getDay(); }
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

function personProgress(p) {
  const tree = p.tree || [];
  const total = tree.length;
  const done = tree.filter(t => t.checked).length;
  const pct = total > 0 ? Math.round((done / total) * 100) : 0;
  return { id: p.id, total, done, pct };
}

function findStalePingpongs(requests, today, thresholdDays = 4) {
  const stale = [];
  for (const r of requests) {
    if (!r.pingpong) continue;
    const m = r.pingpong.match(/\((\d{1,2})-(\d{1,2})\)/);
    if (!m) continue;
    const start = new Date(today.getFullYear(), +m[1] - 1, +m[2]);
    const t0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const days = Math.round((t0 - start) / 86400000);
    if (days >= thresholdDays) stale.push({ ...r, stalledDays: days });
  }
  return stale;
}

function findDueRequests(requests, today, withinDays = 3) {
  const due = [];
  for (const r of requests) {
    if (!r.deadline) continue;
    const d = daysUntilDeadline(r.deadline, today);
    if (d === null) continue;
    if (d <= withinDays) due.push({ ...r, daysLeft: d });
  }
  due.sort((a, b) => a.daysLeft - b.daysLeft);
  return due;
}

function collectBlockers(people) {
  const out = [];
  for (const p of people) {
    for (const b of p.blockers) out.push({ from: p.id, content: b.content, target: b.target });
  }
  return out;
}

function build() {
  const today = nowLocal();
  const dateStr = fmtDate(today);
  const week = isoWeek(today);
  const dow = dayOfWeek1to7(today);
  const dayLabel = WEEKDAY[today.getDay()];

  const data = parseAll(ROOT);
  const teamPlanGoals = computeTeamGoalProgress(data.teamPlan, data.milestones);
  const persons = data.people.map(personProgress).sort((a, b) => a.id.localeCompare(b.id));
  const dueRequests = findDueRequests(data.requests, today, 3);
  const stalePingpongs = findStalePingpongs(data.requests, today, 4);
  const blockers = collectBlockers(data.people);

  return { today, dateStr, week, dow, dayLabel, teamPlanGoals, persons, dueRequests, stalePingpongs, blockers };
}

// {{SLACK_ID_FALLBACK}} — rendered by /oh-my-workboard:init from team.yaml.
const SLACK_ID_FALLBACK = {};
const SLACK_IDS = Object.fromEntries(
  Object.keys(SLACK_ID_FALLBACK).map(id => [id, process.env[`SLACK_ID_${id.replace(/-/g, '_')}`] || SLACK_ID_FALLBACK[id]])
);
function mention(id) {
  const sid = SLACK_IDS[id];
  return sid ? `<@${sid}>` : `@${id}`;
}

function renderText(r) {
  const lines = [];
  lines.push(`Daily — ${r.dateStr} (${r.dayLabel}, W${r.week} D${r.dow})`);
  lines.push('');

  lines.push('Workboard progress (top-level)');
  const teamTotal = r.persons.reduce((a, p) => a + p.total, 0);
  const teamDone = r.persons.reduce((a, p) => a + p.done, 0);
  const teamPct = teamTotal > 0 ? Math.round((teamDone / teamTotal) * 100) : 0;
  lines.push(`  team ${teamPct}%  (${teamDone}/${teamTotal})`);
  for (const p of r.persons) {
    lines.push(`  · @${p.id.padEnd(15)} ${String(p.pct).padStart(3)}%  (${p.done}/${p.total})`);
  }
  lines.push('');

  const trackedGoals = r.teamPlanGoals.filter(g => g.total > 0);
  if (trackedGoals.length > 0) {
    lines.push('Team goals → milestone contribution');
    for (const g of trackedGoals) {
      const icon = g.checked || g.subProgress === 100 ? 'done' : '...';
      const msStr = g.milestoneAverage !== null ? `  → ${g.mappings.join('·')} avg ${g.milestoneAverage}%` : '';
      lines.push(`  · [${icon}] ${g.text} — ${g.subProgress}%${msStr}`);
    }
    lines.push('');
  }

  if (r.blockers.length > 0) {
    lines.push(`Blockers (${r.blockers.length})`);
    for (const b of r.blockers) lines.push(`  · @${b.from} — ${b.content}${b.target ? ` → ${b.target}` : ''}`);
    lines.push('');
  }

  if (r.dueRequests.length > 0) {
    lines.push(`Deadlines (${r.dueRequests.length})`);
    for (const x of r.dueRequests) {
      let label = x.daysLeft < 0 ? `OVERDUE ${-x.daysLeft}d` : x.daysLeft === 0 ? 'TODAY' : `D-${x.daysLeft}`;
      const proj = x.project ? `[${x.project}] ` : '';
      lines.push(`  · ${label}  ${proj}${x.content}  @${x.from} → @${x.to}`);
    }
    lines.push('');
  }

  if (r.stalePingpongs.length > 0) {
    lines.push(`Stale ping-pongs (${r.stalePingpongs.length}, 4+ days)`);
    for (const x of r.stalePingpongs) {
      const proj = x.project ? `[${x.project}] ` : '';
      lines.push(`  · ${proj}${x.content} — ${x.stalledDays}d / ${x.pingpong}`);
    }
  }

  return lines.join('\n').replace(/\n+$/, '');
}

function renderMrkdwn(r) {
  let txt = renderText(r);
  for (const id of Object.keys(SLACK_IDS)) txt = txt.split(`@${id}`).join(mention(id));
  return txt;
}

function renderBlocks(r) {
  const blocks = [];
  blocks.push({
    type: 'header',
    text: { type: 'plain_text', text: `Daily — ${r.dateStr} (${r.dayLabel}, W${r.week} D${r.dow})`, emoji: true },
  });

  {
    const lines = ['*Workboard progress* (top-level)'];
    const teamTotal = r.persons.reduce((a, p) => a + p.total, 0);
    const teamDone = r.persons.reduce((a, p) => a + p.done, 0);
    const teamPct = teamTotal > 0 ? Math.round((teamDone / teamTotal) * 100) : 0;
    lines.push(`team *${teamPct}%*  (${teamDone}/${teamTotal})`);
    for (const p of r.persons) lines.push(`• ${mention(p.id)}  *${p.pct}%*  (${p.done}/${p.total})`);
    blocks.push({ type: 'section', text: { type: 'mrkdwn', text: lines.join('\n') } });
  }

  const trackedGoals = r.teamPlanGoals.filter(g => g.total > 0);
  if (trackedGoals.length > 0) {
    const lines = ['*Team goals → milestone contribution*'];
    for (const g of trackedGoals) {
      const icon = g.checked || g.subProgress === 100 ? ':white_check_mark:' : ':hourglass:';
      const msStr = g.milestoneAverage !== null ? `  _→ ${g.mappings.join('·')} avg ${g.milestoneAverage}%_` : '';
      lines.push(`${icon} ${g.text} — *${g.subProgress}%*${msStr}`);
    }
    blocks.push({ type: 'section', text: { type: 'mrkdwn', text: lines.join('\n') } });
  }

  if (r.blockers.length > 0) {
    const lines = [`*Blockers* (${r.blockers.length})`];
    for (const b of r.blockers) lines.push(`• ${mention(b.from)} — ${b.content}${b.target ? ` → ${b.target}` : ''}`);
    blocks.push({ type: 'section', text: { type: 'mrkdwn', text: lines.join('\n') } });
  }

  if (r.dueRequests.length > 0) {
    const lines = [`*Deadlines* (${r.dueRequests.length})`];
    for (const x of r.dueRequests) {
      let label = x.daysLeft < 0 ? `:rotating_light: overdue ${-x.daysLeft}d`
                : x.daysLeft === 0 ? ':warning: today'
                : `:hourglass: D-${x.daysLeft}`;
      const proj = x.project ? `\`${x.project}\` ` : '';
      lines.push(`• ${label}  ${proj}${x.content}  ${mention(x.from)} → ${mention(x.to)}`);
    }
    blocks.push({ type: 'section', text: { type: 'mrkdwn', text: lines.join('\n') } });
  }

  if (r.stalePingpongs.length > 0) {
    const lines = [`*Stale ping-pongs* (${r.stalePingpongs.length}, 4+ days)`];
    for (const x of r.stalePingpongs) {
      const proj = x.project ? `\`${x.project}\` ` : '';
      lines.push(`• ${proj}${x.content} — ${x.stalledDays}d / ${x.pingpong}`);
    }
    blocks.push({ type: 'section', text: { type: 'mrkdwn', text: lines.join('\n') } });
  }

  return { blocks };
}

const r = build();
if (MODE === 'text') process.stdout.write(renderText(r) + '\n');
else if (MODE === 'mrkdwn') process.stdout.write(renderMrkdwn(r) + '\n');
else process.stdout.write(JSON.stringify(renderBlocks(r), null, 2) + '\n');
