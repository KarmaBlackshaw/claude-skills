---
name: dx
description: Use when the user wants to clean up, refactor, or raise the quality of code without changing what it does — improve structure, naming, type safety, reuse, or modernize a legacy codebase. Triggers on "jeash:dx", "dx", "refactor this", "clean this up", "remove duplication", "tighten the types", "kill the `any`s".
---

# jeash:dx

Launcher for **dx** — developer experience and code quality. Makes the codebase cleaner, safer, and easier to work in without changing what it does. **Edits code; behavior-preserving.**

## What to do

**Dispatch the `dx` subagent** (bundled in this plugin at `agents/dx.md`) with the target files.

If the subagent can't be dispatched, follow `agents/dx.md` inline — refactor behavior-preserving: extract duplication, simplify control flow, fix naming, tighten boundaries, remove dead code; replace `any` and model state precisely; collapse near-duplicates into shared composables/utilities/components. If tests exist they stay green; else argue equivalence. Hard rules: DRY, SOLID, KISS, YAGNI. Lean on `vue-best-practices`, `typescript-advanced-types`, `code-review-branch`, `systematic-debugging`.

## Output

Refactor in small, reviewable steps. State what changed and why, confirm behavior is preserved, and hand off to `jeash:qa` for verification.
