---
name: workboard-model
description: Workboard data model specification — tree format, reserved tags, file formats, parsing rules, single-channel principle. Source of truth for parser.js, lint-workboard.js, and the slash commands.
---

# Workboard Data Model

This skill is the **single source of truth** for the workboard data model. Reference it whenever reading or writing workboard files, adding validation, or building new slash commands.

Operational procedures (when to ask what, how to update) live in `CLAUDE.md`. This skill covers **format and invariants only**.

## Core model

A personal workboard (`people/{id}.md`) is **a single tree**. The only section is `## This Week's Tasks (W{N})`, and every task state is expressed as a tag on a tree leaf.

Workboard files are **not human-readable prose**. They are a data store that AI and the dashboard parse to present to the user. Format precision wins over reading aesthetics.

### Tree format

```
## This Week's Tasks (W17)

- [ ] [project] top-level task (weekly-goal unit)
  - [x] subtask @done(2026-04-22)
  - [ ] subtask @today
  - [ ] subtask @wait(precondition or reason)
  - [ ] subtask @block(reason)
  - free-form note bullet (no checkbox)
- [x] [project] single-shot task @done(2026-04-22) @handoff(user: continuation)
  - artifact: PR #N
```

### Reserved tags (`@tag` or `@tag(value)`)

| Tag | Meaning | Value |
|-----|---------|-------|
| `@today` | picked for today | none |
| `@done(YYYY-MM-DD)` | completed; pair with `[x]` | completion date |
| `@wait(reason)` | external / self precondition | free text — `user:` form forbidden |
| `@block(reason)` | severe variant of `@wait` | same as `@wait` |
| `@handoff(user: action)` | someone else picks up next | `user` = GitHub id (no `@`), `action` = continuation |

- Multiple tags allowed; space-separated at end of line.
- Project label is the leading `[word]` of content. Subtasks inherit from parent (label may be omitted on subs).
- Tree depth: indent 2 spaces = 1 level.
- **Bullet without checkbox (`- text`) is a note**, not a child task.

## Single-channel principle

### Cross-member dependencies → `board/requests.md` only

Anything you ask of a teammate goes into `board/requests.md`. **Never** use `@wait(user:...)` style on the workboard.

**Why:**
- Single channel = no duplication. Dashboard never shows the same dependency twice.
- The request queue tracks ping-pong (changes-requested / awaiting-rereview / approved).
- Receivers see "my queue" in one place — full picture of "what I have to do".

**`@wait(reason)` is still used for:**
- Non-teammate externals (executive, regulator, vendor, external system)
- Self-precondition on your own earlier work
- → Free-text reason only. **Never** include a `user:` field.

### No-duplication rule (workboard ↔ requests.md)

A request in `board/requests.md` MUST NOT also appear as `@today` (or any leaf) on the receiver's workboard.

Why: the dashboard's "my work" view auto-aggregates from `requests.md`. Mirroring it on the workboard makes the same item show up twice.

```
- [ ] audit run @wait(regulator confirmation)   ← OK (external wait)
- [ ] PR #61 main merge                         ← review request in requests.md tracks this
  - merge once review responds                  ← note bullet for context only
```

**Exception — Handoffs**: a handoff is a substantial new task for the receiver, often spanning days. On pickup, the receiver mirrors it as a workboard top-level leaf AND removes it from `requests.md`.

## Parsing rules (AI / dashboard / lint)

- Task line: `^\s*- \[[ x]\] `
- Tag matching: from end of line, repeatedly match `@\w+(\([^)]*\))?` until first non-match.
- Today's work: tree-wide leaves with `@today`.
- Waits / blockers: leaves with `@wait` or `@block`.
- Team-level blockers live in `board/blockers.md`.

Reference implementation: `dashboard/lib/parser.js`. Lint rules: `scripts/lint-workboard.js`.

## Anti-patterns (formats NOT used)

Do **not** use the legacy section-per-state layout (`## In Progress`, `## Waiting`, `## Blockers`, `## Done This Week`, `## Done Last Week`). Everything is expressed via the single tree + tags + notes.

## File inventory

```
board/
  status.md         — team weekly plan + tracking SSOT (leader-edit only)
  blockers.md       — team-level blockers
  requests.md       — request queue (review / work / decision / handoff)
  backlog.md        — unified backlog (project-prefixed, prioritized)
  velocity.md       — weekly hit-rate accumulator (leader, /wrap-week appends one row).
                      Parsed by `parseVelocity` + `computeVelocityTrend(rows, 4)` for 4-week trend.

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

## File formats

### `people/{id}.md`

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

### `board/requests.md`

A single queue tracking cross-member requests (review / work / decision / handoff). Ping-pong state is shared.

```
## {category}
- {requester} → {receiver}: [{project}] {content} — {YYYY-MM-DD}
  - 📎 {artifact location}
  - 🔍 {what to look at / decision asked / what unblocks downstream}
  - ⏰ {YYYY-MM-DD}
  - 🔄 changes-requested → @{requester} in-progress ({MM-DD})
