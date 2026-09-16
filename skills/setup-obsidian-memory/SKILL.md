---
name: setup-obsidian-memory
description: Use when wiring a repository into an Obsidian hub-and-spoke long-term memory system — the user asks to "set up obsidian memory", "add the obsidian thing to this repo", "wire this repo to my vault", "give this project persistent memory across sessions", or bootstrap auto-pull / auto-push memory hooks for a codebase.
---

# Setup Obsidian Memory

Bootstraps hub-and-spoke long-term memory into the **current repo**: a shared Obsidian vault (`Learnings.md` hub + per-repo `Active Context.md` spoke), a gitignored `CLAUDE.local.md` path pointer that also `@imports` the always-on tiers (org Standards, repo Coding Rules, Learnings index) into the system prompt of every session and subagent, and the **machine-global memory hooks** — a SessionStart recall + drain, a SessionEnd capture, and point-of-use lesson retrieval — that persist and synthesize sessions.

**Core principle:** the vault paths live in ONE gitignored file (`CLAUDE.local.md`); hooks and the runtime skill grep them from there. Nothing committed or published ever hardcodes a personal path.

**Install model — global, wired per-repo by the pointer.** The hook scripts live in ONE place (`~/.claude/hooks/`) and are registered ONCE in `~/.claude/settings.json`. Every hook no-ops instantly unless the session's repo has a `CLAUDE.local.md`, so a repo is "wired" purely by that pointer file existing — no per-repo scripts, no per-repo registration, no drift. (Older installs put a copy of the scripts in each repo's `.claude/`; `migrate-to-global.sh` retires those — see **Updating an existing install**.)

**Capture/synthesis pipeline (replaces the old Stop-hook push).** `obsidian-capture.sh` (SessionEnd) queues the finished session into `~/.claude/sync-brain/queue/` and kicks a detached `obsidian-drain.sh`; the drain synthesizes each queued session out-of-band via a headless `claude` run that writes the spoke, then archives it. Editorial judgment (headline / learnings) is out of the hot path, so there is no "correction not saved" problem. `obsidian-push.sh` is retired.

**Recall is two-tier.** Session start (and every subagent start) injects the always-on layer (Standards → Coding Rules) plus the Learnings **indexes**, open Threads, and Active Context — in that priority, packed whole-section under a ~9.4 K-char budget (`RECALL_BUDGET`): the harness inlines hook context only up to 10,000 chars and otherwise swaps in a 2 KB preview, so anything that doesn't fit is spilled to `~/.claude/sync-brain/recall/<session>.md` with a pointer line instead of being silently cut — narrowed to the repo's **domains**, auto-detected from its manifests (`package.json` deps → Frontend / Mobile / Backend-Data, `supabase/` or `*.sql` or `pyproject`/`go.mod` → Backend-Data; Workflow always; no manifest → Workflow only). `DOMAINS=` in the pointer overrides detection (`all` = every spoke). Lesson **bodies** are never injected up front: `obsidian-retrieve.sh` scores every memory unit — rule bullets from all three Standards tiers, `###` lessons in the org **and** global spokes, legacy one-lesson-per-file atomic notes — against each prompt (UserPromptSubmit) and each file about to be edited or read (PreToolUse on Edit/Write/Read and lean-ctx `ctx_edit`/`ctx_read` — so read-only reviewer subagents get lessons at the point of use too), and injects the top matches in full, once per session, right where attention is strongest. Growth in the vault costs nothing per session — only the matched units ever load.

**REQUIRED COMPANION:** the `sync-brain` skill does the runtime read/write. This skill only wires the plumbing. If `~/.claude/skills/sync-brain/` is missing, tell the user to install it (same agentic-ai skills repo) before relying on push/pull.

## When to use
- A repo has no persistent memory and you want Claude to remember across sessions.
- Re-running setup after cloning the repo on a new machine.
- **Not** for one-off notes — this installs standing hooks.

