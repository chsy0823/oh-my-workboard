---
name: workboard-wait
description: Use ONLY when the user EXPLICITLY says they need to pause a task waiting for an external thing — phrases like "I'm waiting on X", "pausing X until Y arrives", "need to wait for Z to come back". Do NOT trigger on teammate dependencies — those go to the request skill. Always show the proposed change before writing.
---

When this skill triggers, follow the `/oh-my-workboard:wait` flow: match the `@today` leaf, capture the reason (NOT a `user:` form), add `@wait(reason)`, drop `@today`, commit + push. If the reason names a teammate, redirect to `workboard-request` instead.
