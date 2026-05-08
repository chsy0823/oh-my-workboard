# oh-my-workboard — E2E Test Guide

Local test playbook. Run top to bottom on a clean machine (or a fresh shell session with no existing `~/.claude/workboard.json`). Each section lists the exact steps, the expected observable outcome, and what a failure looks like.

---

## Prerequisites

Install these before starting:

```bash
brew install node gh yq jq
gh auth login          # pick GitHub.com → HTTPS → browser
node --version         # must print something
```

---

## Part 1 — Plugin Installation

### 1-1. Install plugin from local repo

Claude Code does not yet have a live marketplace, so install from the local path directly.

Open Claude Code in **any** project directory (not the task repo yet). Then:

```
/plugin install /Users/elenore/Documents/develop/oh-my-workboard
```

**Expected:** Claude confirms the plugin is loaded. Running `/oh-my-workboard:doctor` in the next step should not error on "plugin not found".

**Failure signal:** "unknown command" when typing `/oh-my-workboard:`.

---

## Part 2 — Init (solo, global scope)

### 2-1. Run init

Still in any project directory:

```
/oh-my-workboard:init --solo --scope global
```

Answer the prompts:
- id: `testuser`
- name: `Test User`
- keywords: `testuser, test`
- role: `Engineer`
- slack_id: (leave blank)
- task repo path: `~/oh-my-workboard-test-repo`
- GitHub remote: (leave blank for now)
- session_brief opt-in: **y** ← important for Part 3 test
- wip_commit_prompt opt-in: **y** ← important for Part 10 test
- auto_dashboard: n

**Expected:**
- `~/oh-my-workboard-test-repo/` created and `git init`-ed
- `~/.claude/workboard.json` written with correct `"path"`
- `people/testuser.md` exists with current week header
- `.workboard/team.yaml` exists
- `.claude/settings.json`, all hook scripts, scripts/ all present

**Verify manually:**
```bash
cat ~/.claude/workboard.json
ls ~/oh-my-workboard-test-repo/people/
ls ~/oh-my-workboard-test-repo/.claude/hooks/
cat ~/oh-my-workboard-test-repo/.workboard/team.yaml
```

**Failure signal:** Any missing file, or `workboard.json` not written.

---

## Part 3 — SessionStart Hook (session-brief)

The plugin-level `SessionStart` hook fires `dispatch.sh scripts/session-brief.js`.
It must only produce output **inside the task repo** when `session_brief: true`.

### 3-1. Open Claude outside the task repo → silent

Open Claude Code in any other directory (e.g. `~/Documents`). Session start must be **silent** — no workboard output.

**Expected:** Normal Claude start, nothing about workboard.

### 3-2. Open Claude inside the task repo → brief fires

```bash
cd ~/oh-my-workboard-test-repo
# open Claude Code here
```

**Expected:** Brief printed at session start:
```
This Week's Tasks (W__)
  • No tasks yet

Requests for you: none
Blockers: none
```

**Failure signals:**
- Brief fires outside the task repo → dispatch.sh cwd guard broken
- Brief doesn't fire inside → `session_brief` toggle not read, or node error
- Error about missing `team.yaml` or config

---

## Part 4 — `doctor` and `where`

Open Claude inside the task repo:

```
/oh-my-workboard:doctor
```

**Expected:** All sections ✓:
- User config: resolved global `~/.claude/workboard.json`
- Task repo: exists, git repo, on `main`
- Team mapping: team.yaml parses, `testuser` active
- User resolution: `git config user.name` → `testuser`
- CLI prereqs: node ✓, yq ✓, jq ✓, gh ✓ + authenticated
- Hooks: settings.json valid, all hook scripts present and executable
- Skills: `.claude/skills/workboard-model/file-formats.md` and `lint-invariants.md` present
- Lint: 0 errors, 0 warnings
- Toggles: `session_brief: true`, `wip_commit_prompt: true`, `auto_dashboard: false`

