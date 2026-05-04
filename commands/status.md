# /oh-my-workboard:status

Read-only workboard briefing for the current user. No writes.

## Execution

1. Resolve workboard config: prefer `<project-root>/.workboard.json` (project-root = `git rev-parse --show-toplevel`), fall back to `~/.claude/workboard.json`. Halt if neither exists.
2. `cd` to `path`. Resolve current user.
3. Render the same content as `node scripts/session-brief.js --user {id}` (regardless of the `session_brief` toggle — this command is explicit).
4. `cd` back to original cwd.

## Notes

- Useful from any cwd to peek at the workboard without committing to a full ritual command.
- For the auto-fired version on session start, see the `session_brief` flag in `~/.claude/workboard.json`.
