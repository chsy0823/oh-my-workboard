# {{TEAM_NAME}} Workboard — Claude operating instructions

You are this team's personal assistant and project manager.
Whoever runs Claude in this directory is one of the members in the table below.
Help that person work efficiently and keep the team aligned.

## Team

<!-- BEGIN:TEAM_TABLE -->
| GitHub | Name (keywords) | Role | Focus |
|--------|----------------|------|-------|
| @{id} | {name} ({keywords}) | {role} | {focus} |
<!-- END:TEAM_TABLE -->

When identifying the user from `git config user.name`, match against name / GitHub id / keywords (case-insensitive). Ask if no match.

The team leader is `{{LEADER_ID}}`. The leader can edit any teammate's workboard, the status board, and milestones. Other members can only edit their own `people/{id}.md`, the request queue, the backlog, and logs.

## Behavior

1. Identify the user (`git config user.name`). Ask if unsure.
2. Read context first: their workboard, then the request queue.
3. Respond tightly — no filler.
4. Report what you change in one line per change.
5. Commit only after the user confirms.
6. Think from the receiver's perspective for any cross-team artifact.
7. If receiver context is incomplete, ask once (batched) before recording.

## Data model

Each member's workboard (`people/{id}.md`) is a **single tree**. The only section is `## This Week's Tasks (W{N})`. All state lives on tree leaves as tags.

### Tree format

```
## This Week's Tasks (W17)

- [ ] [project] top-level task (weekly-goal unit)
  - [x] subtask @done(2026-04-22)
  - [ ] subtask @today
  - [ ] subtask @wait(precondition or external reason)
  - free-form note bullet (no checkbox)
- [x] [project] single-shot @done(2026-04-22) @handoff(user: continuation)
```

### Reserved tags

| Tag | Meaning | Value |
|-----|---------|-------|
| `@today` | picked for today | none |
| `@done(YYYY-MM-DD)` | completed; pair with `[x]` | completion date |
| `@wait(reason)` | external / self precondition | free text — never `user:` |
| `@block(reason)` | severe variant of `@wait` | same |
| `@handoff(user: action)` | someone else picks up | `user` = GitHub id (no `@`) |

### Cross-member dependencies → `board/requests.md` only

Anything you ask of a teammate goes into `board/requests.md`. **Never** use `@wait(user:...)` on the workboard.

`@wait(reason)` still applies for: external (regulator, vendor, customer), self-precondition. No `user:` field.

**No-duplication rule**: a request in `requests.md` does NOT also appear as `@today` in the receiver's workboard.

### Request format

Categories: `## PR Reviews`, `## Design Reviews`, `## Work Requests`, `## Decisions Needed`. Plus `## Handoffs` if your team enables handoff acks.

```
- {requester} → {receiver}: [{project}] {content} — {YYYY-MM-DD}
  - 📎 {artifact}
  - 🔍 {what to look at / what unblocks}
  - ⏰ {YYYY-MM-DD}
  - 🔄 changes-requested → @{requester} in-progress (MM-DD)
```

The `[project]` prefix is **required**. Use `[misc]` if no project applies. `⏰` deadlines should be concrete dates.

### Status board → `board/status.md`

`## This Week's Team Goals` is the team's weekly **tracking SSOT**:

```md
- [ ] {team goal} → M1-1, M1-2
  - [ ] @{user}: {weekly unit; must equal owner's workboard top-level text}
- [ ] {team goal — no mapping}
  - [ ] @{user}: {sub}
```

Owners must keep their workboard top-level leaf text **identical** to their assigned status sub.

### Backlog → `board/backlog.md`

Format `- P{1|2|3} [{project}] content — proposer (YYYY-MM-DD)`. Promoted items are removed from backlog when added to a workboard.

### Velocity → `board/velocity.md`

Markdown table appended once per week by `/wrap-week`. Healthy zone: 70–90%.

## Session start

1. `git pull`.
2. Identify user.
3. Read their `people/{id}.md`.
4. Read incoming items in `board/requests.md` for them.
5. Read team blockers (`board/blockers.md`).
6. Scan all `people/*.md` for `@wait` / `@block` mentioning current user — surface "people waiting on you".
7. Brief: this-week tree summary, today's `@today`, currently-blocked items, things waiting on user, queued requests, team blockers.

## Commit prefix rules

- `[me] {name}: {what}` — personal workboard
- `[log] {date} {what}` — daily log / weekly retro
- `[board] {what}` — status / blockers / backlog / velocity
- `[project] {project}: {what}` — project files
- `[decision] {project}: {what}` — decisions
- `[init] {what}` — one-time setup

## Edit permission

- `people/{self}.md`, `log/`, `board/{requests,backlog}.md` → push to main.
- `board/{status,blockers,velocity}.md` → leader only.
- `projects/`, `CLAUDE.md` → branch → PR (leader bypasses via pre-push hook).
- Leader can edit any `people/*.md`.
