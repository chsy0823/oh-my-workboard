#!/usr/bin/env bash
# Stop hook — surface uncommitted workboard changes when the session ends.
# Prompt only — never invokes git commit. Default off; toggle in ~/.claude/workboard.json.
#
# Env: CLAUDE_PROJECT_DIR
# Exit: always 0 (non-blocking).

set -u
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
[ -z "$PROJECT_DIR" ] && exit 0
[ ! -d "$PROJECT_DIR/.git" ] && exit 0

# Toggle gate — only fire when the user opted in.
WORKBOARD_JSON="$HOME/.claude/workboard.json"
if [ ! -f "$WORKBOARD_JSON" ]; then
  exit 0
fi
ENABLED="false"
if command -v jq >/dev/null 2>&1; then
  ENABLED="$(jq -r '.wip_commit_prompt // false' "$WORKBOARD_JSON" 2>/dev/null || echo "false")"
else
  if grep -qE '"wip_commit_prompt"\s*:\s*true' "$WORKBOARD_JSON"; then
    ENABLED="true"
  fi
fi
[ "$ENABLED" != "true" ] && exit 0

cd "$PROJECT_DIR" || exit 0

# Surface uncommitted changes only inside workboard data areas.
CHANGES=$(git status --porcelain people/ board/ log/ 2>/dev/null)
[ -z "$CHANGES" ] && exit 0

COUNT=$(printf '%s\n' "$CHANGES" | wc -l | tr -d ' ')

echo "" >&2
echo "[stop] Uncommitted workboard changes ($COUNT files):" >&2
printf '%s\n' "$CHANGES" | sed 's/^/  /' >&2
echo "" >&2
echo "  To wrap up:  git add -A && git commit -m '[me] ...' && git push" >&2
echo "  (auto-commit is intentionally not done — confirm intent before running.)" >&2

exit 0
