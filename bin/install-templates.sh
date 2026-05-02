#!/usr/bin/env bash
# install-templates.sh — generate all oh-my-workboard P5 templates in one shot.
# Run from anywhere: bash bin/install-templates.sh
# Idempotent: overwrites existing template files.

set -euo pipefail
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$PLUGIN_ROOT/templates"

mkdir -p \
  "$T/log" \
  "$T/board" \
  "$T/people" \
  "$T/projects/_example" \
  "$T/.claude/hooks" \
  "$T/.claude/commands" \
  "$T/.githooks" \
  "$T/.github/workflows" \
  "$T/scripts" \
  "$T/dashboard/lib"

# ─────────────────────────────────────────────────────────
# .gitignore
# ─────────────────────────────────────────────────────────
cat <<'EOF_GI' > "$T/.gitignore"
.DS_Store
*.swp
*.swo
*~
node_modules/
package-lock.json
dashboard/test*.png
dashboard/test*.mjs
.obsidian/
EOF_GI

# log/.gitkeep
: > "$T/log/.gitkeep"

# ─────────────────────────────────────────────────────────
# projects/_example/
# ─────────────────────────────────────────────────────────
cat <<'EOF_PROJ_OVERVIEW' > "$T/projects/_example/overview.md"
# {project-name}

## Goal
What this project ships and why it matters. One paragraph.

## Scope
- In scope: ...
- Out of scope: ...

## Timeline
- Kickoff: YYYY-MM-DD
- Target ship: YYYY-MM-DD

## Stakeholders
- Owner: @{leader-id}
- Contributors: @{user-id}, @{user-id}
EOF_PROJ_OVERVIEW

cat <<'EOF_PROJ_MILESTONES' > "$T/projects/_example/milestones.md"
# {project-name} — milestones

Project target: YYYY-MM-DD

## Part 1. {part-name}

### M1-1. {milestone-name}
owner: @{user-id}
start: YYYY-MM-DD
deadline: YYYY-MM-DD

- [ ] checkpoint
- [ ] checkpoint

### M1-2. {milestone-name}
owner: @{user-id}
deadline: YYYY-MM-DD

- [ ] checkpoint
EOF_PROJ_MILESTONES

cat <<'EOF_PROJ_STREAMS' > "$T/projects/_example/streams.md"
# {project-name} — workstreams

Goal: ...
Timeline: ...

## 1. {stream-name}
owner: @{user-id}
status: planning
progress: 0%
remaining: ...
dependency: none
EOF_PROJ_STREAMS

# ─────────────────────────────────────────────────────────
# .claude/commands/start-day.md
# ─────────────────────────────────────────────────────────
cat <<'EOF_CMD_SD' > "$T/.claude/commands/start-day.md"
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
EOF_CMD_SD

# ─────────────────────────────────────────────────────────
# .claude/commands/end-day.md
# ─────────────────────────────────────────────────────────
cat <<'EOF_CMD_ED' > "$T/.claude/commands/end-day.md"
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

For done leaves where someone else picks up next: ask "who continues this?". Add `@handoff(user: action)`. Do NOT touch the receiver's workboard — they pick it up on their `/start-day`.

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
EOF_CMD_ED

# ─────────────────────────────────────────────────────────
# .claude/commands/start-week.md
# ─────────────────────────────────────────────────────────
cat <<'EOF_CMD_SW' > "$T/.claude/commands/start-week.md"
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
EOF_CMD_SW

# ─────────────────────────────────────────────────────────
# .claude/commands/plan-week.md
# ─────────────────────────────────────────────────────────
cat <<'EOF_CMD_PW' > "$T/.claude/commands/plan-week.md"
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
EOF_CMD_PW

# ─────────────────────────────────────────────────────────
# .claude/commands/wrap-week.md
# ─────────────────────────────────────────────────────────
cat <<'EOF_CMD_WW' > "$T/.claude/commands/wrap-week.md"
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
6. **Velocity trend**: last 4 weeks moving average from `board/velocity.md`.

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
EOF_CMD_WW

# ─────────────────────────────────────────────────────────
# .github/workflows/slack-notify.yml
# ─────────────────────────────────────────────────────────
cat <<'EOF_WF_SN' > "$T/.github/workflows/slack-notify.yml"
name: Slack Notification

on:
  push:
    branches: [main]
    paths:
      - 'people/**'
      - 'board/**'
      - 'projects/**'
      - 'log/**'

