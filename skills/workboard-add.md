---
name: workboard-add
description: Use ONLY when the user EXPLICITLY asks to add a new task or item to their workboard or backlog — phrases like "add this as a task", "put X on my workboard", "add to backlog". Do NOT trigger on general project discussion. Always show the proposed entry and confirm before writing.
---

When this skill triggers, follow the `/oh-my-workboard:add` flow: auto-detect `[project]` from repo name, ask for task text, append as a new top-level leaf in this week's tree, commit + push.
