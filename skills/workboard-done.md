---
name: workboard-done
description: Use ONLY when the user EXPLICITLY says they finished a piece of work — phrases like "I'm done with X", "I just merged Y", "X is complete", "shipped Y". Do NOT trigger on speculation ("if I finish this") or general status mentions. Always show the workboard diff and ask "Mark @today done? [y/N]" before writing.
---

When this skill triggers, follow the `/oh-my-workboard:done` flow exactly: capture cwd git context (PR, branch, commits), match the user's `@today` leaf to the current repo, generate a completion note, ask about handoff, then `cd` to the task repo and update + commit + push.