# {{SLACK_ID_BLOCK}} — rendered by /oh-my-workboard:init from team.yaml.
# Each active member with a slack_id becomes SLACK_ID_{id-with-dashes-as-underscores}.
env:
  SLACK_ID_PLACEHOLDER: U000000000

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Build notification
        id: build
        run: |
          BEFORE="${{ github.event.before }}"
          AFTER="${{ github.sha }}"
          if [ -z "$BEFORE" ] || [ "$BEFORE" = "0000000000000000000000000000000000000000" ] \
             || ! git cat-file -e "${BEFORE}^{commit}" 2>/dev/null; then
            RANGE="HEAD~1..HEAD"
          else
            RANGE="${BEFORE}..${AFTER}"
          fi

          COMMIT_COUNT=$(git rev-list --count "$RANGE" 2>/dev/null || echo "1")
          AUTHOR=$(git log -1 --format='%an' "$AFTER")
          LAST_MSG=$(git log -1 --format='%s' "$AFTER")
          if [ "$COMMIT_COUNT" -gt 1 ]; then
            MSG="${LAST_MSG} (+${COMMIT_COUNT} commits)"
          else
            MSG="$LAST_MSG"
          fi
          COMMIT_URL="https://github.com/${{ github.repository }}/commit/${{ github.sha }}"
          SHORT_SHA=$(echo "${{ github.sha }}" | cut -c1-7)

          CHANGED=$(git diff --name-only $RANGE 2>/dev/null || echo "")
          PEOPLE_CHANGES=$(echo "$CHANGED" | grep '^people/' | sed 's|people/||;s|\.md||' || true)
          REQUEST_CHANGES=$(echo "$CHANGED" | grep '^board/requests' || true)
          BLOCKER_CHANGES=$(echo "$CHANGED" | grep '^board/blockers' || true)
          PROJECT_CHANGES=$(echo "$CHANGED" | grep '^projects/' || true)
          LOG_CHANGES=$(echo "$CHANGED" | grep '^log/' || true)

          SUMMARY=""
          [ -n "$PEOPLE_CHANGES" ] && SUMMARY="${SUMMARY}\n:pencil: *Workboard updates:* $(echo "$PEOPLE_CHANGES" | tr '\n' ', ' | sed 's/,$//')"
          [ -n "$REQUEST_CHANGES" ] && SUMMARY="${SUMMARY}\n:eyes: *Request queue changed*"
          [ -n "$BLOCKER_CHANGES" ] && SUMMARY="${SUMMARY}\n:rotating_light: *Blockers changed*"
          [ -n "$PROJECT_CHANGES" ] && SUMMARY="${SUMMARY}\n:milestone: *Project files updated*"
          [ -n "$LOG_CHANGES" ] && SUMMARY="${SUMMARY}\n:spiral_note_pad: *Daily log added*"

          {
            echo "AUTHOR=${AUTHOR}"
            echo "MSG=${MSG}"
            echo "COMMIT_URL=${COMMIT_URL}"
            echo "SHORT_SHA=${SHORT_SHA}"
            echo "SUMMARY<<EOFSUM"
            echo -e "$SUMMARY"
            echo "EOFSUM"
          } >> "$GITHUB_OUTPUT"

      - name: Send to Slack
        if: steps.build.outputs.SUMMARY != ''
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        run: |
          PAYLOAD=$(cat <<JSON
          {
            "blocks": [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "*Workboard Update*\n\`${{ steps.build.outputs.MSG }}\`\nby *${{ steps.build.outputs.AUTHOR }}* (<${{ steps.build.outputs.COMMIT_URL }}|${{ steps.build.outputs.SHORT_SHA }}>)"
                }
              },
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "${{ steps.build.outputs.SUMMARY }}"
                }
              }
            ]
          }
          JSON
          )
          curl -s -X POST "$SLACK_WEBHOOK_URL" -H 'Content-Type: application/json' -d "$PAYLOAD"
EOF_WF_SN

# ─────────────────────────────────────────────────────────
# .github/workflows/daily-report.yml
# ─────────────────────────────────────────────────────────
cat <<'EOF_WF_DR' > "$T/.github/workflows/daily-report.yml"
name: Daily Report

on:
  schedule:
    # KST 09:00 = UTC 00:00 (Mon–Fri). Override TZ + cron if your team isn't in KST.
    - cron: '0 0 * * 1-5'
  workflow_dispatch:

env:
  TZ: Asia/Seoul
  # {{SLACK_ID_BLOCK}} — rendered by /oh-my-workboard:init from team.yaml.
  SLACK_ID_PLACEHOLDER: U000000000

jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Build report payload
        run: node scripts/daily-report.js --blocks > /tmp/daily-report.json

      - name: Send to Slack
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        run: |
          curl -s -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            --data-binary @/tmp/daily-report.json
EOF_WF_DR

# ─────────────────────────────────────────────────────────
# scripts/setup.sh
# ─────────────────────────────────────────────────────────
cat <<'EOF_SETUP' > "$T/scripts/setup.sh"
#!/usr/bin/env bash
# One-time setup. Run after cloning a workboard task repo.

set -e
echo "Workboard setup"
echo "==============="

echo "[1/3] Configuring git hooks..."
git config core.hooksPath .githooks
echo "  ok: commit-msg + pre-push wired"

echo "[2/3] Checking git user.name..."
GIT_USER="$(git config user.name 2>/dev/null || echo "")"
if [ -z "$GIT_USER" ]; then
  echo "  warn: git user.name is unset. Run: git config user.name \"your-id\""
else
  echo "  user: $GIT_USER"
  if [ -f "people/${GIT_USER}.md" ]; then
    echo "  ok: people/${GIT_USER}.md found"
  else
    echo "  warn: people/${GIT_USER}.md not found"
    echo "        ensure git user.name matches your team.yaml id (or one of its keywords)"
  fi
fi

echo "[3/3] Tooling checks..."
command -v yq >/dev/null 2>&1 && echo "  ok: yq present" || echo "  note: yq not found (fallback awk/grep used)"
command -v node >/dev/null 2>&1 && echo "  ok: node $(node --version)" || echo "  note: node not found (daily-report.js + dashboard need it)"

echo ""
echo "Setup complete. Open Claude in this directory and run /oh-my-workboard:start-day."
EOF_SETUP

# ─────────────────────────────────────────────────────────
# CLAUDE.md template
# ─────────────────────────────────────────────────────────
cat <<'EOF_CLAUDE_MD' > "$T/CLAUDE.md"
# {{TEAM_NAME}} Workboard — Claude operating instructions

You are this team's personal assistant and project manager.
Whoever runs Claude in this directory is one of the members in the table below.
Help that person work efficiently and keep the team aligned.

## Team

<!-- BEGIN:TEAM_TABLE -->
| GitHub | Name (keywords) | Role | Focus |
|--------|----------------|------|-------|
| @{id} | {name} ({keywords}) | {role} | {focus} |
<!-- END:TEAM_TABLE -->

When identifying the user from `git config user.name`, match against name / GitHub id / keywords (case-insensitive). Ask if no match.

The team leader is `{{LEADER_ID}}`. The leader can edit any teammate's workboard, the status board, and milestones. Other members can only edit their own `people/{id}.md`, the request queue, the backlog, and logs.

## Behavior

1. Identify the user (`git config user.name`). Ask if unsure.
2. Read context first: their workboard, then the request queue.
3. Respond tightly — no filler.
4. Report what you change in one line per change.
5. Commit only after the user confirms.
6. Think from the receiver's perspective for any cross-team artifact.
7. If receiver context is incomplete, ask once (batched) before recording.

## Data model

Each member's workboard (`people/{id}.md`) is a **single tree**. The only section is `## This Week's Tasks (W{N})`. All state lives on tree leaves as tags.

### Tree format

```
## This Week's Tasks (W17)

- [ ] [project] top-level task (weekly-goal unit)
  - [x] subtask @done(2026-04-22)
  - [ ] subtask @today
  - [ ] subtask @wait(precondition or external reason)
  - free-form note bullet (no checkbox)
