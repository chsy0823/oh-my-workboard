# /oh-my-workboard:request

Record a cross-member request (review / work / decision / handoff) into the task repo's queue, auto-filling context from the current cwd's git state.

## Execution

1. Read `~/.claude/workboard.json`. Halt if missing.
2. Capture cwd git context (do NOT cd yet):
   - Repo name (basename of `git rev-parse --show-toplevel`)
   - Current branch
   - Last commit subject
   - PR if any (`gh pr view --json number,url,title 2>/dev/null`)
3. Ask the user, in order:
   - **Category**: PR Reviews / Design Reviews / Work Requests / Decisions Needed / Handoffs
   - **Receiver**: present active members from `.workboard/team.yaml` (cd briefly to read, or load from path)
   - **Content**: what's being asked
4. Auto-suggest:
   - `[project]` = repo name; if not in `projects/*/`, ask whether to use `[misc]` or a known label
   - `📎` = PR URL when category is PR Reviews and a PR exists
   - `🔍` = "If complete, I can start {matched-text} next" — when one of my `@today` leaves matches the current repo's project label
5. Ask **deadline** (`⏰ YYYY-MM-DD`). Always ask; convert vague answers ("this week") to concrete dates.
6. Show the drafted entry. Confirm with the user.
7. On confirm: `cd` to `path`, append the entry under `## {category}` in `board/requests.md`, commit `[board] request: {category} {content}`, push, `cd` back.

## Notes

- The `[project]` prefix is required (lint R1).
- Never duplicate a request as `@today` on the user's workboard (no-duplication rule).
- For Handoffs, this command is paired with `/oh-my-workboard:done` which writes both the workboard `@handoff` tag AND the requests.md entry.
