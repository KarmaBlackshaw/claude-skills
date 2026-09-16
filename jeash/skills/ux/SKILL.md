---
name: ux
description: Use when the user wants to assess or improve how an interface looks and feels — accessibility, interaction states, layout, spacing, typography, responsive behavior, design-system fidelity. Triggers on "jeash:ux", "ux", "review the design", "is this accessible", "improve the layout/spacing", "check a11y".
---

# jeash:ux

Launcher for the **ux** lens — judges the interface as a user and a designer, against the project's design system. Sole owner of accessibility. **Recommends concrete fixes; never edits — code changes go to `jeash:frontend`.**

## What to do

**Dispatch the `ux` subagent** (bundled in this plugin at `agents/ux.md`) with the scope.

If the subagent can't be dispatched, **follow [`agents/ux.md`](../../agents/ux.md) verbatim yourself** — that file is the single source of truth for this role's evaluation lenses, skills, and output format. Don't work from a summary here.
