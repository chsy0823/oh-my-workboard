# /oh-my-workboard:add

Add a new top-level leaf to the current week's workboard tree, with project label auto-detected from the cwd.

## Execution

1. Read `~/.claude/workboard.json`. Halt if missing.
2. Capture cwd: repo name → candidate `[project]` label.
3. `cd` to `path`. Read `people/{id}.md`.
4. Auto-detect project label:
   - If repo name matches a `projects/*/` directory in the task repo, use that label.
   - Else show the candidate to the user; let them confirm or pick from known labels (`misc`, `new`, plus existing projects).
5. Ask the user the **task text** (top-level summary).
6. Append to the current `## This Week's Tasks (W{N})` section as a new top-level leaf: `- [ ] [{project}] {text}`.
7. Show diff, commit `[me] {name}: add {summary}`, push, `cd` back.

## Notes

- This is for adding a new top-level work item, not a subtask. To split an existing top-level into subtasks, use `/oh-my-workboard:start-day` (which splits in place).
- Lint R7 enforces allowed tags only; this command writes no tags by default.
