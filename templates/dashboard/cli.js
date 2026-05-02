#!/usr/bin/env node
/**
 * CLI briefing — read-only terminal view of the workboard.
 * Usage: node dashboard/cli.js [--user <id>]
 */

const path = require('node:path');
const { parseAll } = require('./lib/parser');

const ROOT = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const userIdx = args.indexOf('--user');
const FILTER_USER = userIdx >= 0 ? args[userIdx + 1] : null;

const C = {
  reset: '\x1b[0m', bold: '\x1b[1m', dim: '\x1b[2m',
  red: '\x1b[31m', green: '\x1b[32m', yellow: '\x1b[33m',
  blue: '\x1b[34m', magenta: '\x1b[35m', cyan: '\x1b[36m',
};

function header(label) {
  console.log('');
  console.log(`${C.bold}${C.cyan}── ${label} ──${C.reset}`);
}

function progressBar(pct, width = 20) {
  const filled = Math.round((pct / 100) * width);
  return `[${C.green}${'█'.repeat(filled)}${C.dim}${'░'.repeat(width - filled)}${C.reset}]`;
}

const data = parseAll(ROOT);

console.log(`${C.bold}Workboard${C.reset}  ${C.dim}${new Date().toISOString().slice(0, 10)}${C.reset}`);

header('Team progress (top-level)');
const persons = data.people.filter(p => !FILTER_USER || p.id === FILTER_USER);
let teamDone = 0, teamTotal = 0;
for (const p of persons) {
  const total = p.tree.length;
  const done = p.tree.filter(t => t.checked).length;
  teamDone += done; teamTotal += total;
  const pct = total > 0 ? Math.round((done / total) * 100) : 0;
  console.log(`  @${p.id.padEnd(20)} ${progressBar(pct)} ${String(pct).padStart(3)}%  (${done}/${total})`);
}
if (!FILTER_USER) {
  const teamPct = teamTotal > 0 ? Math.round((teamDone / teamTotal) * 100) : 0;
  console.log(`  ${C.bold}team total           ${progressBar(teamPct)} ${String(teamPct).padStart(3)}%  (${teamDone}/${teamTotal})${C.reset}`);
}

for (const p of persons) {
  if (p.tree.length === 0) continue;
  header(`@${p.id}${p.title ? ` — ${p.title}` : ''}`);
  for (const item of p.tree) {
    const mark = item.checked ? `${C.green}[x]${C.reset}` : `${C.dim}[ ]${C.reset}`;
    const proj = item.project ? `${C.yellow}[${item.project}]${C.reset} ` : '';
    const tagBits = Object.keys(item.tags).map(t => {
      const v = item.tags[t];
      return `${C.magenta}@${t}${v && v !== true ? `(${v})` : ''}${C.reset}`;
    });
    console.log(`  ${mark} ${proj}${item.text} ${tagBits.join(' ')}`);
    for (const child of item.children) {
      const cmark = child.checked ? `${C.green}[x]${C.reset}` : `${C.dim}[ ]${C.reset}`;
      const cTags = Object.keys(child.tags).map(t => {
        const v = child.tags[t];
        return `${C.magenta}@${t}${v && v !== true ? `(${v})` : ''}${C.reset}`;
      });
      console.log(`    ${cmark} ${child.text} ${cTags.join(' ')}`);
    }
  }
}

const incoming = FILTER_USER ? data.requests.filter(r => r.to === FILTER_USER) : data.requests;
if (incoming.length > 0) {
  header('Request queue' + (FILTER_USER ? ` (incoming for @${FILTER_USER})` : ''));
  for (const r of incoming) {
    const ping = r.pingpong ? ` ${C.yellow}🔄 ${r.pingpong}${C.reset}` : '';
    const dl = r.deadline ? ` ${C.red}⏰ ${r.deadline}${C.reset}` : '';
    console.log(`  ${C.dim}[${r.category}]${C.reset} @${r.from} → @${r.to}: ${r.project ? `[${r.project}] ` : ''}${r.content}${ping}${dl}`);
  }
}

if (data.blockers.length > 0) {
  header('Blockers');
  for (const b of data.blockers) {
    console.log(`  ${C.red}!${C.reset} @${b.from} — ${b.content}${b.target ? ` → ${b.target}` : ''}`);
  }
}

console.log('');
