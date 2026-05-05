---
name: workboard-discuss
description: Use ONLY when the user is composing or proposing something that needs threaded async team input — phrases like "let's discuss this with the team", "I want to share this proposal", "post this as an issue for review", "open a discussion about X", or when the user is writing a multi-paragraph proposal/share that clearly reads like an issue body (architectural decision, plan for feedback, design proposal). Do NOT trigger on quick questions to Claude, code explanations, working notes (use workboard-note), blockers (use workboard-block), reviews / handoffs (use workboard-request), or short status updates. Always show the drafted issue and ask "create issue on {remote}? [y/N]" before calling `gh`.
---

When this skill triggers, follow the `/oh-my-workboard:discuss` flow exactly:

1. Resolve workboard config; verify `remote` is set; verify `gh` CLI is available.
2. Capture cwd repo name as a label candidate.
3. Ask for title, body (use the user's already-written long-form content as the body draft and offer them to edit), optional labels, optional assignees from `team.yaml`.
4. Show the issue preview; require confirmation.
5. Call `gh issue create --repo {remote} ...` and print the URL.
6. Optionally cross-link to a matched `@today` workboard leaf as a note bullet.

When the user has already written a long discussion-style block before invoking the skill, treat that block as the candidate `body` and only ask for the title + optional fields.
