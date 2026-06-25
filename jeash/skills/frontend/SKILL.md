---
name: frontend
description: Use when the user wants to build or change UI — Vue 3 components, views, composables, or Pinia stores in a Vue + TypeScript + Tailwind codebase. Triggers on "jeash:frontend", "frontend", "build this component", "implement this view", "wire up this store", "add this UI".
---

# jeash:frontend

Launcher for the **frontend** builder — ships working Vue 3 + TS + Pinia + Tailwind UI that matches the project's conventions. **Edits code.**

## What to do

**Dispatch the `frontend` subagent** (bundled in this plugin at `agents/frontend.md`) with the task and the files it owns.

If the subagent can't be dispatched, follow `agents/frontend.md` inline. Stack defaults: Vue 3 Composition API + `<script setup>`, TypeScript always, Pinia setup stores, Tailwind utilities (check for a class prefix like `tw-` first; apply it to every utility incl. variants). Invoke the matching skill before writing code — `vue-best-practices`, `vue-pinia-best-practices`, `tailwind-color-token` (before any raw hex), `figma-to-vue` (any Figma URL). Reuse existing components/composables before creating new ones; match neighboring idiom; type everything.

## Output

Working, typecheck-clean code within the assigned files. State what changed; hand off to `jeash:qa` for verification.
