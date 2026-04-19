# Plan — oh-my-workboard

Ported from an in-house team workboard (`prdv-tasks`) into a reusable Claude Code plugin.

## Core design

- **Task repo is separate from project repos.** The plugin stores the path to the task repo in `~/.claude/workboard.json`. Slash commands resolve the path and `cd` into the task repo before acting. This lets users run `/oh-my-workboard:start-day` from any project repo and have it operate on the shared workboard.
- **Team config lives in the task repo's `CLAUDE.md`**, not in the plugin. The plugin parses it to identify members, the team leader, and the project list.
- **Hooks are path-scoped** — `people/*.md` ownership and `main`-branch protections only fire inside the configured task repo path.
- **Solo mode = team mode with 1 member.** The only difference is whether a shared remote exists.

## User config

`~/.claude/workboard.json`:

```json
{
  "mode": "team",
  "path": "/Users/me/work/prdv-tasks",
  "remote": "chsy0823/prdv-tasks"
}
```

`mode` is `solo` or `team`. `remote` is optional; when present, commands will `git push` after committing.

## Phases

### P0 — Repo bootstrap
- `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
- Empty `commands/`, `hooks/`, `templates/`
- README + this PLAN

### P1 — Port existing 4 commands
- `start-day`, `end-day`, `plan-week`, `start-week`
- Each command:
  - Reads `~/.claude/workboard.json`, `cd`s to the task repo
  - Parses `CLAUDE.md` for team/leader/projects (no hardcoded names)

### P2 — `/oh-my-workboard:init` (central)
- Interactive setup:
  - Mode: `--solo` / `--team-init` / `--team-join`
  - Team members (GitHub id, name, keywords, role)
  - Team leader
  - Initial projects (optional)
  - Slack channel + member IDs (optional)
  - Dashboard (optional)
  - Local path for the task repo
  - GitHub remote (optional, available in both modes)
- Actions:
  - Create folder tree (`board/`, `people/`, `projects/`, `log/`)
  - Render `CLAUDE.md` from template
  - Copy `.githooks/` + `git config core.hooksPath .githooks`
  - (opt) Copy Slack workflow
  - (opt) Copy dashboard
  - Write `~/.claude/workboard.json`
  - Initial commit, (opt) push

### P3 — Hooks
- `hooks/hooks.json`:
  - `PreToolUse Edit|Write` — `people/` ownership, `main`-branch projects/CLAUDE.md guard
  - `PostToolUse Edit|Write` — reminder to commit
  - `SessionStart startup` — start dashboard (only if configured)
- All matchers gated on the configured task repo path so they don't fire in unrelated projects.

### P4 — New commands
- `/oh-my-workboard:status` — read-only summary from any cwd
- `/oh-my-workboard:where` — print configured task repo path

### P5 — Template set
- `templates/CLAUDE.md.hbs` with placeholders for team table, leader, projects
- `templates/board/{status,blockers,reviews}.md`
- `templates/people/_member.md`
- `templates/projects/_example/{overview,milestones}.md`
- `templates/.githooks/{commit-msg,pre-push}` — `pre-push` parses the `team_leader:` field from `CLAUDE.md` instead of hardcoding an email
- `templates/.github/workflows/slack-notify.yml` — Slack IDs as placeholders
- `templates/scripts/setup.sh`
- `templates/dashboard/` (optional)

### P6 — Local tests
- `claude --plugin-dir ./oh-my-workboard`
- Three empty scratch dirs: solo / team-init / team-join end-to-end
- Verify every command and hook

### P7 — README / release prep
- Install + quickstart docs per mode
- Version bump to 0.1.0 stable
- `marketplace.json` final check

## Decisions (locked)

- **Name:** `oh-my-workboard` (namespace `/oh-my-workboard:*`)
- **GitHub owner:** `chsy0823`
- **Slack + dashboard:** optional, asked during `init`
- **Team leader identification:** `team_leader: @{id}` field in CLAUDE.md, parsed by `pre-push`
- **Multi-team support:** single team in v0.1, array in a later version

## Deferred

- `P8` — migrate the existing `prdv-tasks` repo off its local `.claude/` setup to use this plugin instead (do after v0.1 ships and is validated)
