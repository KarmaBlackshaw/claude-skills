#!/usr/bin/env bash
# SessionStart hook (async): drain the global sync-brain queue. For each captured
# session, synthesize its outcome out-of-band via a headless `claude` run that
# reads the transcript and upserts a headline into that session's spoke, then
# archive the row. Non-blocking (async:true); empty queue = instant exit, zero
# cost, no `claude` spawn.
set -euo pipefail

# Recursion guard (see capture): the synthesizer must never trigger a drain.
[ -n "${SYNC_BRAIN_SYNTH:-}" ] && exit 0

HOME_Q="${SYNC_BRAIN_HOME:-$HOME/.claude/sync-brain}"
Q="$HOME_Q/queue"; DONE="$HOME_Q/done"; FAILED="$HOME_Q/failed"; LOCK="$HOME_Q/lock"

# Observability: one line per skip/fail/retry so a silent leak surfaces.
# Format (consumed by memory-doctor.sh): <ISO8601 ts>\t<sid|meta-basename>\t<reason>
DLOG="$HOME_Q/drain.log"
log() { printf '%s\t%s\t%s\n' "$(date '+%FT%T%z')" "${1:-?}" "${2:-}" >> "$DLOG" 2>/dev/null || true; }

# Nothing queued -> get out before doing anything expensive.
ls "$Q"/*.meta >/dev/null 2>&1 || exit 0

# Single-drain lock: atomic mkdir (portable; macOS has no flock). Acquire FIRST,
# then reap only on contention — reap+acquire must be atomic, or two drains that
# both read the same stale `born` can each rmdir+re-mkdir and double-process.
if ! mkdir "$LOCK" 2>/dev/null; then
  now="$(date +%s)"; born="$(stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK" 2>/dev/null || echo "$now")"
  # Live holder (<30 min) -> yield. Stale -> reap this dir, retry mkdir once.
  [ $((now - born)) -gt 1800 ] && rmdir "$LOCK" 2>/dev/null || exit 0
  mkdir "$LOCK" 2>/dev/null || exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
mkdir -p "$DONE" "$FAILED"
# ponytail: single reap+retry closes the common race; a sub-ms window where A
# acquires between B's stat and B's rmdir remains. Upgrade to a PID-liveness lock
# only if two drains ever genuinely overlap past the 30-min staleness window.

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
# Cheap-enough default for summarize-and-write. Cheaper: claude-haiku-4-5-20251001.
MODEL="${SYNC_BRAIN_MODEL:-claude-sonnet-5}"
# Synth writes the spoke (outside the repo) via Edit; acceptEdits auto-approves.
# Flip to bypassPermissions if acceptEdits ever blocks the cross-dir edit.
PERM="${SYNC_BRAIN_PERM:-acceptEdits}"
# Test seam: a stub `cmd transcript spoke sid` replaces the real agent.
SYNTH_CMD="${SYNC_BRAIN_SYNTH_CMD:-}"
# Synthesis prompt (inline; __TOKENS__ substituted per session below).
template=$(cat <<'PROMPT'
You are a background memory synthesizer for the sync-brain Obsidian system. Work silently and non-interactively. Never ask questions.

1. Read the session transcript at: __TRANSCRIPT__
2. Read the spoke file at: __SPOKE__
3. Judge the session. If it was trivial or read-only (no feature, fix, refactor, or decision), output only `Nothing to save.` and stop — make NO edits.
4. Otherwise compose a headline: <=12 words, one clause, no semicolons, no parentheticals, plain text. Determine the session date (YYYY-MM-DD) from the transcript; if unclear, use today.
5. Upsert it into the spoke with the Edit tool (do NOT use Bash), keyed on the marker `<!-- session: __SID__ -->`:
   - If that marker already exists: replace the single `### ...` heading line directly above it with `### <date> — <headline>`. Leave the marker line unchanged.
   - Else: insert directly below the line `## Sessions (newest first)` a blank line, then `### <date> — <headline>`, then a line containing exactly `<!-- session: __SID__ -->`.
6. Learnings promotion is RARE. Only if a reusable, cross-repo, behavior-changing lesson emerged that is not already recorded, additionally promote it per the sync-brain skill's Promotion gate. Otherwise do nothing further.

Your only output is the word `Saved.` (or `Nothing to save.`). No narration.
PROMPT
)

for meta in "$Q"/*.meta; do
  [ -e "$meta" ] || continue
  sid="$(grep -m1 '^session_id=' "$meta" | cut -d= -f2- || true)"
  spoke="$(grep -m1 '^spoke=' "$meta" | cut -d= -f2- || true)"
  tpath="$(grep -m1 '^transcript=' "$meta" | cut -d= -f2- || true)"
  [ -n "$sid" ] && [ -n "$spoke" ] || { log "$(basename "$meta")" "bad-meta: missing session_id or spoke"; mv "$meta" "$FAILED/" 2>/dev/null || true; continue; }
  hedged="$(grep -m1 '^hedged=' "$meta" | cut -d= -f2- || true)"; [ -n "$hedged" ] || hedged='?'
  hardlink="$Q/$sid.jsonl"
  src="$hardlink"; [ -f "$src" ] || src="$tpath"   # prefer the pruning-proof copy

  # H1: no transcript anywhere (hardlink gone AND transcript= path pruned) -> this
  # row is PERMANENTLY unsynthesizable. Fail it out of the queue now; NEVER park it
  # (the old `else: continue` wedged such rows forever with attempts=0).
  if [ ! -f "$src" ]; then
    log "$sid" "no-transcript: hardlink+transcript both gone (hedged=$hedged) -> failed/"
    mv "$meta" "$FAILED/$sid.meta" 2>/dev/null || true; rm -f "$hardlink"
    continue
  fi

  # Run the synth. `saved` = it claims a write; verified against the spoke below.
  # `trivial` = it judged the session not worth saving (writes no marker, by design).
  saved=0; trivial=0
  if [ -n "$SYNTH_CMD" ]; then
    SYNC_BRAIN_SYNTH=1 "$SYNTH_CMD" "$src" "$spoke" "$sid" && saved=1 || saved=0
  elif [ -n "$template" ] && command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
    # Pure-bash substitution (no sed) — safe for paths with regex/&/# chars.
    prompt="${template//__TRANSCRIPT__/$src}"; prompt="${prompt//__SPOKE__/$spoke}"; prompt="${prompt//__SID__/$sid}"
    # Headless: no chat to clutter, so the synth uses Edit (acceptEdits auto-approves).
    out="$(SYNC_BRAIN_SYNTH=1 "$CLAUDE_BIN" -p "$prompt" --model "$MODEL" --permission-mode "$PERM" 2>/dev/null || true)"
    case "$out" in
      *[Nn]othing\ to\ save*) trivial=1 ;;   # judged trivial -> no marker expected
      *) saved=1 ;;
    esac
  else
    log "$sid" "no-synth: synthesizer binary unavailable -> left queued, retry next start"
    continue   # transient (NOT unrecoverable): leave queued, retry next start
  fi

  # H2: exit 0 / a `Saved.` string does NOT prove the write landed — acceptEdits
  # can silently block the cross-dir Edit, or the model narrates instead of
  # editing. A real success must leave the session marker in the spoke. A
  # legitimately trivial session writes no marker and is still a success (not a
  # lost write) — distinguished by its `Nothing to save.` output above.
  ok=0
  if [ "$trivial" = 1 ]; then
    ok=1
  elif [ "$saved" = 1 ] && grep -qF "<!-- session: $sid -->" "$spoke" 2>/dev/null; then
    ok=1
  elif [ "$saved" = 1 ]; then
    log "$sid" "lost-write: synth returned ok but session marker absent from spoke"
  fi

  if [ "$ok" = 1 ]; then
    mv "$meta" "$DONE/$sid.meta"; rm -f "$hardlink"
  else
    # Bounded retry so a poison / lost-write session can't respawn an agent every start.
    n="$(grep -m1 '^attempts=' "$meta" | cut -d= -f2- || echo 0)"; [[ "$n" =~ ^[0-9]+$ ]] || n=0
    n=$((n + 1))
    if [ "$n" -ge 3 ]; then
      log "$sid" "failed: gave up after $n attempts -> failed/"
      mv "$meta" "$FAILED/$sid.meta"; rm -f "$hardlink"
    else
      log "$sid" "retry: attempt $n did not verify, requeued"
      # L4: guard the attempts bump — a swallowed sed failure would leave attempts
      # frozen and the row retrying forever with no trace.
      { sed "s/^attempts=.*/attempts=$n/" "$meta" > "$meta.tmp" && mv "$meta.tmp" "$meta"; } \
        || { rm -f "$meta.tmp"; log "$sid" "attempts-write-failed: could not bump attempts to $n"; }
    fi
  fi
done
exit 0
