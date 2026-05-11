#!/usr/bin/env bash
# PreToolUse (Bash) — lint gate before git commit inside Claude.
# Reads tool input JSON from stdin; intercepts "git commit" calls.
# --no-verify: warn and allow (emergency bypass). Lint fail: exit 1 (block).

set -u

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

case "$COMMAND" in
  *"--no-verify"*)
    echo "[workboard-lint] WARNING: --no-verify bypasses lint. Proceeding." >&2
    exit 0
    ;;
esac

if ! command -v node >/dev/null 2>&1; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
if [ -z "$PROJECT_DIR" ]; then
  exit 0
fi

OUTPUT=$(cd "$PROJECT_DIR" && node scripts/lint-workboard.js --errors-only --quiet 2>&1)
RC=$?

if [ "$RC" -ne 0 ]; then
  echo "[workboard-lint] Commit blocked — fix violations before committing:" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

exit 0
