# /oh-my-workboard:where

Print the configured workboard location and current settings.

## Execution

1. Read `~/.claude/workboard.json`. If missing, print "Workboard not configured. Run `/oh-my-workboard:init` first."
2. Print:
   - `mode`: solo | team
   - `path`: absolute path to the task repo
   - `remote`: GitHub `owner/repo` if set, else "(none)"
   - Opt-in flags: `session_brief`, `wip_commit_prompt`, `auto_dashboard` (each true / false)
3. Run `git -C {path} status --short` and report: clean | "{N} uncommitted changes".

## Notes

- Read-only. Useful for confirming setup or sharing with another teammate.
