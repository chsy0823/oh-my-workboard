# /oh-my-workboard:sync-team

Re-render derived files from `.workboard/team.yaml`. Run after editing team membership (adding / removing / flipping `active`).

## Execution

1. Resolve workboard config: prefer `<project-root>/.workboard.json` (project-root = `git rev-parse --show-toplevel`), fall back to `~/.claude/workboard.json`. Halt if neither exists.
2. `cd` to `path`. Read `.workboard/team.yaml`.
3. Re-render:
   - `CLAUDE.md` team table block (between `<!-- BEGIN:TEAM_TABLE -->` and `<!-- END:TEAM_TABLE -->`).
   - `.github/workflows/slack-notify.yml` `env:` block: one `SLACK_ID_{id}: {slack_id}` per active member with a slack_id.
   - `.github/workflows/daily-report.yml` `env:` block (same).
   - `scripts/daily-report.js` `SLACK_ID_FALLBACK` constant.
   - For each active member without a `people/{id}.md`, create one from `templates/people/_member.md` (substitute `{id}` and `{role}`).
4. For each member flipped to `active: false`:
   - Ask the user: "archive `people/{id}.md`? [y/N]"
   - On confirm: `git mv people/{id}.md log/archive-{id}.md` (preserves history without deleting).
5. Show diff. Commit `[project] sync-team: {summary}`, push.
6. `cd` back to original cwd.

## Notes

- This command is leader-only on `main` (pre-push hook will reject non-leaders).
- `team.yaml` keywords drive `git config user.name` resolution — keep them broad enough to cover real users.
