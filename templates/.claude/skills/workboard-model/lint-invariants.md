---
name: workboard-lint-invariants
description: Workboard lint invariants R1–R8 and parsing regexes. Reference when writing or debugging lint-workboard.js, CI validation rules, or new validators. Not needed for normal slash command operation.
---

# Workboard Lint Invariants

## Parsing rules (AI / dashboard / lint)

- Task line regex: `^\s*- \[[ x]\] `
- Tag extraction: from end of line, repeatedly match `@\w+(\([^)]*\))?` until first non-match.
- Today's work: tree-wide leaves with `@today`.
- Waits / blockers: leaves with `@wait` or `@block`.
- Team-level blockers: `board/blockers.md` (separate from workboard).

Reference implementation: `dashboard/lib/parser.js`. Lint entry point: `scripts/lint-workboard.js`.

## Invariants R1–R8

`scripts/lint-workboard.js` validates these 8 rules on every workboard edit (PostToolUse hook) and in CI.

| Rule | Description |
|------|-------------|
| **R1** | Every entry in `board/requests.md` has a `[project]` prefix. |
| **R2** | `people/*.md` contains no `@wait(user: action)` form. Cross-member dependencies must use `requests.md`. |
| **R3** | No workboard `@today` leaf duplicates a `requests.md` entry's content. |
| **R4** | Every `status.md` team-plan sub matches the named owner's workboard top-level leaf text. |
| **R5** | `@today` appears only on leaves (never on a node that has children). |
| **R6** | `@done` and `[x]` are consistent — `[x]` leaves carry `@done(YYYY-MM-DD)`. |
| **R7** | Only allowed tags present (`today / done / wait / block / handoff`); unknown tags flagged. |
| **R8** | `@done(YYYY-MM-DD)` date is parseable as a real date in valid format. |

Errors exit 1 from the PostToolUse hook locally and fail the CI gate in pull requests.
