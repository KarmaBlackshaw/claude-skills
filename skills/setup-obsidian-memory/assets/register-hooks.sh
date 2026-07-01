#!/usr/bin/env bash
# Idempotently register the Obsidian memory hooks in a repo's
# .claude/settings.local.json. Adds SessionStart(obsidian-recall) and
# Stop(obsidian-push) only if that exact command isn't already present, so
# re-runs are safe. Preserves all existing settings/hooks.
# Usage: register-hooks.sh <repo-root>
set -euo pipefail

REPO="${1:?usage: register-hooks.sh <repo-root>}"
S="$REPO/.claude/settings.local.json"
mkdir -p "$REPO/.claude"
[ -f "$S" ] || echo '{}' > "$S"

RECALL='bash "$CLAUDE_PROJECT_DIR/.claude/hooks/obsidian-recall.sh" SessionStart'
PUSH='bash "$CLAUDE_PROJECT_DIR/.claude/hooks/obsidian-push.sh"'

tmp="$(mktemp)"
jq --arg recall "$RECALL" --arg push "$PUSH" '
  def present(cmd; ev): ([ (.hooks[ev] // [])[].hooks[]?.command ] | any(. == cmd));
  .hooks = (.hooks // {})
  | (if present($recall; "SessionStart") then .
     else .hooks.SessionStart = ((.hooks.SessionStart // []) +
       [{hooks:[{type:"command",command:$recall,statusMessage:"Loading Obsidian memory"}]}]) end)
  | (if present($push; "Stop") then .
     else .hooks.Stop = ((.hooks.Stop // []) +
       [{hooks:[{type:"command",command:$push,statusMessage:"Saving to Obsidian"}]}]) end)
' "$S" > "$tmp" && mv "$tmp" "$S"

jq empty "$S" && echo "registered ✓ ($S)"