```
/oh-my-workboard:where
```

**Expected:** Prints `~/.claude/workboard.json` (global) with resolved path.

---

## Part 5 — PreToolUse Hook (check-permissions)

### 5-1. Edit own workboard → allowed

Ask Claude to add any task to `people/testuser.md`. Edit should go through.

**Expected:** File written, no block message.

### 5-2. Edit another member's file → blocked

First create a second member:

```bash
cat >> ~/oh-my-workboard-test-repo/.workboard/team.yaml <<'EOF'

  - id: otherperson
    name: Other Person
    keywords: [otherperson]
    role: Designer
    active: true
EOF
cp ~/oh-my-workboard-test-repo/people/testuser.md \
   ~/oh-my-workboard-test-repo/people/otherperson.md
```

Then ask Claude to edit `people/otherperson.md`:

**Expected:** Hook blocks with:
```
BLOCK: You can only edit your own workboard under people/. (otherperson.md does not match your id: testuser)
```

### 5-3. Edit projects/ on main → blocked

Ask Claude to edit any file under `projects/`:

**Expected:**
```
BLOCK: projects/ and CLAUDE.md cannot be edited directly on main. Create a branch and open a PR.
```

---

## Part 6 — PostToolUse Hook (lint-workboard)

### 6-1. Valid edit → lint passes silently

Ask Claude: "add a task `[test] write E2E tests @today` to my workboard."

**Expected:** Edit goes through, no lint error.

### 6-2. Invalid edit → lint blocks

Ask Claude to add a malformed entry:

> "Add this to my workboard: `- [ ] @wait(otherperson: please review)`"

The `@wait(user: ...)` form violates the data model (R-series).

**Expected:** Lint hook fires, exits 1, Claude sees:
```
[workboard-lint] data-model violations detected — fix and retry.
```

---

## Part 7 — Mid-work Commands (cross-cwd, git context aware)

Open Claude in a **different** git project (your actual coding repo, not the task repo).

### 7-1. `/oh-my-workboard:done`

Say: "I just finished the auth refactor, PR #42."

**Expected:**
1. Claude reads `~/.claude/workboard.json` to locate task repo
2. Matches to a `@today` leaf (or prompts to add one)
3. Marks `[x] @done(YYYY-MM-DD)`, adds PR note bullet
4. Shows draft → asks "commit?"

Verify in task repo: `people/testuser.md` updated correctly.

### 7-2. `/oh-my-workboard:note`

Say: "log a note: decided to use Postgres over MySQL."

**Expected:** Note bullet appended under matched `@today` leaf.

### 7-3. `/oh-my-workboard:add`

Say: "add to my workboard: [test-project] write migration script."

**Expected:** New top-level leaf added under `## This Week's Tasks`.

### 7-4. `/oh-my-workboard:block`

Say: "I'm blocked on the infra team provisioning the staging DB."

**Expected:** Leaf tagged `@block(infra team: staging DB provisioning)`, entry added to `board/blockers.md`.

### 7-5. `/oh-my-workboard:request`

Say: "ask otherperson to review my PR #42."

**Expected:** Entry added to `board/requests.md` under `## PR Reviews` with `→ otherperson`.

### 7-6. `/oh-my-workboard:wait`

Say: "I'm waiting on RA approval before I can continue this."

**Expected:** Matched leaf tagged `@wait(RA approval)`, `@today` removed.

### 7-7. `/oh-my-workboard:status`

Say: "what's on my workboard?"

**Expected:** Read-only briefing. No file writes.

---

## Part 8 — Daily Ritual Commands

Run from **inside the task repo**.

### 8-1. `/oh-my-workboard:start-day`

**Expected:**
- Reads `people/testuser.md`
- Checks `board/requests.md` for incoming requests
- Scans other members' files for `@wait(testuser: ...)`
- Prints structured briefing

