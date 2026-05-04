# /end-day — End the day

Reconcile today's `@today` leaves and capture off-plan work.

## Run order

1. Resolve task repo from `~/.claude/workboard.json`. `cd` there.
2. `git pull`.
3. Resolve user from `git config user.name` against `team.yaml`.
4. **Reference date**: extract `W{N} D{N}` from the latest `start-day` commit message. End-day always closes that day, even if the clock is past midnight.
5. Read `people/{id}.md`.

### Walk every `@today` leaf

For each:
- **Done**: drop `@today`, set `[x]`, add `@done({reference-date})`. Ask for completion-note based on task type:
  - planning/design → artifact link, review needed?
  - dev → PR number, special considerations
  - design/asset → upload path, what changed for others
  - review → conclusion, follow-ups
  - simple/repeating → no note
  Notes go as checkbox-less bullet beneath the leaf.
- **Partial**: drop `@today`. Ask "can today's part be split off?".
  - If yes: insert sub-leaves; today's part as `[x] @done({date})`, remainder as `[ ]`.
  - If no: keep leaf, log progress as note bullet.
- **Missed**: drop `@today`, capture reason as a note if useful.

### Auto-check parents

If every sub-leaf of a parent is `[x]`, mark parent `[x] @done({latest sub date})`.

### Handoffs

For done leaves where someone else picks up next, write **both** of these in the same edit:

1. Add `@handoff(user: action)` to the completed leaf (history record). `user` = GitHub id without `@`.
2. Add an entry to `board/requests.md` under `## Handoffs`:
   - `{me} → {target}: [{project}] {action} — {YYYY-MM-DD}`
   - Add `⏰ YYYY-MM-DD` if a deadline is known.
   - Add `🔍 ...` for any extra context the receiver needs (artifact location, where to start).

This is the single channel for handoffs. Do NOT touch the receiver's workboard — they pick it up on their `/start-day` (which mirrors the entry to their tree and removes it from the queue).

### Off-plan completed work

Ask "anything done today that wasn't in the plan?". For each:
1. Why? (a) original blocked → workaround, (b) teammate request, (c) self-judgment.
2. Add a new leaf — under the relevant project, or under `[misc]` if none. Mark `[x] @done({date})` plus any other tags. Capture the why as note bullet.

### Reconcile waits + ping-pongs

For each `@wait(reason)` and `🔄` request: ask for status. Update tags / pong state.

### Requests / blockers

- New review or work request? → `board/requests.md` (do not mirror to workboard).
- New external/self precondition? → `@wait(reason)` on the leaf (no `user:` field).
- Team-wide impact? → `board/blockers.md`.
- Resolved waits? → drop the tag.

### Leader-only: status.md sync

If user is `team.yaml:leader`, after own workboard is updated:
1. Compare `board/status.md` `## This Week's Team Goals` subs against this day's workboard `@done` entries across all `people/*.md`.
2. Text-match `@user: {text}` subs against same-user workboard top-level leaves where text is identical AND leaf is now `[x]`.
3. For each match where status sub is still `[ ]`, ask user "mark this `[x]`?". On confirm, flip it.
4. For workboard `[x]` entries with NO matching status sub: surface them. Ask whether to add a sub or leave alone.

### Wrap up

1. Show updated tree (and status.md if leader).
2. Commit `[me] {name}: end-day W{N} D{N}`. Push.
