# /oh-my-workboard:done

Mark an `@today` leaf done with auto-generated context from the current cwd's git state.

## Execution

1. Read `~/.claude/workboard.json`. Halt if missing.
2. Capture cwd context: repo name, branch, last 1–3 commit subjects, PR if any.
3. `cd` to `path`. Read `people/{id}.md` (resolve user via `git config user.name` + `team.yaml`).
4. Find candidate leaves: tree leaves with `@today` whose `[project]` label matches the current repo (or whose top-level ancestor's project matches).
5. Pick the leaf:
   - 1 candidate → confirm with user
   - 2+ → present list; user picks
   - 0 → ask user which leaf to mark, OR offer to add a new leaf via `/oh-my-workboard:add`
6. Generate a completion note from git context: "PR #N opened" / "merged into main" / "draft pushed to {branch}" + commit subject summary. Show to user; let them edit before confirming.
7. Update the leaf: drop `@today`, set `[x]`, append `@done({today})`, add the completion note as a checkbox-less bullet beneath.
8. If all sub-leaves are now `[x]`, mark the parent `[x] @done({latest sub date})`.
9. Ask: "anyone picking this up next?" → if yes, also write `@handoff(user: action)` AND a `## Handoffs` entry in `board/requests.md` (delegate to the same flow as `/oh-my-workboard:request`).
10. Show diff, commit `[me] {name}: done {summary}`, push.
11. `cd` back to original cwd.

## Notes

- Commit message body lists what was completed and the PR / branch context.
- The completion note should be useful when reading "what did I do that day?" later — e.g. PR URL, key decision.
