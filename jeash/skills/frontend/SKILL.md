---
name: frontend
description: Use when the user wants to build or change UI — Vue 3 components, views, composables, or Pinia stores in a Vue + TypeScript + Tailwind codebase. Triggers on "jeash:frontend", "frontend", "build this component", "implement this view", "wire up this store", "add this UI".
---

# jeash:frontend

Launcher for the **frontend** builder — ships working Vue 3 + TS + Pinia + Tailwind UI that matches the project's conventions. **Edits code.**

## What to do

**Dispatch the `frontend` subagent** (bundled in this plugin at `agents/frontend.md`) with the task and the files it owns.

If the subagent can't be dispatched, **follow [`agents/frontend.md`](../../agents/frontend.md) verbatim yourself** — that file is the single source of truth for this role's stack defaults, skills, and output format. Don't work from a summary here.
