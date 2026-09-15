#!/usr/bin/env bash
# Self-check for point-of-use retrieval (obsidian-retrieve.sh) across every tier —
# spoke lessons, legacy atomic notes, global lessons, rule bullets — plus domain
# auto-detection, the recall hook's index filter, global index, and seen-set reset.
# Fake vault, no real claude, no tokens.
#   bash skills/setup-obsidian-memory/assets/test_retrieve.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export SYNC_BRAIN_HOME="$T/qhome"
export OBSIDIAN_GLOBAL_STANDARDS="$T/Standards.md"   # fake global rules, isolated from the real file

fail() { echo "FAIL: $1"; exit 1; }
ctx() { jq -r '.hookSpecificOutput.additionalContext // empty'; }

# Layout mirrors the real one: $T = vaults root (global tier), $T/vault = org vault.
# $REPO is a Vue + Supabase app (auto-detects Frontend,Backend-Data,Workflow).
REPO="$T/repo"; V="$T/vault"; mkdir -p "$REPO" "$V/Learnings" "$T/Learnings"
printf '{"dependencies":{"vue":"^3.5","@supabase/supabase-js":"^2"}}\n' > "$REPO/package.json"
wire() { printf 'ACTIVE_CONTEXT=%s\nLEARNINGS=%s\nSTANDARDS=%s\n' "$V/ac.md" "$V/Learnings.md" "$V/Standards.md" > "$1/CLAUDE.local.md"; }
wire "$REPO"
cat > "$V/Learnings.md" <<'EOF'
# Learnings
## Lessons by domain
### [[Frontend]] — Vue
- **focus dead on wrapper** — use focusin.
### [[Mobile]] — RN
- **PRAGMA in its own execAsync** — Android throws.
### [[Workflow]] — shell
- **PIPESTATUS empty in zsh** — temp file.
EOF
cat > "$V/Learnings/Frontend.md" <<'EOF'
# Frontend
## Vue
### `@focus`/`@blur` silently dead on wrapper-div components
focus and blur do not bubble; the wrapper swallows them. Use focusin/focusout.
Source: a
### Prefer destructured prop defaults over withDefaults
Vue 3.5 props destructure carries defaults inline in the component.
Source: b
EOF
cat > "$V/Learnings/Mobile.md" <<'EOF'
# Mobile
## SQLite
### Android expo-sqlite: PRAGMA in its own execAsync, never mixed with DDL
Batching PRAGMA with CREATE throws NullPointerException on Android.
Source: m
EOF
cat > "$V/Learnings/Workflow.md" <<'EOF'
# Workflow
## Shell
### PIPESTATUS is empty in zsh — capture pipe exit portably
redirect to a temp file and read the exit code.
Source: c
EOF
# global (cross-org) lessons tier + its index
cat > "$T/Learnings/Workflow.md" <<'EOF'
# Global Workflow
## Agents
### Subagents self-check only scoped files — verify centrally after a fan-out
The lead must typecheck the whole tree after parallel builders finish.
Source: d
EOF
cat > "$T/Learnings.md" <<'EOF'
# Global Learnings
## Lessons by domain
### [[Workflow]] — agents
- **verify centrally after fan-out** — lead typechecks.
### [[Mobile]] — RN
- **PRAGMA in its own execAsync** — Android throws.
EOF
# rules: global + org
printf '## Principles\n- **Import lodash per-method, never the barrel** — `import round from "lodash/round"`.\n' > "$T/Standards.md"
printf '## Vue\n- **Prefer defineModel over props+emit for v-model** — one declaration.\n' > "$V/Standards.md"

