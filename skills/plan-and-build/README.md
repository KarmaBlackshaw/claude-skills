# plan-and-build

Two-phase workflow skill: **plan (opus) → approve → execute (sonnet/haiku/opus)**.

Bundles one orchestration skill + four subagents that together implement a cost-aware feature pipeline. The planner uses opus for deep reasoning. The executor agents are routed per-step by complexity tag (`[low|med|high]` → haiku/sonnet/opus) so cheap mechanical work doesn't burn frontier-model tokens.

## What's inside

```
plan-and-build/
├── SKILL.md              # orchestrator — Phase 1/2/3 logic + routing
├── README.md             # you are here
└── agents/
    ├── planner.md        # opus — writes plan via superpowers:writing-plans
    ├── executor.md       # sonnet — default executor for [med] steps
    ├── executor-haiku.md # haiku — mechanical [low] steps
    └── executor-opus.md  # opus — hard [high] steps
```

The skill is the entry point. Subagents are dispatched by the orchestrator based on the plan's complexity tags.

## How it works

```
user: "implement <feature>"
   │
   ▼
plan-and-build skill triggers
   │
   ├── Phase 1: Plan
   │     dispatch planner (opus)
   │     planner invokes superpowers:writing-plans
   │     → returns plan markdown w/ [low|med|high] tags per step
   │     orchestrator writes plan to .claude/plans/<slug>-<date>.md
   │
   ├── Phase 2: Approval gate (HARD STOP)
   │     show plan to user
   │     wait for "go" / "approve" / edits
   │
   └── Phase 3: Execute (model-routed)
         group consecutive same-tag steps into batches
         dispatch:
           [low]  → executor-haiku  (cheap, mechanical)
           [med]  → executor        (sonnet, default)
           [high] → executor-opus   (deep reasoning)
         escalate on failure: haiku → sonnet → opus → halt
         relay per-step results to user
         summarize files changed + lint output
         ASK before any git op
```

## Why this exists

Default Claude Code workflow runs everything on whatever model the tab is set to. For multi-step features, that's wasteful — you don't need opus to add a CRUD route, but you do want it for the architecture call. This skill fixes that:

- **Planner stays on opus** — bad plan poisons execution, worth the spend
- **Executor model is per-step**, not per-task
- **Approval gate** — humans review the plan before any code writes
- **No auto-commit** — `superpowers:executing-plans` commits eagerly; this skill does not. User commits when they're ready.
- **No test files** — workflow is for shipping the change, not building a test suite. Verification = build, lint, typecheck, manual run.

Cost example, 10-step plan:
- Without routing: 10 sonnet exec runs
- With routing (6 low + 3 med + 1 high): 1 haiku batch + 1 sonnet batch + 1 opus run
- ~50–60% cheaper at typical price ratios

## Install

Via the repo install script (installs the skill + all four bundled agents):

```bash
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s plan-and-build
```

Restart Claude Code fully after install (Cmd+Q, not just close window).

## Trigger phrases

The skill auto-fires on:
- "implement X", "build X", "add X", "create X"
- "refactor X"
- "plan and build", "feature workflow"

Or invoke explicitly: `use plan-and-build to <task>`.

## Hard rules

These are baked into every agent in this bundle. They override anything any subskill might suggest:

- **NO `git commit` / `git push` / `gh pr create`** without explicit user instruction in the current dispatch
- **NO test file writes** — no `*.test.*`, `*.spec.*`, `__tests__/`
- **NO `superpowers:executing-plans`** — it auto-commits
- **NO `superpowers:test-driven-development`** — workflow doesn't write tests
- **NO improvising** when plan is wrong — halt and surface to user

## Complexity tag heuristics

The planner classifies each step:

| Tag | Use for | Examples |
|-----|---------|----------|
| `[low]` | Mechanical, single-file, predictable | rename symbol, copy boilerplate, add a route from template, doc edit |
| `[med]` | Typical feature work, framework idioms | multi-file CRUD, business logic, store/composable wiring, validators |
| `[high]` | Hard reasoning, perf, security, subtle bugs | algorithms, concurrency, cross-cutting refactor, race conditions, auth/crypto code |

Misclassification is caught by the escalation chain — a haiku that hits `❌ blocked` is retried on sonnet, then opus.

## Adapting to your stack

Skill is stack-agnostic. Subagents pick up project conventions via `ctx_read`/`ctx_search` against the repo. If you want stricter behavior for a specific framework, layer a project-level skill on top (e.g. `vue-best-practices` will activate for Vue work and the executor will follow it).

## Files

- [`SKILL.md`](./SKILL.md) — orchestrator logic, dispatch templates, routing pseudocode
- [`agents/planner.md`](./agents/planner.md) — opus planner spec
- [`agents/executor.md`](./agents/executor.md) — sonnet executor spec
- [`agents/executor-haiku.md`](./agents/executor-haiku.md) — haiku executor spec
- [`agents/executor-opus.md`](./agents/executor-opus.md) — opus executor spec

## Future agents

To extend the pipeline, drop new agent definitions in `agents/`. Naming conventions:

- `<role>.md` for the default-model variant (e.g. `reviewer.md` runs on whatever model its frontmatter says)
- `<role>-<model>.md` for model-specific variants (e.g. `reviewer-opus.md`)

Update `SKILL.md`'s routing table when adding a new role. Agent files must be flat under `agents/` — Claude Code reads them from `~/.claude/agents/*.md` (no subdirs).
