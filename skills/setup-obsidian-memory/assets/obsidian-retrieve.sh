#!/usr/bin/env bash
# Point-of-use memory retrieval — UserPromptSubmit + PreToolUse(Edit|Write) hook.
# Session start injects the always-on rules and only the Learnings INDEX; by the
# time a lesson matters it sits tens of thousands of tokens back and gets
# "forgotten". This hook scores every memory unit against the current prompt (or
# the file about to be edited) and injects the top matches IN FULL, right where
# attention is strongest. Units, across every tier of the ladder:
#   rules   — each `- **rule** — why` bullet in GLOBAL_STANDARDS / STANDARDS /
#             CODING_RULES (already in context; re-surfaced when relevant)
#   lessons — each `###` section of a domain spoke (Learnings/<Spoke>.md), in the
#             org vault AND the cross-org tier GLOBAL_LEARNINGS (obsidian/Learnings/);
#             a legacy atomic note (one lesson per file, no `###`) is one unit
#             whose `# title` line is the header
# A unit injects once per session (seen-set); obsidian-recall.sh clears the set
# on every SessionStart, so a fresh/compacted context re-earns it. Pure awk, one
# pass — milliseconds at 100KB, fine to ~MB.
set -euo pipefail
[ -n "${SYNC_BRAIN_SYNTH:-}" ] && exit 0

input=$(cat)
j() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null || true; }
cwd="$(j .cwd)"; sid="$(j .session_id)"; ev="$(j .hook_event_name)"
PTR="${cwd:-.}/CLAUDE.local.md"; [ -f "$PTR" ] || exit 0
getpath() { grep -m1 "^$1=" "$PTR" 2>/dev/null | cut -d= -f2- || true; }
LEARNINGS="$(getpath LEARNINGS)"; [ -n "$LEARNINGS" ] || exit 0
DIR="${LEARNINGS%.md}"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/obsidian-domains.sh"
DOMAINS="$(resolve_domains "$cwd" "$(getpath DOMAINS)")"
# Rule tiers (same resolution as obsidian-recall.sh).
G="$(getpath GLOBAL_STANDARDS)"; : "${G:=${OBSIDIAN_GLOBAL_STANDARDS:-$HOME/Documents/obsidian/Standards.md}}"
S="$(getpath STANDARDS)"; R="$(getpath CODING_RULES)"
# Cross-org lessons: one dir above the vaults, mirroring GLOBAL_STANDARDS.
GL="$(getpath GLOBAL_LEARNINGS)"; : "${GL:=$(dirname "$(dirname "$LEARNINGS")")/Learnings}"

# Query text: the prompt, or the path of the file about to be edited plus a few
# stack words its extension implies (so `Foo.vue` also pulls Vue/props lessons).
case "$ev" in
  UserPromptSubmit) q="$(j .prompt)" ;;
  PreToolUse)
    f="$(j .tool_input.file_path)"; [ -n "$f" ] || exit 0
    case "${f##*.}" in
      vue)     x="vue component props template computed" ;;
      ts|js)   x="typescript" ;;
      tsx|jsx) x="react native expo" ;;
      sh|bash) x="bash shell script hook" ;;
      sql)     x="postgres supabase migration" ;;
      *)       x="" ;;
    esac
    q="${f#"$cwd"/} $x" ;;
  *) exit 0 ;;
esac
[ -n "$q" ] || exit 0

# Tokens: lowercase words >=3 chars, minus stopwords, unique, first 40.
STOP=' the and for you are with this that from have not but can was were will would should could into your they them then than also just like make need want does done been being each some more most only over under about there their here what when where which while how why all any our out use used using file files code please let its now new one two get got set add can may might must very really '
toks="$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]_' '\n' \
  | awk -v s="$STOP" 'length($0)>=3 && index(s," "$0" ")==0 && !seen[$0]++ && ++n<=40' | tr '\n' ' ')"
[ -n "$toks" ] || exit 0

