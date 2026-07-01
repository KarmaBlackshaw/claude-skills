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

If `CLAUDE.local.md` is missing, tell the user this repo isn't wired to the vault yet and stop.

## Modes

Parse the argument after `/sync-brain` (default `pull`).

### `pull`
Load memory into context so you start informed.
1. Read `LEARNINGS` and `ACTIVE_CONTEXT`.
2. Summarize back: the current active-context state + any learnings relevant to what the user is about to do.

The `obsidian-recall.sh` SessionStart hook already auto-pulls; use this for a manual mid-session refresh.

### `push`
Persist this session's outcome.
1. Read the current `ACTIVE_CONTEXT`.
2. Insert a new entry at the top of the Sessions list (newest first) using the **Session-End Template** below.
3. **Rotation:** keep the last 5 session entries. For any entry you drop, lift its durable, reusable takeaways into `LEARNINGS` (dated, linked back with `[[wikilink]]`).
4. **Promotion:** if a takeaway generalizes beyond this repo, add it to `LEARNINGS` now — don't wait for rotation.
5. Write both files. Confirm exactly what you saved.

## Session-End Template

```markdown
### YYYY-MM-DD — <short title>
- **What:** <what changed this session — features, fixes, refactors>
- **Why:** <the reasoning / root cause, not just the what>
- **Architecture:** <structural decisions or new patterns, if any>
- **Learnings:** <durable, reusable facts; promote cross-repo ones to [[Learnings]]>
- **Follow-ups:** <open threads for next session, if any>
```

## Rules
- Summarize only what actually happened this session — never invent entries.
- Use the real current date.
- Keep `Active Context.md` lean; `Learnings.md` is the durable hub.
- Pass file content through unchanged except for the edits above.
