# plan-and-build — Lessons (seed rules + write fallback)

> **Memory is Obsidian.** The primary self-learning memory is the Obsidian hub-and-spoke
> vault (see SKILL.md → Memory). Generalizable lessons are promoted to the hub ([[Learnings]])
> via the sync-brain Promotion gate at Phase 6, and injected at Phase 0 by the recall hook.
>
> This file now holds only:
> - **Seed rules** (DO/DON'T below) — the pipeline's portable operating constitution, read at
>   Phase 0 as a baseline even when a vault is present.
> - **Write fallback** — Phase 6 (Retro) appends here ONLY when a repo runs plan-and-build
>   without a wired vault.
>
> The 40+ run-accumulated lessons that used to live here were migrated into the Obsidian hub
> on 2026-07-02 (14 consolidated atomic notes) — see the Migrated section below.
> **Project-specific conventions are NOT hardcoded here** — the architect discovers them from
> the project each run (its CLAUDE.md / AGENTS.md, lint config, existing code).

## DON'T (mistakes that cost rework)

- Don't dispatch a builder without its spec file written to `docs/research/components/` first.
- Don't let two parallel builders edit the same file — partition ownership; same file → same builder or sequential wave.
- Don't brief a subagent with "as discussed above" — they have zero context; paste the spec inline every time.
- Don't add imports the project auto-provides — check its auto-import / global-registration setup first.
- Don't hardcode values the project expresses as design tokens / theme variables — use the token.
- Don't introduce new libraries, patterns, or abstractions when the project already has one — reuse it.
- Don't invent conventions — discover them (CLAUDE.md, lint, existing similar files) and follow them.
- Don't write test/spec files — verification is build/lint/typecheck/manual run only.
- Don't auto-commit / push / open a PR — always the user's call.
- Don't skip the QA phase or the Retro phase, even for a single-builder task.
- Don't one-shot a build — loop (build → check vs the spec's acceptance criteria → verify → fix) until satisfied; never ship a partial or unverified result.
- Don't let the QA↔fix loop run unbounded or report done with unmet acceptance criteria — cap at 3 rounds, then halt and surface.
- Don't over-split (an agent per trivial edit) or bundle unrelated work into one builder.
- Don't hand a builder a multi-responsibility job — the bigger the scope, the sloppier the output; split until each builder has ONE clear job describable in a single sentence without "and".
- Don't let a component with 3+ distinct sub-components go to one builder — one builder per sub-component + a separate wrapper builder (wrapper in a later wave).

## DO (what works)

- Architect discovers the project's conventions + reads this file before decomposing.
- Architect partitions the task by file ownership so builders never collide.
- Architect dissects to the smallest single-responsibility units; each builder gets exactly one focused job done at its finest.
- Group builders into waves: parallel within a wave (disjoint files), sequential across (dependencies first).
- Every builder gets its FULL spec inline + owned file paths + complexity tag + the project's verify command.
- QA checks each diff against its spec AND the project's conventions, and quotes real build/lint/typecheck output.
- The spec's acceptance criteria are the satisfaction contract — builders loop against them, QA re-checks them, done = all met.
- When a skill (process or framework) applies to the task, invoke it before acting (see `using-skills.md`).

## Migrated to Obsidian (2026-07-02)

> The 40+ run-accumulated auto-learned lessons were consolidated into **14 atomic notes** in the
> Obsidian hub ([[Learnings]]) — grouped under **Frontend build pipeline**, **Vue**,
> **API & data layer**, **Data model & UI**, and **Shell & tooling** — plus refinements to two
> existing notes ([[annotate-literal-union-returns]], [[verify-centrally-after-fan-out]]). They
> are injected at Phase 0 by the recall hook, so nothing is stranded.

<!-- Phase 6 Retro appends fallback lessons below this line ONLY when no vault is configured -->
