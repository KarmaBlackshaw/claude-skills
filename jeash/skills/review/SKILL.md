---
name: review
description: Use when the user wants a thorough, read-only code review of existing code with no spec required — a branch diff, a feature, a PR, or a named file set. Triggers on "jeash:review", "code review", "review this file / folder / feature / component", "peer review", or asking what's wrong / risky / reinvented in named code. A diff-shaped request ("my changes", "the branch", "this PR", "before I commit") belongs to `jeash:review-changes`, which fans this lens out with ux and qa.
---

# jeash:review

Launcher for the **review** agent — a senior-engineer peer review: structure, smells, reuse, conventions. No commands (that's `jeash:qa`), no a11y (that's `jeash:ux`). **Never edits.**

## What to do

**Dispatch the `review` subagent** (bundled at `agents/review.md`) with the scope (feature / folder / files; or a branch / PR when the user wants this single lens rather than the `jeash:review-changes` fan-out). It runs a deep, read-only, multi-lens review and returns findings ranked by severity with `file:line` evidence.

If the subagent can't be dispatched, **follow [`agents/review.md`](../../agents/review.md) verbatim yourself** — that file is the single source of truth for this role's lenses, library allowlist, and output format. Architecture-deepening lives in `jeash:deepen`. Don't work from a summary here.
