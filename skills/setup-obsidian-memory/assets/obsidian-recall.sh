#!/usr/bin/env bash
# Injects Obsidian long-term memory (Learnings + Active Context) into context.
# SessionStart hook. Reads absolute vault paths from the repo's gitignored
# CLAUDE.local.md so no personal paths live in git.
# No-ops silently if CLAUDE.local.md or the target files are missing.
# Arg $1 = hook event name (default: SessionStart).
set -euo pipefail

EVENT="${1:-SessionStart}"
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PTR="$ROOT/CLAUDE.local.md"
[ -f "$PTR" ] || exit 0

# Value after the first '=' for a KEY line (paths may contain spaces).
getpath() { grep -m1 "^$1=" "$PTR" 2>/dev/null | cut -d= -f2- || true; }

LEARNINGS="$(getpath LEARNINGS)"
ACTIVE="$(getpath ACTIVE_CONTEXT)"

out=""
if [ -n "$LEARNINGS" ] && [ -f "$LEARNINGS" ]; then
  out+="# Global Master Learnings (Obsidian hub)"$'\n\n'"$(cat "$LEARNINGS")"$'\n\n'
fi
if [ -n "$ACTIVE" ] && [ -f "$ACTIVE" ]; then
  out+="# Active Context — this repo (Obsidian spoke)"$'\n\n'"$(cat "$ACTIVE")"$'\n'
fi

[ -z "$out" ] && exit 0

jq -n --arg e "$EVENT" --arg c "Obsidian long-term memory (hub-and-spoke). Read before architectural changes; persist with /sync-brain push.

$out" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
