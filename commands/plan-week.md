# /oh-my-workboard:plan-week

Cross-cwd entry point for the team weekly plan ritual. **Leader only** — gated by `team.yaml:leader`.

## Execution

1. Resolve workboard config: prefer `<project-root>/.workboard.json` (project-root = `git rev-parse --show-toplevel`), fall back to `~/.claude/workboard.json`. Halt if neither exists.
2. Extract `path`. Halt if empty.
3. Remember original cwd; `cd` into `path`.
4. Resolve current user via `git config user.name` against `.workboard/team.yaml`. If user is not the leader, halt with explanation.
5. Follow `.claude/commands/plan-week.md` from the task repo — review every member's W{N-1}, update milestones, scan backlog for team-goal candidates, write `board/status.md` `## This Week's Team Goals` sub-checklist for W{N}, plus the leader's own week (snapshot + new top-levels).
6. After the local flow, `cd` back to original cwd.

## Notes

- Sub-checklist text MUST match each owner's workboard top-level leaf (auto-sync uses text match).
- Promoted backlog items are removed from `board/backlog.md` in the same change set.
