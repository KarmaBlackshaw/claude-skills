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
| `<vault>/Learnings.md` | Global cross-repo hub **index** (MOC; created once, reused by every repo) |
| `<vault>/Learnings/` | Atomic lesson notes, one `<slug>.md` per lesson (the hub path minus its extension) |
| `<vault>/Projects/<repo>/<repo>.md` | This repo's session-log spoke — the **folder-note** (frontmatter-tagged `project/<repo>`); its sibling conventions note is `<repo> — Coding Rules.md` |
| `<vault>/.obsidian/graph.json` | Graph view config: tag nodes on + color groups (created once per vault, only if absent) |
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
Store the chosen root as `VAULT`. Define paths (the spoke is a **folder-note**: same basename as its folder, so `[[<repo>]]` links resolve uniquely):
- `ACTIVE="$VAULT/Projects/$NAME/$NAME.md"`
- `RULES="$VAULT/Projects/$NAME/$NAME — Coding Rules.md"`
- `LEARNINGS="$VAULT/Learnings.md"`

### 3. Create vault notes (NEVER overwrite existing)
- Create `LEARNINGS` (the index) only if missing — use the **Learnings seed** below.
- Create the atomic-notes folder: `mkdir -p "${LEARNINGS%.md}"` (i.e. `<vault>/Learnings/`). Individual lesson notes are written later by `/sync-brain push`.
- Create `ACTIVE` only if missing (`mkdir -p "$VAULT/Projects/$NAME"`) — use the **Active Context seed** below, substituting `<repo>` and the project's stack. The seed's `tags: [project/<repo>]` frontmatter is what makes this project one labeled hub node in the graph (see **Graph project tag** below).
- **Seed the graph config** (per vault, once): if `"$VAULT/.obsidian/graph.json"` does not exist, copy `"$SKILL_DIR/assets/graph.json"` there. It turns on tag nodes and color-codes lessons / spokes / conventions / project facts. Never overwrite an existing one — the user may have tuned it.

### 4. Write the pointer (`CLAUDE.local.md`)
Create `$REPO/CLAUDE.local.md` from the **Pointer seed** below, substituting the real absolute paths into the machine-readable `KEY=value` block. **Do NOT touch the committed `CLAUDE.md`** — it stays authoritative for code conventions.

### 5. Gitignore the pointer
```bash
git -C "$REPO" check-ignore CLAUDE.local.md >/dev/null 2>&1 || printf '\n# Claude local memory pointer (machine-specific Obsidian paths)\nCLAUDE.local.md\n' >> "$REPO/.gitignore"
```

### 6. Install + register the hooks (idempotent)
```bash
bash "$SKILL_DIR/assets/sync-hooks.sh" "$REPO"
```
One command: copies the current `obsidian-recall.sh` + `obsidian-push.sh` into `$REPO/.claude/hooks/`, then merges SessionStart(obsidian-recall) + Stop(obsidian-push) into `settings.local.json` only if absent. Settings are never edited by hand. Safe to re-run — this is also how you propagate a later hook change (see **Updating an existing install**).

### 7. Conflict check (critical)
A Stop/PostCompact hook that does `cat >` on a vault file will **clobber** the spoke on every fire. Scan both settings for one:
```bash
grep -rl "cat >.*Active Context\|obsidian-context-sync" "$HOME/.claude/settings.json" "$REPO/.claude/" 2>/dev/null
```
If found, warn the user and offer to retire it (unregister + note the backup). Memory-write hooks must **append**, never overwrite.

### 8. Verify + finish
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
- **Structure:** this file is an **index (MOC)** — one line per lesson linking to its atomic note in `Learnings/<slug>.md`. NOT a running log; project-only facts stay in that project's `Active Context.md`.
- **Promotion is the exception.** A takeaway earns a note only if it's reusable beyond one session, behavior-changing, and not already covered. Most sessions add nothing.
- **Curate, don't append.** Before adding, refine an existing note on the same topic in place (bump its `updated:`) instead of duplicating; the slug is the dedup key. Group stack-specific lessons (Supabase, TS, Vue…) under a stack heading.
- **Soft cap.** When a section's index passes ~15–20 links or reads noisy, consolidate related notes into one sharper note.
- **Pull:** the `obsidian-recall.sh` SessionStart hook (and `/sync-brain pull`) inject this index plus every linked note at session start.
- **Push:** `/sync-brain push` writes/refines an atomic note and updates its index line via its Promotion gate at session end.

---

## Index (project spokes)

