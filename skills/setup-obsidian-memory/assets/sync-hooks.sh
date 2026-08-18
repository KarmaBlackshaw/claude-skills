#!/usr/bin/env bash
# Install-or-update the Obsidian memory hooks GLOBALLY. Copies the current hook
# scripts from this skill into ~/.claude/hooks/ and idempotently registers them
# in ~/.claude/settings.json. Safe to re-run — this is the single command for
# first-time install AND for propagating a later hook change machine-wide. One
# copy, one patch point; wiring per repo is just the presence of CLAUDE.local.md.
# Usage: sync-hooks.sh   (override dest with CLAUDE_HOOKS_DIR=…)
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_HOOKS_DIR:-$HOME/.claude/hooks}"
mkdir -p "$DEST"

# obsidian-push.sh is retired (superseded by capture/drain) — not installed.
for f in obsidian-recall.sh obsidian-capture.sh obsidian-drain.sh; do
  cp "$SRC/$f" "$DEST/$f"; chmod +x "$DEST/$f"
done

bash "$SRC/register-hooks.sh"
echo "synced global hooks ✓ ($DEST)"
