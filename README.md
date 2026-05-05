# Oh My Workboard

A Claude Code plugin that distributes a structured team workboard — per-member task trees, request queue, blockers, weekly planning, daily Slack reports, retro velocity — all shared through a central git repo and driven from any project's `cwd` via slash commands or natural-language skills.

## What it gives you

- **One workboard repo, many project repos.** Cascading config (`<project-root>/.workboard.json` → `~/.claude/workboard.json`) lets one user point different project repos at different task repos.
- **Cross-cwd updates.** Coding in repo A and want to mark a task done? `/oh-my-workboard:done` reads the cwd's git state (PR, branch, commits) and writes an accurate completion note to the task repo without you switching contexts.
- **Skills auto-trigger from natural language.** Writing "I'm done with X", "ask Eunah for Y", "let's discuss Z" — the matching skill fires, drafts the change, asks for confirmation. No memorizing slash commands.
- **Single-channel discipline.** Cross-member dependencies live in one queue (`board/requests.md`); workboards stay personal. A workboard linter (`R1`–`R8`) enforces the contract on every edit and in CI.
- **Daily report and weekly velocity.** Cron-driven `daily-report.js` posts to Slack at 09:00; `/wrap-week` produces a retro doc and appends a row to `board/velocity.md`. `parseVelocity` + `computeVelocityTrend` give real 4-week trends.
- **Default-off opt-ins.** Session brief, uncommitted-reminder Stop hook, dashboard auto-boot — all off by default; `init` asks each.
- **No auto-commit anywhere.** Every flow shows a draft and asks "commit?". Stop reminder is a prompt, not an action.

## Install

```
/plugin marketplace add chsy0823/oh-my-workboard
/plugin install oh-my-workboard
```

## Quick start (solo)

```
/oh-my-workboard:init --solo --scope global
```

Answer the prompts (id, name, keywords, role, task-repo path, optional GitHub remote, opt-in toggles). The command writes `~/.claude/workboard.json`, creates the task repo, copies templates, and makes the initial `[init]` commit.

Then verify and start using:

```
/oh-my-workboard:doctor       # health check
/oh-my-workboard:where        # print resolved config + path
/oh-my-workboard:start-day    # pick today's @today leaves
```

## Quick start (team)

The leader runs:

```
/oh-my-workboard:init --team-init --scope local
```

