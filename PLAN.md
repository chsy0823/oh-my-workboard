# Plan — oh-my-workboard

A Claude Code plugin that distributes a structured team workboard system: bootstrap + cross-cwd mid-work updates + maintenance, with auto-triggering skills paired to slash commands.

## Why this is a plugin and not a template repo

The plugin's value concentrates in three places:

1. **Bootstrap** (`/oh-my-workboard:init`) — turns a 30-minute manual setup (directory tree, team.yaml, hooks, workflows, settings.json) into a single command.
2. **Cross-cwd mid-work updates** — the user is coding in repo A; the plugin commands (and matching skills) auto-absorb the cwd's git context (PR, branch, diff, recent commits) and write accurate descriptions to the task repo, which a Claude session inside the task repo cannot do.
3. **Distribution + versioning** — `marketplace add chsy0823/oh-my-workboard` for any team; `plugin update` for centralized data-model migrations.

Daily natural-language conversation about the workboard still happens **inside the task repo** (Claude there has CLAUDE.md and the workboard tree); the plugin doesn't replace that, it extends it.

## Core design

- **Task repo separate from project repos.** `~/.claude/workboard.json` stores its path; commands/skills `cd` into it before acting and restore cwd at end.
- **Team mapping SSOT** = `.workboard/team.yaml` inside the task repo. CLAUDE.md table, Slack workflow envs, daily-report Slack mention table, and `people/{id}.md` scaffolds are all rendered from it.
- **Tracking SSOT** = `board/status.md` `## This Week's Team Goals` sub-checklist.
- **Hooks are path-scoped**. They only fire when cwd matches `workboard.path`.
- **Workboard format** = single tree with tags.
- **Solo mode = team mode with 1 member.**

## Data model

### `.workboard/team.yaml`

```yaml
leader: leader-id
members:
  - id: leader-id
    name: Leader Name
    keywords: [keyword]
    role: Team Lead
    slack_id: U000000000
    active: true
  - id: member-id
    name: Member Name
    keywords: [keyword]
    role: Member Role
    slack_id: U000000001
    active: true
```

Consumers: `check-permissions.sh`, `pre-push`, CLAUDE.md table render, `people/{id}.md` scaffolds, `slack-notify.yml` env block, `daily-report.yml` env block, `daily-report.js` SLACK_ID_FALLBACK render.

### Workboard — `people/{id}.md`

```
## This Week's Tasks (W{N})

- [ ] [project] top-level (weekly-goal unit)
  - [x] subtask @done(YYYY-MM-DD)
  - [ ] subtask @today
  - [ ] subtask @wait(reason — no user: field)
  - free-form note bullet (no checkbox)
- [x] [project] single-shot @done(YYYY-MM-DD) @handoff(user: action)
```

Reserved tags: `@today`, `@done(YYYY-MM-DD)`, `@wait(reason)`, `@block(reason)`, `@handoff(user: action)`.

### Status board — `board/status.md`

```md
## This Week's Team Goals

- [ ] {team goal} → M1-1, M1-2
  - [ ] @{user}: {weekly unit; equals user's workboard top-level text}
- [ ] {team goal — no mapping}
  - [ ] @{user}: {sub}
```

The `→ M{N}-{S}` mapping is reference-only; daily-report shows mapped-milestone average alongside sub progress.

### Request queue — `board/requests.md`

Categories: `## PR Reviews`, `## Design Reviews`, `## Work Requests`, `## Decisions Needed`, `## Handoffs` (Handoffs pending stabilization — see "Pending stabilization" below).

```
- {requester} → {receiver}: [{project}] {content} — {YYYY-MM-DD}
  - 📎 {artifact}
  - 🔍 {what to look at / what unblocks downstream}
  - ⏰ {YYYY-MM-DD}
  - 🔄 changes-requested → @{requester} in-progress (MM-DD)
```

`[project]` prefix required (use `[misc]` if none). `⏰` deadlines are concrete dates.

### Backlog — `board/backlog.md`

`- P{1|2|3} [{project}] {content} — {proposer} ({YYYY-MM-DD})`. Default priority P2.

### Velocity — `board/velocity.md`

Markdown table appended once per week by `/wrap-week`.

## User config — `~/.claude/workboard.json`

```json
{
  "mode": "team",
  "path": "/Users/me/work/team-tasks",
  "remote": "owner/team-tasks",
  "session_brief": false,
  "wip_commit_prompt": false,
  "auto_dashboard": false
}
```

`mode` ∈ {`solo`, `team`}. `remote` optional. The three boolean flags are session-intervention opt-ins, **default off**.

## Phases

