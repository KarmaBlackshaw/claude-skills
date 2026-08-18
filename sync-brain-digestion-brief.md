# Sync-Brain Memory Digestion — Design Brief

*A design/architecture question about how an AI coding agent should persist and distill what it learns across work sessions. Written for an outside reviewer with no prior context.*

---

## 1. System overview

I run **Claude Code** (an AI coding agent in my terminal/IDE) wired to an **Obsidian vault** that acts as the agent's long-term memory. The design is **hub-and-spoke**:

- **Hub** — a single global `Learnings.md`: a curated, cross-repo index of durable lessons ("don't do X", "this pattern beats that one"). Small on purpose.
- **Spoke** — one file per code repository (`Projects/<repo>/<repo>.md`): a newest-first **session log**, where each entry is a single one-line headline of what that session accomplished.
- Wiring is a gitignored `CLAUDE.local.md` at each repo root that holds machine-readable paths (`ACTIVE_CONTEXT=` → that repo's spoke, `LEARNINGS=` → the hub, etc.). Paths are always resolved from this file, never hardcoded.

Two **bash hooks** automate it:

- `obsidian-recall.sh` (**SessionStart** hook) — injects the hub index + the repo's active context into the agent at the start of every session, so it begins informed.
- `obsidian-push.sh` (**Stop** hook) — at the end of a session, persists what happened.

## 2. How persistence works today

The **Stop hook** fires when the agent finishes. It receives a small JSON payload including `session_id`, `transcript_path` (path to the full session transcript on disk), and `stop_hook_active`. If the repo is wired and this session hasn't been saved yet, the hook returns a "block" decision whose `reason` is a natural-language instruction telling the agent to:

1. Compose a **≤12-word headline** for the session.
2. Run **one shell command** (an `awk` one-liner — deliberately not the Edit tool, which would clutter the chat with a diff) that writes `### <date> — <headline>` plus a hidden marker `<!-- session: <id> -->` into the spoke's `## Sessions (newest first)` list.

The `<!-- session: <id> -->` marker doubles as a **verification token**: the hook greps for it to confirm the write actually landed. If it's present, the hook stays quiet. Promotion of a lesson up to the global hub is a separate, rare, manual step.

So today: **the agent makes editorial judgments (is this worth saving? what's the headline? is there a reusable lesson?) at stop time, on every session.**

## 3. The bug we just fixed

The write command was **insert-only** — it always prepended a new entry. Combined with the marker being treated as a terminal "already done" guard, this meant: once a session saved once, a later **correction** to that headline was either silently dropped (the agent sees the marker already present and assumes it's done) or created a **duplicate** entry.

**Fix applied and verified:** the write is now an **upsert** keyed on the session marker — if the marker exists, replace the headline line above it; otherwise prepend. Confirmed end-to-end (insert, then correct → single updated entry, no duplicate).

## 4. The residual problem (why I'm reconsidering the design)

Even with the upsert fix, two things still bother me:

1. **Corrections after the first save need a manual trigger.** Once the marker is on disk, the Stop hook intentionally goes quiet (so it doesn't nag every time the agent stops). But that means it can't tell "already correct" from "saved earlier, but the outcome changed since." A corrected headline only lands if I manually run the push again.
2. **Judgment in the hot path.** Asking the agent to decide durability, compose a headline, and consider promoting a lesson *at the moment each session ends* is awkward. It's editorial work at a bad time, and it's the root of the correction friction.

## 5. Proposed redesign — split capture from synthesis

**Decouple recording from distilling:**

- **Capture (mechanical, in the Stop hook):** on each stop, append/upsert one row to a **queue file** — `session_id | last_activity_timestamp | transcript_path`. Pure logging: no AI, no nudge, never blocks, no chat clutter. Because it only records a pointer, there's no correction problem — if a session resumes later, the next stop just updates that row's timestamp.
- **Synthesis (batched AI, later):** a separate pass reads unprocessed queue rows, opens each session's transcript (already saved on disk as JSONL), and *then* decides the headline and any durable learnings, writes them to the spoke + hub, and marks the row done.

The appeal: capture becomes trivial and reliable; the editorial judgment moves out of the hot path into a deliberate batch step that can even look across multiple sessions at once.

## 6. Open design decisions

1. **Staleness gate (leaning yes).** Only synthesize a session once it's been **quiet for >24h**. Because a session can resume (the Stop hook fires again and bumps the row's timestamp), waiting a full day of silence is a reliable "this arc is actually finished" signal — it avoids distilling half-finished work and avoids re-digesting a resumed session. Threshold would be a single constant.

2. **Trigger for the synthesis pass — this is the main thing I want a second opinion on:**
   - **Session-start:** the recall hook, at the start of my *next* session, drains any stale rows. No new infrastructure — but synthesis then runs at the top of my next work session and spends tokens before I start working.
   - **Nightly cron / scheduled agent:** drains stale rows unattended overnight; work sessions stay clean; requires setting up a scheduled routine.
   - **Both:** cron primary, session-start as fallback if the cron didn't run; safe to double-run because rows are marked done (idempotent).
   - Note: the 24h "quiet" gate is *exactly* what a nightly cron naturally keys on, which nudges me toward cron — but I work in bursts on a personal machine, so I'm unsure.

3. **Replace vs augment (decided: replace).** The Stop hook stops composing inline headlines entirely; the batch synthesizer becomes the sole writer of spoke entries.

## 7. Constraints & facts for whoever implements this

- Hooks are **bash**, invoked by Claude Code. The Stop-hook input includes `transcript_path`.
- Must **never block** the agent or **clutter the chat** — single shell commands only, no diff-producing edits during a session.
- Transcripts persist locally at `~/.claude/projects/<slug>/<session_id>.jsonl`.
- The spoke path is resolved dynamically from `CLAUDE.local.md` (`ACTIVE_CONTEXT=`), never hardcoded.
- Everything is **per-repo** today (one spoke per repo). A single global queue would need to route each row back to the correct repo's spoke.
- This is a **single-user, single-machine** setup (personal dev laptop). No multi-user concurrency, but two sessions *can* end close together.

## 8. Questions for the professional

1. Is the **capture/synthesis split + 24h staleness gate** the right architecture here, or is there a simpler / more standard pattern for "log now, distill later"?
2. Best **trigger** for the synthesis pass — session-start, nightly cron, or both — given bursty local usage and transcripts that live on the same machine?
3. **Queue storage:** flat text file vs SQLite? Per-repo queues vs one global queue with routing?
4. **Idempotency & concurrency with just bash + a text file:** two sessions ending near-simultaneously both appending to the queue, or two synthesis passes racing — how to make that safe without heavy machinery?
5. **Pointer vs snapshot:** should the queue store just `transcript_path`, or a self-contained snapshot of the session, given transcripts could theoretically be pruned before the digest runs?