(`--scope local` writes `<current-project-root>/.workboard.json` so the team's task repo is bound to that project; use `--scope global` if you want it as your default everywhere.)

Each member then clones the team's task repo and runs:

```
/oh-my-workboard:init --team-join --scope local
```

Their `git config user.name` is auto-resolved against `team.yaml` keywords; if there's no match, the leader can add a keyword and run `/oh-my-workboard:sync-team`.

## Commands

### Daily / weekly rituals
| Command | What it does |
|---------|---|
| `/oh-my-workboard:start-day` | brief, reconcile waits/ping-pongs, pick `@today` |
| `/oh-my-workboard:end-day` | walk `@today` (done/partial/missed), capture handoffs + off-plan, leader: status.md auto-sync |
| `/oh-my-workboard:start-week` | mirror status subs to own workboard, archive last week, compose new week |
| `/oh-my-workboard:plan-week` *(leader)* | review last week, write `status.md` sub-checklist for new week |
| `/oh-my-workboard:wrap-week` *(leader)* | quantitative wrap-up, retro dialog, append velocity row |

### Mid-work updates (cwd git-context aware)
| Command | What it does |
|---------|---|
| `/oh-my-workboard:request` | queue a review / work / decision / handoff request |
| `/oh-my-workboard:done` | mark a matched `@today` leaf done with PR/branch context |
| `/oh-my-workboard:note` | append a note bullet to a matched `@today` leaf |
| `/oh-my-workboard:block` | record a blocker (external `@block` / teammate request / team-wide) |
| `/oh-my-workboard:wait` | tag a leaf `@wait(reason)`, drop `@today` |
| `/oh-my-workboard:add` | add a new top-level leaf, project label auto-detected |
| `/oh-my-workboard:status` | read-only briefing |
| `/oh-my-workboard:discuss` | open a GitHub issue on the task repo for async team input |

### Maintenance
| Command | What it does |
|---------|---|
| `/oh-my-workboard:init` | interactive setup (`--scope global\|local`, `--solo / --team-init / --team-join`) |
| `/oh-my-workboard:where` | print resolved config (source: local or global) and path |
| `/oh-my-workboard:sync-team` | re-render CLAUDE.md table, workflow envs, daily-report fallback, member files from `team.yaml` |
| `/oh-my-workboard:doctor` | health check (config, hooks, skills, lint, prereqs, legacy format) |
| `/oh-my-workboard:lint` | run `scripts/lint-workboard.js` (R1–R8 invariants) |
| `/oh-my-workboard:report` | render daily report `--text` mode locally (no Slack post) |

## Skills (auto-trigger)

Each mid-work command has a matching skill that auto-fires from natural-language intent:

- `workboard-request` — "send X a review request", "ask Y for Z"
- `workboard-done` — "I just merged Y", "X is done"
- `workboard-note` — "log this", "add a note"
- `workboard-block` — "I'm blocked on X"
- `workboard-wait` — "waiting on X"
- `workboard-add` — "put this on my workboard"
- `workboard-status` — "what's on my workboard?", "brief me"
- `workboard-discuss` — "let's discuss with the team", multi-paragraph proposal/share

Skills are conservative — they only trigger on **explicit recording intent** and always show a draft + ask for confirmation before writing. Casual mentions ("I'll talk to Y later") will not fire.

## Cascading config

Two file locations, resolved in order:

1. `<project-root>/.workboard.json` (project-root = `git rev-parse --show-toplevel` of cwd; falls back to `$PWD`)
2. `~/.claude/workboard.json` (global default)

Local replaces global wholesale (no merge in v0.1). `/oh-my-workboard:where` prints which file was resolved.

Use case: personal task repo as your global default; each company's project repo carries a local `.workboard.json` that points to that company's task repo.

## Prerequisites

- **Claude Code** (this plugin runs inside it)
- **`gh` CLI** — required for `/oh-my-workboard:discuss`. macOS: `brew install gh`. Then `gh auth login`.
- **`node`** — required for `scripts/*.js` (daily report, lint, session brief).
- **`yq`** *(preferred)* — for parsing `team.yaml`. awk/grep fallback exists.
- **`jq`** *(preferred)* — for hook toggle gating. grep fallback exists.

`/oh-my-workboard:doctor` checks all of these and prints actionable install/auth instructions if any are missing.

## Slack (optional)

If your team wants daily reports posted to Slack:

1. Create a webhook on the task repo's GitHub: Settings → Secrets → `SLACK_WEBHOOK_URL`.
2. Provide each member's `slack_id` during `init`. The plugin renders the workflow `env:` blocks and `daily-report.js` `SLACK_ID_FALLBACK` from `team.yaml`.
3. The cron is set for **09:00 KST** weekdays — adjust `.github/workflows/daily-report.yml` if your team is in a different timezone.

## Workboard model

A personal workboard (`people/{id}.md`) is **a single tree**:

```
## This Week's Tasks (W17)

- [ ] [project] top-level (weekly-goal unit)
  - [x] subtask @done(2026-04-22)
  - [ ] subtask @today
  - [ ] subtask @wait(precondition or external reason)
  - free-form note bullet (no checkbox)
- [x] [project] single-shot @done(2026-04-22) @handoff(user: continuation)
```

Reserved tags: `@today`, `@done(YYYY-MM-DD)`, `@wait(reason)`, `@block(reason)`, `@handoff(user: action)`. Cross-member dependencies go to `board/requests.md` only — never `@wait(user:...)`.

Full data-model contract is in `templates/.claude/skills/workboard-model/SKILL.md` (auto-loaded inside task repos). Lint enforces invariants R1–R8 on every workboard edit.

## Repository structure

```
oh-my-workboard/
├── .claude-plugin/
│   ├── plugin.json              # plugin manifest
│   └── marketplace.json         # marketplace listing
├── commands/                    # 19 slash commands
├── skills/                      # 8 auto-trigger skills
├── hooks/
│   ├── hooks.json               # plugin-level SessionStart + Stop
│   └── dispatch.sh              # path-aware router (resolves cascading config)
└── templates/                   # ~30 files copied/rendered into each new task repo
    ├── CLAUDE.md, team.yaml, .gitignore, log/
    ├── board/, people/, projects/
    ├── .claude/{settings.json, commands/, hooks/, skills/}
    ├── .githooks/, .github/workflows/
    ├── scripts/, dashboard/lib/
```

## Status

v0.1.0 — feature-complete, in local-test phase. See [PLAN.md](./PLAN.md) for the design rationale and remaining work (P7 local tests, P8 release prep).

## License

MIT.
