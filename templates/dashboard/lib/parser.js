const fs = require('node:fs');
const path = require('node:path');

const WEEKLY_SECTION_RE = /^This Week'?s Tasks/i;
const TEAM_GOALS_HEADER = /^This Week'?s Team Goals/i;
const PER_MEMBER_FOCUS_HEADER = /^Per-member Focus/i;

const REQUEST_CATEGORY_TYPE = (category) => {
  if (/^Work Requests?/i.test(category)) return 'work';
  if (/^Decisions? Needed/i.test(category)) return 'decision';
  if (/^Handoffs?/i.test(category)) return 'handoff';
  return 'review';
};

function parsePerson(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const fileName = path.basename(filePath, '.md');

  const headerMatch = content.match(/^# (.+?) — (.+)$/m);
  const id = headerMatch ? headerMatch[1].trim() : fileName;
  const title = headerMatch ? headerMatch[2].trim() : '';

  const sections = splitSections(content);
  const workKey = Object.keys(sections).find(k => WEEKLY_SECTION_RE.test(k));

  if (!workKey) {
    return { id, title, weekLabel: '', weeklyGoals: [], doing: [], waiting: [], blockers: [], done: [], tree: [] };
  }

  const tree = parseTree(sections[workKey]);
  const derived = deriveViews(tree);
  return { id, title, weekLabel: workKey, ...derived, tree };
}

function parseTree(text) {
  const lines = text.split('\n');
  const rootItems = [];
  const stack = [{ depth: -1, children: rootItems, notes: null }];

  for (const line of lines) {
    if (!line.trim()) continue;
    const indentMatch = line.match(/^(\s*)/);
    const depth = Math.floor(indentMatch[1].length / 2);

    const taskMatch = line.match(/^\s*- \[([ xX])\]\s*(.+?)\s*$/);
    if (taskMatch) {
      const checked = taskMatch[1] !== ' ';
      const item = parseTaskContent(taskMatch[2]);
      item.checked = checked;
      item.depth = depth;
      item.children = [];
      item.notes = [];

      while (stack.length > 1 && stack[stack.length - 1].depth >= depth) stack.pop();
      stack[stack.length - 1].children.push(item);
      stack.push(item);
      continue;
    }

    const noteMatch = line.match(/^\s*- (?!\[)(.+?)\s*$/);
    if (noteMatch) {
      for (let i = stack.length - 1; i >= 0; i--) {
        if (stack[i].depth < depth && stack[i].notes) {
          stack[i].notes.push(noteMatch[1].trim());
          break;
        }
      }
    }
  }
  return rootItems;
}

function parseTaskContent(raw) {
  const tags = {};
  let rest = raw;
  const tagPattern = /\s+@(\w+)(?:\(([^)]*)\))?$/;
  while (true) {
    const m = rest.match(tagPattern);
    if (!m) break;
    tags[m[1]] = m[2] !== undefined ? m[2] : true;
    rest = rest.slice(0, rest.length - m[0].length);
  }
  rest = rest.trim();

  let project = '';
  const projMatch = rest.match(/^\[([^\]]+)\]\s*(.*)$/);
  if (projMatch) {
    project = projMatch[1].trim();
    rest = projMatch[2];
  }
  return { text: rest.trim(), project, tags };
}

