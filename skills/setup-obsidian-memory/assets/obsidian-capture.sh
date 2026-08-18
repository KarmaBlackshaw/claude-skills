#!/usr/bin/env bash
# SessionEnd hook (SYNCHRONOUS, small `timeout`): capture this session into the
# global sync-brain queue, then kick a detached drain to synthesize it. Runs
# synchronous — NOT async — because async spawns the hook as the session process
# group is dying and can kill it mid-`ln`/`mv`, losing the capture silently. The
# work is milliseconds; a `timeout` in settings raises the SessionEnd budget to
# cover it. Replaces the inline Stop-hook push (obsidian-push.sh, retired):
# editorial judgment (headline / learnings) moves out of the hot path into the
# drain, so there is no "correction not saved" problem — a resumed session just
# re-captures and the drain upserts.
set -euo pipefail

# Recursion guard: the drain spawns a headless `claude` to synthesize, and that
# run fires its own SessionEnd. Never capture the synthesizer's own session.
[ -n "${SYNC_BRAIN_SYNTH:-}" ] && exit 0

input=$(cat)
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
sid="$(printf '%s' "$input" | jq -r '.session_id // empty')"
tpath="$(printf '%s' "$input" | jq -r '.transcript_path // empty')"
[ -n "$cwd" ] && [ -n "$sid" ] || exit 0

# Only for repos wired to a vault; resolve the spoke now (cheap, and the drain
# stays repo-agnostic — one global queue routes by the path captured here).
PTR="$cwd/CLAUDE.local.md"
[ -f "$PTR" ] || exit 0
SPOKE="$(grep -m1 '^ACTIVE_CONTEXT=' "$PTR" | cut -d= -f2- || true)"
[ -n "$SPOKE" ] || exit 0

HOME_Q="${SYNC_BRAIN_HOME:-$HOME/.claude/sync-brain}"
Q="$HOME_Q/queue"
mkdir -p "$Q"
# Same log the drain writes (memory-doctor.sh consumes it): <ts>\t<sid>\t<reason>.
LOG="$HOME_Q/drain.log"
log() { printf '%s\t%s\t%s\n' "$(date '+%FT%T%z')" "${1:-?}" "${2:-}" >> "$LOG" 2>/dev/null || true; }

# Route + retry metadata. Atomic write (tmp then mv). Re-capture overwrites in
# place, so a resumed session just refreshes its own row — idempotent.
# H4: write this row FIRST, before any slow copy, so the session is ALWAYS
# recorded — even if the SessionEnd `timeout` SIGKILLs a large/cross-fs copy
# mid-flight. `hedged` starts 0; flipped to 1 below iff a durable copy lands.
write_meta() { # $1 = hedged (0|1)
  local tmp; tmp="$(mktemp "$Q/.$sid.XXXXXX")"
  {
    printf 'session_id=%s\n' "$sid"
    printf 'repo_root=%s\n' "$cwd"
    printf 'spoke=%s\n' "$SPOKE"
    printf 'transcript=%s\n' "$tpath"
    printf 'hedged=%s\n' "$1"
    printf 'attempts=0\n'
  } > "$tmp"
  mv "$tmp" "$Q/$sid.meta"
}
write_meta 0

# Hedge against transcript pruning: hardlink (O(1), same-fs) first, then an atomic
# cross-fs copy fallback. Runs AFTER the meta so a killed copy still leaves the row
# queued. Record the outcome (hedged=1|0) so the drain can fail a doomed row fast,
# and never silently swallow a real copy failure (H3).
hedged=0
if [ -n "$tpath" ] && [ -f "$tpath" ]; then
  if ln "$tpath" "$Q/$sid.jsonl" 2>/dev/null; then
    hedged=1
  elif cp "$tpath" "$Q/.$sid.jsonl.tmp" 2>/dev/null && mv "$Q/.$sid.jsonl.tmp" "$Q/$sid.jsonl" 2>/dev/null; then
    hedged=1   # temp+mv: a killed cp leaves no truncated transcript for the drain
  else
    rm -f "$Q/.$sid.jsonl.tmp" 2>/dev/null || true
    log "$sid" "hedge-failed: ln+cp both failed for $tpath (transcript= still points there)"
  fi
fi
[ "$hedged" = 1 ] && write_meta 1
# ponytail: the cross-fs cp still runs inside the timed SessionEnd hook; the meta
# is already durable so a killed cp loses only the pruning hedge, not the row.
# Move the copy into the async drain if transcripts ever grow enough to trip the
# timeout:5 (register-hooks.sh) regularly.

# Kick the drain now (primary path) so this session is synthesized before the
# next session starts — no one-session recall lag. Detached so it outlives this
# terminating session: subshell + `nohup` (macOS has no `setsid`); the subshell
# exits immediately, orphaning the drain to init. SessionStart also runs the
# drain as a catch-up net (same lock, idempotent). SYNC_BRAIN_NO_SPAWN disables
# the kick for deterministic tests.
DRAIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/obsidian-drain.sh"
if [ -z "${SYNC_BRAIN_NO_SPAWN:-}" ] && [ -f "$DRAIN" ]; then
  ( nohup bash "$DRAIN" >/dev/null 2>&1 </dev/null & )
fi
exit 0
