---
name: workboard-note
description: Use ONLY when the user EXPLICITLY asks to record a note or progress update on their current task — phrases like "log this", "add a note to my task", "record progress on X". Do NOT trigger on casual ramblings or generic comments. Always show the proposed note and ask "Append to {matched-leaf}? [y/N]" before writing.
---

When this skill triggers, follow the `/oh-my-workboard:note` flow: match the `@today` leaf to the current repo, capture or auto-suggest note text, append as a note bullet, commit + push.
