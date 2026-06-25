# Agent roster

Portable, mentionable Claude Code agents. Source of truth lives here; install to any device.

## Roster

| Agent | Model | Owns | Edits source? |
|-------|-------|------|---------------|
| **architect** | opus | Orchestration, planning, decomposition, file partitioning, routing review findings, synthesis | No — plans & delegates |
| **frontend** | sonnet | Building Vue 3 + TS + Pinia + Tailwind UI | Yes |
| **ux** | sonnet | Accessibility, interaction states, layout, design-system fidelity | Suggests (defers to frontend) |
| **dx** | opus | Code quality, refactors, DRY/SOLID/KISS/YAGNI, legacy cleanup | Yes |
| **review** | opus | Deep multi-lens review (architecture, quality, reuse & libraries, conventions, a11y) of a branch/feature/PR | No — reports for assignment |
| **qa** | sonnet | Review vs spec + conventions, typecheck/lint/build verification | No — reports |

`architect` is the overall coordinator: mention it for whole-feature or codebase-wide work and it delegates to the others. After the build, the architect routes **all written code through `review`**, then assigns each finding to the right field (`frontend` / `dx` / `ux`) before the final `qa` gate. Mention a single field (e.g. `dx`, or `review` for a standalone code review with no spec) to go straight to that specialist.

## Install

```bash
./install.sh          # copy into ~/.claude/agents/
./install.sh --link   # symlink instead, so repo edits stay live
```

Restart Claude Code afterward. Agents are then mentionable in every project on this device, and (with agent teams enabled) spawnable as teammates by name.

## Enable agent teams (for multi-agent runs)

In `~/.claude/settings.json`:

```json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```

## Skills

Every agent is instructed to invoke the relevant skill (e.g. `vue-best-practices`, `tailwind-color-token`, `figma-to-vue`, `code-review-branch`) before improvising. Skills load from your project/user settings the same as a normal session.
