# /oh-my-workboard:start-week

Cross-cwd entry point for personal weekly setup (members). Run after the leader has run `/oh-my-workboard:plan-week`.

## Execution

1. Resolve workboard config: prefer `<project-root>/.workboard.json` (project-root = `git rev-parse --show-toplevel`), fall back to `~/.claude/workboard.json`. Halt if neither exists.
2. Extract `path`. Halt if empty.
3. Remember original cwd; `cd` into `path`.
4. Follow `.claude/commands/start-week.md` from the task repo — review last week, archive its tree to `log/w{N-1}.md`, mirror `status.md` `@{user}` subs to own workboard top-level (verbatim), add self-driven items, scan `backlog.md` for promotion candidates (and remove promoted items from backlog).
5. After the local flow, `cd` back to original cwd.

## Notes

- Aim for 2–5 top-level leaves total. Leave subtask splitting to `/start-day`.
