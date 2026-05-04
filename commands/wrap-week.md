# /oh-my-workboard:wrap-week

Cross-cwd entry point for the weekly retrospective. **Leader only** — gated by `team.yaml:leader`.

## Execution

1. Read `~/.claude/workboard.json`. Halt if missing.
2. Extract `path`. Halt if empty.
3. Remember original cwd; `cd` into `path`.
4. Resolve current user. If not leader, halt with explanation.
5. Follow `.claude/commands/wrap-week.md` from the task repo — Step 1 quantitative wrap-up (team-plan sub %, per-user top-level %, milestone deltas, request/blocker counts, velocity trend via `parseVelocity` + `computeVelocityTrend(rows, 4)`), Step 2 retrospective dialog, Step 3 write `log/w{N}-retro.md`, Step 4 append a row to `board/velocity.md`, commit `[log] retro W{N} ({pct}%)`.
6. After the local flow, `cd` back to original cwd.

## Notes

- Run on the last working day of the week or just before next week's `/oh-my-workboard:plan-week`.
- Causes systemic, never personal blame. Target 80–90% hit-rate, not 100%.