## What gets created
| Target | Purpose |
|---|---|
| `<vaults-root>/Learnings.md` + `Learnings/` | **Global lessons** tier — cross-org, cross-stack insights (one index + spokes above all vaults, mirroring `GLOBAL_STANDARDS`; created once) |
| `<vault>/Learnings.md` | **Org lessons** hub **index** (MOC; created once, reused by every repo in this vault) |
| `<vault>/Learnings/` | Domain **spoke** files (`Frontend.md`, `Backend-Data.md`, `Mobile.md`, `Workflow.md`) holding lesson detail; the hub path minus its extension |
| `<vault>/Standards.md` | **Org-shared coding standards** (one per vault; injected in full every session — the cross-repo convention layer) |
| `<vault>/Projects/<repo>/<repo>.md` | This repo's session-log spoke — the **folder-note** (frontmatter-tagged `project/<repo>`); its sibling conventions note is `<repo> — Coding Rules.md` |
| `<vault>/Projects/<repo>/<repo> — Threads.md` | This repo's **open-threads ledger** — durable follow-ups that survive session rotation (recall injects the `open` rows) |
| `<vault>/.obsidian/graph.json` | Graph view config: tag nodes on + color groups (created once per vault, only if absent) |
| `<repo>/CLAUDE.local.md` | **gitignored** — declares the vault paths (single source of truth); its presence is what wires the repo. Ends with a `## Memory imports` block of `@path` lines (written by `register-imports.sh`) that load org Standards + repo Coding Rules + the Learnings index into the system prompt — no size cap, reaches every subagent |
| `~/.claude/hooks/obsidian-recall.sh` | SessionStart (skips `compact`) → injects the session-scoped remainder (open Threads, Active Context); the always-on tiers come in via the `@imports` instead |
| `~/.claude/hooks/obsidian-capture.sh` | SessionEnd → queues the session + kicks the drain |
| `~/.claude/hooks/obsidian-drain.sh` | SessionStart (async catch-up) + detached from capture → synthesizes queued sessions into their spoke |
| `~/.claude/hooks/obsidian-retrieve.sh` | UserPromptSubmit + PreToolUse(Edit\|Write\|Read\|ctx_edit\|ctx_read) → injects the lesson bodies that match the prompt / file about to be edited or read (point-of-use recall; seen-set keyed per agent so subagents get their own pass) |
| `~/.claude/hooks/obsidian-domains.sh` | sourced by recall + retrieve — detects the repo's Learnings domains from its manifests (`DOMAINS=` overrides) |
| `~/.claude/settings.json` | registers all four, once, machine-wide |

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
- `THREADS="$VAULT/Projects/$NAME/$NAME — Threads.md"`
- `LEARNINGS="$VAULT/Learnings.md"`
- `STANDARDS="$VAULT/Standards.md"`  (org-shared standards — one per vault, shared by every repo in this org)
- `GLOBAL_STANDARDS="$(dirname "$VAULT")/Standards.md"`  (cross-org, cross-stack baseline — ONE file above all vaults, shared by every repo everywhere)
- `GLOBAL_LEARNINGS="$(dirname "$VAULT")/Learnings"`  (cross-org lessons tier — `Learnings.md` index + `Learnings/` spokes above all vaults; the hooks derive it from `LEARNINGS`, so the pointer key is only needed for a non-standard layout)

### 3. Create vault notes (NEVER overwrite existing)
- Create `LEARNINGS` (the index) only if missing — use the **Learnings seed** below.
- Create the spokes folder: `mkdir -p "${LEARNINGS%.md}"` (i.e. `<vault>/Learnings/`). Domain spoke files are created/appended later by `/sync-brain push`.
- Create `STANDARDS` (`$VAULT/Standards.md`) only if missing — use the **Standards seed** below. This is the org-shared convention layer, injected in full every session; seed it from the conventions common to this org's repos. Put **only org-specific** rules here — anything true across orgs and stacks belongs one tier up in `GLOBAL_STANDARDS`.
- Create `GLOBAL_LEARNINGS.md` (the global index) + the `GLOBAL_LEARNINGS/` dir only if missing — same shape as the **Learnings seed** below, titled *Global Learnings (cross-org, cross-stack)*. A lesson lands there only via `/sync-brain push` check D (holds in a different org AND stack).
- Create `GLOBAL_STANDARDS` only if missing — the cross-org baseline, one file for every vault. The recall hook injects it **ungated** (before the org file, and even in repos with no `CLAUDE.local.md`), so it never needs a `KEY=` line unless the vault root is non-standard; the hook defaults to `$HOME/Documents/obsidian/Standards.md`, overridable via the `OBSIDIAN_GLOBAL_STANDARDS` env var.
- Create `ACTIVE` only if missing (`mkdir -p "$VAULT/Projects/$NAME"`) — use the **Active Context seed** below, substituting `<repo>` and the project's stack. The seed's `tags: [project/<repo>]` frontmatter is what makes this project one labeled hub node in the graph (see **Graph project tag** below).
- Create `THREADS` only if missing — use the **Threads-ledger seed** below (same `project/<repo>` tag). It starts as an empty table; `/sync-brain push` fills it.
- **Seed the graph config** (per vault, once): if `"$VAULT/.obsidian/graph.json"` does not exist, copy `"$SKILL_DIR/assets/graph.json"` there. It turns on tag nodes and color-codes lessons / spokes / conventions / project facts. Never overwrite an existing one — the user may have tuned it.

