---
name: deepen
description: Use when the user wants to improve the architecture, find deepening opportunities, surface architectural friction, or make code more testable / AI-navigable — shallow modules → deep modules, as a visual HTML report. Triggers on "jeash:deepen", "deepen", "improve the architecture", "find deepening opportunities", "where is the friction", "make this more testable".
---

# jeash:deepen

Launcher for the **deepen** agent — a read-only architecture scout that surfaces shallow-module friction and illustrates deep-module opportunities in an HTML report opened from the OS temp dir. **Never edits, never proposes interfaces.**

## What to do

**Dispatch the `deepen` subagent** (bundled at `agents/deepen.md`) with the module / subsystem / pain point the user named, or nothing if they want the hot spots found from git history.

If the subagent can't be dispatched, **follow [`agents/deepen.md`](../../agents/deepen.md) verbatim yourself** — that file is the single source of truth for the vocabulary, process, and report format. Don't work from a summary here.
