#!/usr/bin/env bash
# Idempotently register the Obsidian memory hooks in the GLOBAL
# ~/.claude/settings.json — one registration for the whole machine. Each hook
# script no-ops unless the session's repo has a CLAUDE.local.md, so wiring stays
# per-repo via that pointer file while the scripts (~/.claude/hooks) and the
# registration live in exactly one place. Adds each hook only if its exact
# command isn't already present, and never touches other tools' hooks.
#
#   SessionStart : obsidian-recall.sh  (matcher: startup|resume|clear|fork — skip
#                                       compact so a full re-inject doesn't land
#                                       right after compaction)
#   SessionStart : obsidian-drain.sh   (async catch-up net; primary drain is the
#                                       detached one kicked by capture)
#   SessionEnd   : obsidian-capture.sh (synchronous + timeout — never async, or
#                                       it can be killed mid-write at teardown)
#   UserPromptSubmit / PreToolUse(Edit|Write|Read|ctx_edit|ctx_read) : obsidian-retrieve.sh
#                                       (point-of-use lesson bodies for the file
#                                       about to be edited OR read — read-only
#                                       reviewer subagents get lessons too)
# Usage: register-hooks.sh   (override target with CLAUDE_SETTINGS=…)
set -euo pipefail

S="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
mkdir -p "$(dirname "$S")"
[ -f "$S" ] || echo '{}' > "$S"

H="$HOME/.claude/hooks"
RECALL="bash \"$H/obsidian-recall.sh\" SessionStart"
RETRIEVE_MATCHER="Edit|Write|MultiEdit|Read|mcp__lean-ctx__ctx_edit|mcp__lean-ctx__ctx_read"
DRAIN="bash \"$H/obsidian-drain.sh\""
CAPTURE="bash \"$H/obsidian-capture.sh\""
RETRIEVE="bash \"$H/obsidian-retrieve.sh\""

tmp="$(mktemp)"
jq --arg recall "$RECALL" --arg drain "$DRAIN" --arg capture "$CAPTURE" --arg retrieve "$RETRIEVE" --arg rm "$RETRIEVE_MATCHER" '
  def present(cmd; ev): ([ (.hooks[ev] // [])[].hooks[]?.command ] | any(. == cmd));
  .hooks = (.hooks // {})
  | (if present($recall; "SessionStart") then . else
      .hooks.SessionStart = ((.hooks.SessionStart // []) +
        [{matcher:"startup|resume|clear|fork",
          hooks:[{type:"command",command:$recall,statusMessage:"Loading Obsidian memory"}]}]) end)
  | (if present($drain; "SessionStart") then . else
      .hooks.SessionStart = ((.hooks.SessionStart // []) +
        [{hooks:[{type:"command",command:$drain,async:true,statusMessage:"Draining Obsidian memory queue"}]}]) end)
  | (if present($capture; "SessionEnd") then . else
      .hooks.SessionEnd = ((.hooks.SessionEnd // []) +
        [{hooks:[{type:"command",command:$capture,timeout:5,statusMessage:"Queuing session for Obsidian"}]}]) end)
  | (if present($retrieve; "UserPromptSubmit") then . else
      .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) +
        [{hooks:[{type:"command",command:$retrieve,timeout:5}]}]) end)
  # Retired: SubagentStart recall — the always-on tiers now reach subagents via
  # CLAUDE.md imports (register-imports.sh). Drop a stale registration.
  | .hooks.SubagentStart = ((.hooks.SubagentStart // []) | map(select(([.hooks[]?.command] | any(test("obsidian-recall.sh\" SubagentStart"))) | not)))
  | (if (.hooks.SubagentStart | length) == 0 then del(.hooks.SubagentStart) else . end)
  | (if present($retrieve; "PreToolUse") then . else
      .hooks.PreToolUse = ((.hooks.PreToolUse // []) +
        [{matcher:$rm,hooks:[{type:"command",command:$retrieve,timeout:5}]}]) end)
  # Matcher may have widened since first registration — refresh it in place.
  | .hooks.PreToolUse |= map(if ([.hooks[]?.command] | any(. == $retrieve)) then .matcher = $rm else . end)
' "$S" > "$tmp" && mv "$tmp" "$S"

jq empty "$S" && echo "registered global obsidian hooks ✓ ($S)"
