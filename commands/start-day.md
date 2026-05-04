# /oh-my-workboard:start-day

Cross-cwd entry point for the workboard's `/start-day` ritual. Resolves the task repo from `~/.claude/workboard.json`, switches into it, and follows the project-local flow.

## Execution

1. Read `~/.claude/workboard.json`. If missing, halt with: "Workboard not configured. Run `/oh-my-workboard:init` first."
2. Extract `path`. If empty or invalid, halt with the same guidance.
3. Remember the original cwd.
4. `cd` into `path`.
5. Read `.claude/commands/start-day.md` from the task repo and follow it as if invoked there. That file is the canonical flow — pull, brief, reconcile waits/ping-pongs, pick `@today`, validate (≥1 `@today` OR `no-start` note), commit + push.
6. After the local flow finishes, `cd` back to the original cwd.

## Notes

- All writes touch only files inside the task repo.
- If the task repo has no `.claude/commands/start-day.md`, halt and tell the user to re-run init or restore the file.
- Project-local hooks (PreToolUse / PostToolUse) fire as normal once cwd is the task repo.