# Lesson files from the org spokes dir and the global one, narrowed to the repo's
# domains (detected or DOMAINS=). A dir with none of those spoke files is a legacy
# atomic-note vault (one lesson per file) — take every .md there instead.
files=()
for d in "$DIR" "$GL"; do
  [ -d "$d" ] || continue
  picked=()
  if [ -n "$DOMAINS" ]; then
    IFS=',' read -ra ds <<<"$DOMAINS"
    for x in "${ds[@]}"; do x="${x// /}"; [ -f "$d/$x.md" ] && picked+=("$d/$x.md"); done
  fi
  [ "${#picked[@]}" -eq 0 ] && for f in "$d"/*.md; do [ -f "$f" ] && picked+=("$f"); done
  [ "${#picked[@]}" -gt 0 ] && files+=("${picked[@]}")
done
for f in "$G" "$S" "$R"; do [ -n "$f" ] && [ -f "$f" ] && files+=("$f"); done
[ "${#files[@]}" -gt 0 ] || exit 0

SEEN_DIR="${SYNC_BRAIN_HOME:-$HOME/.claude/sync-brain}/seen"; mkdir -p "$SEEN_DIR"
SEEN="$SEEN_DIR/${sid:-nosid}"; touch "$SEEN"
KEYS="$(mktemp)"; trap 'rm -f "$KEYS"' EXIT

# One pass. Score = sum over query tokens (3 if in the unit's header, else 1 if in
# its body). Keep the top N of each kind scoring >= MIN, skip seen keys, stay in a
# byte budget. Chosen keys go to $KEYS.
# ponytail: substring overlap, no stemming/synonyms — swap the scorer for
# embeddings (ctx_semantic_search) if misses persist once the corpus passes ~1MB.
out="$(awk -v toks="$toks" -v seen="$SEEN" -v keys="$KEYS" -v g="$G" -v s="$S" -v r="$R" \
        -v min=4 -v ntop_rules=2 -v ntop_lessons=3 -v maxb=8000 '
  function pick(kind, top,   p, best, bs, k, body, acc) {
    for (p = 0; p < top; p++) { best = ""; bs = 0
      for (k in SC) if (K[k] == kind && SC[k] > bs) { bs = SC[k]; best = k }
      if (best == "") break
      body = B[best]; delete SC[best]
      if (bytes + length(body) > maxb) continue
      bytes += length(body); acc = acc body "\n\n"; print best > keys }
    return acc }
  BEGIN { n = split(toks, T, " "); while ((getline l < seen) > 0) S[l] = 1; close(seen) }
  FNR == 1 { f = FILENAME; cur = ""
    tier = (f == g ? "global" : (f == s ? "org" : (f == r ? "repo" : "")))
    fu = ""; if (tier == "") { base = f; sub(/.*\//, "", base); sub(/\.md$/, "", base)
      fu = f "|" base; O[++c] = fu; K[fu] = "lesson"; H[fu] = ""; B[fu] = "" } }
  tier != "" { if ($0 ~ /^- \*\*/) { k = f "|" $0; O[++c] = k; K[k] = "rule"; H[k] = tolower($0); B[k] = "- (" tier " rule) " substr($0, 3) }; next }
  /^### / { cur = f "|" substr($0, 5); O[++c] = cur; K[cur] = "lesson"; H[cur] = tolower($0); B[cur] = $0; HasSec[fu] = 1; next }
  /^## /  { cur = ""; next }
  cur != "" { B[cur] = B[cur] "\n" $0; next }
  { if (H[fu] == "" && $0 ~ /^# /) H[fu] = tolower($0); B[fu] = B[fu] (B[fu] == "" ? "" : "\n") $0 }
  END {
    for (i = 1; i <= c; i++) { k = O[i]
      if (k in S || (k in HasSec) || B[k] == "") continue
      lc = tolower(B[k]); sc = 0
      for (t = 1; t <= n; t++) { if (index(H[k], T[t])) sc += 3; else if (index(lc, T[t])) sc += 1 }
      if (sc >= min) SC[k] = sc }
    rules = pick("rule", ntop_rules); lessons = pick("lesson", ntop_lessons)
    if (rules != "")   printf "## Rules that apply here\n%s", rules
    if (lessons != "") printf "## Lessons\n%s", lessons }
' "${files[@]}")"
[ -n "$out" ] || exit 0
cat "$KEYS" >> "$SEEN"

what="this prompt"; [ "$ev" = PreToolUse ] && what="the file you are about to edit"
jq -n --arg e "$ev" --arg c "# Memory matched to $what (Obsidian — rules + lessons learned the hard way; apply them)

$out" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
