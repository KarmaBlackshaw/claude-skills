---
name: review
description: Use when the user wants a thorough, read-only code review of existing code with no spec required — a branch diff, a feature, a PR, or a named file set. Triggers on "jeash:review", "review my changes", "review the branch", "review this PR", "code review", "review before merge", or asking what's wrong / risky / reinvented in the current code.
---

# jeash:review

Launcher for the **review** agent — a deep, read-only, multi-lens code review. **Never edits.**

## What to do

**Dispatch the `review` subagent** (bundled in this plugin at `agents/review.md`) with the scope (branch / feature / PR / files). It reviews across every lens in one pass — architecture, code quality (DRY/SOLID/KISS/YAGNI, type safety), **reuse & libraries** (flags hand-rolled code a battle-tested lib like VueUse / lodash-es / date-fns / zod / ofetch already solves), conventions, and UX/a11y — grounds convention claims by running the project's real typecheck/lint, and returns findings ranked by severity with `file:line` evidence.

If the subagent can't be dispatched, follow `agents/review.md` inline: establish scope (detect the base branch dynamically, review the *diff*) → map each file's role → review every lens → ground convention claims with real command output (never claim "clean" without running it).

## Output

Map → findings table (`Severity | File:line | Issue | Recommendation`) → **library swaps** (`File:line | Hand-rolled | Replace with`, marking existing vs new dep; omit if none) → top refactors → verdict. Read-only, evidence-backed, no editing.
