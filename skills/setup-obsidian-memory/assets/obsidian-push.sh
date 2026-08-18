#!/usr/bin/env bash
# RETIRED 2026-08-09 — unregistered from settings.local.json. Superseded by the
# capture/synthesis pipeline: obsidian-capture.sh (SessionEnd) queues the session
# and obsidian-drain.sh (SessionStart) synthesizes it out-of-band. Kept for
# rollback: re-add the Stop hook entry to restore the old inline-push behavior.
#
# Stop hook: nudge the model to persist this session to the Obsidian vault via
# the sync-brain skill's push mode, then VERIFY the write actually landed.
# Only fires when this repo is wired to a vault (CLAUDE.local.md present).
#
# Verification: the push writes a spoke entry ending in `<!-- session: <id> -->`.
# This hook re-checks that marker is on disk. If present, the session was
# persisted -> stay quiet. If absent, nudge again (bounded), so a push that was
# claimed but never written gets caught instead of silently lost.
set -euo pipefail

input=$(cat)
# Loop guard: never re-block within a hook-triggered stop cycle.
if [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
  exit 0
fi

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PTR="$ROOT/CLAUDE.local.md"
[ -f "$PTR" ] || exit 0

session_id="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"

# Verify-it-landed: this session already wrote its marked entry -> quiet.
ACTIVE="$(grep -m1 '^ACTIVE_CONTEXT=' "$PTR" 2>/dev/null | cut -d= -f2- || true)"
if [ -n "$ACTIVE" ] && [ -f "$ACTIVE" ] && grep -qF "session: $session_id" "$ACTIVE"; then
  exit 0
fi

# Not persisted yet: nudge, but bound retries so a genuinely trivial session
# (model chooses to write nothing) isn't nagged forever. Count attempts/session.
STAMP="${TMPDIR:-/tmp}/obsidian-push-${session_id}.n"
n="$(cat "$STAMP" 2>/dev/null || true)"; [[ "$n" =~ ^[0-9]+$ ]] || n=0
[ "$n" -ge 2 ] && exit 0
printf '%s' "$((n + 1))" > "$STAMP"

reason="Obsidian memory checkpoint (Stop hook). If this session produced a durable outcome (feature / fix / refactor / decision), save it with ONE shell command — do NOT use the Edit tool, its diff clutters the chat. Otherwise print \`Nothing to save.\` and stop.

Compose a headline: ≤12 words, one clause, no semicolons, no parentheticals, plain text (no single quotes). Then run this single command from the repo root — it upserts this session's entry keyed on the marker: a new entry prepended under the spoke's \`## Sessions (newest first)\` line, or if you already saved this session, the existing headline replaced in place (correction overwrites the first pass, no duplicate):

  S=\"\$(grep -m1 '^ACTIVE_CONTEXT=' CLAUDE.local.md | cut -d= -f2-)\"; awk -v h=\"### \$(date +%F) — <YOUR HEADLINE>\" -v m='<!-- session: $session_id -->' '{a[NR]=\$0} \$0==m{seen=1} /^## Sessions \\(newest first\\)/{hdr=NR} END{if(seen){for(i=1;i<=NR;i++){if(a[i+1]==m&&a[i]~/^### /)a[i]=h; print a[i]}}else{for(i=1;i<=NR;i++){print a[i]; if(i==hdr){print \"\"; print h; print m}}}}' \"\$S\" > \"\$S.tmp\" && mv \"\$S.tmp\" \"\$S\"

The \`<!-- session: $session_id -->\` marker line is REQUIRED — this checkpoint greps for it to confirm the write landed. Skip rotation, the threads ledger, and hub promotion UNLESS a genuinely reusable cross-repo lesson emerged (only then, separately, add it to the right domain spoke + Learnings index). After the command, your ONLY output is the word \`Saved.\` — no summary, no narration."

jq -n --arg r "$reason" '{decision:"block", reason:$r}'
