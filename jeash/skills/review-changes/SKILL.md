---
name: review-changes
description: Use when the user wants their changes reviewed against the Obsidian vault's captured Standards and Learnings, orchestrated across jeash review lenses — read-only, report only, no edits. Auto-picks scope — a file/dir/branch/PR the user names wins; otherwise uncommitted changes if any exist, otherwise the branch diff. Triggers on "jeash:review-changes", "review my changes", "review my uncommitted changes", "review the branch", "review this PR", "review before I commit", "vault review", "audit against standards", "review against learnings".
---

# jeash:review-changes

Launcher for an **architect-orchestrated, vault-grounded review**. Picks the review scope, recalls the vault's durable Standards + Learnings, fans out the review lenses the diff warrants, and returns one ranked findings report. **Read-only on source — reports, never edits.**

## What to do

**Dispatch the `architect` subagent** (bundled in this plugin at `agents/architect.md`) in **report-only review mode** with this brief:

> **Report-only review — do NOT build, edit, or delegate a build.**
> 1. **Recall memory first** (per your Memory section): resolve the repo's `CLAUDE.local.md` → `STANDARDS`, `LEARNINGS`, `ACTIVE_CONTEXT` (KEY=value paths), read them. No `CLAUDE.local.md`, or files missing → skip silently and proceed (memory is best-effort, never a blocker). Never hardcode vault paths.
> 2. **Resolve the scope** — first match wins:
>    - **User named a target** (a file, directory, base branch, or PR) → review exactly that. This always overrides the auto chain below.
>    - **Uncommitted changes exist** → review the full working tree against `HEAD`: staged (`git diff --cached`) + unstaged (`git diff`) + untracked (`git ls-files --others --exclude-standard`). Ignore anything already committed.
>    - **Otherwise, the branch diff** → detect the base branch dynamically (`qa`/`staging`/`main`/`master` as the repo uses — do NOT assume `main`) and diff the current branch against it.
>    - **Nothing to review** (clean tree, branch even with base, no target named) → say so and stop.
>    State which scope you chose in one line before the findings.
> 3. **Fan out the lenses the diff warrants** — always `review`; add `ux` for user-facing UI changes and `qa` (typecheck/lint/build) to ground convention and correctness claims. You decide which, based on the diff. Partition files so no two lenses collide. Paste the recalled Standards + Learnings inline into each subagent prompt — subagents get no session-start injection.
> 4. **Synthesize one report:** findings ranked by severity with `file:line` evidence. Cite every vault-grounded finding against its rule (`violates Standards.md §… / Learnings/Frontend.md: …`) so each fix traces back to its source, and flag any place the changes conflict with a recalled Standard or Learning. **No edits, no fixes — report only.**

If the subagent can't be dispatched (agent teams disabled, etc.), **follow [`agents/architect.md`](../../agents/architect.md) verbatim yourself** for the recall + orchestration mandate, apply the report-only brief above, and produce the report directly. That agent file is the single source of truth — don't work from a summary here.
