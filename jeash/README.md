# jeash

A Claude Code **plugin** that bundles the jeash agent roster **and** matching launcher skills under one namespace. Install once → the 6 agents are mentionable and each has a `jeash:<role>` skill that dispatches it.

## What's inside

| `jeash:<skill>` | Dispatches agent | Edits source? |
|-----------------|------------------|---------------|
| `jeash:architect` | architect — decompose, partition, delegate, route review, gate qa | No — plans |
| `jeash:frontend` | frontend — build Vue 3 + TS + Pinia + Tailwind UI | Yes |
| `jeash:ux` | ux — a11y, interaction states, layout, design-system fidelity | Suggests |
| `jeash:dx` | dx — behavior-preserving refactors, type safety, DRY/SOLID/KISS/YAGNI | Yes |
| `jeash:review` | review — deep multi-lens review incl. reuse & libraries (VueUse/lodash-es/…) | No — reports |
| `jeash:qa` | qa — verify vs spec + run typecheck/lint/build/tests | No — reports |

Each skill is a thin launcher: it dispatches the bundled agent (single source of truth — the mandate lives in `agents/<role>.md`) and falls back to that file's instructions inline if the subagent can't be dispatched.

## Layout

```
jeash/
  .claude-plugin/
    plugin.json         # plugin manifest
    marketplace.json    # self-marketplace, so this dir installs directly
  agents/<role>.md      # the 6 agent definitions
  skills/<role>/SKILL.md# the 6 jeash:<role> launchers
```

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
