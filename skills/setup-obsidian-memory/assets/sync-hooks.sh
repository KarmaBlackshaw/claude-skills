#!/usr/bin/env bash
# Install-or-update the Obsidian memory hooks in a repo. Copies the CURRENT hook
# scripts from this skill into <repo>/.claude/hooks/ and idempotently registers
# them in settings.local.json. Safe to re-run — this is the single command for
# both first-time install and propagating a later hook change to a wired repo
# (no manual cp, no manual settings editing).
# Usage: sync-hooks.sh <repo-root>
set -euo pipefail

REPO="${1:?usage: sync-hooks.sh <repo-root>}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$REPO/.claude/hooks"
cp "$SRC/obsidian-recall.sh" "$SRC/obsidian-push.sh" "$REPO/.claude/hooks/"
chmod +x "$REPO/.claude/hooks/obsidian-recall.sh" "$REPO/.claude/hooks/obsidian-push.sh"

bash "$SRC/register-hooks.sh" "$REPO"   # merges hooks into settings.local.json if absent
echo "synced hooks ✓ ($REPO)"
