---
name: workboard-block
description: Use ONLY when the user EXPLICITLY says they are blocked or stuck on a task — phrases like "I'm blocked on X", "X is blocking me", "stuck waiting for Y". Do NOT trigger on speculative discussion or hypotheticals. Always show the proposed change and confirm scope (external / teammate / team-wide) before writing.
---

When this skill triggers, follow the `/oh-my-workboard:block` flow: ask scope (external → `@wait`/`@block` on leaf; teammate → delegate to request skill; team-wide → also `board/blockers.md`), apply the change, commit + push.