### P0 — Repo bootstrap ✓
`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, README, this PLAN.

### P1 — Ritual commands (5)
- `start-day` — pick `@today`, brief, validate
- `end-day` — walk `@today`, off-plan capture, leader-only status sync
- `start-week` — mirror status subs, archive last week, compose new week
- `plan-week` — leader-only; backlog scan, status.md sub-checklist for new week
- `wrap-week` — leader-only; quantitative wrap-up + retro + velocity row

Each:
- Reads `~/.claude/workboard.json`, cd's to task repo, restores cwd at end.
- Resolves user via `git config user.name` against `team.yaml`.
- No auto-commit; always shows draft and asks before commit + push.

### P2 — `/oh-my-workboard:init`
Interactive: mode (`--solo` / `--team-init` / `--team-join`), members, leader, projects, Slack/dashboard opt-ins, task-repo path, GitHub remote.

Renders from collected data:
- `.workboard/team.yaml`
- `CLAUDE.md` (substitutes `{{TEAM_TABLE}}`, `{{LEADER_ID}}`, `{{TEAM_NAME}}`)
- `people/{id}.md` per active member
- `.github/workflows/{slack-notify,daily-report}.yml` env blocks (only if Slack)
- `scripts/daily-report.js` SLACK_ID_FALLBACK block

Copies as-is: `board/{status,blockers,requests,backlog,velocity}.md`, `.githooks/`, `.claude/{settings.json,commands/,hooks/}`, `scripts/setup.sh`, `dashboard/lib/parser.js`, `dashboard/cli.js`.

Writes `~/.claude/workboard.json`. Initial `[init]` commit + (opt) push.

`--team-join` variant: clones existing task repo, validates `.workboard/team.yaml`, writes `~/.claude/workboard.json`. No rendering.

### P3 — Hooks
- `hooks/hooks.json` declares plugin-level PreToolUse/PostToolUse hooks that gate on `cwd == workboard.path`. Inside that path, they delegate to `{task-repo}/.claude/hooks/*.sh`.
- Hook contract: `$CLAUDE_FILE_PATH` + `$CLAUDE_PROJECT_DIR` env vars (already used by the templates).
- `check-permissions.sh`: ownership (people/{self} only) + branch protection (projects/, CLAUDE.md non-leader on main); team.yaml-driven; `yq` primary, awk/grep fallback.
- `remind-commit.sh`: PostToolUse on `people/**` — prints reminder when there are uncommitted changes.
- Optional opt-in hooks (off by default; enabled via `workboard.json` flags):
  - SessionStart brief (`session_brief: true`)
  - Stop prompt for WIP commits (`wip_commit_prompt: true`)
  - SessionStart dashboard auto-boot (`auto_dashboard: true`)
- `.githooks/pre-push` reads `leader` from team.yaml for bypass.

### P4 — Mid-work commands + parallel skills

Each mid-work entry exists as **both** a slash command (explicit) and a skill (auto-trigger from natural language). Same logic; different entry points. All flows always show a draft and ask "commit?" before writing — never auto-commit.

| Command / Skill | cwd auto-absorb | User input | Writes to |
|------------------|-----------------|------------|-----------|
| `request` / `workboard-request` | category 1: PR# (`gh pr view`), branch, commit summary; category 2-4: project label from repo name; "what unblocks me" auto-drafted from current `@today` matching this repo | category, receiver, content, focus, deadline | `board/requests.md` |
| `done` / `workboard-done` | recent commits, PR#, branch, diff summary | confirm leaf match | own `people/{id}.md` (mark `[x]`, `@done`, completion note) |
| `note` / `workboard-note` | branch, recent activity | note text | matched `@today` leaf as note bullet |
| `block` / `workboard-block` | branch, error context, blocked file path | reason, scope (external / teammate / team-wide) | `@block(reason)` leaf, OR `requests.md`, OR `board/blockers.md` |
| `wait` / `workboard-wait` | matched `@today` leaf | reason | `@wait(reason)` on leaf, drop `@today` |
| `add` / `workboard-add` | project label from repo name | task text, week target | new top-level leaf in current week |
| `status` / `workboard-status` | none (read-only) | optional `--user` | terminal briefing |

Skill description rule: trigger ONLY on explicit recording intent ("send X a request", "ask Y to do Z", "I'm done with this", "I'm blocked"). Casual mentions ("I'll talk to Y later") MUST NOT trigger. Always show draft + confirm before writing.

cwd → `@today` leaf matching algorithm:
1. Auto-detect project label from repo name (or from `team.yaml` known-projects fuzzy match).
2. Find current user's `@today` leaves where project matches.
3. 1 match → auto-pick. 2+ → ask. 0 → ask the user to add `@today` first or specify which leaf.

### P5 — Maintenance commands
- `where` — print configured task-repo path, mode, remote, opt-in flag states.
- `sync-team` — re-render CLAUDE.md team table, Slack workflow envs, `daily-report.js` SLACK_ID_FALLBACK, and `people/{id}.md` scaffolds from `.workboard/team.yaml`. Archives files for members flipped to `active: false` (with confirmation).
- `doctor` — health check: hooks active? team.yaml resolves current user? Slack ID resolution? lint status? old-format detection? Prints summary.
- `lint` — runs `scripts/lint-workboard.js` against current task repo; reports invariant violations.
- `report` — locally render daily-report `--text` mode for preview without posting to Slack.

### P6 — Templates ✓ (mostly done)
Generated by `bin/install-templates.sh`:
- `CLAUDE.md` (with render markers)
- `team.yaml`, `.gitignore`, `log/.gitkeep`
- `board/{status,blockers,requests,backlog,velocity}.md`
- `people/_member.md`
- `projects/_example/{overview,milestones,streams}.md`
- `.claude/commands/{start-day,end-day,start-week,plan-week,wrap-week}.md` (project-local copies)
- `.claude/hooks/{check-permissions,remind-commit}.sh` (env-var contract)
- `.claude/settings.json`
- `.githooks/{commit-msg,pre-push}` (team.yaml-driven leader bypass)
- `.github/workflows/{slack-notify,daily-report}.yml` (with `{{SLACK_ID_BLOCK}}` markers)
- `scripts/{setup.sh,daily-report.js}`
- `dashboard/lib/parser.js`, `dashboard/cli.js`

**To port** (see "Port from validated implementation" below):
- `skills/workboard-model/SKILL.md` (data-model spec lifted out of CLAUDE.md)
- `scripts/lint-workboard.js` + `.claude/hooks/lint-workboard.sh` + `.github/workflows/lint-workboard.yml`
- Handoffs category in `board/requests.md` + parser branch + command flow updates
- `parseVelocity()` + `computeVelocityTrend()` in `dashboard/lib/parser.js`
- (opt-in, toggle-gated) `scripts/session-brief.js` + `.claude/hooks/uncommitted-reminder.sh`

**Deferred to v0.2**:
- `dashboard/server.js`, `dashboard/public/index.html` (web UI)

### P7 — Local tests
- `claude --plugin-dir ./oh-my-workboard`
- Three scratch dirs: solo / team-init / team-join end-to-end
- All ritual commands fire correctly cross-cwd
- All mid-work commands auto-absorb cwd git context
- Skills auto-trigger correctly from natural-language utterances; no false positives on casual mentions
- Hooks fire only inside task repo
- Add 6th member via team.yaml + `/sync-team` — CLAUDE.md, workflows, `people/` all update
- Flip member to `active: false` — sync-team archives without losing history
- `/report` produces valid Slack-blocks JSON
- Force-trigger daily-report.yml via `workflow_dispatch`

### P8 — README / release prep
- Install + quickstart per mode
- Daily-report setup (Slack webhook secret, runner notes)
- Slash command vs skill usage examples
- Version bump to 0.1.0
- `marketplace.json` final check

## Port from validated implementation

These features are validated in real use and ready to port. Recommended order: **workboard-model skill → lint → Handoffs → velocity → toggle-gated session brief / stop reminder**. Items 2–5 build on items 1 and the existing P5 templates.

### 1. `skills/workboard-model` (foundation)

Move the data-model spec out of CLAUDE.md into a dedicated skill, so CLAUDE.md becomes a behavior doc and the model spec is loaded only when relevant.

Source: `.claude/skills/prdv-workboard-model/SKILL.md` (251L) + `.gitignore` allow-list `!.claude/skills/`.

Plugin adaptations:
- Rename: `prdv-workboard-model` → `workboard-model`
- Translate the entire SKILL.md to English: frontmatter (`name`, `description`), lint R1–R8 table, single-channel rule, tree format, reserved tags table, file format sections
- Replace hardcoded example values (`sarcofit`, `chsy0823`, etc.) with generic placeholders (`{project}`, `{user}`)
- CLAUDE.md template shrinks (~700L → ~320L pattern from prdv); data-model section becomes a pointer to the skill
- Plugin's `templates/.gitignore` allow-list adds `!.claude/skills/`

### 2. Lint (`scripts/lint-workboard.js` + hook + CI)

Workboard invariant validator implementing R1–R8 from the model.

Source files:
- `scripts/lint-workboard.js` (180L, R1–R8 rules)
- `.claude/hooks/lint-workboard.sh` (PostToolUse wrapper)
- `.github/workflows/lint-workboard.yml` (CI gate)
- `.claude/settings.json` PostToolUse registration

Plugin adaptations:
- Translate all Korean comments and finding messages to English (e.g. `@today 가 leaf 가 아닌 노드에 붙음` → `@today must only be on leaves`)
- `KNOWN_PROJECT_LABELS` already auto-collected from `data.milestones[].project` — keep
- `ALLOWED_TAGS` matches the workboard model — keep as-is

### 3. Handoffs category in `requests.md`

Adds a fifth category for cross-member handoff acknowledgment, replacing the workboard-only `@handoff` flow with single-channel tracking.

Source files:
- `templates/board/requests.md` — add `## Handoffs` empty section + preamble entry
- `templates/dashboard/lib/parser.js` — `reqTypeOf` `'handoff'` branch (already in plugin's parser; verify)
- `templates/dashboard/public/index.html` — incoming/outgoing badge `'handoff'` case (deferred to v0.2 with dashboard UI)
- `templates/.claude/commands/end-day.md` — handoff-send flow (writes both `@handoff` tag and a Handoffs entry)
- `templates/.claude/commands/start-day.md` — handoff-pickup is the documented exception to the no-duplication rule (mirror allowed)
- `templates/CLAUDE.md` — Handoffs category one-liner

Plugin adaptations:
- Category name `Handoffs` (English, no i18n)
- Badge labels: `Handoff in`, `Handoff out`
- All flow docs translated to English

### 4. Velocity machine-readable

Make `board/velocity.md` parseable so `/wrap-week` renders real 4-week trends.

Source files:
- `dashboard/lib/parser.js` — `parseVelocity()` and `computeVelocityTrend()` functions, `parseAll().velocity` field (already partially in plugin's parser; finalize)
- `templates/.claude/commands/wrap-week.md` Step 1 #6 (real trend instead of placeholder)
- `templates/board/velocity.md` header

Plugin adaptations:
- Parser comments and function docstrings → English
- Velocity table headers `Week / Planned subs / Done subs / % / Note` (already English)
- `^W(\d+)$` regex unchanged
- Wrap-week trend message → English

### 5. SessionStart brief + Stop reminder (toggle-gated, opt-in)

Source files:
- `scripts/session-brief.js` (170L) — per-user briefing renderer
- `.claude/hooks/uncommitted-reminder.sh` — Stop hook prompt
- `.claude/settings.json` SessionStart command extension + Stop hook entry

Plugin adaptations (must satisfy memories: default-off + no-auto-commit):
- Both hooks read `~/.claude/workboard.json` flags before running:
  ```bash
  if [ "$(jq -r .session_brief ~/.claude/workboard.json)" = "true" ]; then
    node scripts/session-brief.js
  fi
  ```
- `init` interactively asks each toggle (default `n`):
  - `Enable session brief on every Claude Code start? [y/N]`
  - `Enable uncommitted reminder at session end? [y/N]`
- `session-brief.js` `TEAM_KEYWORDS` hardcode → load from `.workboard/team.yaml`
- Stop hook is **prompt only** — never invokes `git commit` automatically. Output: "Uncommitted changes in `people/{id}.md`. Commit now? [y/N]" — user types the commit if desired
- All output strings English: `📋 {user} — W{N} D{day}`, "This week", "Today", "Waiting on me", "Incoming requests", "Outgoing requests", "My blockers"

## Decisions (locked)

- **Name:** `oh-my-workboard` (namespace `/oh-my-workboard:*`, plugin-namespaced skills `workboard-*`)
- **GitHub owner:** `chsy0823`
- **Marketplace name:** `workboard`
- **Language:** all shipped artifacts in **English**.
- **Cross-cwd value driver:** mid-work commands auto-absorb cwd git context to write accurate task-repo descriptions.
- **Skills + slash duality:** every mid-work entry has both. Skills must be conservative (explicit recording intent only).
- **No auto-commit anywhere.** Always draft + confirm.
- **Default off, opt-in.** Session-intervention features (`session_brief`, `wip_commit_prompt`, `auto_dashboard`) are off by default; init asks explicitly.
- **Team mapping SSOT** = `.workboard/team.yaml` inside the task repo.
- **Tracking SSOT** = `board/status.md` `## This Week's Team Goals` sub-checklist.
- **Workboard-model spec lives in a skill** (`skills/workboard-model/SKILL.md`), not inline in CLAUDE.md. CLAUDE.md is behavior; the skill is the data-model contract.
- **Hook contract** = `$CLAUDE_FILE_PATH` + `$CLAUDE_PROJECT_DIR` env vars.
- **Parser** = `yq` primary, `awk`/`grep` fallback. No hard yq dependency in v0.1.
- **Cross-member dependencies** = `board/requests.md` only. No `@wait(user:...)` on workboards.
- **Dashboard parser is core**: `dashboard/lib/parser.js` ships even when dashboard UI is opted out (daily-report needs it).
- **Multi-team support**: single team in v0.1, array of contexts later.

## Deferred

- Web dashboard (`dashboard/server.js`, `dashboard/public/index.html`) — v0.2.
- Multi-team context switching (`/oh-my-workboard:switch {name}`) — v0.3.
- Dashboard as its own separately-versioned plugin — v0.3.
- Daily-report scheduling without GitHub Actions (local cron / launchd recipe) — v0.2.
