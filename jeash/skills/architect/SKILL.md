---
name: architect
description: Use when the user wants whole-feature or codebase-wide work that spans multiple roles and needs decomposition, delegation, file partitioning, and sequencing rather than a single edit. Triggers on "jeash:architect", "architect", "plan this feature", "coordinate this", "break this down", "orchestrate", or any multi-role build.
---

# jeash:architect

Launcher for the **architect** — the lead role that owns the shape of the work: decomposes it, partitions files, delegates, routes the build through review, and gates with qa. **Read-only on source — plans and delegates, never edits.**

## What to do

**Dispatch the `architect` subagent** (bundled in this plugin at `agents/architect.md`) with the user's request, and let it own decomposition, delegation, file partitioning, the post-build `review` pass, and the final `qa` gate. As the lead session it spawns the other fields as teammates — requires agent teams enabled.

If the subagent can't be dispatched, **follow [`agents/architect.md`](../../agents/architect.md) verbatim yourself** — that file is the single source of truth for this role's mandate, skills, sequencing, and output format. Don't work from a summary here.
