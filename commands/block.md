# /oh-my-workboard:block

Capture a blocker on a workboard leaf, choosing the right channel for the dependency type.

## Execution

1. Read `~/.claude/workboard.json`. Halt if missing.
2. Capture cwd context: repo, branch, error context the user mentioned.
3. Ask the user the **scope** of the blocker:
   - **External** (regulator, vendor, customer, external system, self-precondition) → `@wait(reason)` on the matched workboard leaf. **Never** include a `user:` field.
   - **Teammate dependency** → write to `board/requests.md` as `Work Requests` or `Decisions Needed` (delegate to `/oh-my-workboard:request`).
   - **Team-wide impact** → also append to `board/blockers.md`.
4. `cd` to `path`. Read `people/{id}.md`.
5. Match the leaf (same algorithm as `/done`); if 0 / 2+, ask.
6. Apply the chosen change:
   - External: add `@block(reason)` (or `@wait(reason)` if less severe).
   - Teammate: hand off to `/oh-my-workboard:request` flow.
   - Team-wide: write `board/blockers.md` entry as well.
7. Show diff, commit `[me] {name}: block {leaf-summary}` (or `[board] blockers: ...` for team-wide), push, `cd` back.

## Notes

- Lint R2 forbids `@wait(user:...)`. Use `requests.md` for teammate deps.
- `@block` is the high-severity variant of `@wait`. Use `@wait` for typical preconditions.
