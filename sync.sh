#!/usr/bin/env bash
# One command to install/update EVERYTHING on this machine from this repo:
#   • every skill in skills/*/   → ~/.claude/skills/<name>   (rsync mirror, per-skill --delete)
#   • every skill's agents/*.md  → ~/.claude/agents/          (register; our own only, never --delete)
#   • Obsidian memory hooks       → repos you pick from a scan  (per-repo, interactive)
# Idempotent — this is BOTH first-time install and update. The repo copy is the source of truth.
#
# Usage:
#   ./sync.sh                sync skills+agents, then pick repos to wire memory hooks
#   ./sync.sh --skills-only  sync skills+agents only, skip hook wiring
#   ./sync.sh --check        report skill/agent drift only (no writes; exit 1 if drift)
#   SCAN_ROOT=~/code ./sync.sh   where to scan for repos (default: ~/Documents)
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILLS_SRC="$SRC/skills"
SKILLS_DEST="${SKILLS_DEST:-$HOME/.claude/skills}"
AGENTS_DEST="${AGENTS_DEST:-$HOME/.claude/agents}"
HOOK_SYNC="$SKILLS_SRC/setup-obsidian-memory/assets/sync-hooks.sh"
SCAN_ROOT="${SCAN_ROOT:-$HOME/Documents}"
mode="${1:-}"

skill_dirs() { find "$SKILLS_SRC" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort; }

# ---- --check: report drift, write nothing -----------------------------------
if [ "$mode" = "--check" ]; then
  drift=0
  while IFS= read -r s; do
    if diff -rq --exclude='.git' "$SKILLS_SRC/$s" "$SKILLS_DEST/$s" >/dev/null 2>&1; then
      echo "skill $s: in sync ✓"
    else
      echo "skill $s: DRIFT (or missing) vs $SKILLS_DEST/$s"; drift=1
    fi
    for a in "$SKILLS_SRC/$s"/agents/*.md; do
      [ -e "$a" ] || continue
      b="$(basename "$a")"
      if diff -q "$a" "$AGENTS_DEST/$b" >/dev/null 2>&1; then
        echo "  agent $b: in sync ✓"
      else
        echo "  agent $b: DRIFT (or missing) vs $AGENTS_DEST"; drift=1
      fi
    done
  done < <(skill_dirs)
  exit "$drift"
fi

# ---- skills + agents ---------------------------------------------------------
mkdir -p "$SKILLS_DEST" "$AGENTS_DEST"
nsk=0; nag=0
while IFS= read -r s; do
  dest="$SKILLS_DEST/$s"
  if [ "$SKILLS_SRC/$s" -ef "$dest" ] 2>/dev/null; then
    echo "skill $s: already at install dir, skipping self-copy"
  else
    mkdir -p "$dest"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete --exclude='.git' "$SKILLS_SRC/$s"/ "$dest"/
    else
      rm -rf "$dest"; mkdir -p "$dest"; cp -R "$SKILLS_SRC/$s"/. "$dest"/
    fi
  fi
  nsk=$((nsk+1))
  for a in "$SKILLS_SRC/$s"/agents/*.md; do
    [ -e "$a" ] || continue
    cp -f "$a" "$AGENTS_DEST/$(basename "$a")"; nag=$((nag+1))
  done
done < <(skill_dirs)
echo "skills: synced $nsk → $SKILLS_DEST   |   agents: registered $nag → $AGENTS_DEST"

[ "$mode" = "--skills-only" ] && { echo "done ✓ (skills only)"; exit 0; }

# ---- memory hooks: pick repos, then reuse sync-hooks.sh per repo -------------
[ -x "$HOOK_SYNC" ] || { echo "hooks: $HOOK_SYNC missing/not executable, skipping"; exit 0; }

repos=()
while IFS= read -r r; do repos+=("$r"); done \
  < <(find "$SCAN_ROOT" -maxdepth 3 -name .git -type d 2>/dev/null | sed 's#/\.git$##' | sort)
[ "${#repos[@]}" -eq 0 ] && { echo "hooks: no git repos under $SCAN_ROOT"; exit 0; }

echo
echo "Wire Obsidian memory hooks into which repos? (scan: $SCAN_ROOT)"
for i in "${!repos[@]}"; do
  mark="  "; [ -f "${repos[$i]}/.claude/hooks/obsidian-recall.sh" ] && mark="✓ "
  printf "  %2d) %s%s\n" "$((i+1))" "$mark" "${repos[$i]}"
done
echo "  (✓ = already wired). Enter numbers (e.g. 1 3 5), 'a' for all, blank to skip."
printf "> "; read -r sel || sel=""

chosen=()
case "$sel" in
  ""|n|N) echo "hooks: skipped"; exit 0 ;;
  a|A|all) chosen=("${repos[@]}") ;;
  *)
    for tok in ${sel//,/ }; do
      case "$tok" in *[!0-9]*|"") continue ;; esac
      idx=$((tok-1))
      [ "$idx" -ge 0 ] && [ "$idx" -lt "${#repos[@]}" ] && chosen+=("${repos[$idx]}")
    done ;;
esac

[ "${#chosen[@]}" -eq 0 ] && { echo "hooks: nothing selected"; exit 0; }
for r in "${chosen[@]}"; do bash "$HOOK_SYNC" "$r"; done
echo "done ✓ (skills + agents + hooks in ${#chosen[@]} repo(s))"
