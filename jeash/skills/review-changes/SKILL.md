---
name: review-changes
description: Use when the user wants their changes reviewed against the Obsidian vault's captured Standards and Learnings, orchestrated across jeash review lenses — read-only, report only, no edits. Auto-picks scope — a file/dir/branch/PR the user names wins; otherwise uncommitted changes if any exist, otherwise the branch diff. Owns every diff-shaped review request: "jeash:review-changes", "review my changes", "review my uncommitted changes", "review the branch", "review this PR", "review before I commit / merge", "vault review", "audit against standards", "review against learnings". A single named file / folder / feature with no diff framing goes to `jeash:review` alone.
---

# jeash:review-changes

Launcher for an **architect-orchestrated, vault-grounded review**. Picks the review scope, fans out the review lenses the diff warrants, and returns one ranked findings report. **Read-only on source — reports, never edits.**

## What to do

**Adopt the `architect` role in this (lead) session** — read [`agents/architect.md`](../../agents/architect.md) — in **report-only review mode**:

1. **Report-only — do NOT build, edit, or delegate a build.**
2. **Resolve the scope** — first match wins:
   - **User named a target** (a file, directory, base branch, or PR) → review exactly that.
   - **Uncommitted changes exist** → review the full working tree against `HEAD`: staged (`git diff --cached`) + unstaged (`git diff`) + untracked (`git ls-files --others --exclude-standard`). Ignore anything already committed.
   - **Otherwise, the branch diff** → detect the base branch dynamically (`qa`/`staging`/`main`/`master` as the repo uses — never assume `main`) and diff the current branch against it.
   - **Nothing to review** (clean tree, branch even with base, no target named) → say so and stop.
   State which scope you chose in one line before the findings.
3. **Fan out the lenses the diff warrants** — always `review`; add `ux` when the diff touches UI (sole a11y owner); add `qa` to run typecheck/lint/build/tests and ground correctness. Partition files so no two lenses collide. Standards + the Learnings index are in every subagent's system prompt (CLAUDE.md imports) — no need to paste them.
4. **Synthesize one report** in the finding schema (`Severity | file:line | issue | fix | owner`), ranked by severity. Keep every vault citation (`violates Standards.md §… / Learnings/Frontend.md: …`) so each fix traces back to its source. **No edits, no fixes — report only.**
