# /oh-my-workboard:discuss

Open a discussion on the task repo as a GitHub issue. Replaces ad-hoc `.md` files passed around for review with a threaded, async, notification-aware channel that your teammates already see.

## Execution

1. Resolve workboard config: prefer `<project-root>/.workboard.json` (project-root = `git rev-parse --show-toplevel`), fall back to `~/.claude/workboard.json`. Halt if neither exists.
2. Verify `remote` is set in the resolved config. Halt with: "Discussion issues need a GitHub remote on the task repo. Re-run `/oh-my-workboard:init` with a remote, or set one manually."
3. Verify `gh` CLI is installed and authenticated. If not, halt with the install/auth instructions.
4. Capture cwd git context (do NOT cd yet):
   - Repo name (basename of `git rev-parse --show-toplevel`)
   - Current branch
   - Last commit subject (for optional "context" mention only — do NOT auto-include in the issue body)
5. Ask the user, one at a time:
   - **Title**: short, scannable headline.
   - **Body**: full discussion content, markdown allowed. Encourage concrete framing — what's being decided, options A/B, constraints, deadline if any.
   - **Labels** (optional, comma-separated): auto-suggest the cwd repo name as a candidate label if it matches a known project; otherwise show known labels via `gh label list --repo {remote}` if available.
   - **Assignees** (optional, comma-separated): present active members from `.workboard/team.yaml`. The user can pick or skip.
6. Show the drafted issue preview to the user. Ask "create issue on `{remote}`? [y/N]".
7. On confirm, run:
   ```
   gh issue create --repo {remote} \
     --title "{title}" \
     --body "{body}" \
     --label "{label1},{label2}" \
     --assignee "{user1},{user2}"
   ```
   Capture the returned issue URL.
8. **Optional cross-link**: if the current cwd repo matches a project label in the user's `@today` leaves, ask "link this issue to `@today` leaf `{matched-text}`? [y/N]". On confirm: `cd` to the task repo, append a note bullet `- Discussion: {issue-url}` under the matched leaf, commit `[me] {name}: discussion link {issue-#}`, push, `cd` back.
9. Print the issue URL to the user.

## Notes

- **The issue lives in the task repo's GitHub repository**, not in the cwd's repo. All teammates with the task repo cloned see it.
- The optional cross-link step is for keeping the workboard pointing at the discussion. It's opt-in — most discussions don't need a workboard leaf entry.
- For listing or commenting on existing discussions, use `gh issue list --repo {remote}` or `gh issue view N --repo {remote}` directly. v0.1 only handles creation.
- Do NOT use this for blockers (`/oh-my-workboard:block`), reviews / handoffs (`/oh-my-workboard:request`), or quick questions (just ask the teammate). Use this when the topic genuinely needs threaded async input.
