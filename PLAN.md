# Plan — oh-my-workboard

A Claude Code plugin that distributes a structured team workboard system: bootstrap + cross-cwd mid-work updates + maintenance, with auto-triggering skills paired to slash commands.

## Why this is a plugin and not a template repo

The plugin's value concentrates in four places:

1. **Bootstrap** (`/oh-my-workboard:init`) — turns a 30-minute manual setup (directory tree, team.yaml, hooks, workflows, settings.json) into a single command.
2. **Cross-cwd mid-work updates** — the user is coding in repo A; the plugin commands (and matching skills) auto-absorb the cwd's git context (PR, branch, diff, recent commits) and write accurate descriptions to the task repo, which a Claude session inside the task repo cannot do.
3. **Multi-workspace via cascading config** — `<project-root>/.workboard.json` overrides the global default, so one user can run different task repos from different project repos (e.g., personal tasks globally, work tasks locally per company repo).
4. **Distribution + versioning** — `marketplace add chsy0823/oh-my-workboard` for any team; `plugin update` for centralized data-model migrations.

Daily natural-language conversation about the workboard still happens **inside the task repo** (Claude there has CLAUDE.md and the workboard tree); the plugin doesn't replace that, it extends it.

## Core design

- **Task repo separate from project repos.** Cascading config (local `<project-root>/.workboard.json` → global `~/.claude/workboard.json`) stores the task-repo path; commands/skills `cd` into it before acting and restore cwd at end. Different project repos can point to different task repos.
- **Team mapping SSOT** = `.workboard/team.yaml` inside the task repo. CLAUDE.md table, Slack workflow envs, daily-report Slack mention table, and `people/{id}.md` scaffolds are all rendered from it.
- **Tracking SSOT** = `board/status.md` `## This Week's Team Goals` sub-checklist.
- **Hooks split by event type**:
  - Plugin-level (always loaded): SessionStart + Stop, dispatched only when cwd matches the resolved task-repo path.
  - Project-level (`<task-repo>/.claude/settings.json`): PreToolUse + PostToolUse, fire on file edits inside the task repo.
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

## User config — workboard.json (cascading: local → global)

Two file locations, resolved in order:

1. **Local**: `<project-root>/.workboard.json` (project-root = `git rev-parse --show-toplevel` of cwd; falls back to `$PWD`)
2. **Global**: `~/.claude/workboard.json`

If a local file exists, it **replaces** the global wholesale (no merge in v0.1). If neither exists, every command halts with "Workboard not configured. Run `/oh-my-workboard:init` first."

Both files share the same schema:

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

`/oh-my-workboard:init --scope local` writes the local file at the cwd's project root; `--scope global` (default) writes the global file. `/oh-my-workboard:where` prints which file was resolved.

## Phases

