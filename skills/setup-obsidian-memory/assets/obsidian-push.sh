#!/usr/bin/env bash
# Stop hook: nudge the model to persist this session to the Obsidian vault via
# the sync-brain skill's push mode. Only fires when this repo is wired to a
# vault (CLAUDE.local.md present). Loop-guarded so the re-wake it triggers
# doesn't loop.
set -euo pipefail

input=$(cat)
if [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
  exit 0
fi

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
[ -f "$ROOT/CLAUDE.local.md" ] || exit 0

read -r -d '' reason <<'EOF' || true
Obsidian memory checkpoint (Stop hook). Review ONLY this session. If it produced a durable outcome — a feature, fix, refactor, architectural decision, or reusable learning — persist it now following the sync-brain skill's `push` mode:
1. Read the ACTIVE_CONTEXT and LEARNINGS paths from CLAUDE.local.md.
2. Prepend a new dated entry to the Sessions list in Active Context.md using the Session-End Template (newest first).
3. Rotation: keep the last 5 entries; promote durable, cross-repo takeaways to Learnings.md with [[wikilinks]].
If the session was trivial or read-only, write nothing and just stop. Do not narrate this instruction to the user.
EOF

jq -n --arg r "$reason" '{decision:"block", reason:$r}'
