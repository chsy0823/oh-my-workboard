---
name: workboard-request
description: Use ONLY when the user EXPLICITLY asks to record a cross-member request, handoff, or assignment — phrases like "send X a review request", "ask Y to do Z", "queue this for ~", "request ~ from @user". Do NOT trigger on casual mentions like "I'll talk to Y later" or general discussion. Always show the drafted entry and ask "Add to board/requests.md? [y/N]" before writing.
---

When this skill triggers, follow the `/oh-my-workboard:request` flow exactly: capture cwd git context, ask category / receiver / content / deadline, auto-fill `[project]` from repo name + `📎` from PR URL + `🔍` from matched `@today` leaf, draft the entry, confirm with the user, then `cd` to the task repo and append + commit + push.