### 4. Write the pointer (`CLAUDE.local.md`)
Create `$REPO/CLAUDE.local.md` from the **Pointer seed** below, substituting the real absolute paths into the machine-readable `KEY=value` block. Domains are **auto-detected** from the repo's manifests — leave `DOMAINS=` out. Set it only to override: `DOMAINS=Frontend,Workflow` to pin, `DOMAINS=all` to see every spoke. Check what detection picked in the Verify step (the recall output says `filtered to …`). **Do NOT touch the committed `CLAUDE.md`** — it stays authoritative for code conventions.

Then add the imports and pre-approve them (imports outside the project dir are silently dropped until the project is approved in `~/.claude.json`; the script sets the flag so headless runs and subagents load them from the first session):
```bash
bash "$SKILL_DIR/assets/register-imports.sh" "$REPO"
```
Idempotent — appends only the `@path` lines that are missing. Claude Code's import parser stops at whitespace (an em-dash is fine), so a vault path with spaces (`<repo> — Coding Rules.md`) is imported through a space-free symlink the script creates under `~/.claude/imports/`. Verified: imports reach subagents; the approval flag is per project and headless runs never prompt for it.

### 5. Gitignore the pointer
```bash
git -C "$REPO" check-ignore CLAUDE.local.md >/dev/null 2>&1 || printf '\n# Claude local memory pointer (machine-specific Obsidian paths)\nCLAUDE.local.md\n' >> "$REPO/.gitignore"
```

### 6. Ensure the global hooks are installed (once per machine)
```bash
bash "$SKILL_DIR/assets/sync-hooks.sh"
```
One command, no repo arg: copies the current `obsidian-recall.sh` + `obsidian-capture.sh` + `obsidian-drain.sh` + `obsidian-retrieve.sh` + `obsidian-domains.sh` + `register-imports.sh` into `~/.claude/hooks/`, merges the hooks into `~/.claude/settings.json` only if absent, and adds the global-Standards `@import` to `~/.claude/CLAUDE.md` (the ungated top tier, every repo). Idempotent — a no-op if already installed. Because wiring is by `CLAUDE.local.md` presence, once this has run once the repo you just pointed (Step 4) is already wired; there is nothing per-repo to install. Settings are never edited by hand.

### 7. Conflict check (critical)
A Stop/PostCompact hook that does `cat >` on a vault file will **clobber** the spoke on every fire. Scan both settings for one:
```bash
grep -rl "cat >.*Active Context\|obsidian-context-sync" "$HOME/.claude/settings.json" "$REPO/.claude/" 2>/dev/null
```
If found, warn the user and offer to retire it (unregister + note the backup). Memory-write hooks must **append**, never overwrite.

### 8. Verify + finish
```bash
export CLAUDE_PROJECT_DIR="$REPO"
jq empty "$HOME/.claude/settings.json" && echo "global settings valid"
bash "$HOME/.claude/hooks/obsidian-recall.sh" SessionStart | jq -e '.hookSpecificOutput.additionalContext' >/dev/null && echo "recall hook ok"
# capture queues this repo (uses a throwaway session id + SYNC_BRAIN_NO_SPAWN so no drain fires)
printf '{"cwd":"%s","session_id":"verify-x","transcript_path":""}' "$REPO" | SYNC_BRAIN_NO_SPAWN=1 bash "$HOME/.claude/hooks/obsidian-capture.sh" \
  && [ -f "$HOME/.claude/sync-brain/queue/verify-x.meta" ] && echo "capture hook ok" && rm -f "$HOME/.claude/sync-brain/queue/verify-x.meta"
git -C "$REPO" check-ignore CLAUDE.local.md >/dev/null && echo "pointer gitignored"
# retrieval: a prompt naming a lesson's subject must pull that lesson body (pick a header from a spoke)
printf '{"cwd":"%s","session_id":"verify-x","hook_event_name":"UserPromptSubmit","prompt":"<words from a lesson ### header>"}' "$REPO" \
  | bash "$HOME/.claude/hooks/obsidian-retrieve.sh" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null && echo "retrieve hook ok"
bash "$SKILL_DIR/assets/test_retrieve.sh"   # plumbing self-check, no tokens
```
Then tell the user: **fully restart Claude Code** (quit, not just close the window) — hooks load at session start.

## Seeds

