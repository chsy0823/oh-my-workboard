---
name: workboard-status
description: Use when the user asks for their workboard summary or briefing — phrases like "what's on my workboard?", "show my tasks", "what should I do today?", "brief me", "workboard status". Read-only — never writes.
---

When this skill triggers, follow the `/oh-my-workboard:status` flow: resolve task repo path from `~/.claude/workboard.json`, render the briefing (this-week tree, today's `@today`, waits, incoming requests, outgoing pending, my blockers).
