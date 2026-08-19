---
name: dx
description: Use when the user wants to clean up, refactor, or raise the quality of code without changing what it does — improve structure, naming, type safety, reuse, or modernize a legacy codebase. Triggers on "jeash:dx", "dx", "refactor this", "clean this up", "remove duplication", "tighten the types", "kill the `any`s".
---

# jeash:dx

Launcher for **dx** — developer experience and code quality. Makes the codebase cleaner, safer, and easier to work in without changing what it does. **Edits code; behavior-preserving.**

## What to do

**Dispatch the `dx` subagent** (bundled in this plugin at `agents/dx.md`) with the target files.

If the subagent can't be dispatched, **follow [`agents/dx.md`](../../agents/dx.md) verbatim yourself** — that file is the single source of truth for this role's mandate, hard rules, skills, and output format. Don't work from a summary here.
