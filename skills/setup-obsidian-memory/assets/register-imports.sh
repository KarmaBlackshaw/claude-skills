#!/usr/bin/env bash
# Put the always-on memory tiers into the SYSTEM PROMPT via CLAUDE.md `@path`
# imports instead of a hook message. A hook's additionalContext is inlined only
# up to ~10K chars (past that: a 2 KB preview + file path), and hook output
# never reaches subagents unless re-injected per event; memory-file imports have
# no such cap and are part of every subagent's context by design.
#
#   register-imports.sh --global     append `@<GLOBAL_STANDARDS>` to ~/.claude/CLAUDE.md
#   register-imports.sh [<repo>]     append `@<STANDARDS>`, `@<CODING_RULES>`,
#                                    `@<LEARNINGS>` (from the repo's CLAUDE.local.md
#                                    KEY=value block) to that CLAUDE.local.md
# Idempotent: a line is added only if that exact `@path` isn't present.
set -euo pipefail

HDR='## Memory imports'
NOTE='<!-- always-on tiers, read into the system prompt for this session and every subagent: org Standards, repo Coding Rules, Learnings index. Lesson bodies still arrive per prompt / per opened file via obsidian-retrieve.sh. -->'

# The import parser stops at whitespace, so a vault path with spaces (e.g.
# `<repo> — Coding Rules.md`) never loads. Import it through a space-free
# symlink under ~/.claude/imports/ instead — symlinks resolve fine, and unlike a
# hardlink a symlink survives the vault app rewriting the file.
LINKS="$HOME/.claude/imports"
importable() { # $1 = real path → prints the path to put after `@`
  case "$1" in
    *[[:space:]]*)
      mkdir -p "$LINKS"; slug="$(printf '%s' "$1" | sed 's|.*/||; s/\.md$//; s/[^A-Za-z0-9._-]\{1,\}/-/g; s/^-//; s/-$//')"
      ln -sfn "$1" "$LINKS/$slug.md"; printf '%s' "$LINKS/$slug.md" ;;
    *) printf '%s' "$1" ;;
  esac
}
add_import() { # $1 = target file, $2 = path to import
  [ -f "$2" ] || return 0
  # a stale line importing the raw (space-containing) path never loads — drop it
  case "$2" in *[[:space:]]*) grep -vxF "@$2" "$1" > "$1.tmp" && mv "$1.tmp" "$1" ;; esac
  i="$(importable "$2")"
  grep -qxF "@$i" "$1" && return 0
  grep -q "^$HDR" "$1" || printf '\n%s\n%s\n' "$HDR" "$NOTE" >> "$1"
  printf '@%s\n' "$i" >> "$1"; echo "  + @$i"
}

if [ "${1:-}" = --global ]; then
  G="${OBSIDIAN_GLOBAL_STANDARDS:-$HOME/Documents/obsidian/Standards.md}"
  T="$HOME/.claude/CLAUDE.md"; [ -f "$T" ] || : > "$T"
  echo "$T"; add_import "$T" "$G"; exit 0
fi

R="$(cd "${1:-.}" && pwd)"; PTR="$R/CLAUDE.local.md"
[ -f "$PTR" ] || { echo "skip: no CLAUDE.local.md in $R"; exit 0; }
# Imports outside the project dir are silently dropped until the project is
# approved (per-project flag in ~/.claude.json; interactive sessions prompt for
# it once, headless runs and subagents never do). Pre-approve — the vault is
# the user's own — so the tiers load from the first session.
CFG="$HOME/.claude.json"
if [ -f "$CFG" ] && command -v jq >/dev/null; then
  if [ "$(jq -r --arg p "$R" '.projects[$p].hasClaudeMdExternalIncludesApproved // false' "$CFG")" != true ]; then
    tmp="$(mktemp)"; jq --arg p "$R" '.projects[$p] = ((.projects[$p] // {}) + {hasClaudeMdExternalIncludesApproved:true, hasClaudeMdExternalIncludesWarningShown:true})' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
    echo "  ✓ approved external includes for $R"
  fi
fi
getpath() { grep -m1 "^$1=" "$PTR" 2>/dev/null | cut -d= -f2- || true; }
echo "$PTR"
for k in STANDARDS CODING_RULES LEARNINGS; do
  p="$(getpath "$k")"; [ -n "$p" ] && add_import "$PTR" "$p"
done
