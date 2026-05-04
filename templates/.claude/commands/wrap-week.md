# /wrap-week — Weekly retrospective (leader only)

Run on the last working day of the week or just before next week's `/plan-week`. Gated by `team.yaml:leader`.

## Step 1 — Quantitative wrap-up (auto-presented)

Show the leader these numbers in one block, then wait for "OK":

1. **Hit-rate headline**:
   - Team-plan subs: `{done}/{total}` ({pct}%)
   - Workboard top-levels: `{done}/{total}` ({pct}%)
   - Δ vs last week (last row of `board/velocity.md`).
   - Health zone (70–90%) — in/out indicator.
2. **Team-plan sub results** (`board/status.md`): per-goal `[x]/total`. Unfinished subs by owner.
3. **Workboard top-level results** (`people/*.md`): per-person `[x]/total`. Unfinished top-levels.
4. **Milestone movement** (this week): current vs last week's snapshot in `log/w{N-1}.md` if available.
5. **Request / blocker counts**:
   - Stale ping-pongs in `requests.md` (4+ days): N
   - Past-due requests: N
   - Open blockers (`board/blockers.md` + `@block` leaves): N
6. **Velocity trend**: parse `board/velocity.md` via `parseVelocity()` and `computeVelocityTrend(rows, 4)` from `dashboard/lib/parser.js`. Show: latest week pct, 4-week avg, delta vs previous week (▲/▼), delta vs 4-week avg, and the `recent` rows table. One-line summary: "this week {pct}% vs 4wk avg {avgPct}% — trending up/down/flat" (use `deltaVsAvg` sign).

Ask: "Numbers look right? Any extra slice you want before retro?". Wait for OK.

## Step 2 — Retrospective dialog

1. **Hit-rate evaluation**: "{pct}% — too low, fine, too high?".
2. **Causes of misses**: per unfinished sub, ask owner+reason. Categories: (a) estimation off, (b) external dep / waiting, (c) priority shift, (d) blocker, (e) leave/absence, (f) work harder than expected.
3. **Pattern extraction**: group reasons; surface recurring patterns.
4. **Next-week scope adjustment**: <60% → smaller scope; >90% → can take more; consistent miss by one owner → dig into deps / sub-count.
5. **Milestone deadline impact**: any milestones at risk? Note candidates for `projects/*/milestones.md` deadline updates.
6. **What worked / what to keep**.

## Step 3 — Write retro doc

`log/w{N}-retro.md`:

```md
# W{N} retro — {YYYY-MM-DD}

## Snapshot
- Team-plan subs: {done}/{total} ({pct}%)
- Workboard top-levels: {done}/{total} ({pct}%)
- Milestone delta: ...
- Stale ping-pongs: {N}
- Past-due: {N}
- Open blockers: {N}

## What worked
- ...

## What didn't / why
- {sub} (@{owner}) — reason

## Patterns
- ...

## Apply next week (W{N+1})
- Scope: ...
- Milestone candidates: ...
- Flow improvements: ...

## Keepers
- ...
```

## Step 4 — Update velocity

Append a row to `board/velocity.md`:

```md
| W{N} | {planned-subs} | {done-subs} | {pct}% | {one-line summary} |
```

## Wrap up

1. Show retro doc + velocity row.
2. Commit `[log] retro W{N} ({pct}%)`. Push.
3. Reference this in next `/plan-week`.

## Caveats

- Not a personal-evaluation tool. Causes systemic, never per-person blame.
- 100% is not the target. 80–90% with accurate estimation is healthier.
- Retro short. ≤30 minutes.
