# /oh-my-workboard:lint

Run the workboard data-model linter.

## Execution

1. Read `~/.claude/workboard.json`. Halt if missing.
2. `cd` to `path`. Run `node scripts/lint-workboard.js`. Print the output verbatim.
3. `cd` back to original cwd.

## Notes

- Errors block `git push` via the `Lint Workboard` workflow.
- Locally, the same script runs on PostToolUse (when editing workboard files inside the task repo).
- Pass `--errors-only` to suppress warnings (modify the command call in this file or run the script directly).
