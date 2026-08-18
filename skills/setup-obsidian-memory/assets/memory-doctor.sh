#!/usr/bin/env bash
# memory-doctor.sh — audit an Obsidian hub-and-spoke vault for hygiene issues.
# Usage: memory-doctor.sh <vault-root> [--repo <path> ...]
#   <vault-root>  the dir containing Learnings.md (+ Learnings/ + Projects/)
#   --repo <path> optional repo root(s) to resolve dead file refs against
# Read-only. Exit 1 if actionable issues (broken links / orphans) found, else 0.
# Stale notes + dead file refs are advisory (warnings), never fail the exit.
set -uo pipefail

VAULT="${1:-}"
[ -n "$VAULT" ] || { echo "usage: memory-doctor.sh <vault-root> [--repo <path> ...]"; exit 2; }
shift || true
REPOS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPOS+=("${2:-}"); shift 2 ;;
    *) shift ;;
  esac
done

HUB="$VAULT/Learnings.md"
NOTES="$VAULT/Learnings"
[ -f "$HUB" ] || { echo "no Learnings.md at $VAULT — not a hub vault"; exit 2; }

today="$(date +%F)"
stale_before="$(date -v-6m +%F 2>/dev/null || date -d '6 months ago' +%F 2>/dev/null || echo 0000-00-00)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Illustrative link tokens used in preamble/template prose — never real links.
is_placeholder() {
  case "$1" in
    wikilink|wikilinks|slug|name|their-name|stack-or-workflow|tag-or-workflow|YYYY-MM-DD|Learnings/|Memory/) return 0 ;;
    *) return 1 ;;
  esac
}
export -f is_placeholder

echo "🩺 memory-doctor — $VAULT"
echo "   today=$today  stale-threshold=$stale_before  repos-for-deadrefs=${#REPOS[@]}"
echo

# Resolvable note basenames (every .md in the vault, minus .obsidian).
find "$VAULT" -name '*.md' -not -path '*/.obsidian/*' -print0 \
  | while IFS= read -r -d '' f; do basename "$f" .md; done | sort -u > "$work/names"

# ── 1. Broken wikilinks ──────────────────────────────────────────────
: > "$work/broken"
find "$VAULT" -name '*.md' -not -path '*/.obsidian/*' -print0 | while IFS= read -r -d '' f; do
  grep -oE '\[\[[^]]+\]\]' "$f" 2>/dev/null | sed -E 's/^\[\[//; s/\]\]$//' | while IFS= read -r link; do
    target="${link%%|*}"; target="${target%%#*}"
    [ -z "$target" ] && continue                       # bare [[#heading]] self-link
    is_placeholder "$target" && continue               # illustrative prose token
    if [[ "$target" == */* ]]; then
      [ -f "$VAULT/$target.md" ] || [ -f "$VAULT/$target" ] || echo "${f#$VAULT/} → [[$target]]" >> "$work/broken"
    else
      grep -qxF "$target" "$work/names" || echo "${f#$VAULT/} → [[$target]]" >> "$work/broken"
    fi
  done
done
nbroken=$(sort -u "$work/broken" | wc -l | tr -d ' ')
echo "── 1. Broken wikilinks: $nbroken ──"
sort -u "$work/broken" | sed 's/^/  /'
echo

# ── 2. Stale notes (updated: older than threshold) ───────────────────
: > "$work/stale"
if [ -d "$NOTES" ]; then
  find "$NOTES" -name '*.md' -print0 | while IFS= read -r -d '' f; do
    up=$(grep -m1 '^updated:' "$f" | sed -E 's/^updated:[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$up" ] || { echo "$(basename "$f" .md) — no 'updated:' field" >> "$work/stale"; continue; }
    [[ "$up" < "$stale_before" ]] && echo "$(basename "$f" .md) — updated $up" >> "$work/stale"
  done
fi
nstale=$(wc -l < "$work/stale" | tr -d ' ')
echo "── 2. Stale / undated notes: $nstale (advisory) ──"
sed 's/^/  /' "$work/stale"
echo

# ── 3. Orphans (index ↔ notes out of sync) ───────────────────────────
: > "$work/orphan"
# 3a: note file exists but no index line links to it
if [ -d "$NOTES" ]; then
  find "$NOTES" -name '*.md' -print0 | while IFS= read -r -d '' f; do
    slug=$(basename "$f" .md)
    grep -qE "\[\[$slug([|#]|\]\])" "$HUB" || echo "note not in index: $slug" >> "$work/orphan"
  done
fi
# 3b: index links to a note file that doesn't exist
grep -oE '\[\[[^]]+\]\]' "$HUB" | sed -E 's/^\[\[//; s/\]\]$//' | while IFS= read -r link; do
  target="${link%%|*}"; target="${target%%#*}"
  [ -z "$target" ] && continue
  is_placeholder "$target" && continue                      # illustrative prose token
  # resolve vault-wide: index links point to lessons (Learnings/) OR spokes (Projects/)
  if [[ "$target" == */* ]]; then
    [ -f "$VAULT/$target.md" ] || [ -f "$VAULT/$target" ] || echo "index links missing note: $target" >> "$work/orphan"
  else
    grep -qxF "$target" "$work/names" || echo "index links missing note: $target" >> "$work/orphan"
  fi
