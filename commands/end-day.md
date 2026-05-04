# /oh-my-workboard:end-day

Cross-cwd entry point for the workboard's `/end-day` ritual.

## Execution

1. Resolve workboard config: prefer `<project-root>/.workboard.json` (project-root = `git rev-parse --show-toplevel`), fall back to `~/.claude/workboard.json`. If neither exists, halt with: "Workboard not configured. Run `/oh-my-workboard:init` first."
2. Extract `path`. Halt if empty.
3. Remember original cwd; `cd` into `path`.
4. Follow `.claude/commands/end-day.md` from the task repo — walk every `@today` leaf (done / partial / missed), capture handoffs (writing both `@handoff` tag AND a `## Handoffs` entry in `requests.md`), capture off-plan work, reconcile waits + ping-pongs, leader-only status.md sync.
5. After the local flow, `cd` back to original cwd.

## Notes

- The leader extension (status.md sub auto-sync) only triggers when the resolved user matches `team.yaml:leader`.
- All writes touch only the task repo.
