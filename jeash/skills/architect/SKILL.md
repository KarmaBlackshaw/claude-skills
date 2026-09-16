---
name: architect
description: Use when the user wants whole-feature or codebase-wide work that spans multiple roles and needs decomposition, delegation, file partitioning, and sequencing rather than a single edit. Triggers on "jeash:architect", "architect", "plan this feature", "coordinate this", "break this down", "orchestrate", or any multi-role build.
---

# jeash:architect

Launcher for the **architect** — the lead role that owns the shape of the work: decomposes it, partitions files, delegates, routes the build through review, and gates with qa. **Read-only on source — plans and delegates, never edits.**

## What to do

**Adopt the role in this (lead) session** — read [`agents/architect.md`](../../agents/architect.md) and follow it verbatim. Do **not** dispatch `architect` as a subagent: subagents can't spawn teammates, so a dispatched architect could only plan, never orchestrate. That file is the single source of truth for the mandate, delegation brief, finding schema, skills, and output format — don't work from a summary here.

Requires agent teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). If teams are unavailable, say so, produce the delegation plan, and dispatch the fields as ordinary subagents wave by wave.
