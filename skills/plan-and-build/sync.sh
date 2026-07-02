#!/usr/bin/env bash
# Install-or-update the plan-and-build skill on this machine from a single source.
# Copies the skill dir (this script's dir) into ~/.claude/skills/plan-and-build AND
# registers its agents into ~/.claude/agents/ (the flat dir Claude Code dispatches from).
# Safe to re-run — one command for first-time install and for propagating any later
# edit, so the skill copy and the registered agents can never silently drift.
#
# Usage:
#   ./sync.sh            install/update skill + register agents
#   ./sync.sh --check    report drift only (no writes); exit 1 if out of sync
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DEST="${PB_SKILL_DEST:-$HOME/.claude/skills/plan-and-build}"
AGENTS_DEST="${PB_AGENTS_DEST:-$HOME/.claude/agents}"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

agents() { find "$SRC/agents" -maxdepth 1 -name '*.md' -exec basename {} \; ; }

if [ "$CHECK" = 1 ]; then
  drift=0
  # skill files (SRC is authoritative)
  if [ "$SRC" -ef "$SKILL_DEST" ] 2>/dev/null; then
    echo "skill: SRC is the install dir (in place)"
  elif diff -rq --exclude='.git' "$SRC" "$SKILL_DEST" >/dev/null 2>&1; then
    echo "skill: in sync ✓"
  else
    echo "skill: DRIFT vs $SKILL_DEST"; drift=1
  fi
  # registered agents
  while IFS= read -r a; do
    if diff -q "$SRC/agents/$a" "$AGENTS_DEST/$a" >/dev/null 2>&1; then
      echo "agent $a: in sync ✓"
    else
      echo "agent $a: DRIFT (or missing) vs $AGENTS_DEST"; drift=1
    fi
  done < <(agents)
  exit "$drift"
fi

# 1. Skill files → ~/.claude/skills/plan-and-build (mirror; SRC is source of truth)
if [ "$SRC" -ef "$SKILL_DEST" ] 2>/dev/null; then
  echo "skill: already at install dir, skipping self-copy"
else
  mkdir -p "$SKILL_DEST"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude='.git' "$SRC"/ "$SKILL_DEST"/
  else
    rm -rf "$SKILL_DEST"; mkdir -p "$SKILL_DEST"; cp -R "$SRC"/. "$SKILL_DEST"/
  fi
  echo "skill: synced → $SKILL_DEST"
fi

# 2. Agents → ~/.claude/agents/ (register; overwrite only our own, never --delete others)
mkdir -p "$AGENTS_DEST"
n=0
while IFS= read -r a; do
  cp -f "$SRC/agents/$a" "$AGENTS_DEST/$a"; n=$((n+1))
done < <(agents)
echo "agents: registered $n → $AGENTS_DEST"
echo "plan-and-build synced ✓"