```

- **Categories**: `PR Reviews`, `Design Reviews`, `Work Requests`, `Decisions Needed`, `Handoffs`
- **`Handoffs`** = the requester completed a piece of work and another teammate continues it. Paired with the workboard leaf's `@handoff(user: action)` tag.
- **`[project]` prefix is required** — the dashboard groups by project. Use `[misc]` if no real project applies.
- Optional sub-lines (📎, 🔍, ⏰, 🔄) appear only when relevant.
- **`⏰` deadline must be its own subline** — do not bury it inside 🔍 (the dashboard reads `⏰` for D-N calculation). `MM-DD` is also accepted (current year assumed).

Ping-pong state tags:
- `🔄 changes-requested → @{worker} in-progress ({date})` — ball is on the worker
- `🔄 awaiting-rereview ({date})` — ball is back on the reviewer
- Remove the entry on final approval.

When recording a request, ensure the receiver has enough context to act:
- What to look at / produce (artifact location or concrete work)
- Decision / completion criteria (objective)
- What unblocks downstream once complete (helps receiver prioritize)
- Deadline (`⏰` — always ask; convert vague answers like "this week" into a concrete date)

### `board/backlog.md`

Unified backlog. No per-person split. Sortable by priority.

```
# Backlog

- P1 [{project}] content — {proposer} (YYYY-MM-DD)
  - optional notes
- P2 [new] another idea — {proposer} (YYYY-MM-DD)
- P3 [misc] low priority — {proposer} (YYYY-MM-DD)
```

- Priority: `P1` / `P2` / `P3`. May be omitted (defaults to `P2`).
- `[project]` prefix required — existing project name, `[new]`, or `[misc]`.

### `board/status.md`

Team weekly plan + progress tracking. **Leader-edit only.**

```
# Team Status — W{N}

## This Week's Team Goals
- [ ] {team goal 1} → M1-1, M1-2
  - [x] @{user}: {sub task}
  - [ ] @{user}: {sub task}
- [ ] {team goal 2} → M4-1
  - [ ] @{user}: {sub task}
- [ ] {team goal 3 — no mapping}
  - [ ] @{user}: {sub task}

## Per-member Focus (optional, narrative)
...

## Blockers
...

## Reviews Awaiting Leader
...
```

**Team-goal format rules:**
- Top level is `- [ ] {goal}` (weekly complete/incomplete).
- `→ M{N}-{S}, M{N}-{S}` mapping (optional). Daily report shows mapped milestone average as a *reference* alongside sub progress.
- Sub-checklist `  - [ ] @{user}: {task}` — that user's weekly unit. **Single source of truth for tracking.**
- Sub text MUST match that user's workboard top-level leaf **exactly** (auto-sync uses text match).

**Tracking flow** (leader as single owner):
1. `/plan-week` (Mon) — leader writes the sub-checklist.
2. `/start-week` (each member) — mirrors their `@{user}` subs as workboard top-level leaves.
3. Each `/end-day` (each member) — updates own workboard.
4. Leader's `/end-day` — text-matches member workboard `@done` entries against status.md subs and flips them to `[x]`.
5. `scripts/daily-report.js` (e.g. 09:00 cron weekdays) — sub `[x]` ratio + mapped-milestone average → Slack.

### `projects/{project}/milestones.md`

```
Project target: {date}

## M{N}. {milestone-name}
owner: {user}
deadline: {YYYY-MM}
- [x] {done item}
- [ ] {open item}
```

### `board/velocity.md`

Weekly hit-rate accumulator. One row appended per `/wrap-week`. Parsed for 4-week trend in the next `/wrap-week`.

```
| Week | Planned subs | Done subs | %  | Note                  |
|------|--------------|-----------|----|------------------------|
| W17  | 12           | 9         | 75 | external dep slip ×2  |
```

- `Week` column matches `^W(\d+)$`.
- `%` is integer (cell may include or omit the `%` sign; both accepted).

## Invariants (lint-validated)

`scripts/lint-workboard.js` validates the following 8 rules:

1. **R1** — every entry in `board/requests.md` has a `[project]` prefix.
2. **R2** — `people/*.md` has no `@wait(user: action)` form (cross-member dependencies must use `requests.md`).
3. **R3** — no workboard `@today` leaf duplicates a `requests.md` entry's content.
4. **R4** — every `status.md` team-plan sub matches the named owner's workboard top-level leaf text.
5. **R5** — `@today` appears only on leaves (never on a node with children).
6. **R6** — `@done` and `[x]` are consistent (`[x]` leaves should carry `@done(YYYY-MM-DD)`).
7. **R7** — only allowed tags are present (`today / done / wait / block / handoff`); unknown tags are flagged.
8. **R8** — `@done(YYYY-MM-DD)` date is parseable as a real date in valid format.

Errors block via the PostToolUse hook locally and via the CI gate in pull requests.
