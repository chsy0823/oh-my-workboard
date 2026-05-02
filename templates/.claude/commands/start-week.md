# /start-week — Personal weekly setup (members)

Mirror the leader's `status.md` subs and add self-driven items. Run after the leader has run `/plan-week`.

## Run order

1. Resolve task repo. `cd` there. `git pull`.
2. Read `people/{id}.md`.

### Last week review

For each `## This Week's Tasks (W{N-1})` top-level leaf:
- `[x]` → just summarize.
- not done → ask reason, capture as note bullet.

### Last week archive

Append the entire W{N-1} tree to `log/w{N-1}.md` under `## {id}`. Empty the section in the workboard.

### Mirror team plan subs

1. Read `board/status.md` `## This Week's Team Goals`.
2. Extract subs that match `@{current-user}: {text}`.
3. Show the list: "leader assigned these to you this week — mirror to your workboard?".
4. On confirm, add each sub as a top-level leaf with **the exact same text**.
5. Project label: copy from sub if present, else ask.

### Self-driven items

1. Anything in your owned milestones (`projects/*/milestones.md`) for this week?
2. Anything from teammate workboards / `requests.md` that gates your work and isn't yet mirrored?
3. Learning, research, prep work?
4. Scan `board/backlog.md` for promotion candidates. **Removed from backlog when promoted.**

### Compose the new week

Write the new `## This Week's Tasks (W{N})` section:
- Mirrored items from status.md
- Self-driven items
- Carry-over of last week's unfinished top-levels (deduped)
- Backlog promotions (and remove the source line in `backlog.md`)

Aim for 2–5 top-levels. Don't pre-split into subs.

### Wrap up

1. Show updated workboard.
2. Commit `[me] {name}: start-week W{N}`. Push.
