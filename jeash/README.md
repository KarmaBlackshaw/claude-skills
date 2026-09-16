# jeash

A Claude Code **plugin** that bundles the jeash agent roster **and** matching launcher skills under one namespace. Install once → the 7 agents are mentionable and each has a `jeash:<role>` skill that dispatches it.

## What's inside

| `jeash:<skill>` | Role | Edits source? |
|-----------------|------|---------------|
| `jeash:architect` | architect — decompose, partition, delegate, route review, gate qa. **Runs in the lead session** (subagents can't spawn teammates) | No — plans |
| `jeash:frontend` | frontend — build Vue 3 + TS + Pinia + Tailwind UI, incl. from Figma | Yes |
| `jeash:ux` | ux — **sole owner of a11y**, interaction states, layout, design-system fidelity | No — reports |
| `jeash:dx` | dx — behavior-preserving refactors, type safety, DRY/SOLID/KISS/YAGNI | Yes |
| `jeash:review` | review — senior-engineer peer review: structure, smells, reuse & libraries (VueUse/lodash-es/…), conventions. No commands, no a11y | No — reports |
| `jeash:qa` | qa — functional QA: spec correctness + typecheck/lint/build/tests + runtime drive | No — reports |
| `jeash:deepen` | deepen — shallow→deep module opportunities as an HTML report | No — reports |
| `jeash:review-changes` | architect in report-only mode: auto-scoped, vault-grounded review across review / ux / qa | No — reports |

`review`, `qa`, and `ux` don't overlap: review judges code, qa proves function, ux owns how it looks and works for every user. All three report in one schema — `Severity | file:line | issue | fix | owner` — so the architect turns rows straight into assignments.

Each launcher is thin: it dispatches the bundled agent (the mandate lives in `agents/<role>.md`, the single source of truth) or, for architect, makes the lead session adopt that file.

## Layout

```
jeash/
  .claude-plugin/
    plugin.json         # plugin manifest
    marketplace.json    # self-marketplace, so this dir installs directly
  agents/<role>.md      # the 7 agent definitions
  skills/<role>/SKILL.md# the jeash:<role> launchers
```

## Requires

Not declared in the manifest — install separately:

- **gstack** plugin — `spec`, `autoplan`, `investigate`, `health`, `devex-review`, `browse`, `qa-only`, `design-review`, `review`.
- **superpowers** plugin — `superpowers:dispatching-parallel-agents`, `superpowers:verification-before-completion`.
- **Local skills** from this repo / `~/.claude/skills` — `feature-dev`, `plan-and-build`, `code-review-branch`, `figma-to-vue`, `tailwind-color-token`, `vue-best-practices`, `vue-pinia-best-practices`, `vue2-best-practices`, `typescript-advanced-types`, `web-component-design`, `tailwind-design-system`, `frontend-design`, `ui-ux-pro-max`.
- **lean-ctx** MCP server — the read-only agents list `mcp__lean-ctx__ctx_*` tools explicitly.
- **Memory** — the `setup-obsidian-memory` skill's `SubagentStart` hook injects Standards + Learnings into every agent. Without it, agents run on CLAUDE.md alone.

`frontend` and `dx` declare no `tools:` so they inherit everything (incl. Figma MCP servers); the read-only roles keep explicit allowlists.

## Install

From this directory as a local marketplace:

```
/plugin marketplace add /Users/admin/Documents/personal/agentic-ai/jeash
/plugin install jeash@jeash
```

Then restart Claude Code (full quit). Invoke skills as `jeash:review`, `jeash:qa`, … and mention the agents by name (`architect`, `dx`, …).

## Agent teams

`jeash:architect` delegates by spawning the other agents as teammates — enable in `~/.claude/settings.json`:

```json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```
