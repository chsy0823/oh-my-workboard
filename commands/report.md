# /oh-my-workboard:report

Render the daily report locally for preview (no Slack post).

## Execution

1. Resolve workboard config: prefer `<project-root>/.workboard.json` (project-root = `git rev-parse --show-toplevel`), fall back to `~/.claude/workboard.json`. Halt if neither exists.
2. `cd` to `path`. Run `node scripts/daily-report.js --text`. Print the output verbatim.
3. `cd` back to original cwd.

## Notes

- This is the same content the `Daily Report` workflow posts to Slack on weekday mornings, but in plain text.
- Useful for sanity-checking the report content before relying on the Slack post, or for ad-hoc summaries.
