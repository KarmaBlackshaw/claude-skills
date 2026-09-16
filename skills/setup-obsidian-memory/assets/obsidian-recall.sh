#!/usr/bin/env bash
# Injects Obsidian long-term memory (Learnings + Coding Rules + Active Context) into context.
# SessionStart + SubagentStart hook. Reads absolute vault paths from the repo's gitignored
# CLAUDE.local.md so no personal paths live in git.
# No-ops silently if CLAUDE.local.md or the target files are missing.
# Arg $1 = hook event name (default: SessionStart).
set -euo pipefail

# The drain spawns a headless `claude` to synthesize a queued session; that run
# fires SessionStart too. It doesn't need memory injected to write a 12-word
# summary — skip the whole blob so synthesis stays cheap.
[ -n "${SYNC_BRAIN_SYNTH:-}" ] && exit 0

EVENT="${1:-SessionStart}"
# Hook stdin (JSON) carries the session id; skipped when run by hand from a tty.
input=""; [ -t 0 ] || input="$(cat)"
SID="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
# Fresh context (startup/resume/clear/compact) => let obsidian-retrieve.sh
# re-inject lessons this session already saw; they are gone from context now.
# A subagent shares the parent's session id — clearing here would re-inject
# into the parent's next prompt, so only a real SessionStart clears.
[ -n "$SID" ] && [ "$EVENT" != SubagentStart ] && rm -f "${SYNC_BRAIN_HOME:-$HOME/.claude/sync-brain}/seen/$SID"
CWD="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
ROOT="${CWD:-${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}}"
PTR="$ROOT/CLAUDE.local.md"

# Value after the first '=' for a KEY line (paths may contain spaces).
# No-ops when CLAUDE.local.md is absent — the global block below is ungated and
# still injects, so an unwired repo gets the baseline standards.
getpath() { [ -f "$PTR" ] && grep -m1 "^$1=" "$PTR" 2>/dev/null | cut -d= -f2- || true; }

# Global standards: the cross-org, cross-stack baseline (top tier of the
# ladder: global -> org -> repo -> lessons). Path is env-overridable so no
# personal path is hardcoded in git.
GLOBAL_STANDARDS="$(getpath GLOBAL_STANDARDS)"
: "${GLOBAL_STANDARDS:=${OBSIDIAN_GLOBAL_STANDARDS:-$HOME/Documents/obsidian/Standards.md}}"

LEARNINGS="$(getpath LEARNINGS)"
STANDARDS="$(getpath STANDARDS)"
RULES="$(getpath CODING_RULES)"
ACTIVE="$(getpath ACTIVE_CONTEXT)"
THREADS="$(getpath THREADS)"
# Which Learnings spokes this repo cares about: DOMAINS= in the pointer, else
# detected from the repo's manifests (obsidian-domains.sh). "" = no filter.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/obsidian-domains.sh"
DOMAINS="$(resolve_domains "$ROOT" "$(getpath DOMAINS)")"
# Cross-org lessons tier: <vaults-root>/Learnings.md (+ Learnings/), one dir above
# the vaults, mirroring GLOBAL_STANDARDS. Overridable per repo via GLOBAL_LEARNINGS=.
GLOBAL_LEARNINGS="$(getpath GLOBAL_LEARNINGS)"
[ -z "$GLOBAL_LEARNINGS" ] && [ -n "$LEARNINGS" ] && GLOBAL_LEARNINGS="$(dirname "$(dirname "$LEARNINGS")")/Learnings"

# Keep only the index sections for this repo's domains — a bash repo doesn't need
# 27 Vue lines every session. A legacy index (no `### [[Spoke]]` headings) passes
# through whole. Lesson bodies arrive on demand via obsidian-retrieve.sh anyway.
filter_index() { awk -v d="$DOMAINS" 'BEGIN{n=split(d,D,",")} /^### \[\[/{insec=1; keep=(n==0); for(i=1;i<=n;i++){gsub(/ /,"",D[i]); if(index($0,"[[" D[i] "]]")) keep=1}} !insec||keep' "$1"; }

