# /oh-my-workboard:doctor

Health check for the plugin + task repo configuration.

## Execution

Print sections (each with ✓ or ✗):

1. **User config**: resolved config (local or global) exists, `path` resolves, `mode` valid; print which file was used.
2. **Task repo**: directory exists, is a git repo, on `main` (or report current branch).
3. **Team mapping**: `.workboard/team.yaml` exists, parses, leader present, ≥1 active member.
4. **User resolution**: `git config user.name` resolves to a member id via id/name/keywords; print the resolved id.
5. **CLI prereqs**:
   - `gh` CLI installed → `gh --version`; `gh auth status` succeeds. Required for `/oh-my-workboard:discuss`.
   - `node` installed (required for `scripts/*.js`).
   - `yq` installed (preferred; awk/grep fallback exists).
   - `jq` installed (preferred for hook toggle gating; grep fallback exists).
6. **Hooks**:
   - `.claude/settings.json` exists, valid JSON
   - PostToolUse hooks present (lint-workboard.sh, remind-commit.sh)
   - PreToolUse hooks present (check-permissions.sh)
   - All hook scripts present and executable
7. **Skills**: `.claude/skills/workboard-model/SKILL.md` exists.
8. **Slack** (if configured): each `SLACK_ID_{id}` env in workflows resolves; `SLACK_WEBHOOK_URL` secret exists (or report unset).
9. **Lint**: run `node scripts/lint-workboard.js --quiet` and report errors / warnings count.
10. **Legacy format**: scan `people/*.md` for old-style sections (`## In Progress`, `## Waiting`, etc.); flag any.
11. **Toggle flags**: report `session_brief`, `wip_commit_prompt`, `auto_dashboard` states.

## Notes

- Read-only. Never modifies anything.
- Useful as the first command to run after `init` or after a plugin update.