### Learnings seed (`<vault>/Learnings.md`)
```markdown
# 🧠 Global Master Learnings

> Cross-repo, long-term memory hub for Claude Code. Durable, reusable lessons that outlive any single session or project. Per-project context lives in each repo's spoke note.

## How this file works
- **Structure:** this file is an **index (MOC)** — one summary line per lesson, grouped under its **domain spoke** section. Lesson detail lives in the spoke files under `Learnings/` (`Frontend.md`, `Backend-Data.md`, `Mobile.md`, `Workflow.md`), not here. NOT a running log; project-only facts stay in that project's `Active Context.md`.
- **Promotion is the exception.** A takeaway earns a line only if it's reusable beyond one session, behavior-changing, and not already covered. Most sessions add nothing.
- **Curate, don't append.** Before adding, refine an existing lesson on the same topic in place inside its spoke (bump the spoke's `updated:`) instead of duplicating; the `###` header is the dedup key. File each lesson under the right spoke and `##` area.
- **Soft cap.** When a spoke's `##` area passes ~15–20 lessons or reads noisy, merge related `###` subsections into one sharper lesson.
- **Pull:** the `obsidian-recall.sh` SessionStart hook (and `/sync-brain pull`) inject **only this index** — spoke bodies are read on demand to keep per-session tokens low.
- **Push:** `/sync-brain push` appends/refines a lesson in its domain spoke and updates its index line via the Promotion gate at session end.

---

## Index (project spokes)

## Lessons
<!-- Index only: lesson detail lives in the domain spokes (Learnings/Frontend.md, Backend-Data.md, Mobile.md, Workflow.md); keep one summary line here per lesson, grouped under its spoke section. Refine the existing lesson in its spoke before adding a new one. The recall hook injects only this file. -->
```

### Standards seed (`<vault>/Standards.md` — org-shared, injected in full every session)
One per vault (= one per org). Seed it with the conventions common to that org's repos — keep it tight, it loads every session. Repo-specifics stay in each repo's Coding Rules; durable *lessons* go to [[Learnings]]; global workflow prefs live in `~/.claude/CLAUDE.md`.
```markdown
---
tags: [standards]
type: coding-standards
scope: <org>-org
updated: YYYY-MM-DD
---
# 🧭 <Org> Coding Standards

> Shared conventions for every repo in the `<org>` vault. The `obsidian-recall.sh` SessionStart hook injects this file **in full, every session**. Cross-repo only — repo-specifics stay in each repo's `<repo> — Coding Rules.md`.

## Core (stack-agnostic)
- <e.g. DRY/KISS/SOLID/YAGNI; no `any`/casts; package-first; never commit unless asked>

## <Primary stack — e.g. Vue 3 / React Native>
- <shared framework conventions>

## Styling
- <Tailwind / NativeWind conventions>
```

### Active Context seed (`<vault>/Projects/<repo>/<repo>.md` — the folder-note spoke)
The `project/<repo>` tag is load-bearing — do not drop it (see **Graph project tag**).
```markdown
---
tags: [project/<repo>]
---
# Active Context — <repo>

> Session log for Claude Code (newest first). This file is the **spoke**; the **hub** is [[Learnings]].
> **Rotation:** keep the last 5 session entries. When dropping an older one, lift its durable takeaways into the matching [[Learnings]] domain spoke (Frontend / Backend-Data / Mobile / Workflow) and refresh its index line.

## Project
<one line: stack / what this repo is>

---

## Sessions (newest first)

<!-- Newer sessions above. When >5 entries, move the oldest's durable takeaways to [[Learnings]] and delete the stale summary. -->
```

### Threads-ledger seed (`<vault>/Projects/<repo>/<repo> — Threads.md`)
Durable open action items — where follow-ups outlive session rotation. Starts empty; `/sync-brain push` opens/closes rows. The `project/<repo>` tag keeps it on the graph with the rest of the spoke.
```markdown
---
tags: [project/<repo>]
---
# Open Threads — <repo>

> Durable follow-ups for this repo (survive session rotation). `/sync-brain push` logs new follow-ups here as `open` and flips resolved ones to `done`; the recall hook injects the `open` rows each session start.

| status | thread | opened | source |
|--------|--------|--------|--------|
```

### Pointer seed (`<repo>/CLAUDE.local.md`)
```markdown
# Persistent Memory & Self-Learning (LOCAL — gitignored, machine-specific)

> Not committed. Wires this repo to the Obsidian vault. The committed `CLAUDE.md` is untouched and authoritative for code conventions.