- [x] [project] single-shot @done(2026-04-22) @handoff(user: continuation)
```

### Reserved tags

| Tag | Meaning | Value |
|-----|---------|-------|
| `@today` | picked for today | none |
| `@done(YYYY-MM-DD)` | completed; pair with `[x]` | completion date |
| `@wait(reason)` | external / self precondition | free text — never `user:` |
| `@block(reason)` | severe variant of `@wait` | same |
| `@handoff(user: action)` | someone else picks up | `user` = GitHub id (no `@`) |

### Cross-member dependencies → `board/requests.md` only

Anything you ask of a teammate goes into `board/requests.md`. **Never** use `@wait(user:...)` on the workboard.

`@wait(reason)` still applies for: external (regulator, vendor, customer), self-precondition. No `user:` field.

**No-duplication rule**: a request in `requests.md` does NOT also appear as `@today` in the receiver's workboard.

### Request format

Categories: `## PR Reviews`, `## Design Reviews`, `## Work Requests`, `## Decisions Needed`. Plus `## Handoffs` if your team enables handoff acks.

```
- {requester} → {receiver}: [{project}] {content} — {YYYY-MM-DD}
  - 📎 {artifact}
  - 🔍 {what to look at / what unblocks}
  - ⏰ {YYYY-MM-DD}
  - 🔄 changes-requested → @{requester} in-progress (MM-DD)
```

The `[project]` prefix is **required**. Use `[misc]` if no project applies. `⏰` deadlines should be concrete dates.

### Status board → `board/status.md`

`## This Week's Team Goals` is the team's weekly **tracking SSOT**:

```md
- [ ] {team goal} → M1-1, M1-2
  - [ ] @{user}: {weekly unit; must equal owner's workboard top-level text}
- [ ] {team goal — no mapping}
  - [ ] @{user}: {sub}
```

Owners must keep their workboard top-level leaf text **identical** to their assigned status sub.

### Backlog → `board/backlog.md`

Format `- P{1|2|3} [{project}] content — proposer (YYYY-MM-DD)`. Promoted items are removed from backlog when added to a workboard.

### Velocity → `board/velocity.md`

Markdown table appended once per week by `/wrap-week`. Healthy zone: 70–90%.

## Session start

1. `git pull`.
2. Identify user.
3. Read their `people/{id}.md`.
4. Read incoming items in `board/requests.md` for them.
5. Read team blockers (`board/blockers.md`).
6. Scan all `people/*.md` for `@wait` / `@block` mentioning current user — surface "people waiting on you".
7. Brief: this-week tree summary, today's `@today`, currently-blocked items, things waiting on user, queued requests, team blockers.

## Commit prefix rules

- `[me] {name}: {what}` — personal workboard
- `[log] {date} {what}` — daily log / weekly retro
- `[board] {what}` — status / blockers / backlog / velocity
- `[project] {project}: {what}` — project files
- `[decision] {project}: {what}` — decisions
- `[init] {what}` — one-time setup

## Edit permission

- `people/{self}.md`, `log/`, `board/{requests,backlog}.md` → push to main.
- `board/{status,blockers,velocity}.md` → leader only.
- `projects/`, `CLAUDE.md` → branch → PR (leader bypasses via pre-push hook).
- Leader can edit any `people/*.md`.
EOF_CLAUDE_MD

# ─────────────────────────────────────────────────────────
# dashboard/lib/parser.js — generalized for English headings
# ─────────────────────────────────────────────────────────
cat <<'EOF_PARSER' > "$T/dashboard/lib/parser.js"
const fs = require('node:fs');
const path = require('node:path');

const WEEKLY_SECTION_RE = /^This Week'?s Tasks/i;
const TEAM_GOALS_HEADER = /^This Week'?s Team Goals/i;
const PER_MEMBER_FOCUS_HEADER = /^Per-member Focus/i;

const REQUEST_CATEGORY_TYPE = (category) => {
  if (/^Work Requests?/i.test(category)) return 'work';
  if (/^Decisions? Needed/i.test(category)) return 'decision';
  if (/^Handoffs?/i.test(category)) return 'handoff';
  return 'review';
};

function parsePerson(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const fileName = path.basename(filePath, '.md');

  const headerMatch = content.match(/^# (.+?) — (.+)$/m);
  const id = headerMatch ? headerMatch[1].trim() : fileName;
  const title = headerMatch ? headerMatch[2].trim() : '';

  const sections = splitSections(content);
  const workKey = Object.keys(sections).find(k => WEEKLY_SECTION_RE.test(k));

  if (!workKey) {
    return { id, title, weekLabel: '', weeklyGoals: [], doing: [], waiting: [], blockers: [], done: [], tree: [] };
  }

  const tree = parseTree(sections[workKey]);
  const derived = deriveViews(tree);
  return { id, title, weekLabel: workKey, ...derived, tree };
}

function parseTree(text) {
  const lines = text.split('\n');
  const rootItems = [];
  const stack = [{ depth: -1, children: rootItems, notes: null }];

  for (const line of lines) {
    if (!line.trim()) continue;
    const indentMatch = line.match(/^(\s*)/);
    const depth = Math.floor(indentMatch[1].length / 2);

    const taskMatch = line.match(/^\s*- \[([ xX])\]\s*(.+?)\s*$/);
    if (taskMatch) {
      const checked = taskMatch[1] !== ' ';
      const item = parseTaskContent(taskMatch[2]);
      item.checked = checked;
      item.depth = depth;
      item.children = [];
      item.notes = [];

      while (stack.length > 1 && stack[stack.length - 1].depth >= depth) stack.pop();
      stack[stack.length - 1].children.push(item);
      stack.push(item);
      continue;
    }

    const noteMatch = line.match(/^\s*- (?!\[)(.+?)\s*$/);
    if (noteMatch) {
      for (let i = stack.length - 1; i >= 0; i--) {
        if (stack[i].depth < depth && stack[i].notes) {
          stack[i].notes.push(noteMatch[1].trim());
          break;
        }
      }
    }
  }
  return rootItems;
}

function parseTaskContent(raw) {
  const tags = {};
  let rest = raw;
  const tagPattern = /\s+@(\w+)(?:\(([^)]*)\))?$/;
  while (true) {
    const m = rest.match(tagPattern);
    if (!m) break;
    tags[m[1]] = m[2] !== undefined ? m[2] : true;
    rest = rest.slice(0, rest.length - m[0].length);
  }
  rest = rest.trim();

  let project = '';
  const projMatch = rest.match(/^\[([^\]]+)\]\s*(.*)$/);
  if (projMatch) {
    project = projMatch[1].trim();
    rest = projMatch[2];
  }
  return { text: rest.trim(), project, tags };
}

