# /oh-my-workboard:init

Interactive setup. Creates a task repo, renders templates from collected inputs, and writes a workboard config file (global default or project-local) so the other slash commands and skills know where to operate.

## Mode and scope

The user can pass two flag axes:

- **Mode**: `--solo` / `--team-init` / `--team-join`
- **Scope**: `--scope global` (default) writes to `~/.claude/workboard.json`. `--scope local` writes to `{project-root}/.workboard.json` where project-root is `git rev-parse --show-toplevel` from the cwd where init was invoked. If the cwd is not inside a git repo, `local` falls back to `$PWD`.

Detect from the user's first message; ask if either is missing.

## Config resolution (used by every other command)

When any plugin command runs, it resolves the active workboard config in this order:

1. `<project-root>/.workboard.json` (project-root = `git rev-parse --show-toplevel` of cwd; falls back to `$PWD`)
2. `~/.claude/workboard.json` (global default)
3. None → halt with "Workboard not configured. Run `/oh-my-workboard:init` first."

Local replaces global wholesale (no merge in v0.1). To use the global default in a directory that has a local file, the user can delete the local file or run init with `--scope local` again with the desired settings.

## Branch A — `--solo` or `--team-init`

### Step 1: Collect inputs

Ask in this order, one question at a time:

1. **Team name** (used as the title in `CLAUDE.md`).
2. **Members** (start with the user themselves; for `--solo` this is the only one):
   - `id`: GitHub username (no `@`)
   - `name`: display name
   - `keywords`: aliases for `git config user.name` matching (one or more, comma-separated). Always include the id and name; add nicknames so case-insensitive substring match works.
   - `role`: free text (e.g., `Engineering Lead`)
   - `slack_id`: optional Slack member id (`U...`); leave blank to skip
   - For team mode, ask "add another member? [y/N]" and loop. For solo, skip.
3. **Leader** (only for `--team-init`): pick one of the members. Skip for `--solo`.
4. **Projects** (optional): list of project directory names to seed under `projects/`.
5. **Task repo path**: absolute local path where the repo will live (default `~/work/{team-name-lowercased-with-dashes}-tasks`).
6. **GitHub remote**: optional `owner/repo`. If supplied, the initial commit will be pushed.
7. **Slack** (optional): if the user wants Slack notifications, confirm `slack_id` is set on each member; remind them to add the `SLACK_WEBHOOK_URL` secret to the repo on GitHub before workflows can post.
8. **Daily report**: only if Slack is configured — ask "render `.github/workflows/daily-report.yml`? [Y/n]" (default yes).
9. **Opt-in toggles** (each defaults to `n`):
   - `Enable session brief on every Claude Code start? [y/N]`
   - `Enable uncommitted reminder at session end? [y/N]`
   - `Auto-boot dashboard on session start? [y/N]` (reserved; the web UI is deferred to v0.2)

Show a summary of all collected inputs and ask "proceed? [y/N]".

### Step 2: Create the task repo

1. `mkdir -p` the chosen path (refuse if it already exists and is non-empty unless the user confirms overwrite).
2. `git init` inside it.
3. Create the directory tree:
   ```
   board/  people/  projects/  log/
   .claude/{commands,hooks,skills}/
   .githooks/  .github/workflows/  scripts/  dashboard/lib/
   .workboard/
   ```

### Step 3: Render `.workboard/team.yaml`

Compose the YAML from the collected member data:

```yaml
leader: {leader-id}
members:
  - id: {id}
    name: {name}
    keywords: [{kw1}, {kw2}, ...]
    role: {role}
    slack_id: {slack_id-or-omit}
    active: true
  ...
```

### Step 4: Copy templates as-is

From `${CLAUDE_PLUGIN_ROOT}/templates/`, copy these to the task repo verbatim:

- `board/{status,blockers,requests,backlog,velocity}.md`
- `.githooks/{commit-msg,pre-push}` → set executable bits
- `.claude/settings.json`
- `.claude/hooks/{check-permissions,remind-commit,lint-workboard,uncommitted-reminder}.sh` → set executable bits
- `.claude/commands/{start-day,end-day,start-week,plan-week,wrap-week}.md` (project-local copies of the ritual flows)
- `.claude/skills/workboard-model/SKILL.md`
- `scripts/setup.sh` → executable
- `scripts/lint-workboard.js` → executable
- `scripts/session-brief.js` → executable
- `dashboard/lib/parser.js`
- `dashboard/cli.js` → executable
- `log/.gitkeep`
- `.gitignore`

### Step 5: Render templated files

For each, read the template, substitute markers, write to the task repo:

1. **`CLAUDE.md`**:
   - `{{TEAM_NAME}}` → team name
   - `{{LEADER_ID}}` → leader id
   - Replace the block between `<!-- BEGIN:TEAM_TABLE -->` and `<!-- END:TEAM_TABLE -->` with a markdown table row per active member: `| @{id} | {name} ({keywords-csv}) | {role} | {focus} |` (ask the user for `{focus}` per member or leave blank).

2. **`people/{id}.md`** per active member: read `templates/people/_member.md`, substitute `{id}`, `{role}`, `{N}` (current ISO week number).

3. **`projects/{name}/`** per project: copy `templates/projects/_example/{overview,milestones,streams}.md`, replace `_example` references with the project name.

4. **`scripts/daily-report.js`**: replace the `SLACK_ID_FALLBACK = {}` block with one entry per active member that has a `slack_id`:
   ```js
   const SLACK_ID_FALLBACK = {
     '{id1}': '{slack_id1}',
     '{id2}': '{slack_id2}',
   };
   ```

5. **`.github/workflows/slack-notify.yml`** (only if Slack opted in): replace the `{{SLACK_ID_BLOCK}}` placeholder section with `env:` entries `SLACK_ID_{id-with-dashes-as-underscores}: {slack_id}` per active member. If Slack is not opted in, do not copy this workflow.

6. **`.github/workflows/daily-report.yml`** (only if daily-report opted in): same env block as above. If not opted in, do not copy.

7. **`.github/workflows/lint-workboard.yml`**: copy as-is (no substitutions). Unconditional.

### Step 6: Initialize git hooks

```
git -C {path} config core.hooksPath .githooks
```

### Step 7: Initial commit

```
git -C {path} add -A
git -C {path} commit -m "[init] initial setup"
```

If `remote` was supplied, also:

```
git -C {path} remote add origin git@github.com:{remote}.git
git -C {path} branch -M main
git -C {path} push -u origin main
```

(If the remote is already initialized with a commit, `git pull --rebase` first.)

### Step 8: Write the workboard config file

Choose location based on `--scope`:

- **Global** (default): `~/.claude/workboard.json`
- **Local**: `<project-root>/.workboard.json` where project-root = `git rev-parse --show-toplevel` of the cwd where init was invoked (NOT the new task repo). If cwd is not inside a git repo, write to `$PWD/.workboard.json` and warn the user.

Content:

```json
{
  "mode": "{solo|team}",
  "path": "{path}",
  "remote": "{owner/repo or null}",
  "session_brief": {true|false},
  "wip_commit_prompt": {true|false},
  "auto_dashboard": {true|false}
}
```

### Step 9: Confirm

Show:
- Path of the new task repo
- Path of the workboard config file (global vs local)
- If local: remind that the config applies only when Claude is run from inside that project's git repo
- Reminder to set `SLACK_WEBHOOK_URL` GitHub secret if Slack was configured
- Suggested next command: `/oh-my-workboard:doctor` to verify setup

## Branch B — `--team-join`

### Step 1: Collect inputs

1. **GitHub remote**: `owner/repo` of the existing team's task repo.
2. **Local clone path**: default `~/work/{repo-name}`.
3. **Scope** (default `local` if cwd is inside a project repo, else `global`).
4. **Opt-in toggles** (same as Branch A Step 1 #9).

### Step 2: Clone

```
git clone git@github.com:{remote}.git {path}
```

### Step 3: Validate

- `{path}/.workboard/team.yaml` must exist. If missing, halt: "this repo doesn't look like an oh-my-workboard task repo — `.workboard/team.yaml` is missing."
- Resolve `git config user.name` against the cloned `team.yaml`. If no match, warn the user; suggest editing `git config user.name` or asking the leader to add a keyword.

### Step 4: Activate hooks

```
git -C {path} config core.hooksPath .githooks
```

### Step 5: Write the workboard config file

Same as Branch A Step 8.

### Step 6: Confirm

Show next steps: `/oh-my-workboard:doctor`, `/oh-my-workboard:start-day`.

## Errors & rollback

- If any step fails after `mkdir -p`, leave the partial state in place but tell the user where things stopped. Do **not** rm the repo automatically.
- If the config file write fails, the task repo is still usable; the user can write the config manually using the printed snippet.

## Notes

- This command and `/oh-my-workboard:where` are the only ones that touch the workboard config files. `/oh-my-workboard:sync-team` re-renders derived files inside the task repo but never edits the config.
- Re-running init in a directory that already has a local `.workboard.json` overwrites it (with confirmation).
- For complex team setups (many members, custom roles), encourage editing `.workboard/team.yaml` after init and running `/oh-my-workboard:sync-team` to re-render derived files.
