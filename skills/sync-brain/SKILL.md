---
name: sync-brain
description: Pull or push long-term memory between the current repo and a centralized Obsidian vault (hub-and-spoke). Use when the user says "/sync-brain", "sync brain", "pull context", "push learnings", "save session to obsidian", or at the start/end of a work session to load or persist project memory.
---

# sync-brain

Hub-and-spoke long-term memory. The **hub** is a global `Learnings.md` in an Obsidian vault; each repo is a **spoke** — a folder-note `Projects/<repo>/<repo>.md` session log (conventions sit in the sibling `<repo> — Coding Rules.md`). Always resolve the spoke path from `ACTIVE_CONTEXT` in `CLAUDE.local.md`, never by hardcoded filename. This skill moves context between the current repo and the vault.

## Path discovery (do this first, every time)

**Never hardcode vault paths.** Read them from the repo root's `CLAUDE.local.md` (gitignored). Grep the machine-readable `KEY=value` block for:

- `ACTIVE_CONTEXT=` → this repo's session log
- `LEARNINGS=` → global cross-repo learnings
- `CODING_RULES=` → this repo's conventions synced from `CLAUDE.md`
- `STANDARDS=` → org-shared coding standards (one per vault; injected in full every session)
- `THREADS=` → this repo's open-threads ledger (durable follow-ups; survives session rotation)

```bash
grep -m1 '^ACTIVE_CONTEXT=' CLAUDE.local.md | cut -d= -f2-
grep -m1 '^LEARNINGS=' CLAUDE.local.md | cut -d= -f2-
```

The lesson **detail** lives in four **domain spokes** under `<notes-dir>/` (the `LEARNINGS` path with its extension removed, `…/Learnings.md` → `…/Learnings/`): `Frontend.md` (Vue / TS / data-model & UI), `Backend-Data.md` (Supabase / PostgREST / API), `Mobile.md` (React Native / Expo), `Workflow.md` (memory / agents / build pipeline / shell). Each groups lessons under `##`/`###` headers. `LEARNINGS` itself is only the index — the SessionStart hook injects it alone; spokes are read on demand. (Legacy per-lesson atomic notes are archived under `<notes-dir>/_archive/`.)

If `CLAUDE.local.md` is missing, tell the user this repo isn't wired to the vault yet and stop.

## Modes

Parse the argument after `/sync-brain` (default `pull`).

### `pull`
Load memory into context so you start informed.
1. Read `LEARNINGS` and `ACTIVE_CONTEXT`.
2. Summarize back: the current active-context state + any learnings relevant to what the user is about to do.

The `obsidian-recall.sh` SessionStart hook already auto-pulls; use this for a manual mid-session refresh.

### `push`
Persist this session's outcome. Default target is the **spoke** (`ACTIVE_CONTEXT`). The **hub** (`LEARNINGS`) is a small curated set — not a dump. Most sessions add nothing to it. Nothing important is lost on rotation because the two things worth keeping have durable homes: **learnings** graduate to the hub (gate below), and **follow-ups** land in the **THREADS ledger**.
1. Read the current `ACTIVE_CONTEXT` and the `THREADS` ledger.
2. Insert a new entry at the top of the Sessions list (newest first) using the **Session-End Template** below. If a Stop-hook checkpoint handed you a `<!-- session: <id> -->` marker, end the entry with that exact line — the checkpoint greps for it to verify the write landed (no marker → it nudges again).
3. **Thread ledger — follow-ups survive rotation.** For every follow-up in the new entry, add an `open` row to the `THREADS` ledger; flip any thread you resolved this session to `done`. An open item then lives in the ledger independently of the session entry that spawned it, so dropping that entry later never loses it. The recall hook injects the ledger's `open` rows every session start.
4. **Rotation:** keep the last 5 session entries. When you drop an older one, its follow-ups are already in the ledger (nothing to salvage) — only run its **Learnings** through the Promotion gate before deleting.

**Promotion gate — most takeaways NEVER reach the hub.** Promote to `LEARNINGS` only if ALL hold:
- **Reusable** beyond this one session — you'd genuinely apply it again.
- **Behavior-changing** — it would alter a future decision, not just record what happened.
- **Not already covered** — grep the hub first; no existing entry says the same thing.

A takeaway failing any gate stays in `ACTIVE_CONTEXT`. Stack-specific lessons (Supabase, TS, Vue…) MAY be promoted, but file them under a stack heading — never as loose top-level notes.