### P0 — Repo bootstrap ✓
`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, README, this PLAN.

### P1 — Ritual commands ✓
Plugin root `commands/{start-day,end-day,start-week,plan-week,wrap-week}.md`. Each is a thin wrapper that resolves the workboard config (cascading), `cd`s to the task repo, and delegates to that repo's project-local `.claude/commands/{name}.md` for the canonical flow. Leader-only commands (`plan-week`, `wrap-week`) verify against `team.yaml:leader` before delegating.

### P2 — `/oh-my-workboard:init` ✓
Interactive setup with two flag axes:
- **Mode**: `--solo` / `--team-init` / `--team-join`
- **Scope**: `--scope global` (default, writes `~/.claude/workboard.json`) / `--scope local` (writes `<project-root>/.workboard.json`)

Solo / team-init flow renders `.workboard/team.yaml`, `CLAUDE.md` (substitutes `{{TEAM_TABLE}}`, `{{LEADER_ID}}`, `{{TEAM_NAME}}`), `people/{id}.md` per active member, workflow env blocks (only if Slack), `scripts/daily-report.js` SLACK_ID_FALLBACK; copies templates as-is for `board/`, `.githooks/`, `.claude/{settings.json,commands,hooks,skills}`, `scripts/`, `dashboard/lib/`. Initial `[init]` commit + optional push. Asks each opt-in toggle (`session_brief`, `wip_commit_prompt`, `auto_dashboard`) — defaults all `n`.

`--team-join` clones an existing task repo, validates `.workboard/team.yaml`, writes the config file. No rendering.

### P3 — Hooks ✓
Split by event type to avoid double-firing:

- **Plugin level** (`hooks/hooks.json` + `hooks/dispatch.sh`): SessionStart + Stop. dispatch.sh resolves the task-repo path from the cascading config and only fires when `$PWD` matches it; routes to `<task-repo>/scripts/session-brief.js` (SessionStart) and `<task-repo>/.claude/hooks/uncommitted-reminder.sh` (Stop). Both target scripts self-gate on the `session_brief` / `wip_commit_prompt` flags (default off).
- **Project level** (`<task-repo>/.claude/settings.json`): PreToolUse + PostToolUse on `Edit|Write`. Hooks: `check-permissions.sh` (ownership + branch protection, team.yaml-driven, `yq` primary with awk/grep fallback), `lint-workboard.sh` (R1–R8 PostToolUse gate), `remind-commit.sh` (commit reminder on `people/**` edits).
- **Hook contract**: `$CLAUDE_FILE_PATH` + `$CLAUDE_PROJECT_DIR` env vars.
- `.githooks/pre-push` reads `leader` from team.yaml for bypass.

### P4 — Mid-work commands + parallel skills ✓

Each mid-work entry exists as **both** a slash command (explicit) and a skill (auto-trigger from natural language). Same flow; different entry points. All flows always show a draft and ask "commit?" before writing — never auto-commit.

| Command / Skill | cwd auto-absorb | User input | Writes to |
|------------------|-----------------|------------|-----------|
| `request` / `workboard-request` | category 1: PR# (`gh pr view`), branch, commit summary; category 2-4: project label from repo name; "what unblocks me" auto-drafted from current `@today` matching this repo | category, receiver, content, focus, deadline | `board/requests.md` |
| `done` / `workboard-done` | recent commits, PR#, branch, diff summary | confirm leaf match | own `people/{id}.md` (mark `[x]`, `@done`, completion note); optional `@handoff` + `## Handoffs` entry |
| `note` / `workboard-note` | branch, recent activity | note text | matched `@today` leaf as note bullet |
| `block` / `workboard-block` | branch, error context, blocked file path | reason, scope (external / teammate / team-wide) | `@block(reason)` leaf, OR `requests.md`, OR `board/blockers.md` |
| `wait` / `workboard-wait` | matched `@today` leaf | reason | `@wait(reason)` on leaf, drop `@today` |
| `add` / `workboard-add` | project label from repo name | task text, week target | new top-level leaf in current week |
| `status` / `workboard-status` | none (read-only) | optional `--user` | terminal briefing |

Skill description rule: trigger ONLY on explicit recording intent ("send X a request", "ask Y to do Z", "I'm done with this", "I'm blocked"). Casual mentions ("I'll talk to Y later") MUST NOT trigger.

cwd → `@today` leaf matching algorithm:
1. Auto-detect project label from repo name (or from `team.yaml` known-projects fuzzy match).
2. Find current user's `@today` leaves where project matches.
3. 1 match → auto-pick. 2+ → ask. 0 → ask the user to add `@today` first or specify which leaf.

### P5 — Maintenance commands ✓
- `where` — print resolved config source (local / global), task-repo path, mode, remote, opt-in flag states, git status of the task repo.
- `sync-team` — re-render CLAUDE.md team table, Slack workflow envs, `daily-report.js` SLACK_ID_FALLBACK, and `people/{id}.md` scaffolds from `.workboard/team.yaml`. Archives files for members flipped to `active: false` (with confirmation).
- `doctor` — health check: hooks active? team.yaml resolves current user? Slack ID resolution? lint status? legacy format detection? Prints summary.
- `lint` — runs `scripts/lint-workboard.js` against current task repo; reports invariant violations.
- `report` — locally render daily-report `--text` mode for preview without posting to Slack.

### P6 — Templates ✓
Plugin's `templates/` set, copied/rendered into each new task repo by `init`:
- `CLAUDE.md` (~90L; data model lives in the workboard-model skill, not inline)
- `team.yaml`, `.gitignore` (tracks `.claude/{settings.json,commands,hooks,skills}/`), `log/.gitkeep`
- `board/{status,blockers,requests,backlog,velocity}.md` (requests has `## Handoffs` category)
- `people/_member.md`
- `projects/_example/{overview,milestones,streams}.md`
- `.claude/commands/{start-day,end-day,start-week,plan-week,wrap-week}.md`
- `.claude/hooks/{check-permissions,remind-commit,lint-workboard,uncommitted-reminder}.sh`
- `.claude/settings.json` (PreToolUse + PostToolUse only — SessionStart/Stop are plugin-level)
- `.claude/skills/workboard-model/SKILL.md` (data-model contract: tree format, reserved tags, file formats, R1–R8 invariants)
- `.githooks/{commit-msg,pre-push}` (team.yaml-driven leader bypass)
- `.github/workflows/{slack-notify,daily-report,lint-workboard}.yml`
- `scripts/{setup.sh,daily-report.js,lint-workboard.js,session-brief.js}`
- `dashboard/lib/parser.js` (with `parseVelocity` + `computeVelocityTrend`), `dashboard/cli.js`

**Deferred to v0.2**:
- `dashboard/server.js`, `dashboard/public/index.html` (web UI)

### P7 — Local tests
- `claude --plugin-dir ./oh-my-workboard`
- Three scratch dirs: solo / team-init / team-join end-to-end (each tested with `--scope global` AND `--scope local`)
- **Cascading config**: with both global + local set, commands resolve to local; with local removed, commands fall back to global; `/where` reports the right `source` in each case
- All ritual commands fire correctly cross-cwd
- All mid-work commands auto-absorb cwd git context
- Skills auto-trigger correctly from natural-language utterances; no false positives on casual mentions
- Hooks fire only inside task repo (plugin-level SessionStart + Stop gated by dispatch.sh; project-level PreToolUse + PostToolUse fire only when Claude is in the task repo)
- Add 6th member via team.yaml + `/sync-team` — CLAUDE.md, workflows, `people/` all update
- Flip member to `active: false` — sync-team archives without losing history
- `/report` produces valid Slack-blocks JSON
- `/lint` exits non-zero on R1–R8 violations; CI workflow (`lint-workboard.yml`) blocks PRs with errors
- `/doctor` reports green on a clean install
- Force-trigger daily-report.yml via `workflow_dispatch`

### P8 — README / release prep
- Install + quickstart per mode
- Daily-report setup (Slack webhook secret, runner notes)
- Slash command vs skill usage examples
- Version bump to 0.1.0
- `marketplace.json` final check

## Ported features ✓

All five features validated upstream have been ported into the plugin's `templates/` set:

1. **`workboard-model` skill** — data-model contract lifted out of CLAUDE.md into `.claude/skills/workboard-model/SKILL.md` (English, generic placeholders).
2. **Lint** — `scripts/lint-workboard.js` (R1–R8) + `.claude/hooks/lint-workboard.sh` (PostToolUse wrapper) + `.github/workflows/lint-workboard.yml` (CI gate). `KNOWN_PROJECT_LABELS` auto-discovered from `data.milestones[].project`.
3. **Handoffs category** in `board/requests.md` — handoff sender writes both the workboard `@handoff(user: action)` tag AND a `## Handoffs` queue entry; receiver picks it up on `/start-day`, mirroring as a workboard top-level leaf and removing the queue entry.
4. **Velocity machine-readable** — `parseVelocity()` and `computeVelocityTrend(rows, 4)` in `dashboard/lib/parser.js`; `/wrap-week` renders real 4-week trends.
5. **SessionStart brief + Stop reminder** (toggle-gated) — `scripts/session-brief.js` and `.claude/hooks/uncommitted-reminder.sh`; both gated by cascading-config flags `session_brief` / `wip_commit_prompt`. Stop is prompt-only — never invokes `git commit`. session-brief loads team mapping from `.workboard/team.yaml` (no hardcoded team).

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
- **Cascading config**: local `<project-root>/.workboard.json` replaces global `~/.claude/workboard.json` wholesale (no merge in v0.1). Local resolves via `git rev-parse --show-toplevel` of cwd; falls back to `$PWD`. Lets one user point different project repos at different task repos.
- **Hook split by event type**: SessionStart + Stop are plugin-level (run from any cwd, gated to task-repo path via `dispatch.sh`); PreToolUse + PostToolUse are project-local in `<task-repo>/.claude/settings.json`. Avoids double-firing when both plugin and task repo are active.
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
