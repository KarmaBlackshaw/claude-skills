---
name: sync-brain
description: Pull or push long-term memory between the current repo and a centralized Obsidian vault (hub-and-spoke). Use when the user says "/sync-brain", "sync brain", "pull context", "push learnings", "save session to obsidian", or at the start/end of a work session to load or persist project memory.
---

# sync-brain

Hub-and-spoke long-term memory. The **hub** is a global `Learnings.md` in an Obsidian vault; each repo is a **spoke** with its own `Active Context.md` session log. This skill moves context between the current repo and the vault.

## Path discovery (do this first, every time)

**Never hardcode vault paths.** Read them from the repo root's `CLAUDE.local.md` (gitignored). Grep the machine-readable `KEY=value` block for:

- `ACTIVE_CONTEXT=` → this repo's session log
- `LEARNINGS=` → global cross-repo learnings
- `CODING_RULES=` → conventions synced from `CLAUDE.md`

```bash
grep -m1 '^ACTIVE_CONTEXT=' CLAUDE.local.md | cut -d= -f2-
grep -m1 '^LEARNINGS=' CLAUDE.local.md | cut -d= -f2-
```

The atomic **lesson notes** live in `<notes-dir>/`, which is the `LEARNINGS` path with its extension removed (`…/Learnings.md` → `…/Learnings/`). `LEARNINGS` itself is only the index.

If `CLAUDE.local.md` is missing, tell the user this repo isn't wired to the vault yet and stop.

## Modes

Parse the argument after `/sync-brain` (default `pull`).

### `pull`
Load memory into context so you start informed.
1. Read `LEARNINGS` and `ACTIVE_CONTEXT`.
2. Summarize back: the current active-context state + any learnings relevant to what the user is about to do.

The `obsidian-recall.sh` SessionStart hook already auto-pulls; use this for a manual mid-session refresh.

### `push`
Persist this session's outcome. Default target is the **spoke** (`ACTIVE_CONTEXT`). The **hub** (`LEARNINGS`) is a small curated set — not a dump. Most sessions add nothing to it.
1. Read the current `ACTIVE_CONTEXT`.
2. Insert a new entry at the top of the Sessions list (newest first) using the **Session-End Template** below.
3. **Rotation:** keep the last 5 session entries. When you drop an older one, run its takeaways through the Promotion gate before deleting.

**Promotion gate — most takeaways NEVER reach the hub.** Promote to `LEARNINGS` only if ALL hold:
- **Reusable** beyond this one session — you'd genuinely apply it again.
- **Behavior-changing** — it would alter a future decision, not just record what happened.
- **Not already covered** — grep the hub first; no existing entry says the same thing.

A takeaway failing any gate stays in `ACTIVE_CONTEXT`. Stack-specific lessons (Supabase, TS, Vue…) MAY be promoted, but file them under a stack heading — never as loose top-level notes.

**Curate as atomic notes.** The hub `LEARNINGS` is an **index** — one `[[wikilink]]` line per lesson. Each lesson's full detail lives in its own note at `<notes-dir>/<slug>.md` (see Path discovery). To promote a lesson that passed the gate:
- **Slug** = kebab-case of the lesson title — it's the dedup key.
- **Existing note on the topic?** Refine that note in place (tighten, add the nuance, bump `updated:`). Do NOT create a near-duplicate; leave its index line as-is.
- **New note?** Create `<notes-dir>/<slug>.md` from the **Atomic-Note Template** below, then add ONE index line under the right section heading in `LEARNINGS`: `- **<one-line summary>** [[<slug>]]`.
- Stack-specific lessons (Supabase, TS, Vue…) go under a stack section heading — never loose.

**Soft cap.** If a section's index passes ~15–20 links or reads noisy, consolidate related notes into one sharper note (merge the bodies, delete the merged files, collapse their index lines).

4. Write the spoke, the atomic note(s), and the hub index. Confirm exactly what you saved to the spoke and which notes you created or refined (if any).

## Session-End Template

```markdown
### YYYY-MM-DD — <short title>
- **What:** <what changed this session — features, fixes, refactors>
- **Why:** <the reasoning / root cause, not just the what>
- **Architecture:** <structural decisions or new patterns, if any>
- **Learnings:** <optional — leave blank if none; only promote to [[Learnings]] via the push Promotion gate>
- **Follow-ups:** <open threads for next session, if any>
```

## Atomic-Note Template (`<notes-dir>/<slug>.md`)

```markdown
---
tags: [learning, <stack-or-workflow>]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
# <Lesson title — the claim in one line>

<the mechanism: what happens, why, and the fix — a short paragraph, not a session log>

Source: [[Active Context]] · <repo> · YYYY-MM-DD
```

## Rules
- Summarize only what actually happened this session — never invent entries.
- Use the real current date.
- Promotion to the hub is the exception, not the default — most sessions add nothing to `Learnings.md`.
- Keep `Active Context.md` lean; keep `Learnings.md` small and curated — refine existing entries over appending new ones.
- Pass file content through unchanged except for the edits above — in particular, preserve the spoke's `tags: [project/<repo>]` frontmatter (it's the note's graph hub label; see setup-obsidian-memory → **Graph project tag**).
- Global atomic lesson notes stay tagged `[learning, …]` only — never add a `project/<repo>` tag; they're cross-repo and hub to `[[Learnings]]`.
