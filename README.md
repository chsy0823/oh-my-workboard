# Oh My Workboard

A Claude Code plugin that packages a proven team task-board workflow — per-member workboards, reviews, blockers, dailies, and weekly planning, all shared through a central git repo.

**Status:** early development (v0.1.0). See [PLAN.md](./PLAN.md) for the roadmap.

## The idea

Teams usually work across many project repos but want a single place for "who is doing what, what's blocked, what needs review". This plugin keeps that single place in a dedicated task repo, and lets you drive it from Claude Code via slash commands — no matter which project repo you happen to be in.

## What you get (planned)

- `/oh-my-workboard:init` — bootstrap a new team or solo task repo
- `/oh-my-workboard:start-day` — today's briefing + plan
- `/oh-my-workboard:end-day` — close out the day and commit
- `/oh-my-workboard:plan-week` — weekly team planning (leader)
- `/oh-my-workboard:start-week` — member's weekly plan
- `/oh-my-workboard:status` — read-only summary from any cwd
- `/oh-my-workboard:where` — show the configured task repo path

The plugin remembers your task repo path in `~/.claude/workboard.json`, so commands work from anywhere. Hooks for `people/` ownership and `main`-branch protection fire only inside the task repo.

## Install (once v0.1.0 is tagged)

```
/plugin marketplace add chsy0823/oh-my-workboard
/plugin install oh-my-workboard@workboard
/oh-my-workboard:init
```

## Modes

- **solo** — personal workboard, optional GitHub remote for backup/sync
- **team-init** — create a new shared task repo for a team
- **team-join** — clone an existing team task repo and register it locally
