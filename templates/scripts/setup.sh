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
