---
name: workboard-file-formats
description: Workboard file schemas — people/{id}.md, board/requests.md, board/backlog.md, board/status.md, board/velocity.md, projects/{project}/milestones.md. Reference when reading or writing board files, building new commands, or authoring weekly planning flows.
---

# Workboard File Formats

## File inventory

```
board/
  status.md         — team weekly plan + tracking SSOT (leader-edit only)
  blockers.md       — team-level blockers
  requests.md       — request queue (review / work / decision / handoff)
  backlog.md        — unified backlog (project-prefixed, prioritized)
  velocity.md       — weekly hit-rate accumulator (/wrap-week appends one row)

people/
  {id}.md           — personal workboard (single tree)

projects/
  {project}/
    overview.md     — goal, scope, timeline
    milestones.md   — milestone checklists
    streams.md      — workstream progress
    decisions/      — decision records

log/
  {YYYY-MM-DD}.md   — daily log
  w{N}.md           — weekly snapshot (whole-team shared)
  w{N}-retro.md     — weekly retro (leader, /wrap-week)
```

---

## `people/{id}.md`

```
# {id} — {role}

## This Week's Tasks (W{N})

- [ ] [project] top-level task
  - [x] subtask @done(2026-04-22)
  - [ ] subtask @today
  - [ ] subtask @wait(reason)
  - [ ] subtask @block(reason)
  - artifact: PR #N (note bullet, no checkbox)
- [x] [project] single-shot @done(2026-04-22) @handoff(user: continuation)
  - conclusion: ...
```

The weekly section is the only `##` section.

---

## `board/requests.md`

A single queue tracking cross-member requests. Ping-pong state is tracked inline.

```
## {category}
- {requester} → {receiver}: [{project}] {content} — {YYYY-MM-DD}
  - 📎 {artifact location}
  - 🔍 {what to look at / decision asked / what unblocks downstream}
  - ⏰ {YYYY-MM-DD}
  - 🔄 changes-requested → @{requester} in-progress ({MM-DD})
```

**Categories**: `PR Reviews`, `Design Reviews`, `Work Requests`, `Decisions Needed`, `Handoffs`

- `[project]` prefix required on every entry. Use `[misc]` if no project applies.
- `⏰` deadline must be its own subline (dashboard reads it for D-N calculation).
- Optional sublines (📎, 🔍, ⏰, 🔄) appear only when relevant.

Ping-pong state:
- `🔄 changes-requested → @{worker} in-progress ({date})` — ball on worker
- `🔄 awaiting-rereview ({date})` — ball back on reviewer
- Remove entry on final approval.

**`Handoffs`** category: requester completed work, receiver continues. Paired with `@handoff(user: action)` on the workboard leaf. On pickup, receiver mirrors it as a workboard top-level leaf AND removes from requests.md.

---

## `board/backlog.md`

```
# Backlog

- P1 [{project}] content — {proposer} (YYYY-MM-DD)
  - optional notes
- P2 [new] another idea — {proposer} (YYYY-MM-DD)
- P3 [misc] low priority — {proposer} (YYYY-MM-DD)
```

- Priority: `P1` / `P2` / `P3` (default `P2` if omitted).
- `[project]` prefix required: existing project name, `[new]`, or `[misc]`.

---

## `board/status.md`

Team weekly plan. **Leader-edit only.**

```
# Team Status — W{N}

## This Week's Team Goals
- [ ] {team goal 1} → M1-1, M1-2
  - [x] @{user}: {sub task}
  - [ ] @{user}: {sub task}
- [ ] {team goal 2} → M4-1
  - [ ] @{user}: {sub task}

## Per-member Focus (optional, narrative)
...

## Blockers
...

## Reviews Awaiting Leader
...
```

**Format rules:**
- Top level `- [ ] {goal}` = weekly complete/incomplete.
- `→ M{N}-{S}` = optional milestone mapping (daily report uses it as reference).
- Sub `  - [ ] @{user}: {task}` — MUST match that user's workboard top-level leaf text exactly (auto-sync uses text match).

**Tracking flow:**
1. `/plan-week` (Mon) — leader writes sub-checklist.
2. `/start-week` (each member) — mirrors `@{user}` subs as workboard top-level leaves.
3. `/end-day` (each member) — updates own workboard.
4. Leader's `/end-day` — text-matches member `@done` entries against subs, flips to `[x]`.
5. `daily-report.js` (09:00 cron) — sub `[x]` ratio + milestone average → Slack.

---

## `projects/{project}/milestones.md`

```
Project target: {date}

## M{N}. {milestone-name}
owner: {user}
deadline: {YYYY-MM}
- [x] {done item}
- [ ] {open item}
```

---

## `board/velocity.md`

Weekly hit-rate accumulator. One row appended per `/wrap-week`. Parsed by `parseVelocity` + `computeVelocityTrend(rows, 4)` for 4-week trend.

```
| Week | Planned subs | Done subs | %  | Note                  |
|------|--------------|-----------|----|------------------------|
| W17  | 12           | 9         | 75 | external dep slip ×2  |
```

- `Week` column matches `^W(\d+)$`.
- `%` is integer (with or without `%` sign; both accepted).
