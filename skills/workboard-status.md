---
name: workboard-status
description: Use when the user asks for their workboard summary or briefing — phrases like "what's on my workboard?", "show my tasks", "what should I do today?", "brief my workboard", "workboard status". Do NOT trigger on generic "brief me" alone. Read-only — never writes.
---

When this skill triggers, follow the `/oh-my-workboard:status` flow: resolve task repo path from `~/.claude/workboard.json`, render the briefing (this-week tree, today's `@today`, waits, incoming requests, outgoing pending, my blockers).