done
norphan=$(sort -u "$work/orphan" | wc -l | tr -d ' ')
echo "── 3. Index/notes orphans: $norphan ──"
sort -u "$work/orphan" | sed 's/^/  /'
echo

# ── 4. Dead file refs (heuristic; advisory) ──────────────────────────
: > "$work/dead"
# backticked tokens that look like source paths (contain / and a code extension)
find "$VAULT" -name '*.md' -not -path '*/.obsidian/*' -print0 | while IFS= read -r -d '' f; do
  grep -oE '`[^`]*`' "$f" 2>/dev/null | tr -d '`' \
    | grep -oE '[A-Za-z0-9_./@-]+\.(ts|tsx|js|jsx|vue|css|json|sh|py|md)' \
    | grep '/' | sort -u | while IFS= read -r ref; do
      if [ ${#REPOS[@]} -gt 0 ]; then
        hit=0
        for rp in "${REPOS[@]}"; do [ -e "$rp/$ref" ] && hit=1 && break; done
        [ "$hit" = 0 ] && echo "${f#$VAULT/}: $ref" >> "$work/dead"
      else
        echo "${f#$VAULT/}: $ref" >> "$work/dead"   # no repo → list for manual review
      fi
    done
done
ndead=$(sort -u "$work/dead" | wc -l | tr -d ' ')
if [ ${#REPOS[@]} -gt 0 ]; then
  echo "── 4. Dead file refs (not found in given repos): $ndead (advisory) ──"
else
  echo "── 4. File refs to eyeball (no --repo given, cannot resolve): $ndead (advisory) ──"
fi
sort -u "$work/dead" | sed 's/^/  /' | head -40
[ "$ndead" -gt 40 ] && echo "  … ($((ndead-40)) more)"
echo

# ── 5. Sync-brain queue health ───────────────────────────────────────
# The vault checks above never look at the capture/drain pipeline; a stuck queue
# leaks memory silently. Count the dirs, flag rows too old and rows that can
# never synthesize (transcript pruned AND hedge gone — H1's fail-fast targets).
SB="${SYNC_BRAIN_HOME:-$HOME/.claude/sync-brain}"
STALE_DAYS="${SYNC_BRAIN_STALE_DAYS:-3}"
nqueued=0; ndone=0; nfailed=0; nqold=0; nunrec=0
if [ -d "$SB" ]; then
  nqueued=$(find "$SB/queue"  -name '*.meta' 2>/dev/null | wc -l | tr -d ' ')
  ndone=$(  find "$SB/done"   -name '*.meta' 2>/dev/null | wc -l | tr -d ' ')
  nfailed=$(find "$SB/failed" -name '*.meta' 2>/dev/null | wc -l | tr -d ' ')
  echo "── 5. Sync-brain queue: queued=$nqueued done=$ndone failed=$nfailed ──"
  if [ -d "$SB/queue" ]; then
    while IFS= read -r -d '' m; do
      echo "  stale queued (>${STALE_DAYS}d): $(basename "$m" .meta)"; nqold=$((nqold+1))
    done < <(find "$SB/queue" -name '*.meta' -mtime +"$STALE_DAYS" -print0 2>/dev/null)
    for m in "$SB/queue"/*.meta; do
      [ -e "$m" ] || continue
      sid=$(grep -m1 '^session_id=' "$m" | cut -d= -f2-)
      tp=$( grep -m1 '^transcript=' "$m" | cut -d= -f2-)
      [ -f "$SB/queue/$sid.jsonl" ] && continue          # pruning hedge still present
      [ -n "$tp" ] && [ -f "$tp" ] && continue           # live transcript still present
      echo "  UNRECOVERABLE (no transcript, no hedge): ${sid:-$(basename "$m" .meta)}"; nunrec=$((nunrec+1))
    done
  fi
  if [ -f "$SB/drain.log" ]; then
    echo "  drain.log (last 5):"
    tail -n 5 "$SB/drain.log" 2>/dev/null | sed 's/^/    /'
  fi
else
  echo "── 5. Sync-brain queue: (no $SB — pipeline not installed) ──"
fi
echo

# ── Summary / exit ───────────────────────────────────────────────────
echo "── summary ──"
echo "  broken links: $nbroken | stale: $nstale | orphans: $norphan | dead-refs: $ndead"
echo "  queue: queued=$nqueued done=$ndone failed=$nfailed | stale-queued: $nqold | unrecoverable: $nunrec"
if [ "$nbroken" -gt 0 ] || [ "$norphan" -gt 0 ] || [ "$nunrec" -gt 0 ]; then
  echo "  ✗ actionable issues found (broken links / orphans / unrecoverable queue rows)"
  exit 1
fi
echo "  ✓ no actionable issues (stale/dead-refs are advisory)"
exit 0
