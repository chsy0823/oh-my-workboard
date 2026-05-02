#!/usr/bin/env bash
# PreToolUse (Edit|Write) — file ownership + main branch protection.
# Driven by .workboard/team.yaml. Hook contract: env vars CLAUDE_FILE_PATH + CLAUDE_PROJECT_DIR.

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

TEAM_YAML="$PROJECT_DIR/.workboard/team.yaml"
[ ! -f "$TEAM_YAML" ] && exit 0

GIT_USER="$(git -C "$PROJECT_DIR" config user.name 2>/dev/null || echo "")"
USER_LOWER="$(printf '%s' "$GIT_USER" | tr '[:upper:]' '[:lower:]')"
BRANCH="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"

LEADER=""
MY_ID=""

if command -v yq >/dev/null 2>&1; then
  LEADER="$(yq e '.leader' "$TEAM_YAML" 2>/dev/null || echo "")"
  [ "$LEADER" = "null" ] && LEADER=""
  if [ -n "$USER_LOWER" ]; then
    MY_ID="$(yq e "
      .members[] |
      select(.active == true) |
      select(
        (.id | ascii_downcase | test(\"$USER_LOWER\")) or
        (.name | ascii_downcase | test(\"$USER_LOWER\")) or
        ((.keywords // []) | .[] | ascii_downcase | test(\"$USER_LOWER\"))
      ) | .id
    " "$TEAM_YAML" 2>/dev/null | head -1 || echo "")"
    [ "$MY_ID" = "null" ] && MY_ID=""
  fi
else
  LEADER="$(grep -E '^leader:' "$TEAM_YAML" | awk '{print $2}' | tr -d '"' | head -1 || echo "")"
  if [ -n "$USER_LOWER" ]; then
    cur_id=""
    cur_active="true"
    while IFS= read -r line; do
      case "$line" in
        '  - id:'*|'- id:'*)
          cur_id="$(printf '%s\n' "$line" | sed -E 's/.*id:[[:space:]]*//' | tr -d '"' | tr -d "'" | xargs)"
          cur_active="true"
          ;;
        *'active:'*)
          cur_active="$(printf '%s\n' "$line" | sed -E 's/.*active:[[:space:]]*//' | tr -d '"' | xargs)"
          ;;
      esac
      if [ "$cur_active" = "true" ] && [ -n "$cur_id" ]; then
        if printf '%s\n' "$line" | tr '[:upper:]' '[:lower:]' | grep -q "$USER_LOWER"; then
          MY_ID="$cur_id"
          break
        fi
      fi
    done < "$TEAM_YAML"
  fi
fi

IS_LEADER=0
[ -n "$LEADER" ] && [ "$MY_ID" = "$LEADER" ] && IS_LEADER=1

# Rule 1: people/ — non-leader can only edit own file
case "$REL_PATH" in
  people/*)
    if [ "$IS_LEADER" = "1" ]; then
      exit 0
    fi
    FILENAME="$(basename "$REL_PATH" .md)"
    if [ -n "$MY_ID" ] && [ "$FILENAME" != "$MY_ID" ]; then
      echo "BLOCK: You can only edit your own workboard under people/. ($FILENAME.md does not match your id: $MY_ID)" >&2
      exit 1
    fi
    ;;
esac

# Rule 2: projects/ and CLAUDE.md — non-leader cannot edit on main (allow .template)
if [ "$BRANCH" = "main" ] && [ "$IS_LEADER" != "1" ]; then
  case "$REL_PATH" in
    projects/*|CLAUDE.md)
      case "$REL_PATH" in
        *.template*|*/.template/*) exit 0 ;;
      esac
      echo "BLOCK: projects/ and CLAUDE.md cannot be edited directly on main. Create a branch and open a PR." >&2
      exit 1
      ;;
  esac
fi

exit 0