function deriveViews(tree) {
  const weeklyGoals = [];
  const doing = [];
  const waiting = [];
  const blockers = [];
  const done = [];

  for (const item of tree) {
    const reasonNote = item.notes.find(n => /^unfinished:/i.test(n));
    weeklyGoals.push({
      project: item.project || '',
      text: item.text,
      checked: item.checked,
      reason: reasonNote ? reasonNote.replace(/^unfinished:\s*/i, '') : '',
    });
  }

  function walk(items, parentProject, topAncestor) {
    for (const item of items) {
      const project = item.project || parentProject;
      const isLeaf = item.children.length === 0;
      const detail = item.notes.join(' / ');
      const parent = topAncestor ? topAncestor.text : null;

      if (item.tags.today) doing.push({ project, parent, task: item.text, detail });
      if (item.tags.wait !== undefined) {
        const reason = typeof item.tags.wait === 'string' ? item.tags.wait : '';
        const idx = reason.indexOf(':');
        const gateUser = idx >= 0 ? reason.slice(0, idx).trim() : '';
        const gateAction = idx >= 0 ? reason.slice(idx + 1).trim() : reason;
        waiting.push({ project, parent, task: item.text, detail: reason, gateUser, gateAction });
      }
      if (item.tags.block !== undefined) {
        const val = typeof item.tags.block === 'string' ? item.tags.block : '';
        const idx = val.indexOf(':');
        const target = idx >= 0
          ? `@${val.slice(0, idx).trim()}: ${val.slice(idx + 1).trim()}`
          : (val ? `@${val.trim()}` : '');
        blockers.push({ content: item.text, target });
      }
      if (item.checked && isLeaf) done.push({ project, parent, task: item.text, detail });
      if (item.children.length > 0) walk(item.children, project, topAncestor || item);
    }
  }
  walk(tree, '', null);

  return { weeklyGoals, doing, waiting, blockers, done };
}