## Memory locations
- **Active Context** (this repo's session log): `<ACTIVE path>`
- **Global Master Learnings** (cross-repo hub): `<LEARNINGS path>`
- **Org Standards** (shared conventions for every repo in this vault, injected in full every session): `<vault>/Standards.md`

## Instructions for Claude
- **Before** architectural changes: read Active Context + Learnings (auto-injected at session start by `.claude/hooks/obsidian-recall.sh`; or `/sync-brain pull`).
- **At session end / on request:** `/sync-brain push` — append a session summary to Active Context, promote durable cross-repo lessons into the matching Learnings **domain spoke** (`Learnings/Frontend.md`, `Backend-Data.md`, `Mobile.md`, `Workflow.md`) as a `###` subsection + a one-line index entry.
- Keep Active Context lean (last 5 sessions); graduate durable lessons into a Learnings domain spoke and refresh its index line. The SessionStart hook injects **only** the `Learnings.md` index — spokes are read on demand.

<!-- sync-brain paths (machine-readable — scripts grep these KEY=value lines; do not rename keys)
ACTIVE_CONTEXT=<ACTIVE path>
LEARNINGS=<LEARNINGS path>
STANDARDS=<vault>/Standards.md
GLOBAL_STANDARDS=<vaults-root>/Standards.md
CODING_RULES=<vault>/Projects/<repo>/<repo> — Coding Rules.md
THREADS=<vault>/Projects/<repo>/<repo> — Threads.md
DOMAINS=<optional override — auto-detected from manifests when absent; `all` = every spoke>
GLOBAL_LEARNINGS=<vaults-root>/Learnings   (optional — derived from LEARNINGS when absent)
-->
```

## Graph project tag
The Obsidian graph can't label edges. Spokes are **folder-notes** (`Projects/<repo>/<repo>.md`) so each is uniquely named + labeled, and `[[<repo>]]` links resolve without ambiguity. On top of that, every note under `Projects/<repo>/` (the spoke `<repo>.md`, `<repo> — Coding Rules.md`, `Memory.md` + `Memory/*`) carries a nested `project/<repo>` frontmatter tag: with `showTags` on that tag becomes one hub node per project and its facts orbit it. Global `Learnings/` notes stay **untagged by project on purpose** — they're cross-repo and hub to `[[Learnings]]`. The seeded `graph.json` color-codes four categories: lessons (`path:"Learnings/"`), **spokes** (`path:"Projects/" -file:"Coding Rules" -path:Memory` — folder-notes share no filename token, so match by path minus the other two), conventions (`file:"Coding Rules"`), project facts (`path:Memory`). To back-fill tags on an already-populated vault, add `project/<slug>` to each note's `tags:` (idempotent: skip if present; drop a redundant bare `<slug>` tag).

## Updating an existing install
Changed a hook script? There's one copy now — re-run `sync-hooks.sh` once and every wired repo picks it up next session (idempotent: re-copies the current scripts to `~/.claude/hooks/`, re-registers only if missing):
```bash
bash "$SKILL_DIR/assets/sync-hooks.sh"
```

### Migrating a legacy per-repo install to global
Older installs copied the scripts into each repo's `.claude/hooks/` and registered them in that repo's `settings.local.json`. Once the global hooks exist, those repos would fire the hooks **twice** per event. Retire the per-repo copies with `migrate-to-global.sh` (backs up each `settings.local.json`, strips only the obsidian hook entries, deletes the local scripts — everything else untouched):
```bash
bash "$SKILL_DIR/assets/sync-hooks.sh"                       # install global once
for repo in $(find "$HOME/Documents" -maxdepth 4 -path '*/.claude/hooks/obsidian-recall.sh' | sed 's:/.claude/hooks/obsidian-recall.sh::'); do
  bash "$SKILL_DIR/assets/migrate-to-global.sh" "$repo"
done
```
Find wired repos by installed hook (`find … -path '*/.claude/hooks/obsidian-recall.sh'`) or pointer (`find <dir> -maxdepth 2 -name CLAUDE.local.md`).

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
| Injecting lesson bodies at session start | They land ~100K tokens before they matter and get "forgotten"; index up front, bodies via `obsidian-retrieve.sh` at point of use |
| `DOMAINS=` naming a spoke that doesn't exist | Spell it as the file: `Frontend`, `Backend-Data`, `Mobile`, `Workflow`. (A vault with none of the named spoke files — a legacy atomic-note vault — is read whole, so a typo silences nothing, it just stops filtering.) |
| Detection picked the wrong stack | Check the recall output's `filtered to …`; pin with `DOMAINS=` in the pointer |
| Global reg + leftover per-repo reg | Fires hooks twice per event — run `migrate-to-global.sh` on legacy repos |
