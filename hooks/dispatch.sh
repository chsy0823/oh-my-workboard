#!/usr/bin/env bash
# Plugin-level hook dispatcher.
#
# Reads ~/.claude/workboard.json `.path` and fires the named hook script in
# the configured task repo only when the current cwd matches that path.
# This keeps plugin-level hooks scoped to task-repo sessions; outside the
# task repo, the dispatcher is a no-op.
#
# Usage: dispatch.sh <relative-script-path>
#   e.g. dispatch.sh scripts/session-brief.js
#        dispatch.sh .claude/hooks/uncommitted-reminder.sh
#
# Exit: always 0 (plugin hooks must not block).

set -u
TARGET="${1:-}"
[ -z "$TARGET" ] && exit 0

# Resolve workboard config: local (project root .workboard.json) wins over global.
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
LOCAL_JSON="$PROJECT_ROOT/.workboard.json"
GLOBAL_JSON="$HOME/.claude/workboard.json"
if [ -f "$LOCAL_JSON" ]; then
  WORKBOARD_JSON="$LOCAL_JSON"
elif [ -f "$GLOBAL_JSON" ]; then
  WORKBOARD_JSON="$GLOBAL_JSON"
else
  exit 0
fi

# Resolve task repo path. Prefer jq; fall back to grep+sed.
WB_PATH=""
if command -v jq >/dev/null 2>&1; then
  WB_PATH="$(jq -r '.path // empty' "$WORKBOARD_JSON" 2>/dev/null)"
fi
if [ -z "$WB_PATH" ]; then
  WB_PATH="$(grep -oE '"path"[[:space:]]*:[[:space:]]*"[^"]+"' "$WORKBOARD_JSON" 2>/dev/null | sed -E 's/.*"([^"]+)"[^"]*$/\1/' | head -1)"
fi
[ -z "$WB_PATH" ] && exit 0

# Only fire when the user is inside the configured task repo.
[ "$PWD" != "$WB_PATH" ] && exit 0

SCRIPT_PATH="$WB_PATH/$TARGET"
[ ! -f "$SCRIPT_PATH" ] && exit 0

export CLAUDE_PROJECT_DIR="$WB_PATH"

case "$TARGET" in
  *.js)
    command -v node >/dev/null 2>&1 || exit 0
    node "$SCRIPT_PATH" 2>/dev/null || true
    ;;
  *.sh)
    bash "$SCRIPT_PATH" 2>/dev/null || true
    ;;
esac

exit 0