function splitSections(content) {
  const sections = {};
  const lines = content.split('\n');
  let currentSection = null;
  let currentLines = [];

  for (const line of lines) {
    const sectionMatch = line.match(/^## (.+)$/);
    if (sectionMatch) {
      if (currentSection) sections[currentSection] = currentLines.join('\n');
      currentSection = sectionMatch[1].trim();
      currentLines = [];
    } else if (currentSection) {
      currentLines.push(line);
    }
  }
  if (currentSection) sections[currentSection] = currentLines.join('\n');
  return sections;
}

function parseMilestones(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const titleMatch = content.match(/^#\s+(.+?)\s*—\s*milestones/im);
  const title = titleMatch ? titleMatch[1].trim() : '';
  const timelineMatch = content.match(/^[^\n#]*?target:\s*(.+)$/im);
  const timeline = timelineMatch ? timelineMatch[1].trim() : '';

  const milestones = [];
  const parts = [];
  const lines = content.split('\n');
  let currentPart = null;
  let currentMilestone = null;
  let currentBody = [];

  function flushMilestone() {
    if (!currentMilestone) return;
    const body = currentBody.join('\n');
    const ownerMatch = body.match(/^owner:\s*(.+)$/m);
    const startMatch = body.match(/^start:\s*(.+)$/m);
    const deadlineMatch = body.match(/^deadline:\s*(.+)$/m);
    const checks = [];
    for (const l of body.split('\n')) {
      const cm = l.match(/^-\s*\[([ xX])\]\s*(.+)$/);
      if (cm) checks.push({ text: cm[2].trim(), checked: cm[1] !== ' ' });
    }
    const done = checks.filter(c => c.checked).length;
    const total = checks.length;
    milestones.push({
      ...currentMilestone,
      part: currentPart ? currentPart.num : '',
      partName: currentPart ? currentPart.name : '',
      owner: ownerMatch ? ownerMatch[1].trim() : '',
      start: startMatch ? startMatch[1].trim() : '',
      deadline: deadlineMatch ? deadlineMatch[1].trim() : '',
      checks, done, total,
      progress: total > 0 ? Math.round((done / total) * 100) : 0,
    });
    currentMilestone = null;
    currentBody = [];
  }

  for (const line of lines) {
    const partMatch = line.match(/^##\s+Part\s+(\S+?)\.\s*(.+?)\s*$/);
    const msMatch = line.match(/^###\s+M(\S+?)\.\s*(.+?)\s*$/);
    if (partMatch) {
      flushMilestone();
      const partName = partMatch[2].replace(/\s*★.*$/, '').trim();
      currentPart = { num: partMatch[1], name: partName };
      parts.push(currentPart);
    } else if (msMatch) {
      flushMilestone();
      currentMilestone = { num: msMatch[1], name: msMatch[2].trim() };
    } else if (currentMilestone) {
      currentBody.push(line);
    }
  }
  flushMilestone();
  return { title, timeline, milestones, parts };
}

function parseRequests(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const sections = splitSections(content);
  const requests = [];
  for (const [category, text] of Object.entries(sections)) {
    const lines = text.split('\n');
    let current = null;
    for (const line of lines) {
      const match = line.match(/^- (.+)$/);
      if (match && match[1].trim() !== '') {
        const raw = match[1].trim();
        const parsed = raw.match(/^(.+?)\s*→\s*(.+?):\s*(.+?)(?:\s*—\s*(.+))?$/);
        if (parsed) {
          let content2 = parsed[3].trim();
          let project = '';
          const projMatch = content2.match(/^\[([^\]]+)\]\s*(.+)$/);
          if (projMatch) {
            project = projMatch[1].trim();
            content2 = projMatch[2].trim();
          }
          current = {
            category,
            reqType: REQUEST_CATEGORY_TYPE(category),
            from: parsed[1].trim(),
            to: parsed[2].trim(),
            content: content2, project,
            date: parsed[4] ? parsed[4].trim() : '',
            artifact: '', focus: '', pingpong: '', deadline: '',
          };
          requests.push(current);
        }
        continue;
      }
      if (current && line.match(/^\s+-\s/)) {
        const sub = line.replace(/^\s+-\s/, '').trim();
        if (sub.startsWith('📎')) current.artifact = (current.artifact ? current.artifact + ' | ' : '') + sub.replace(/^📎\s*/, '');
        else if (sub.startsWith('🔍')) current.focus = sub.replace(/^🔍\s*/, '');
        else if (sub.startsWith('🔄')) current.pingpong = sub.replace(/^🔄\s*/, '');
        else if (sub.startsWith('⏰')) current.deadline = sub.replace(/^⏰\s*/, '');
      }
    }
  }
  return requests;
}

function parseBacklog(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const items = [];
  let current = null;
  let inBody = false;
  const itemRe = /^-\s+(?:(P[123])\s+)?\[([^\]]+)\]\s*(.+?)(?:\s*—\s*([^\s(]+)(?:\s*\(([\d-]+)\))?)?\s*$/;

  for (const raw of lines) {
    if (!inBody) {
      if (/^-\s/.test(raw)) inBody = true;
      else continue;
    }
    const m = raw.match(itemRe);
    if (m) {
      current = {
        priority: m[1] || 'P2',
        project: m[2].trim(),
        text: m[3].trim(),
        by: m[4] ? m[4].trim() : '',
        date: m[5] ? m[5].trim() : '',
        notes: [],
      };
      items.push(current);
      continue;
    }
    const noteMatch = raw.match(/^\s+-\s+(.+?)\s*$/);
    if (noteMatch && current) current.notes.push(noteMatch[1].trim());
  }
  return items;
}

function parseStreams(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const nameMatch = content.match(/^# (.+?) — workstreams?/mi);
  const name = nameMatch ? nameMatch[1].trim() : path.basename(path.dirname(filePath));
  const goalMatch = content.match(/^Goal:\s*(.+)$/mi);
  const timelineMatch = content.match(/^Timeline:\s*(.+)$/mi);
  const streams = [];
  const streamBlocks = content.split(/^## \d+\.\s*/m).slice(1);
  for (const block of streamBlocks) {
    const lines = block.split('\n');
    const streamName = lines[0].trim();
    const props = {};
    for (const line of lines.slice(1)) {
      const kv = line.match(/^(\w+):\s*(.+)$/);
      if (kv) props[kv[1].trim()] = kv[2].trim();
    }
    streams.push({
      name: streamName,
      owner: props['owner'] || '',
      status: props['status'] || '',
      progress: props['progress'] || '0%',
      remaining: props['remaining'] || '',
      dependency: props['dependency'] || 'none',
    });
  }
  return { name, goal: goalMatch ? goalMatch[1].trim() : '', timeline: timelineMatch ? timelineMatch[1].trim() : '', streams };
}

function parseTeamPlan(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const goals = [];
  let inGoals = false;
  let currentGoal = null;
  for (const line of lines) {
    if (line.startsWith('## ') && TEAM_GOALS_HEADER.test(line.slice(3))) { inGoals = true; continue; }
    if (inGoals && line.startsWith('## ')) break;
    if (!inGoals) continue;

    const topMatch = line.match(/^- (?:\[([ xX])\]\s*)?(.+?)\s*$/);
    const subMatch = line.match(/^\s+- (?:\[([ xX])\]\s*)?(.+?)\s*$/);

    if (subMatch && currentGoal) {
      const checked = subMatch[1] && subMatch[1].toLowerCase() === 'x';
      let text = subMatch[2];
      const userMatch = text.match(/^@(\S+):\s*(.+)$/);
      const owner = userMatch ? userMatch[1] : '';
      const subText = userMatch ? userMatch[2].trim() : text;
      currentGoal.subs.push({ checked: !!checked, owner, text: subText });
    } else if (topMatch && line.startsWith('- ')) {
      const checked = topMatch[1] && topMatch[1].toLowerCase() === 'x';
      let text = topMatch[2];
      let mappings = [];
      const arrowIdx = text.lastIndexOf(' → ');
      if (arrowIdx >= 0) {
        const keyPart = text.slice(arrowIdx + 3).trim();
        text = text.slice(0, arrowIdx).trim();
        mappings = keyPart.split(',').map(s => s.trim()).filter(Boolean);
      }
      currentGoal = { text, checked: !!checked, hasCheckbox: topMatch[1] !== undefined, mappings, subs: [] };
      goals.push(currentGoal);
    }
  }

  const focuses = [];
  let currentMember = null;
  let inFocuses = false;
  for (const line of lines) {
    if (line.startsWith('## ') && PER_MEMBER_FOCUS_HEADER.test(line.slice(3))) { inFocuses = true; continue; }
    if (inFocuses && /^## [^#]/.test(line)) break;
    if (inFocuses && line.startsWith('### @')) {
      const match = line.match(/^### @(\S+)\s*—\s*(.+)$/);
      if (match) { currentMember = { id: match[1], focus: match[2].trim(), items: [] }; focuses.push(currentMember); }
    } else if (inFocuses && currentMember && line.startsWith('- ')) {
      currentMember.items.push(line.replace(/^- /, '').trim());
    }
  }
  return { goals, focuses };
}

function parseVelocity(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const rows = [];
  for (const line of lines) {
    const m = line.match(/^\|\s*(W\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)%?\s*\|\s*(.*?)\s*\|\s*$/);
    if (m) rows.push({ week: m[1], planned: +m[2], done: +m[3], pct: +m[4], note: m[5] });
  }
  return rows;
}

function computeTeamGoalProgress(teamPlan, milestones) {
  if (!teamPlan || !teamPlan.goals) return [];
  const msById = {};
  for (const ms of milestones || []) {
    for (const m of ms.milestones || []) msById[`M${m.num}`] = m;
  }
  return teamPlan.goals.map(g => {
    const total = g.subs.length;
    const done = g.subs.filter(s => s.checked).length;
    const subProgress = total > 0 ? Math.round((done / total) * 100) : null;
    const mapped = (g.mappings || []).map(k => msById[k]).filter(Boolean);
    const msAvg = mapped.length > 0
      ? Math.round(mapped.reduce((a, m) => a + (m.progress || 0), 0) / mapped.length)
      : null;
    return {
      text: g.text, checked: g.checked, hasCheckbox: g.hasCheckbox,
      mappings: g.mappings, subs: g.subs, done, total, subProgress,
      milestoneAverage: msAvg,
      mappedMilestones: mapped.map(m => ({ num: `M${m.num}`, progress: m.progress, name: m.name })),
    };
  });
}

function parseAll(rootDir) {
  const result = { people: [], projects: [], blockers: [], milestones: [], requests: [], backlog: [], teamPlan: null, velocity: [] };

  const peopleDir = path.join(rootDir, 'people');
  if (fs.existsSync(peopleDir)) {
    for (const file of fs.readdirSync(peopleDir).filter(f => f.endsWith('.md'))) {
      const person = parsePerson(path.join(peopleDir, file));
      result.people.push(person);
      for (const b of person.blockers) result.blockers.push({ ...b, from: person.id });
    }
  }

  const projectsDir = path.join(rootDir, 'projects');
  if (fs.existsSync(projectsDir)) {
    const dirs = fs.readdirSync(projectsDir).filter(d => !d.startsWith('.') && fs.statSync(path.join(projectsDir, d)).isDirectory());
    for (const dir of dirs) {
      const milestonesFile = path.join(projectsDir, dir, 'milestones.md');
      if (fs.existsSync(milestonesFile)) {
        const ms = parseMilestones(milestonesFile);
        ms.project = dir;
        result.milestones.push(ms);
      }
      const streamsFile = path.join(projectsDir, dir, 'streams.md');
      if (fs.existsSync(streamsFile)) result.projects.push(parseStreams(streamsFile));
    }
  }

  const requestsFile = path.join(rootDir, 'board', 'requests.md');
  if (fs.existsSync(requestsFile)) result.requests = parseRequests(requestsFile);

  const backlogFile = path.join(rootDir, 'board', 'backlog.md');
  if (fs.existsSync(backlogFile)) result.backlog = parseBacklog(backlogFile);

  const statusFile = path.join(rootDir, 'board', 'status.md');
  if (fs.existsSync(statusFile)) result.teamPlan = parseTeamPlan(statusFile);

  const velocityFile = path.join(rootDir, 'board', 'velocity.md');
  if (fs.existsSync(velocityFile)) result.velocity = parseVelocity(velocityFile);

  result.members = result.people.map(p => ({ id: p.id, title: p.title }));

  const teamIds = new Set(result.people.map(p => p.id));
  const edges = [];
  for (const person of result.people) {
    for (const w of person.waiting) {
      if (w.gateUser && teamIds.has(w.gateUser)) {
        edges.push({
          waiter: person.id, gatekeeper: w.gateUser, action: w.gateAction,
          unblockTask: w.task, waiterProject: w.project, waiterParent: w.parent,
        });
      }
    }
  }
  for (const p of result.people) p.blocking = edges.filter(e => e.gatekeeper === p.id);
  result.dependencies = edges;

  return result;
}

module.exports = {
  parseAll, parsePerson, parseStreams, parseMilestones,
  parseRequests, parseBacklog, parseTeamPlan, parseVelocity,
  computeTeamGoalProgress,
};
EOF_PARSER

# ─────────────────────────────────────────────────────────
# scripts/daily-report.js — port with English strings + team.yaml-driven SLACK_IDS
# ─────────────────────────────────────────────────────────
cat <<'EOF_DAILY' > "$T/scripts/daily-report.js"
#!/usr/bin/env node
/**
 * Daily Report
 * Usage: node scripts/daily-report.js [--text|--blocks|--mrkdwn]
 *   --blocks (default): Slack blocks JSON
 *   --text: plain text (CLI preview)
 *   --mrkdwn: mrkdwn single block (Slack mentions resolved)
 */

const path = require('node:path');
const { parseAll, computeTeamGoalProgress } = require('../dashboard/lib/parser');

const ROOT = path.resolve(__dirname, '..');
const MODE = process.argv.includes('--text') ? 'text'
           : process.argv.includes('--mrkdwn') ? 'mrkdwn'
           : 'blocks';

function nowLocal() { return new Date(); }
function fmtDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${dd}`;
}
function isoWeek(d) {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  const day = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
}
function dayOfWeek1to7(d) { return d.getDay() === 0 ? 7 : d.getDay(); }
const WEEKDAY = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

function daysUntilDeadline(s, today) {
  if (!s) return null;
  let m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  let target;
  if (m) target = new Date(+m[1], +m[2] - 1, +m[3]);
  else if ((m = s.match(/^(\d{1,2})-(\d{1,2})/))) target = new Date(today.getFullYear(), +m[1] - 1, +m[2]);
  else return null;
  const t0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  return Math.round((target - t0) / 86400000);
}

function personProgress(p) {
  const tree = p.tree || [];
  const total = tree.length;
  const done = tree.filter(t => t.checked).length;
  const pct = total > 0 ? Math.round((done / total) * 100) : 0;
  return { id: p.id, total, done, pct };
}

function findStalePingpongs(requests, today, thresholdDays = 4) {
  const stale = [];
  for (const r of requests) {
    if (!r.pingpong) continue;
    const m = r.pingpong.match(/\((\d{1,2})-(\d{1,2})\)/);
    if (!m) continue;
    const start = new Date(today.getFullYear(), +m[1] - 1, +m[2]);
    const t0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const days = Math.round((t0 - start) / 86400000);
    if (days >= thresholdDays) stale.push({ ...r, stalledDays: days });
  }
  return stale;
}

function findDueRequests(requests, today, withinDays = 3) {
  const due = [];
  for (const r of requests) {
    if (!r.deadline) continue;
    const d = daysUntilDeadline(r.deadline, today);
    if (d === null) continue;
    if (d <= withinDays) due.push({ ...r, daysLeft: d });
  }
  due.sort((a, b) => a.daysLeft - b.daysLeft);
  return due;
}

function collectBlockers(people) {
  const out = [];
  for (const p of people) {
    for (const b of p.blockers) out.push({ from: p.id, content: b.content, target: b.target });
  }
  return out;
}

function build() {
  const today = nowLocal();
  const dateStr = fmtDate(today);
  const week = isoWeek(today);
  const dow = dayOfWeek1to7(today);
  const dayLabel = WEEKDAY[today.getDay()];

  const data = parseAll(ROOT);
  const teamPlanGoals = computeTeamGoalProgress(data.teamPlan, data.milestones);
  const persons = data.people.map(personProgress).sort((a, b) => a.id.localeCompare(b.id));
  const dueRequests = findDueRequests(data.requests, today, 3);
  const stalePingpongs = findStalePingpongs(data.requests, today, 4);
  const blockers = collectBlockers(data.people);

  return { today, dateStr, week, dow, dayLabel, teamPlanGoals, persons, dueRequests, stalePingpongs, blockers };
}

// {{SLACK_ID_FALLBACK}} — rendered by /oh-my-workboard:init from team.yaml.
const SLACK_ID_FALLBACK = {};
const SLACK_IDS = Object.fromEntries(
  Object.keys(SLACK_ID_FALLBACK).map(id => [id, process.env[`SLACK_ID_${id.replace(/-/g, '_')}`] || SLACK_ID_FALLBACK[id]])
);
function mention(id) {
  const sid = SLACK_IDS[id];
  return sid ? `<@${sid}>` : `@${id}`;
}

function renderText(r) {
  const lines = [];
  lines.push(`Daily — ${r.dateStr} (${r.dayLabel}, W${r.week} D${r.dow})`);
  lines.push('');

  lines.push('Workboard progress (top-level)');
  const teamTotal = r.persons.reduce((a, p) => a + p.total, 0);
  const teamDone = r.persons.reduce((a, p) => a + p.done, 0);
  const teamPct = teamTotal > 0 ? Math.round((teamDone / teamTotal) * 100) : 0;
  lines.push(`  team ${teamPct}%  (${teamDone}/${teamTotal})`);
  for (const p of r.persons) {
    lines.push(`  · @${p.id.padEnd(15)} ${String(p.pct).padStart(3)}%  (${p.done}/${p.total})`);
  }
  lines.push('');

  const trackedGoals = r.teamPlanGoals.filter(g => g.total > 0);
  if (trackedGoals.length > 0) {
    lines.push('Team goals → milestone contribution');
    for (const g of trackedGoals) {
      const icon = g.checked || g.subProgress === 100 ? 'done' : '...';
      const msStr = g.milestoneAverage !== null ? `  → ${g.mappings.join('·')} avg ${g.milestoneAverage}%` : '';
      lines.push(`  · [${icon}] ${g.text} — ${g.subProgress}%${msStr}`);
    }
    lines.push('');
  }

  if (r.blockers.length > 0) {
    lines.push(`Blockers (${r.blockers.length})`);
    for (const b of r.blockers) lines.push(`  · @${b.from} — ${b.content}${b.target ? ` → ${b.target}` : ''}`);
    lines.push('');
  }

  if (r.dueRequests.length > 0) {
    lines.push(`Deadlines (${r.dueRequests.length})`);
    for (const x of r.dueRequests) {
      let label = x.daysLeft < 0 ? `OVERDUE ${-x.daysLeft}d` : x.daysLeft === 0 ? 'TODAY' : `D-${x.daysLeft}`;
      const proj = x.project ? `[${x.project}] ` : '';
      lines.push(`  · ${label}  ${proj}${x.content}  @${x.from} → @${x.to}`);
    }
    lines.push('');
  }

  if (r.stalePingpongs.length > 0) {
    lines.push(`Stale ping-pongs (${r.stalePingpongs.length}, 4+ days)`);
    for (const x of r.stalePingpongs) {
      const proj = x.project ? `[${x.project}] ` : '';
      lines.push(`  · ${proj}${x.content} — ${x.stalledDays}d / ${x.pingpong}`);
    }
  }

  return lines.join('\n').replace(/\n+$/, '');
}

function renderMrkdwn(r) {
  let txt = renderText(r);
  for (const id of Object.keys(SLACK_IDS)) txt = txt.split(`@${id}`).join(mention(id));
  return txt;
}

function renderBlocks(r) {
  const blocks = [];
  blocks.push({
    type: 'header',
    text: { type: 'plain_text', text: `Daily — ${r.dateStr} (${r.dayLabel}, W${r.week} D${r.dow})`, emoji: true },
  });

  {
    const lines = ['*Workboard progress* (top-level)'];
    const teamTotal = r.persons.reduce((a, p) => a + p.total, 0);
    const teamDone = r.persons.reduce((a, p) => a + p.done, 0);
    const teamPct = teamTotal > 0 ? Math.round((teamDone / teamTotal) * 100) : 0;
    lines.push(`team *${teamPct}%*  (${teamDone}/${teamTotal})`);
    for (const p of r.persons) lines.push(`• ${mention(p.id)}  *${p.pct}%*  (${p.done}/${p.total})`);
    blocks.push({ type: 'section', text: { type: 'mrkdwn', text: lines.join('\n') } });
  }

  const trackedGoals = r.teamPlanGoals.filter(g => g.total > 0);
  if (trackedGoals.length > 0) {
    const lines = ['*Team goals → milestone contribution*'];
    for (const g of trackedGoals) {
      const icon = g.checked || g.subProgress === 100 ? ':white_check_mark:' : ':hourglass:';
      const msStr = g.milestoneAverage !== null ? `  _→ ${g.mappings.join('·')} avg ${g.milestoneAverage}%_` : '';
      lines.push(`${icon} ${g.text} — *${g.subProgress}%*${msStr}`);
    }
    blocks.push({ type: 'section', text: { type: 'mrkdwn', text: lines.join('\n') } });
  }

  if (r.blockers.length > 0) {
    const lines = [`*Blockers* (${r.blockers.length})`];
    for (const b of r.blockers) lines.push(`• ${mention(b.from)} — ${b.content}${b.target ? ` → ${b.target}` : ''}`);
    blocks.push({ type: 'section', text: { type: 'mrkdwn', text: lines.join('\n') } });
  }

  if (r.dueRequests.length > 0) {
    const lines = [`*Deadlines* (${r.dueRequests.length})`];
    for (const x of r.dueRequests) {
      let label = x.daysLeft < 0 ? `:rotating_light: overdue ${-x.daysLeft}d`
                : x.daysLeft === 0 ? ':warning: today'
                : `:hourglass: D-${x.daysLeft}`;
      const proj = x.project ? `\`${x.project}\` ` : '';
      lines.push(`• ${label}  ${proj}${x.content}  ${mention(x.from)} → ${mention(x.to)}`);
    }
    blocks.push({ type: 'section', text: { type: 'mrkdwn', text: lines.join('\n') } });
  }

  if (r.stalePingpongs.length > 0) {
    const lines = [`*Stale ping-pongs* (${r.stalePingpongs.length}, 4+ days)`];
    for (const x of r.stalePingpongs) {
      const proj = x.project ? `\`${x.project}\` ` : '';
      lines.push(`• ${proj}${x.content} — ${x.stalledDays}d / ${x.pingpong}`);
    }
    blocks.push({ type: 'section', text: { type: 'mrkdwn', text: lines.join('\n') } });
  }

  return { blocks };
}

const r = build();
if (MODE === 'text') process.stdout.write(renderText(r) + '\n');
else if (MODE === 'mrkdwn') process.stdout.write(renderMrkdwn(r) + '\n');
else process.stdout.write(JSON.stringify(renderBlocks(r), null, 2) + '\n');
EOF_DAILY

# ─────────────────────────────────────────────────────────
# dashboard/cli.js — terminal briefing (English)
# ─────────────────────────────────────────────────────────
cat <<'EOF_CLI' > "$T/dashboard/cli.js"
#!/usr/bin/env node
/**
 * CLI briefing — read-only terminal view of the workboard.
 * Usage: node dashboard/cli.js [--user <id>]
 */

const path = require('node:path');
const { parseAll } = require('./lib/parser');

const ROOT = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const userIdx = args.indexOf('--user');
const FILTER_USER = userIdx >= 0 ? args[userIdx + 1] : null;

const C = {
  reset: '\x1b[0m', bold: '\x1b[1m', dim: '\x1b[2m',
  red: '\x1b[31m', green: '\x1b[32m', yellow: '\x1b[33m',
  blue: '\x1b[34m', magenta: '\x1b[35m', cyan: '\x1b[36m',
};

function header(label) {
  console.log('');
  console.log(`${C.bold}${C.cyan}── ${label} ──${C.reset}`);
}

function progressBar(pct, width = 20) {
  const filled = Math.round((pct / 100) * width);
  return `[${C.green}${'█'.repeat(filled)}${C.dim}${'░'.repeat(width - filled)}${C.reset}]`;
}

const data = parseAll(ROOT);

console.log(`${C.bold}Workboard${C.reset}  ${C.dim}${new Date().toISOString().slice(0, 10)}${C.reset}`);

header('Team progress (top-level)');
const persons = data.people.filter(p => !FILTER_USER || p.id === FILTER_USER);
let teamDone = 0, teamTotal = 0;
for (const p of persons) {
  const total = p.tree.length;
  const done = p.tree.filter(t => t.checked).length;
  teamDone += done; teamTotal += total;
  const pct = total > 0 ? Math.round((done / total) * 100) : 0;
  console.log(`  @${p.id.padEnd(20)} ${progressBar(pct)} ${String(pct).padStart(3)}%  (${done}/${total})`);
}
if (!FILTER_USER) {
  const teamPct = teamTotal > 0 ? Math.round((teamDone / teamTotal) * 100) : 0;
  console.log(`  ${C.bold}team total           ${progressBar(teamPct)} ${String(teamPct).padStart(3)}%  (${teamDone}/${teamTotal})${C.reset}`);
}

for (const p of persons) {
  if (p.tree.length === 0) continue;
  header(`@${p.id}${p.title ? ` — ${p.title}` : ''}`);
  for (const item of p.tree) {
    const mark = item.checked ? `${C.green}[x]${C.reset}` : `${C.dim}[ ]${C.reset}`;
    const proj = item.project ? `${C.yellow}[${item.project}]${C.reset} ` : '';
    const tagBits = Object.keys(item.tags).map(t => {
      const v = item.tags[t];
      return `${C.magenta}@${t}${v && v !== true ? `(${v})` : ''}${C.reset}`;
    });
    console.log(`  ${mark} ${proj}${item.text} ${tagBits.join(' ')}`);
    for (const child of item.children) {
      const cmark = child.checked ? `${C.green}[x]${C.reset}` : `${C.dim}[ ]${C.reset}`;
      const cTags = Object.keys(child.tags).map(t => {
        const v = child.tags[t];
        return `${C.magenta}@${t}${v && v !== true ? `(${v})` : ''}${C.reset}`;
      });
      console.log(`    ${cmark} ${child.text} ${cTags.join(' ')}`);
    }
  }
}

const incoming = FILTER_USER ? data.requests.filter(r => r.to === FILTER_USER) : data.requests;
if (incoming.length > 0) {
  header('Request queue' + (FILTER_USER ? ` (incoming for @${FILTER_USER})` : ''));
  for (const r of incoming) {
    const ping = r.pingpong ? ` ${C.yellow}🔄 ${r.pingpong}${C.reset}` : '';
    const dl = r.deadline ? ` ${C.red}⏰ ${r.deadline}${C.reset}` : '';
    console.log(`  ${C.dim}[${r.category}]${C.reset} @${r.from} → @${r.to}: ${r.project ? `[${r.project}] ` : ''}${r.content}${ping}${dl}`);
  }
}

if (data.blockers.length > 0) {
  header('Blockers');
  for (const b of data.blockers) {
    console.log(`  ${C.red}!${C.reset} @${b.from} — ${b.content}${b.target ? ` → ${b.target}` : ''}`);
  }
}

console.log('');
EOF_CLI

# ─────────────────────────────────────────────────────────
chmod +x \
  "$PLUGIN_ROOT/templates/.githooks/commit-msg" \
  "$PLUGIN_ROOT/templates/.githooks/pre-push" \
  "$PLUGIN_ROOT/templates/.claude/hooks/check-permissions.sh" \
  "$PLUGIN_ROOT/templates/.claude/hooks/remind-commit.sh" \
  "$T/scripts/setup.sh" \
  "$T/scripts/daily-report.js" \
  "$T/dashboard/cli.js"

echo "P5 templates installed under $T"
echo ""
echo "Created / updated:"
echo "  - .gitignore, log/.gitkeep"
echo "  - projects/_example/{overview,milestones,streams}.md"
echo "  - .claude/commands/{start-day,end-day,start-week,plan-week,wrap-week}.md"
echo "  - .github/workflows/{slack-notify,daily-report}.yml"
echo "  - scripts/{setup.sh,daily-report.js}"
echo "  - dashboard/lib/parser.js, dashboard/cli.js"
echo "  - CLAUDE.md (template with render markers)"
echo ""
echo "Deferred to v0.2 (separate task):"
echo "  - dashboard/server.js, dashboard/public/index.html  (web UI)"