# Sections in priority order. The harness inlines a hook's additionalContext
# only up to 10,000 chars — past that it persists the whole blob to a file and
# injects a 2 KB preview, so a 30 KB "full" injection silently became 2 KB of
# it. Pack whole sections under BUDGET (rules tiers first — they are the
# always-on baseline), spill the rest to a file, and point at it.
BUDGET="${RECALL_BUDGET:-9400}"
titles=(); bodies=()
add() { [ -n "$2" ] && { titles+=("$1"); bodies+=("$2"); }; }
# UNGATED — every repo gets this, wired to a vault or not. In FULL, and first,
# because it is the always-on baseline everything else specializes.
[ -f "$GLOBAL_STANDARDS" ] && add "Global Coding Standards (Obsidian — every repo, every org, every stack)" "$(cat "$GLOBAL_STANDARDS")"
# Org standards: conventions for every repo in this org's vault — the tier below
# the global baseline. Injected in FULL (unlike Learnings) because they apply to
# all work, not just situationally. Keep the file tight.
[ -n "$STANDARDS" ] && [ -f "$STANDARDS" ] && add "Org Coding Standards (Obsidian — shared across this org's repos)" "$(cat "$STANDARDS")"
[ -n "$RULES" ] && [ -f "$RULES" ] && add "Coding Rules — this repo (Obsidian spoke)" "$(cat "$RULES")"
# Learnings: the index (MOC) ONLY — one summary line per lesson, grouped by
# domain spoke. Bodies live in Learnings/<Spoke>.md and arrive on demand via
# obsidian-retrieve.sh, never up front.
[ -n "$GLOBAL_LEARNINGS" ] && [ -f "$GLOBAL_LEARNINGS.md" ] && add "Global Learnings (Obsidian — cross-org lessons index${DOMAINS:+, filtered to $DOMAINS})" "$(filter_index "$GLOBAL_LEARNINGS.md")"
[ -n "$LEARNINGS" ] && [ -f "$LEARNINGS" ] && add "Org Learnings (Obsidian hub — index${DOMAINS:+, filtered to $DOMAINS})" "$(filter_index "$LEARNINGS")"
# Open threads: only the ledger's `open` rows — unfinished action items that
# survived session rotation. Done rows stay out of context.
if [ -n "$THREADS" ] && [ -f "$THREADS" ]; then
  open_rows="$(grep -E '^\|[[:space:]]*open[[:space:]]*\|' "$THREADS" 2>/dev/null || true)"
  [ -n "$open_rows" ] && add "Open Threads — this repo (unfinished action items; close them or they carry forward)" "| status | thread | opened | source |"$'\n'"|---|---|---|---|"$'\n'"$open_rows"
fi
[ -n "$ACTIVE" ] && [ -f "$ACTIVE" ] && add "Active Context — this repo (Obsidian spoke)" "$(cat "$ACTIVE")"

[ "${#titles[@]}" -eq 0 ] && exit 0

pre="Obsidian long-term memory (hub-and-spoke). Read before architectural changes; persist with /sync-brain push.
The Learnings indexes are tables of contents only — lesson BODIES (and the rule bullets that apply) are auto-injected per prompt / per edited file by obsidian-retrieve.sh. When a 'Memory matched' block appears, apply it."
SPILL_DIR="${SYNC_BRAIN_HOME:-$HOME/.claude/sync-brain}/recall"; mkdir -p "$SPILL_DIR"
spill="$SPILL_DIR/${SID:-$$}.md"; : > "$spill"
inline=""; spilled=(); total=${#pre}
for i in "${!titles[@]}"; do
  sec="# ${titles[$i]}"$'\n\n'"${bodies[$i]}"$'\n\n'
  if [ $((total + ${#sec})) -le "$BUDGET" ]; then inline+="$sec"; total=$((total + ${#sec}))
  else printf '%s' "$sec" >> "$spill"; spilled+=("${titles[$i]%% (*}"); fi
done
if [ "${#spilled[@]}" -gt 0 ]; then
  list="$(printf '%s, ' "${spilled[@]}")"
  inline+="# More memory — not inlined (context budget): ${list%, }"$'\n\n'"Read \`$spill\` ($(wc -c < "$spill" | tr -d ' ') chars) before architectural decisions or when a task needs project history."$'\n'
else rm -f "$spill"; fi

jq -n --arg e "$EVENT" --arg c "$pre

$inline" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
