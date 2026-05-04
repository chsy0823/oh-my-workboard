# /start-day — Start the day

Pick today's `@today` leaves from the weekly tree.

## Run order

1. Resolve task repo via `~/.claude/workboard.json`. `cd` there.
2. `git pull`.
3. `date '+%Y-%m-%d %A %u'` — capture today's date and weekday number (`%u`: 1=Mon..7=Sun = D{N}).
4. Resolve current user from `git config user.name` against `.workboard/team.yaml` (id / name / keywords). If no match, ask.
5. Read `people/{id}.md`.

### Detect missing end-day

Compare `git log --grep="start-day" -1` and `git log --grep="end-day" -1`.
If a `start-day` is not yet closed by an `end-day`, run that day's end-day first
(extract W/D from the open start-day commit), then continue with today.

### Brief

1. `## This Week's Tasks (W{N})` summary: remaining top-level leaves; `@today` and `@wait` overview.
2. Incoming `board/requests.md` items where receiver is the current user (and ball is on them — exclude `🔄 changes-requested → @other`).
3. Ping-pong status changes on requests the current user sent.
4. Team blockers from `board/blockers.md` that mention the current user.
5. Active milestones from related `projects/*/milestones.md`.

### Reconcile waits and ping-pongs

For each `@wait(reason)` leaf and each `🔄` request: ask "any movement?" and update tags / states.

### Pick today's work

1. Build candidate list from two sources:
   - Tree leaves not done and not gated by `@wait`.
   - `requests.md` items where ball is on the current user.
2. Show candidates; user picks.
3. For each pick, confirm it can finish today. If not, **split in place** into 2–5 sub-leaves; tag only today's chunk with `@today`. Parent stays `[ ]`.
4. If a `requests.md` item is picked, do **not** mirror it onto the workboard — no-duplication rule.
   - **Exception — `## Handoffs` category**: handoffs are substantial new work for the receiver, often spanning days. If the user picks a handoff:
     1. Remove the corresponding entry from `board/requests.md` `## Handoffs`.
     2. Mirror it as a top-level leaf in this week's tree: `- [ ] [{project}] {action}`.
     3. Tag that leaf (or one of its sub-leaves) with `@today`.
5. If nothing is picked, ask once more. If still nothing, write `- no-start({YYYY-MM-DD}): {reason}` under the weekly section.

### Pre-commit validation

At least ONE must hold:
- (a) at least one `@today` tag in the tree, OR
- (b) selected items are requests.md-only and the user confirmed, OR
- (c) `no-start({today})` note exists.

### Wrap up

1. Show updated tree.
2. Commit `[me] {name}: start-day W{N} D{N}` with body listing today's picks (or no-start reason).
3. Push.
