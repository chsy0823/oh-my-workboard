# /plan-week — Team weekly plan (leader only)

Set the team's direction for the week before members run `/start-week`. Gated by `team.yaml:leader`.

## Run order

1. Resolve task repo. `cd` there. `git pull`.
2. Verify current user is the leader. If not, halt with explanation.

### Team review

1. Read all `people/*.md` `## This Week's Tasks (W{N-1})` trees.
2. Per person, summarize: completed top-levels, carry-over candidates, lingering `@wait`, and unresolved `requests.md` items affecting them.
3. Read `projects/*/milestones.md` for milestone progress.
4. Show the full team rollup.

### Milestone updates

For each project, ask the leader whether to flip any milestone checkboxes based on last week's outcomes.

### Backlog scan

1. Read `board/backlog.md`; present items by priority.
2. Ask per item: "promote this to a team goal?".
3. Promoted to teammate's queue → that teammate decides during `/start-week`.
4. Promoted to leader's own work → add as top-level leaf in leader's workboard now.
5. **Remove promoted items from `backlog.md`.**

### Set team direction

Walk through:
1. Top milestones for this week.
2. Per-member focus.
3. Reviews needed.

### Write `board/status.md`

Use the team-goal sub-checklist format:

```md
- [ ] {team goal} → M1-1, M1-2
  - [ ] @{user}: {weekly unit, must match user's workboard top-level text}
- [ ] {team goal — no milestone mapping}
  - [ ] @{user}: {sub}
```

Rules:
1. Top-level checkbox: weekly goal complete/incomplete.
2. `→ M{N}-{S}` mapping is optional reference; daily-report shows mapped milestone average alongside sub progress.
3. Each team goal has subs `  - [ ] @{user}: {text}`. Text MUST match the user's workboard top-level when they mirror it.
4. Background or training items can have no mapping — only subs.
5. Aim for 1–3 subs per person.

### Leader's own week

Snapshot leader's W{N-1} to `log/w{N-1}.md`, then create W{N} with carry-over + new top-levels (2–4 items).

### Wrap up

1. Show status.md, milestones.md changes, and leader's workboard.
2. Commit `[board] plan-week W{N}`. Push.
3. Tell the team to run `/start-week`.
