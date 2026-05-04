# /oh-my-workboard:note

Append a free-form note bullet under a matched `@today` leaf.

## Execution

1. Read `~/.claude/workboard.json`. Halt if missing.
2. Capture cwd context: repo name, branch, recent commit subject (for note auto-suggestion).
3. `cd` to `path`. Read `people/{id}.md`.
4. Match an `@today` leaf to the current repo (same algorithm as `/done`). If 0 / 2+, ask.
5. Ask user: "what's the note?". Auto-suggest based on recent commit subject if relevant.
6. Append as a checkbox-less bullet beneath the matched leaf.
7. Show diff, commit `[me] {name}: note {summary}`, push, `cd` back.

## Notes

- Notes are for context that would help when reading the workboard later (artifact links, blocking decisions, partial-progress status).
- Don't use this for completion — use `/oh-my-workboard:done` instead.
