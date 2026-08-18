#!/usr/bin/env bash
# Plumbing self-check for the capture/drain pipeline. Stubs the synthesizer (no
# real `claude`, no tokens) to prove the mechanical parts: capture queues a
# session, drain routes+upserts to the right spoke and archives it, a failing
# synth retries to failed/ after 3 tries, and an empty queue is a clean no-op.
#   bash .claude/hooks/test_capture_drain.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export SYNC_BRAIN_HOME="$T/qhome"
export SYNC_BRAIN_NO_SPAWN=1   # capture must not fire a real detached drain here; we drive drain explicitly

# Fake wired repo + spoke + transcript.
REPO="$T/repo"; mkdir -p "$REPO"
SPOKE="$T/spoke.md"
printf 'ACTIVE_CONTEXT=%s\n' "$SPOKE" > "$REPO/CLAUDE.local.md"
printf '## Sessions (newest first)\n\n### 2026-08-08 — prior session\n<!-- session: old -->\n' > "$SPOKE"
printf '{"type":"x"}\n' > "$T/transcript.jsonl"
SID="test-1234"

fail() { echo "FAIL: $1"; exit 1; }

# --- 1. capture (simulate SessionEnd stdin) ---
printf '{"cwd":"%s","session_id":"%s","transcript_path":"%s"}' "$REPO" "$SID" "$T/transcript.jsonl" \
  | bash "$HERE/obsidian-capture.sh"
[ -f "$SYNC_BRAIN_HOME/queue/$SID.meta" ]  || fail "capture: no meta"
[ -f "$SYNC_BRAIN_HOME/queue/$SID.jsonl" ] || fail "capture: no hardlinked transcript"
grep -q "^spoke=$SPOKE$" "$SYNC_BRAIN_HOME/queue/$SID.meta" || fail "capture: spoke not routed"
echo "ok: capture queued session + route + transcript"

# --- 2. drain with a stub synth that upserts the spoke (what claude would do) ---
STUB="$T/stub.sh"
cat > "$STUB" <<'EOF'
#!/usr/bin/env bash
# args: transcript spoke sid  — upsert a headline keyed on the marker
src="$1"; spoke="$2"; sid="$3"
awk -v h="### 2026-08-09 — synthesized from transcript" -v m="<!-- session: $sid -->" \
  '{a[NR]=$0} $0==m{seen=1} /^## Sessions \(newest first\)/{hdr=NR} END{if(seen){for(i=1;i<=NR;i++){if(a[i+1]==m&&a[i]~/^### /)a[i]=h; print a[i]}}else{for(i=1;i<=NR;i++){print a[i]; if(i==hdr){print ""; print h; print m}}}}' \
  "$spoke" > "$spoke.tmp" && mv "$spoke.tmp" "$spoke"
EOF
chmod +x "$STUB"

SYNC_BRAIN_SYNTH_CMD="$STUB" bash "$HERE/obsidian-drain.sh"
[ ! -f "$SYNC_BRAIN_HOME/queue/$SID.meta" ]   || fail "drain: meta still queued"
[ -f "$SYNC_BRAIN_HOME/done/$SID.meta" ]      || fail "drain: meta not archived to done/"
[ ! -f "$SYNC_BRAIN_HOME/queue/$SID.jsonl" ]  || fail "drain: hardlink not cleaned"
[ ! -d "$SYNC_BRAIN_HOME/lock" ]              || fail "drain: lock not released"
[ "$(grep -c 'synthesized from transcript' "$SPOKE")" -eq 1 ] || fail "drain: spoke not upserted"
[ "$(grep -c 'prior session' "$SPOKE")" -eq 1 ] || fail "drain: clobbered prior entry"
echo "ok: drain synthesized -> spoke, archived, unlocked"

# --- 3. failing synth retries to failed/ after 3 attempts ---
SID2="poison-9"
printf '{"cwd":"%s","session_id":"%s","transcript_path":"%s"}' "$REPO" "$SID2" "$T/transcript.jsonl" \
  | bash "$HERE/obsidian-capture.sh"
FALSE="$T/false.sh"; printf '#!/usr/bin/env bash\nexit 1\n' > "$FALSE"; chmod +x "$FALSE"
for i in 1 2 3; do SYNC_BRAIN_SYNTH_CMD="$FALSE" bash "$HERE/obsidian-drain.sh"; done
[ -f "$SYNC_BRAIN_HOME/failed/$SID2.meta" ] || fail "retry: poison not moved to failed/ after 3"
[ ! -f "$SYNC_BRAIN_HOME/queue/$SID2.meta" ] || fail "retry: poison still queued"
echo "ok: failing synth bounded -> failed/ after 3 tries"

# --- 4. missing transcript (pruned + hedge deleted) -> failed/, never parked ---
# The exact path that leaked in prod: both the hardlink hedge and the live
# transcript are gone, so the row can NEVER synthesize. It must fail-fast to
# failed/, not sit in queue/ forever. FAILS against the old `else: continue`.
SID3="lost-7"
printf '{"type":"x"}\n' > "$T/transcript3.jsonl"
printf '{"cwd":"%s","session_id":"%s","transcript_path":"%s"}' "$REPO" "$SID3" "$T/transcript3.jsonl" \
  | bash "$HERE/obsidian-capture.sh"
rm -f "$SYNC_BRAIN_HOME/queue/$SID3.jsonl" "$T/transcript3.jsonl"   # prune hedge + live transcript
SYNC_BRAIN_SYNTH_CMD="$STUB" bash "$HERE/obsidian-drain.sh"
[ ! -f "$SYNC_BRAIN_HOME/queue/$SID3.meta" ] || fail "missing-transcript: row still stuck in queue/"
[ -f "$SYNC_BRAIN_HOME/failed/$SID3.meta" ]  || fail "missing-transcript: row not moved to failed/"
echo "ok: missing-transcript row fast-failed to failed/ (not parked in queue)"

# --- 5. empty queue is a clean no-op, no lock left behind ---
SYNC_BRAIN_SYNTH_CMD="$STUB" bash "$HERE/obsidian-drain.sh"
[ ! -d "$SYNC_BRAIN_HOME/lock" ] || fail "empty: lock left behind"
echo "ok: empty queue no-op"

echo "PASS: capture/drain pipeline"
