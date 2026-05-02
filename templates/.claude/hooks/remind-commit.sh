#!/usr/bin/env bash
# PostToolUse (Edit|Write) — nudge to commit after editing people/ files.
# Hook contract: env vars CLAUDE_FILE_PATH + CLAUDE_PROJECT_DIR.

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

case "$REL_PATH" in
  people/*) ;;
  *) exit 0 ;;
esac

DIRTY="$(git -C "$PROJECT_DIR" status --short 2>/dev/null | wc -l | tr -d ' ')"
if [ "${DIRTY:-0}" -gt 0 ]; then
  echo "Workboard updated. Don't forget to commit and push before you wrap up."
fi

exit 0
