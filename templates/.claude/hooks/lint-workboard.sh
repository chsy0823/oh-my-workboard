#!/usr/bin/env bash
# PostToolUse (Edit|Write) — workboard data-model lint.
# Fires only on workboard-related files; if scripts/lint-workboard.js reports errors,
# exits 2 to send feedback to Claude. Hook contract: $CLAUDE_FILE_PATH + $CLAUDE_PROJECT_DIR.

set -u
FILE="${CLAUDE_FILE_PATH:-}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"

if [ -z "$FILE" ] || [ -z "$PROJECT_DIR" ]; then
  exit 0
fi
case "$FILE" in
  "$PROJECT_DIR"/*) REL_PATH="${FILE#$PROJECT_DIR/}" ;;
  *) exit 0 ;;
esac

# Only lint when a workboard-affecting file is touched.
case "$REL_PATH" in
  people/*.md|board/requests.md|board/status.md|board/blockers.md|board/backlog.md|projects/*/milestones.md)
    ;;
  *)
    exit 0
    ;;
esac

# Skip silently if Node is unavailable (avoid false blocks).
if ! command -v node >/dev/null 2>&1; then
  exit 0
fi

OUTPUT=$(cd "$PROJECT_DIR" && node scripts/lint-workboard.js --errors-only --quiet 2>&1)
RC=$?

if [ "$RC" -ne 0 ]; then
  echo "[workboard-lint] data-model violations detected — fix and retry." >&2
  echo "$OUTPUT" >&2
  exit 2
fi

exit 0