### 8-2. `/oh-my-workboard:end-day`

**Expected:**
- Walks each `@today` leaf: done / partial / missed
- Prompts for handoffs → writes `@handoff` tag + `## Handoffs` entry in `board/requests.md`
- Shows draft, asks "commit?"

---

## Part 9 — Cascading Config (local overrides global)

### 9-1. Write a local config in a project repo

```bash
cd ~/Documents/some-other-project   # any git repo
cat > .workboard.json <<'EOF'
{
  "mode": "solo",
  "path": "/tmp/another-task-repo",
  "remote": null,
  "session_brief": false,
  "wip_commit_prompt": false,
  "auto_dashboard": false
}
EOF
```

### 9-2. Verify `where` picks up local

Open Claude in `some-other-project`:

```
/oh-my-workboard:where
```

**Expected:** Prints local `.workboard.json` from `some-other-project/` — NOT `~/.claude/workboard.json`.

### 9-3. Verify toggle override

Since `session_brief: false` in local config, session brief must be silent.

### 9-4. Cleanup

```bash
rm ~/Documents/some-other-project/.workboard.json
```

---

## Part 10 — Stop Hook (uncommitted-reminder)

### 10-1. Leave uncommitted changes and close the session

Make an edit in the task repo but do **not** commit. Then close Claude (Ctrl+C or `/exit`).

**Expected:** Prompt appears:
```
[oh-my-workboard] You have uncommitted workboard changes. Commit before closing?
```

No automatic commit — prompt only.

**Failure signal:** No prompt → toggle not read or Stop hook not firing.

---

## Part 11 — `discuss` command + `workboard-discuss` skill

Requires `gh` authenticated and `remote` set in config (re-run init with a GitHub remote if needed).

### 11-1. Command

Inside task repo:

```
/oh-my-workboard:discuss
```

Provide title and body.

**Expected:**
- Issue preview shown
- "create issue on {remote}? [y/N]" prompt
- On `y`: `gh issue create` runs, URL printed
- Optional cross-link to `@today` leaf

### 11-2. Skill auto-trigger

Write a multi-paragraph proposal in chat (no command invocation):

> "I want to share this with the team: we should migrate to a monorepo. Here's why: [three paragraphs]"

**Expected:** `workboard-discuss` skill fires, body pre-filled from your text, asks for confirmation before creating issue.

**Must NOT fire on:** one-liners, questions, or casual mentions.

---

## Part 12 — Lint command

Inside task repo:

```
/oh-my-workboard:lint
```

**Expected:** Runs `node scripts/lint-workboard.js`, prints R1–R8 results. Clean repo: `0 errors, 0 warnings`.

---

## Cleanup

```bash
rm -rf ~/oh-my-workboard-test-repo
rm ~/.claude/workboard.json
```

---

## Failure triage quick-reference

| Symptom | Likely cause | Where to look |
|---------|-------------|---------------|
| Session brief fires outside task repo | cwd guard not applied | `hooks/dispatch.sh` prefix match |
| Session brief never fires inside task repo | `session_brief` toggle false, or node error | `scripts/session-brief.js`, `workboard.json` |
| Permission hook doesn't block | `CLAUDE_FILE_PATH`/`CLAUDE_PROJECT_DIR` not set | `templates/.claude/settings.json` matcher |
| Lint hook doesn't run | `node` not in PATH, or file path not matching case | `lint-workboard.sh` line 20 path filter |
| `where` shows wrong config | Local `.workboard.json` shadowing unexpectedly | `dispatch.sh` config resolution order |
| `done`/`add`/`note` can't find task repo | `path` field missing or wrong in resolved config | `~/.claude/workboard.json` |
| `discuss` fails | `gh` not authenticated, or `remote` not set | `gh auth status`, `where` output |
| Stop hook prompt never appears | `wip_commit_prompt` toggle false, or Stop hook not registered | `hooks/hooks.json`, `workboard.json` |