**Convention vs lesson — route to the right home.** A durable *always-on rule* the whole org should follow (a coding convention, e.g. "no `any`", "NativeWind only") belongs in **`STANDARDS`**, not `LEARNINGS`: Standards are injected in full every session; Learnings are situational insights read on demand. Add a new shared convention as a tight bullet under the right `##` in `STANDARDS`. A repo-only rule stays in that repo's `CODING_RULES`. Only cross-repo *insight-shaped* takeaways go to the Learnings spokes.

**Curate in domain spokes.** The hub `LEARNINGS` is an **index** — one summary line per lesson, grouped under its domain-spoke section. Each lesson's full detail is a `###` subsection inside the matching spoke (`Frontend` / `Backend-Data` / `Mobile` / `Workflow`). To promote a lesson that passed the gate:
- **Pick the spoke by domain**, and let the `###` header be the lesson's one-line claim (the dedup key — scan the spoke's existing headers first).
- **Existing lesson on the topic?** Refine that `###` subsection in place (tighten, add the nuance, bump the spoke's `updated:`). Do NOT add a near-duplicate; leave its index line as-is.
- **New lesson?** Append a `###` subsection under the right `##` area in the spoke (create the spoke file with `tags: [learning]` frontmatter if it doesn't exist yet; body = the mechanism + fix, keep a `Source:` line), then add ONE index line under that spoke's section in `LEARNINGS`: `- **<one-line summary>** — <terse how>`.
- **Never** put a lesson body in `LEARNINGS`, and **never** create a new per-lesson file — the SessionStart hook injects only the index; bloating it or re-fragmenting into atomic notes defeats the token budget the spokes exist to protect.

**Soft cap.** If a spoke's `##` area passes ~15–20 lessons or reads noisy, merge related `###` subsections into one sharper lesson (merge the bodies, collapse their index lines).

5. Write the session **spoke** (`ACTIVE_CONTEXT`), the `THREADS` ledger, any promoted lesson(s) in their **domain spoke**, and the hub index. Confirm in one line exactly what you saved: the session entry, ledger rows opened/closed, and any lessons added or refined.

## Session-End Template

```markdown
### YYYY-MM-DD — <short title>
- **What:** <what changed this session — features, fixes, refactors>
- **Why:** <the reasoning / root cause, not just the what>
- **Architecture:** <structural decisions or new patterns, if any>
- **Learnings:** <optional — leave blank if none; only promote to [[Learnings]] via the push Promotion gate>
- **Follow-ups:** <open threads for next session, if any — each one also becomes an `open` row in the THREADS ledger>
```

## Threads-Ledger Template (`THREADS` — `<repo> — Threads.md`)

Durable open action items — the one place follow-ups outlive session rotation. New follow-ups land as `open`; resolved ones flip to `done` (keep the row for history). The recall hook injects only the `open` rows each session start.

```markdown
| status | thread | opened | source |
|--------|--------|--------|--------|
| open | <short, actionable — what to do next> | YYYY-MM-DD | <session title or [[wikilink]]> |
| done | <resolved item> | YYYY-MM-DD | <session title> |
```

## Domain-Spoke Lesson format (`<notes-dir>/{Frontend,Backend-Data,Mobile,Workflow}.md`)

Each spoke carries `tags: [learning]` frontmatter and an `updated:` date. A lesson is a `###` subsection under a `##` area:

```markdown
### <Lesson title — the claim in one line>

<the mechanism: what happens, why, and the fix — a short paragraph, not a session log>

Source: <repo> · YYYY-MM-DD
```

## Rules
- Summarize only what actually happened this session — never invent entries.
- Use the real current date.
- Promotion to the hub is the exception, not the default — most sessions add nothing to `Learnings.md`.
- Keep the spoke (`<repo>.md`, resolved from `ACTIVE_CONTEXT`) lean; keep `Learnings.md` small and curated — refine existing entries over appending new ones.
- Pass file content through unchanged except for the edits above — in particular, preserve the spoke's `tags: [project/<repo>]` frontmatter (it's the note's graph hub label; see setup-obsidian-memory → **Graph project tag**).
- Domain spokes (`Learnings/{Frontend,Backend-Data,Mobile,Workflow}.md`) stay tagged `[learning]` only — never add a `project/<repo>` tag; they're cross-repo and hub to `[[Learnings]]`.