## Lessons
<!-- Index only: each lesson is an atomic note at Learnings/<slug>.md; keep one dated one-line link here per lesson. Refine the existing note before adding a new one. -->
```

### Active Context seed (`<vault>/Projects/<repo>/<repo>.md` — the folder-note spoke)
The `project/<repo>` tag is load-bearing — do not drop it (see **Graph project tag**).
```markdown
---
tags: [project/<repo>]
---
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
CODING_RULES=<vault>/Projects/<repo>/<repo> — Coding Rules.md
-->
```

## Graph project tag
The Obsidian graph can't label edges. Spokes are **folder-notes** (`Projects/<repo>/<repo>.md`) so each is uniquely named + labeled, and `[[<repo>]]` links resolve without ambiguity. On top of that, every note under `Projects/<repo>/` (the spoke `<repo>.md`, `<repo> — Coding Rules.md`, `Memory.md` + `Memory/*`) carries a nested `project/<repo>` frontmatter tag: with `showTags` on that tag becomes one hub node per project and its facts orbit it. Global `Learnings/` notes stay **untagged by project on purpose** — they're cross-repo and hub to `[[Learnings]]`. The seeded `graph.json` color-codes four categories: lessons (`path:"Learnings/"`), **spokes** (`path:"Projects/" -file:"Coding Rules" -path:Memory` — folder-notes share no filename token, so match by path minus the other two), conventions (`file:"Coding Rules"`), project facts (`path:Memory`). To back-fill tags on an already-populated vault, add `project/<slug>` to each note's `tags:` (idempotent: skip if present; drop a redundant bare `<slug>` tag).

## Updating an existing install
Changed a hook (e.g. the recall/push scripts)? Propagate it to every wired repo with **no manual copying** — `sync-hooks.sh` is idempotent (re-copies the current hooks, re-registers only if missing):
```bash
for repo in <wired-repo-roots…>; do
  bash "$SKILL_DIR/assets/sync-hooks.sh" "$repo"
done
```
Find wired repos with `find <dir> -maxdepth 2 -name CLAUDE.local.md`. Settings never need hand-editing: registration lives in the per-machine, gitignored `settings.local.json` and is handled by the script; the committed `settings.json` is intentionally left untouched so the memory hooks are never forced on teammates who clone the repo.

## Maintenance

Two read-mostly helpers in `assets/` keep a wired vault healthy.

### `memory-doctor.sh <vault-root> [--repo <path> …]`
Audits a hub vault (the dir with `Learnings.md`). Read-only. Prints four sections and exits `1` if it finds **actionable** issues (broken links / orphans), else `0`:
1. **Broken wikilinks** — `[[target]]` (handles `|alias`/`#heading`) that resolves to no note anywhere in the vault. Illustrative prose tokens (`wikilink`, `slug`, `name`…) are denylisted.
2. **Stale notes** — `Learnings/*.md` whose `updated:` is older than 6 months (or missing). Advisory.
3. **Orphans** — a note file with no index line, or an index link with no note file. Actionable.
4. **Dead file refs** — backticked `path/to.ext` tokens in notes; pass `--repo <path>` (repeatable) to resolve them against real repos, else they're just listed to eyeball. Advisory.

Run it after a migration or every so often; fix broken links + orphans, review the advisories.

### `migrate-native-memory.sh <repo-root> [--source inrepo|native|<dir>]`
Mechanically folds a repo's native memory store into its Obsidian spoke (routes by `type:`/filename-prefix: `feedback_`/`rules_` → Coding Rules, `reference_` → Coding Rules `### Reference`, `project_` → Active Context Standing Notes above `## Sessions`). **Idempotent** (dedupes by heading), **never deletes the source**, and prints anything it can't classify under `NEEDS MANUAL PLACEMENT`. Source default `inrepo` = `<repo>/.claude/memory`; `native` = `~/.claude/projects/<slug>/memory`. It does the ~80% mechanical mapping — judgment-heavy dedup/promotion still belongs to `/sync-brain push`.

## Common mistakes
| Mistake | Fix |
|---|---|
| Hardcoding vault paths in hooks/skills | Paths live only in `CLAUDE.local.md`; hooks grep them |
| Overwriting the committed `CLAUDE.md` | Append pointer to the gitignored `CLAUDE.local.md` instead |
| Non-idempotent re-runs | Guard settings + gitignore edits (the provided scripts already do) |
| A hook present on disk but unregistered | Present ≠ wired — always run the Verify step |
| A `cat >` memory-write hook | It clobbers the note; must append (Step 7) |
