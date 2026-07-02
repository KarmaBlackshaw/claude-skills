#!/usr/bin/env bash
# migrate-native-memory.sh — mechanically fold a repo's native/in-repo memory
# store into its Obsidian spoke (Coding Rules + Active Context Standing Notes).
# Usage: migrate-native-memory.sh <repo-root> [--source inrepo|native|<dir>]
#   default source: inrepo (<repo>/.claude/memory); native = ~/.claude/projects/<slug>/memory
# Idempotent (dedupes by heading). Read-only on the SOURCE — never deletes it.
# Honest scope: does the ~80% mechanical mapping by type; prints anything it
# can't classify under NEEDS MANUAL PLACEMENT for you to route by hand.
set -uo pipefail

REPO="${1:-}"; [ -n "$REPO" ] || { echo "usage: migrate-native-memory.sh <repo-root> [--source inrepo|native|<dir>]"; exit 2; }
shift || true
SRCMODE="inrepo"
[ "${1:-}" = "--source" ] && { SRCMODE="${2:?}"; shift 2; }

PTR="$REPO/CLAUDE.local.md"
[ -f "$PTR" ] || { echo "no CLAUDE.local.md — wire the repo first (setup-obsidian-memory)"; exit 2; }
getp() { grep -m1 "^$1=" "$PTR" 2>/dev/null | cut -d= -f2- || true; }
ACTIVE="$(getp ACTIVE_CONTEXT)"; RULES="$(getp CODING_RULES)"
[ -n "$ACTIVE" ] || { echo "no ACTIVE_CONTEXT in CLAUDE.local.md"; exit 2; }

case "$SRCMODE" in
  inrepo) SRC="$REPO/.claude/memory" ;;
  native) slug="$(printf '%s' "$REPO" | sed 's:/:-:g')"; SRC="$HOME/.claude/projects/$slug/memory" ;;
  *)      SRC="$SRCMODE" ;;
esac
[ -d "$SRC" ] || { echo "no source memory dir at $SRC"; exit 2; }

today="$(date +%F)"
RULES_SECTION="## Migrated from native memory ($today)"
ACTIVE_SECTION="## Migrated from native memory ($today)"
added_r=0; added_a=0; dup=0; manual=0

# Ensure a target file has the migration section header; create file if absent.
ensure_rules() {
  [ -n "$RULES" ] || return 1
  [ -f "$RULES" ] || printf -- '---\ntags: [project/%s]\n---\n\n# Coding Rules — %s\n' "$(basename "$REPO")" "$(basename "$REPO")" > "$RULES"
  grep -qF "$RULES_SECTION" "$RULES" || printf '\n%s\n' "$RULES_SECTION" >> "$RULES"
}
title_of() { # frontmatter name: → else filename slug
  local t; t="$(grep -m1 '^name:' "$1" | sed -E 's/^name:[[:space:]]*//; s/[[:space:]]*$//')"
  [ -n "$t" ] && printf '%s' "$t" || basename "$1" .md
}
body_of() { awk 'BEGIN{fm=0} NR==1&&/^---$/{fm=1;next} fm==1&&/^---$/{fm=2;next} fm!=1{print}' "$1"; }
classify() { # feedback|reference|rules|project|ambiguous
  local f="$1" ft; ft="$(grep -m1 '^type:' "$f" | sed -E 's/^type:[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$ft" ] && ft="$(grep -m1 '^  type:' "$f" | sed -E 's/^[[:space:]]*type:[[:space:]]*//; s/[[:space:]]*$//')"
  case "$ft" in feedback|reference|project) echo "$ft"; return;; esac
  case "$(basename "$f")" in
    feedback_*|feedback-*) echo feedback;; reference_*|reference-*) echo reference;;
    rules_*|rules-*) echo rules;; project_*|project-*) echo project;;
    *) echo ambiguous;;
  esac
}

for f in "$SRC"/*.md; do
  [ -e "$f" ] || continue
  [ "$(basename "$f")" = "MEMORY.md" ] && continue
  t="$(title_of "$f")"
  kind="$(classify "$f")"
  # dedupe: title already a heading in either target?
  if { [ -f "$RULES" ] && grep -qF "### $t" "$RULES"; } || grep -qF "### $t" "$ACTIVE" 2>/dev/null; then
    echo "  dup (skip): $t"; dup=$((dup+1)); continue
  fi
  case "$kind" in
    feedback|rules)
      ensure_rules && { printf '\n### %s\n\n%s\n' "$t" "$(body_of "$f")" >> "$RULES"; added_r=$((added_r+1)); } ;;
    reference)
      ensure_rules; grep -qF '### Reference' "$RULES" || printf '\n### Reference\n' >> "$RULES"
      printf '\n#### %s\n\n%s\n' "$t" "$(body_of "$f")" >> "$RULES"; added_r=$((added_r+1)) ;;
    project)
      # insert an Active-Context migration section just above "## Sessions"
      if ! grep -qF "$ACTIVE_SECTION" "$ACTIVE"; then
        awk -v sec="$ACTIVE_SECTION" '/^## Sessions/ && !done {print sec"\n"; done=1} {print}' "$ACTIVE" > "$ACTIVE.tmp" && mv "$ACTIVE.tmp" "$ACTIVE"
        grep -qF "$ACTIVE_SECTION" "$ACTIVE" || printf '\n%s\n' "$ACTIVE_SECTION" >> "$ACTIVE"  # no Sessions header → append
      fi
      # append the fact right under the section header
      awk -v sec="$ACTIVE_SECTION" -v t="$t" -v body="$(body_of "$f")" '
        {print} $0==sec && !ins {print "\n### " t "\n\n" body; ins=1}' "$ACTIVE" > "$ACTIVE.tmp" && mv "$ACTIVE.tmp" "$ACTIVE"
      added_a=$((added_a+1)) ;;
    *)
      echo "  NEEDS MANUAL PLACEMENT: $(basename "$f") (title: $t)"; manual=$((manual+1)) ;;
  esac
done

echo
echo "migrate-native-memory ($SRCMODE → spoke)"
echo "  → Coding Rules: $added_r   → Active Context: $added_a   dup-skipped: $dup   manual: $manual"
echo "  source left intact: $SRC"
[ "$manual" -gt 0 ] && echo "  ⚠ $manual file(s) had no type/prefix — place them by hand."
exit 0