function deriveViews(tree) {
  const weeklyGoals = [];
  const doing = [];
  const waiting = [];
  const blockers = [];
  const done = [];

  for (const item of tree) {
    const reasonNote = item.notes.find(n => /^unfinished:/i.test(n));
    weeklyGoals.push({
      project: item.project || '',
      text: item.text,
      checked: item.checked,
      reason: reasonNote ? reasonNote.replace(/^unfinished:\s*/i, '') : '',
    });
  }

  function walk(items, parentProject, topAncestor) {
    for (const item of items) {
      const project = item.project || parentProject;
      const isLeaf = item.children.length === 0;
      const detail = item.notes.join(' / ');
      const parent = topAncestor ? topAncestor.text : null;

      if (item.tags.today) doing.push({ project, parent, task: item.text, detail });
      if (item.tags.wait !== undefined) {
        const reason = typeof item.tags.wait === 'string' ? item.tags.wait : '';
        const idx = reason.indexOf(':');
        const gateUser = idx >= 0 ? reason.slice(0, idx).trim() : '';
        const gateAction = idx >= 0 ? reason.slice(idx + 1).trim() : reason;
        waiting.push({ project, parent, task: item.text, detail: reason, gateUser, gateAction });
      }
      if (item.tags.block !== undefined) {
        const val = typeof item.tags.block === 'string' ? item.tags.block : '';
        const idx = val.indexOf(':');
        const target = idx >= 0
          ? `@${val.slice(0, idx).trim()}: ${val.slice(idx + 1).trim()}`
          : (val ? `@${val.trim()}` : '');
        blockers.push({ content: item.text, target });
      }
      if (item.checked && isLeaf) done.push({ project, parent, task: item.text, detail });
      if (item.children.length > 0) walk(item.children, project, topAncestor || item);
    }
  }
  walk(tree, '', null);

  return { weeklyGoals, doing, waiting, blockers, done };
}