prompt() { printf '{"cwd":"%s","session_id":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "${REPO_OVERRIDE:-$REPO}" "$1" "$2" | bash "$HERE/obsidian-retrieve.sh"; }
edit()   { printf '{"cwd":"%s","session_id":"%s","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$REPO" "$1" "$2" | bash "$HERE/obsidian-retrieve.sh"; }

# --- 1. prompt pulls the matching lesson body, not the others ---
o="$(prompt s1 'the @focus event on my BaseInput wrapper div never fires' | ctx)"
grep -q 'Use focusin/focusout' <<<"$o" || fail "prompt: matching lesson body not injected"
grep -q 'PIPESTATUS' <<<"$o" && fail "prompt: unrelated Workflow lesson leaked"
grep -q 'withDefaults' <<<"$o" && fail "prompt: unrelated Frontend lesson leaked"
echo "ok: prompt -> matching lesson body only"

# --- 2. same session, same lesson -> silent (seen-set) ---
[ -z "$(prompt s1 'focus wrapper div again')" ] || fail "seen: lesson re-injected in same session"
echo "ok: seen-set suppresses repeat"

# --- 3. PreToolUse on a .vue path pulls Vue lessons, not shell ---
o="$(edit s2 "$REPO/src/components/BaseInput.vue" | ctx)"
grep -q 'wrapper-div' <<<"$o" || fail "edit: .vue path did not pull the component lesson"
grep -q 'PIPESTATUS' <<<"$o" && fail "edit: shell lesson leaked into a .vue edit"
echo "ok: PreToolUse .vue -> Vue lessons"

# --- 4. rule bullets re-surface, labeled by tier ---
o="$(prompt s5 'should I import round from the lodash barrel or per-method' | ctx)"
grep -q '^- (global rule) \*\*Import lodash per-method' <<<"$o" || fail "rules: global rule bullet missing/unlabeled"
grep -q '^## Rules that apply here' <<<"$o" || fail "rules: section header missing"
o="$(prompt s5 'use defineModel for the v-model on this component' | ctx)"
grep -q '^- (org rule) \*\*Prefer defineModel' <<<"$o" || fail "rules: org rule bullet missing/unlabeled"
echo "ok: rule bullets retrieved with tier labels"

# --- 5. global (cross-org) lessons tier is scanned ---
o="$(prompt s6 'after the subagents fan-out finished, verify centrally with a typecheck' | ctx)"
grep -q 'lead must typecheck' <<<"$o" || fail "global: cross-org lesson not injected"
echo "ok: global lessons tier retrieved"

# --- 6. auto-detected domains: a Vue+Supabase repo never sees Mobile lessons ---
[ -z "$(prompt s7 'Android expo-sqlite PRAGMA execAsync NullPointerException')" ] || fail "detect: Mobile lesson leaked into a Vue repo"
echo "ok: auto-detect excludes off-stack spokes"

# --- 7. no manifest -> Workflow only; DOMAINS=all -> everything ---
R3="$T/repo-docs"; mkdir -p "$R3"; wire "$R3"
REPO_OVERRIDE="$R3"
[ -z "$(prompt s8 'focus wrapper div never fires')" ] || fail "detect: Frontend lesson leaked into a manifest-less repo"
grep -q 'temp file' <<<"$(prompt s8 'PIPESTATUS empty in zsh pipe' | ctx)" || fail "detect: Workflow lesson missing in a manifest-less repo"
printf 'DOMAINS=all\n' >> "$R3/CLAUDE.local.md"
grep -q 'focusin' <<<"$(prompt s9 'focus wrapper div never fires' | ctx)" || fail "DOMAINS=all: Frontend lesson missing"
unset REPO_OVERRIDE
echo "ok: manifest-less repo -> Workflow only; DOMAINS=all -> everything"

# --- 8. legacy atomic-note vault: no <Spoke>.md files -> filter falls back to every note ---
V2="$T/vault2"; R4="$T/repo-legacy"; mkdir -p "$V2/Learnings" "$R4"
printf '{"dependencies":{"vue":"^3"}}\n' > "$R4/package.json"
printf 'ACTIVE_CONTEXT=%s\nLEARNINGS=%s\n' "$V2/ac.md" "$V2/Learnings.md" > "$R4/CLAUDE.local.md"
printf '# Legacy index\n## Lessons\n### Frontend — Vue\n- 2026-07-01 — defineModel mismatch [[definemodel-vmodel-name-mismatch]]\n' > "$V2/Learnings.md"
cat > "$V2/Learnings/definemodel-vmodel-name-mismatch.md" <<'EOF'
---
tags: [learning, vue]
---
# Unnamed defineModel() + a named v-model:foo binding is a silent no-op
Bind with plain v-model when the child declares a bare defineModel.
EOF
REPO_OVERRIDE="$R4"
o="$(prompt s10 'my v-model:open on the modal with defineModel never updates, silent no-op' | ctx)"
grep -q 'Bind with plain v-model' <<<"$o" || fail "legacy: atomic note not retrieved under auto-detected domains"
unset REPO_OVERRIDE
o="$(printf '{"session_id":"z"}' | CLAUDE_PROJECT_DIR="$R4" bash "$HERE/obsidian-recall.sh" SessionStart | ctx)"
grep -q 'defineModel mismatch' <<<"$o" || fail "legacy: recall dropped the legacy index"
echo "ok: legacy atomic-note vault retrieved + indexed despite domain filter"

# --- 9. recall: filters org+global index by detected domains, resets seen-set ---
o="$(printf '{"session_id":"s1"}' | CLAUDE_PROJECT_DIR="$REPO" bash "$HERE/obsidian-recall.sh" SessionStart | ctx)"
grep -q '\[\[Frontend\]\] — Vue' <<<"$o" || fail "recall: org Frontend index section missing"
grep -q '\[\[Workflow\]\] — shell' <<<"$o" || fail "recall: org Workflow index section missing"
grep -q '\[\[Mobile\]\]' <<<"$o" && fail "recall: Mobile index section leaked (org or global)"
grep -q '\[\[Workflow\]\] — agents' <<<"$o" || fail "recall: global index not injected"
grep -q 'filtered to Frontend,Backend-Data,Workflow' <<<"$o" || fail "recall: detected domains not reported"
[ ! -f "$SYNC_BRAIN_HOME/seen/s1" ] || fail "recall: seen-set for s1 not cleared"
echo "ok: recall filters org+global index by detected domains + clears seen-set"

# --- 10. unwired repo -> clean no-op ---
[ -z "$(printf '{"cwd":"%s","session_id":"x","hook_event_name":"UserPromptSubmit","prompt":"focus"}' "$T" | bash "$HERE/obsidian-retrieve.sh")" ] || fail "unwired repo produced output"
echo "ok: unwired repo is a no-op"
echo "all retrieve checks passed"
