# /oh-my-workboard:where

Print the configured workboard location and current settings.

## Execution

1. Resolve workboard config: prefer `<project-root>/.workboard.json` (project-root = `git rev-parse --show-toplevel`), fall back to `~/.claude/workboard.json`. If neither exists, print "Workboard not configured. Run `/oh-my-workboard:init` first."
2. Print:
   - `source`: `local: {full-path-to-config}` (project-root .workboard.json) OR `global: ~/.claude/workboard.json`
   - `mode`: solo | team
   - `path`: absolute path to the task repo
   - `remote`: GitHub `owner/repo` if set, else "(none)"
   - Opt-in flags: `session_brief`, `wip_commit_prompt`, `auto_dashboard` (each true / false)
3. Run `git -C {path} status --short` and report: clean | "{N} uncommitted changes".

## Notes

- Read-only. Useful for confirming setup or sharing with another teammate.
