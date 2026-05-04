# /oh-my-workboard:wait

Add a `@wait(reason)` tag to a matched leaf and drop `@today`.

## Execution

1. Read `~/.claude/workboard.json`. Halt if missing.
2. Capture cwd context (project hint).
3. `cd` to `path`. Read `people/{id}.md`.
4. Match the `@today` leaf (same algorithm as `/done`); if 0 / 2+, ask.
5. Ask the user for the wait **reason**. The reason must NOT be a `user:` form — that's a teammate dependency, which goes to `/oh-my-workboard:request` instead.
6. Update the leaf: append `@wait(reason)`, drop `@today`.
7. Show diff, commit `[me] {name}: wait {leaf-summary}`, push, `cd` back.

## Notes

- Reasons are free text: external dependency, regulator, vendor, self-precondition.
- Lint R2 will reject `@wait(user: action)` — for that, use `/oh-my-workboard:request`.
