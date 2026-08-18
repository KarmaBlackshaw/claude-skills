#!/usr/bin/env bash
# Migrate ONE repo off per-repo Obsidian hooks, now that the scripts and their
# registration live globally (~/.claude/hooks + ~/.claude/settings.json). Without
# this, a repo that still registers the hooks locally fires them TWICE per event
# (double memory injection, double capture) once the global registration exists.
#
# What it does, idempotently:
#   1. Back up <repo>/.claude/settings.local.json -> *.pre-global.bak
#   2. Remove any SessionStart/Stop/SessionEnd hook whose command references an
#      obsidian-*.sh script; drop groups/events left empty; drop .hooks if empty.
#      Every non-obsidian hook and all other settings are preserved untouched.
#   3. Delete the now-dead repo-local hook scripts (and .claude/hooks if empty).
# Usage: migrate-to-global.sh <repo-root>
set -euo pipefail

REPO="${1:?usage: migrate-to-global.sh <repo-root>}"
S="$REPO/.claude/settings.local.json"

if [ -f "$S" ]; then
  cp "$S" "$S.pre-global.bak"
  tmp="$(mktemp)"
  jq '
    def strip(ev):
      if (.hooks[ev]?) then
        .hooks[ev] |= ( map(.hooks |= map(select((.command // "") | test("obsidian-.*\\.sh") | not)))
                        | map(select((.hooks | length) > 0)) )
        | (if ((.hooks[ev] | length) == 0) then del(.hooks[ev]) else . end)
      else . end;
    if (.hooks?) then
      strip("SessionStart") | strip("Stop") | strip("SessionEnd")
      | (if ((.hooks | length) == 0) then del(.hooks) else . end)
    else . end
  ' "$S" > "$tmp" && mv "$tmp" "$S"
  jq empty "$S"
fi

rm -f "$REPO/.claude/hooks/obsidian-recall.sh" \
      "$REPO/.claude/hooks/obsidian-push.sh" \
      "$REPO/.claude/hooks/obsidian-capture.sh" \
      "$REPO/.claude/hooks/obsidian-drain.sh" \
      "$REPO/.claude/hooks/test_capture_drain.sh" \
      "$REPO/.claude/hooks/test_upsert.sh" 2>/dev/null || true
rmdir "$REPO/.claude/hooks" 2>/dev/null || true   # only succeeds if now empty
echo "migrated to global ✓ ($REPO)"
