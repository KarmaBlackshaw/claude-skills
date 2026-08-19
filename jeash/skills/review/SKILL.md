---
name: review
description: Use when the user wants a thorough, read-only code review of existing code with no spec required — a branch diff, a feature, a PR, or a named file set. Triggers on "jeash:review", "review my changes", "review the branch", "review this PR", "code review", "review before merge", or asking what's wrong / risky / reinvented in the current code.
---

# jeash:review

Launcher for the **review** agent — a deep, read-only, multi-lens code review. **Never edits.**

## What to do

**Dispatch the `review` subagent** (bundled at `agents/review.md`) with the scope (branch / feature / PR / files). It runs a deep, read-only, multi-lens review and returns findings ranked by severity with `file:line` evidence.

If the subagent can't be dispatched, **follow [`agents/review.md`](../../agents/review.md) verbatim yourself** — that file is the single source of truth for this role's lenses, library allowlist, deepening mode, and output format. Don't work from a summary here.
