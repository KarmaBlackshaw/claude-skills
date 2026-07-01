---
name: setup-obsidian-memory
description: Use when wiring a repository into an Obsidian hub-and-spoke long-term memory system — the user asks to "set up obsidian memory", "add the obsidian thing to this repo", "wire this repo to my vault", "give this project persistent memory across sessions", or bootstrap auto-pull / auto-push memory hooks for a codebase.
---

# Setup Obsidian Memory

Bootstraps hub-and-spoke long-term memory into the **current repo**: a shared Obsidian vault (`Learnings.md` hub + per-repo `Active Context.md` spoke), a gitignored `CLAUDE.local.md` path pointer, an auto-pull SessionStart hook, and an auto-push Stop hook.

**Core principle:** the vault paths live in ONE gitignored file (`CLAUDE.local.md`); hooks and the runtime skill grep them from there. Nothing committed or published ever hardcodes a personal path.

**REQUIRED COMPANION:** the `sync-brain` skill does the runtime read/write. This skill only wires the plumbing. If `~/.claude/skills/sync-brain/` is missing, tell the user to install it (same agentic-ai skills repo) before relying on push/pull.

## When to use
- A repo has no persistent memory and you want Claude to remember across sessions.
- Re-running setup after cloning the repo on a new machine.
- **Not** for one-off notes — this installs standing hooks.

## What gets created
| Target | Purpose |
|---|---|
| `<vault>/Learnings.md` | Global cross-repo hub (created once, reused by every repo) |
| `<vault>/Projects/<repo>/Active Context.md` | This repo's session-log spoke |
| `<repo>/CLAUDE.local.md` | **gitignored** — declares the vault paths (single source of truth) |
| `<repo>/.claude/hooks/obsidian-recall.sh` | SessionStart → injects memory into context |
| `<repo>/.claude/hooks/obsidian-push.sh` | Stop → nudges the model to run `/sync-brain push` |
| `<repo>/.claude/settings.local.json` | registers both hooks |

Assets referenced below (`assets/…`) live in this skill's base directory (shown when the skill loads). Set `SKILL_DIR` to that path.

## Steps

### 1. Gather context
```bash
REPO="$(git rev-parse --show-toplevel)"   # abort + ask if this errors (not a git repo)
NAME="$(basename "$REPO")"
```
If `$REPO/CLAUDE.local.md` already exists, the repo is likely already wired — read it, run the **Verify** step only, and stop. Don't recreate.

### 2. Get the vault path
Detect candidate Obsidian vaults (folders containing `.obsidian/`), then confirm with the user via AskUserQuestion:
```bash
find "$HOME/Documents" "$HOME/Library/Mobile Documents" "$HOME" -maxdepth 4 -name .obsidian -type d 2>/dev/null | sed 's:/\.obsidian::'
```
Store the chosen root as `VAULT`. Define paths:
- `ACTIVE="$VAULT/Projects/$NAME/Active Context.md"`
- `LEARNINGS="$VAULT/Learnings.md"`

### 3. Create vault notes (NEVER overwrite existing)
- Create `LEARNINGS` only if missing — use the **Learnings seed** below.
- Create `ACTIVE` only if missing (`mkdir -p "$VAULT/Projects/$NAME"`) — use the **Active Context seed** below, substituting `<repo>` and the project's stack.

### 4. Write the pointer (`CLAUDE.local.md`)
Create `$REPO/CLAUDE.local.md` from the **Pointer seed** below, substituting the real absolute paths into the machine-readable `KEY=value` block. **Do NOT touch the committed `CLAUDE.md`** — it stays authoritative for code conventions.

### 5. Gitignore the pointer
```bash
git -C "$REPO" check-ignore CLAUDE.local.md >/dev/null 2>&1 || printf '\n# Claude local memory pointer (machine-specific Obsidian paths)\nCLAUDE.local.md\n' >> "$REPO/.gitignore"
```

### 6. Install the hooks
```bash
mkdir -p "$REPO/.claude/hooks"
cp "$SKILL_DIR/assets/obsidian-recall.sh" "$SKILL_DIR/assets/obsidian-push.sh" "$REPO/.claude/hooks/"
chmod +x "$REPO/.claude/hooks/obsidian-recall.sh" "$REPO/.claude/hooks/obsidian-push.sh"
```

### 7. Register the hooks (idempotent)
```bash
bash "$SKILL_DIR/assets/register-hooks.sh" "$REPO"
```
Merges SessionStart(obsidian-recall) + Stop(obsidian-push) into `settings.local.json` only if absent — safe to re-run.