function splitSections(content) {
  const sections = {};
  const lines = content.split('\n');
  let currentSection = null;
  let currentLines = [];

  for (const line of lines) {
    const sectionMatch = line.match(/^## (.+)$/);
    if (sectionMatch) {
      if (currentSection) sections[currentSection] = currentLines.join('\n');
      currentSection = sectionMatch[1].trim();
      currentLines = [];
    } else if (currentSection) {
      currentLines.push(line);
    }
  }
  if (currentSection) sections[currentSection] = currentLines.join('\n');
  return sections;
}

function parseMilestones(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const titleMatch = content.match(/^#\s+(.+?)\s*—\s*milestones/im);
  const title = titleMatch ? titleMatch[1].trim() : '';
  const timelineMatch = content.match(/^[^\n#]*?target:\s*(.+)$/im);
  const timeline = timelineMatch ? timelineMatch[1].trim() : '';

  const milestones = [];
  const parts = [];
  const lines = content.split('\n');
  let currentPart = null;
  let currentMilestone = null;
  let currentBody = [];

  function flushMilestone() {
    if (!currentMilestone) return;
    const body = currentBody.join('\n');
    const ownerMatch = body.match(/^owner:\s*(.+)$/m);
    const startMatch = body.match(/^start:\s*(.+)$/m);
    const deadlineMatch = body.match(/^deadline:\s*(.+)$/m);
    const checks = [];
    for (const l of body.split('\n')) {
      const cm = l.match(/^-\s*\[([ xX])\]\s*(.+)$/);
      if (cm) checks.push({ text: cm[2].trim(), checked: cm[1] !== ' ' });
    }
    const done = checks.filter(c => c.checked).length;
    const total = checks.length;
    milestones.push({
      ...currentMilestone,
      part: currentPart ? currentPart.num : '',
      partName: currentPart ? currentPart.name : '',
      owner: ownerMatch ? ownerMatch[1].trim() : '',
      start: startMatch ? startMatch[1].trim() : '',
      deadline: deadlineMatch ? deadlineMatch[1].trim() : '',
      checks, done, total,
      progress: total > 0 ? Math.round((done / total) * 100) : 0,
    });
    currentMilestone = null;
    currentBody = [];
  }

  for (const line of lines) {
    const partMatch = line.match(/^##\s+Part\s+(\S+?)\.\s*(.+?)\s*$/);
    const msMatch = line.match(/^###\s+M(\S+?)\.\s*(.+?)\s*$/);
    if (partMatch) {
      flushMilestone();
      const partName = partMatch[2].replace(/\s*★.*$/, '').trim();
      currentPart = { num: partMatch[1], name: partName };
      parts.push(currentPart);
    } else if (msMatch) {
      flushMilestone();
      currentMilestone = { num: msMatch[1], name: msMatch[2].trim() };
    } else if (currentMilestone) {
      currentBody.push(line);
    }
  }
  flushMilestone();
  return { title, timeline, milestones, parts };
}

function parseRequests(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const sections = splitSections(content);
  const requests = [];
  for (const [category, text] of Object.entries(sections)) {
    const lines = text.split('\n');
    let current = null;
    for (const line of lines) {
      const match = line.match(/^- (.+)$/);
      if (match && match[1].trim() !== '') {
        const raw = match[1].trim();
        const parsed = raw.match(/^(.+?)\s*→\s*(.+?):\s*(.+?)(?:\s*—\s*(.+))?$/);
        if (parsed) {
          let content2 = parsed[3].trim();
          let project = '';
          const projMatch = content2.match(/^\[([^\]]+)\]\s*(.+)$/);
          if (projMatch) {
            project = projMatch[1].trim();
            content2 = projMatch[2].trim();
          }
          current = {
            category,
            reqType: REQUEST_CATEGORY_TYPE(category),
            from: parsed[1].trim(),
            to: parsed[2].trim(),
            content: content2, project,
            date: parsed[4] ? parsed[4].trim() : '',
            artifact: '', focus: '', pingpong: '', deadline: '',
          };
          requests.push(current);
        }
        continue;
      }
      if (current && line.match(/^\s+-\s/)) {
        const sub = line.replace(/^\s+-\s/, '').trim();
        if (sub.startsWith('📎')) current.artifact = (current.artifact ? current.artifact + ' | ' : '') + sub.replace(/^📎\s*/, '');
        else if (sub.startsWith('🔍')) current.focus = sub.replace(/^🔍\s*/, '');
        else if (sub.startsWith('🔄')) current.pingpong = sub.replace(/^🔄\s*/, '');
        else if (sub.startsWith('⏰')) current.deadline = sub.replace(/^⏰\s*/, '');
      }
    }
  }
  return requests;
}

function parseBacklog(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const items = [];
  let current = null;
  let inBody = false;
  const itemRe = /^-\s+(?:(P[123])\s+)?\[([^\]]+)\]\s*(.+?)(?:\s*—\s*([^\s(]+)(?:\s*\(([\d-]+)\))?)?\s*$/;

  for (const raw of lines) {
    if (!inBody) {
      if (/^-\s/.test(raw)) inBody = true;
      else continue;
    }
    const m = raw.match(itemRe);
    if (m) {
      current = {
        priority: m[1] || 'P2',
        project: m[2].trim(),
        text: m[3].trim(),
        by: m[4] ? m[4].trim() : '',
        date: m[5] ? m[5].trim() : '',
        notes: [],
      };
      items.push(current);
      continue;
    }
    const noteMatch = raw.match(/^\s+-\s+(.+?)\s*$/);
    if (noteMatch && current) current.notes.push(noteMatch[1].trim());
  }
  return items;
}

function parseStreams(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const nameMatch = content.match(/^# (.+?) — workstreams?/mi);
  const name = nameMatch ? nameMatch[1].trim() : path.basename(path.dirname(filePath));
  const goalMatch = content.match(/^Goal:\s*(.+)$/mi);
  const timelineMatch = content.match(/^Timeline:\s*(.+)$/mi);
  const streams = [];
  const streamBlocks = content.split(/^## \d+\.\s*/m).slice(1);
  for (const block of streamBlocks) {
    const lines = block.split('\n');
    const streamName = lines[0].trim();
    const props = {};
    for (const line of lines.slice(1)) {
      const kv = line.match(/^(\w+):\s*(.+)$/);
      if (kv) props[kv[1].trim()] = kv[2].trim();
    }
    streams.push({
      name: streamName,
      owner: props['owner'] || '',
      status: props['status'] || '',
      progress: props['progress'] || '0%',
      remaining: props['remaining'] || '',
      dependency: props['dependency'] || 'none',
    });
  }
  return { name, goal: goalMatch ? goalMatch[1].trim() : '', timeline: timelineMatch ? timelineMatch[1].trim() : '', streams };
}

function parseTeamPlan(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const goals = [];
  let inGoals = false;
  let currentGoal = null;
  for (const line of lines) {
    if (line.startsWith('## ') && TEAM_GOALS_HEADER.test(line.slice(3))) { inGoals = true; continue; }
    if (inGoals && line.startsWith('## ')) break;
    if (!inGoals) continue;

    const topMatch = line.match(/^- (?:\[([ xX])\]\s*)?(.+?)\s*$/);
    const subMatch = line.match(/^\s+- (?:\[([ xX])\]\s*)?(.+?)\s*$/);

    if (subMatch && currentGoal) {
      const checked = subMatch[1] && subMatch[1].toLowerCase() === 'x';
      let text = subMatch[2];
      const userMatch = text.match(/^@(\S+):\s*(.+)$/);
      const owner = userMatch ? userMatch[1] : '';
      const subText = userMatch ? userMatch[2].trim() : text;
      currentGoal.subs.push({ checked: !!checked, owner, text: subText });
    } else if (topMatch && line.startsWith('- ')) {
      const checked = topMatch[1] && topMatch[1].toLowerCase() === 'x';
      let text = topMatch[2];
      let mappings = [];
      const arrowIdx = text.lastIndexOf(' → ');
      if (arrowIdx >= 0) {
        const keyPart = text.slice(arrowIdx + 3).trim();
        text = text.slice(0, arrowIdx).trim();
        mappings = keyPart.split(',').map(s => s.trim()).filter(Boolean);
      }
      currentGoal = { text, checked: !!checked, hasCheckbox: topMatch[1] !== undefined, mappings, subs: [] };
      goals.push(currentGoal);
    }
  }

  const focuses = [];
  let currentMember = null;
  let inFocuses = false;
  for (const line of lines) {
    if (line.startsWith('## ') && PER_MEMBER_FOCUS_HEADER.test(line.slice(3))) { inFocuses = true; continue; }
    if (inFocuses && /^## [^#]/.test(line)) break;
    if (inFocuses && line.startsWith('### @')) {
      const match = line.match(/^### @(\S+)\s*—\s*(.+)$/);
      if (match) { currentMember = { id: match[1], focus: match[2].trim(), items: [] }; focuses.push(currentMember); }
    } else if (inFocuses && currentMember && line.startsWith('- ')) {
      currentMember.items.push(line.replace(/^- /, '').trim());
    }
  }
  return { goals, focuses };
}

// Parse board/velocity.md.
// Row format: `| W{N} | {planned} | {done} | {pct}% | {note} |`
// Header / separator / blank rows are skipped. Malformed rows are ignored.
function parseVelocity(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const rows = [];
  for (const raw of content.split('\n')) {
    const line = raw.trim();
    if (!line.startsWith('|')) continue;
    const cells = line.split('|').map(c => c.trim()).filter(c => c.length > 0);
    if (cells.length < 4) continue;
    if (/^-+$/.test(cells[0])) continue;
    const wkMatch = cells[0].match(/^W(\d+)$/);
    if (!wkMatch) continue;
    const planned = parseInt(cells[1], 10);
    const done = parseInt(cells[2], 10);
    const pctMatch = cells[3].match(/(-?\d+)/);
    if (Number.isNaN(planned) || Number.isNaN(done) || !pctMatch) continue;
    rows.push({
      week: parseInt(wkMatch[1], 10),
      planned,
      done,
      pct: parseInt(pctMatch[1], 10),
      note: cells[4] || '',
    });
  }
  rows.sort((a, b) => a.week - b.week);
  return rows;
}

// Compute trend over the last `lookback` weeks: average pct, delta vs previous, delta vs avg.
function computeVelocityTrend(rows, lookback = 4) {
  if (!rows || rows.length === 0) {
    return { recent: [], avgPct: null, latest: null, deltaVsAvg: null, deltaVsPrev: null };
  }
  const recent = rows.slice(-lookback);
  const latest = rows[rows.length - 1];
  const avgPct = Math.round(recent.reduce((a, r) => a + r.pct, 0) / recent.length);
  const prev = rows.length >= 2 ? rows[rows.length - 2] : null;
  return {
    recent,
    avgPct,
    latest,
    deltaVsAvg: latest.pct - avgPct,
    deltaVsPrev: prev ? latest.pct - prev.pct : null,
  };
}

function computeTeamGoalProgress(teamPlan, milestones) {
  if (!teamPlan || !teamPlan.goals) return [];
  const msById = {};
  for (const ms of milestones || []) {
    for (const m of ms.milestones || []) msById[`M${m.num}`] = m;
  }
  return teamPlan.goals.map(g => {
    const total = g.subs.length;
    const done = g.subs.filter(s => s.checked).length;
    const subProgress = total > 0 ? Math.round((done / total) * 100) : null;
    const mapped = (g.mappings || []).map(k => msById[k]).filter(Boolean);
    const msAvg = mapped.length > 0
      ? Math.round(mapped.reduce((a, m) => a + (m.progress || 0), 0) / mapped.length)
      : null;
    return {
      text: g.text, checked: g.checked, hasCheckbox: g.hasCheckbox,
      mappings: g.mappings, subs: g.subs, done, total, subProgress,
      milestoneAverage: msAvg,
      mappedMilestones: mapped.map(m => ({ num: `M${m.num}`, progress: m.progress, name: m.name })),
    };
  });
}

function parseAll(rootDir) {
  const result = { people: [], projects: [], blockers: [], milestones: [], requests: [], backlog: [], teamPlan: null, velocity: [] };

  const peopleDir = path.join(rootDir, 'people');
  if (fs.existsSync(peopleDir)) {
    for (const file of fs.readdirSync(peopleDir).filter(f => f.endsWith('.md'))) {
      const person = parsePerson(path.join(peopleDir, file));
      result.people.push(person);
      for (const b of person.blockers) result.blockers.push({ ...b, from: person.id });
    }
  }

  const projectsDir = path.join(rootDir, 'projects');
  if (fs.existsSync(projectsDir)) {
    const dirs = fs.readdirSync(projectsDir).filter(d => !d.startsWith('.') && fs.statSync(path.join(projectsDir, d)).isDirectory());
    for (const dir of dirs) {
      const milestonesFile = path.join(projectsDir, dir, 'milestones.md');
      if (fs.existsSync(milestonesFile)) {
        const ms = parseMilestones(milestonesFile);
        ms.project = dir;
        result.milestones.push(ms);
      }
      const streamsFile = path.join(projectsDir, dir, 'streams.md');
      if (fs.existsSync(streamsFile)) result.projects.push(parseStreams(streamsFile));
    }
  }

  const requestsFile = path.join(rootDir, 'board', 'requests.md');
  if (fs.existsSync(requestsFile)) result.requests = parseRequests(requestsFile);

  const backlogFile = path.join(rootDir, 'board', 'backlog.md');
  if (fs.existsSync(backlogFile)) result.backlog = parseBacklog(backlogFile);

  const statusFile = path.join(rootDir, 'board', 'status.md');
  if (fs.existsSync(statusFile)) result.teamPlan = parseTeamPlan(statusFile);

  const velocityFile = path.join(rootDir, 'board', 'velocity.md');
  if (fs.existsSync(velocityFile)) result.velocity = parseVelocity(velocityFile);

  result.members = result.people.map(p => ({ id: p.id, title: p.title }));

  const teamIds = new Set(result.people.map(p => p.id));
  const edges = [];
  for (const person of result.people) {
    for (const w of person.waiting) {
      if (w.gateUser && teamIds.has(w.gateUser)) {
        edges.push({
          waiter: person.id, gatekeeper: w.gateUser, action: w.gateAction,
          unblockTask: w.task, waiterProject: w.project, waiterParent: w.parent,
        });
      }
    }
  }
  for (const p of result.people) p.blocking = edges.filter(e => e.gatekeeper === p.id);
  result.dependencies = edges;

  return result;
}

module.exports = {
  parseAll, parsePerson, parseStreams, parseMilestones,
  parseRequests, parseBacklog, parseTeamPlan, parseVelocity,
  computeTeamGoalProgress, computeVelocityTrend,
};
