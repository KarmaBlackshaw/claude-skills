#!/usr/bin/env bash
# Injects Obsidian long-term memory (Learnings + Coding Rules + Active Context) into context.
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
RULES="$(getpath CODING_RULES)"
ACTIVE="$(getpath ACTIVE_CONTEXT)"
THREADS="$(getpath THREADS)"

out=""
if [ -n "$LEARNINGS" ] && [ -f "$LEARNINGS" ]; then
  out+="# Global Master Learnings (Obsidian hub — index)"$'\n\n'"$(cat "$LEARNINGS")"$'\n\n'
  # Expand every atomic lesson note. The notes folder is the hub file without its
  # extension: <vault>/Learnings.md -> <vault>/Learnings/. Index + full detail.
  NOTES_DIR="${LEARNINGS%.md}"
  if [ -d "$NOTES_DIR" ]; then
    shopt -s nullglob
    for note in "$NOTES_DIR"/*.md; do
      out+="## Lesson: $(basename "${note%.md}")"$'\n\n'"$(cat "$note")"$'\n\n'
    done
    shopt -u nullglob
  fi
fi
if [ -n "$RULES" ] && [ -f "$RULES" ]; then
  out+="# Coding Rules — this repo (Obsidian spoke)"$'\n\n'"$(cat "$RULES")"$'\n\n'
fi
if [ -n "$ACTIVE" ] && [ -f "$ACTIVE" ]; then
  out+="# Active Context — this repo (Obsidian spoke)"$'\n\n'"$(cat "$ACTIVE")"$'\n'
fi
# Open threads: inject only the ledger's `open` rows — unfinished action items
# that survived session rotation. Done rows stay out of context.
if [ -n "$THREADS" ] && [ -f "$THREADS" ]; then
  open_rows="$(grep -E '^\|[[:space:]]*open[[:space:]]*\|' "$THREADS" 2>/dev/null || true)"
  if [ -n "$open_rows" ]; then
    out+=$'\n'"# Open Threads — this repo (unfinished action items; close them or they carry forward)"$'\n\n'"| status | thread | opened | source |"$'\n'"|---|---|---|---|"$'\n'"$open_rows"$'\n'
  fi
fi

[ -z "$out" ] && exit 0

jq -n --arg e "$EVENT" --arg c "Obsidian long-term memory (hub-and-spoke). Read before architectural changes; persist with /sync-brain push.

$out" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