### 8. Conflict check (critical)
A Stop/PostCompact hook that does `cat >` on a vault file will **clobber** the spoke on every fire. Scan both settings for one:
```bash
grep -rl "cat >.*Active Context\|obsidian-context-sync" "$HOME/.claude/settings.json" "$REPO/.claude/" 2>/dev/null
```
If found, warn the user and offer to retire it (unregister + note the backup). Memory-write hooks must **append**, never overwrite.

### 9. Verify + finish
```bash
export CLAUDE_PROJECT_DIR="$REPO"
jq empty "$REPO/.claude/settings.local.json" && echo "settings valid"
echo '{"stop_hook_active":false}' | bash "$REPO/.claude/hooks/obsidian-push.sh" | jq -e '.decision=="block"' >/dev/null && echo "push hook ok"
bash "$REPO/.claude/hooks/obsidian-recall.sh" SessionStart | jq -e '.hookSpecificOutput.additionalContext' >/dev/null && echo "recall hook ok"
git -C "$REPO" check-ignore CLAUDE.local.md >/dev/null && echo "pointer gitignored"
```
Then tell the user: **fully restart Claude Code** (quit, not just close the window) — hooks load at session start.

## Seeds

### Learnings seed (`<vault>/Learnings.md`)
```markdown
# 🧠 Global Master Learnings

> Cross-repo, long-term memory hub for Claude Code. Durable, reusable lessons that outlive any single session or project. Per-project context lives in each repo's spoke note.

## How this file works
- **Scope:** lessons that generalize across projects. Project-only facts stay in that project's `Active Context.md`.
- **Promotion:** when a session log entry proves durable and reusable, promote it here and link back with `[[wikilink]]`.
- **Pull:** the `obsidian-recall.sh` SessionStart hook (and `/sync-brain pull`) inject this file at session start.
- **Push:** `/sync-brain push` appends new lessons here at session end.

---

## Index (project spokes)

## Lessons
<!-- Add dated (YYYY-MM-DD) cross-repo lessons here. -->
```

### Active Context seed (`<vault>/Projects/<repo>/Active Context.md`)
```markdown
# Active Context — <repo>

> Session log for Claude Code (newest first). This file is the **spoke**; the **hub** is [[Learnings]].
> **Rotation:** keep the last 5 session entries. When dropping an older one, lift its durable takeaways into [[Learnings]] and link back with `[[wikilink]]`.

## Project
<one line: stack / what this repo is>

---

## Sessions (newest first)

<!-- Newer sessions above. When >5 entries, move the oldest's durable takeaways to [[Learnings]] and delete the stale summary. -->
```

### Pointer seed (`<repo>/CLAUDE.local.md`)
```markdown
# Persistent Memory & Self-Learning (LOCAL — gitignored, machine-specific)

> Not committed. Wires this repo to the Obsidian vault. The committed `CLAUDE.md` is untouched and authoritative for code conventions.

## Memory locations
- **Active Context** (this repo's session log): `<ACTIVE path>`
- **Global Master Learnings** (cross-repo hub): `<LEARNINGS path>`

## Instructions for Claude
- **Before** architectural changes: read Active Context + Learnings (auto-injected at session start by `.claude/hooks/obsidian-recall.sh`; or `/sync-brain pull`).
- **At session end / on request:** `/sync-brain push` — append a session summary to Active Context, promote durable cross-repo lessons to Learnings.
- Keep Active Context lean (last 5 sessions); graduate durable lessons to Learnings with `[[wikilinks]]`.

<!-- sync-brain paths (machine-readable — scripts grep these KEY=value lines; do not rename keys)
ACTIVE_CONTEXT=<ACTIVE path>
LEARNINGS=<LEARNINGS path>
CODING_RULES=<vault>/Projects/<repo>/Coding Rules.md
-->
```

## Common mistakes
| Mistake | Fix |
|---|---|
| Hardcoding vault paths in hooks/skills | Paths live only in `CLAUDE.local.md`; hooks grep them |
| Overwriting the committed `CLAUDE.md` | Append pointer to the gitignored `CLAUDE.local.md` instead |
| Non-idempotent re-runs | Guard settings + gitignore edits (the provided scripts already do) |
| A hook present on disk but unregistered | Present ≠ wired — always run the Verify step |
| A `cat >` memory-write hook | It clobbers the note; must append (Step 8) |
