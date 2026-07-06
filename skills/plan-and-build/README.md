# plan-and-build

Architect-orchestrated, spec-driven, **self-learning** frontend build pipeline:
**recall → brainstorm → architect → (scaled gate) → builders → QA → retro**.

Every non-trivial request first goes through a **scaled brainstorm** (design + approval), then
an architect that dissects it, partitions the work into collision-free file sets, and writes one
spec file per component. Builders (routed by complexity to haiku/sonnet/opus) build their owned
files in parallel, **debugging to root cause** and claiming done only **with verification
evidence**. QA always verifies with **two verdicts (spec + code-quality)**. A retro agent
promotes what it learned to **Obsidian long-term memory** so the next run is smarter.

Four superpowers-style disciplines are ported in, self-contained (no plugin dependency):
skills-first, **design-before-build**, **root-cause debugging**, **evidence-before-claims**.
Commit/finishing-branch is deliberately excluded — committing stays the user's call.

No git worktrees — parallel safety comes from the architect giving each builder a
**disjoint** set of files.

## What's inside

```
plan-and-build/
├── SKILL.md               # orchestrator — the 7-phase loop + dispatch templates
├── README.md              # you are here
├── using-skills.md        # ported: skill-discovery discipline
├── brainstorming.md       # ported: design-before-build (scaled), Phase 1
├── systematic-debugging.md# ported: root cause before any fix, Phases 4–5
├── verifying.md           # ported: no completion claim without fresh evidence
├── lessons.md             # legacy local memory + write fallback (memory is Obsidian now)
├── spec-template.md       # the per-component spec the architect fills
└── agents/
    ├── pb-architect.md  # opus — consume design + partition + write specs (read-only on source)
    ├── executor.md      # sonnet — build [med] owned files
    ├── executor-haiku.md# haiku  — build [low] owned files
    ├── executor-opus.md # opus   — build [high] owned files
    ├── qa-reviewer.md   # sonnet — verify diff vs spec + code-quality + conventions (2 verdicts)
    └── retro.md         # sonnet — promote generalizable lessons to Obsidian (sync-brain gate)
```

> Claude Code dispatches agents from `~/.claude/agents/*.md` (flat, no subdirs). The
> `agents/` folder here is the bundled/portable copy. **Run the repo-root `./sync.sh` after
> editing any agent or skill file** — it installs every skill into `~/.claude/skills/` and
> registers all agents into `~/.claude/agents/`, so the two copies can't silently drift
> (`./sync.sh --check` reports drift without writing).
>
> The spec-writer is named **`pb-architect`** (not `architect`) on purpose: the `architect`
> name is owned by the standalone jeash orchestrator agent (delegates teammates). Renaming
> here keeps the two from colliding in the flat `~/.claude/agents/` namespace.

## The loop

```
user: "implement / build / fix / refactor <X>"
   │
   ├── Phase 0  Recall      read disciplines + Obsidian memory → inject into every prompt
   ├── Phase 1  Brainstorm  scaled: trivial → 1-line design; non-trivial → design + approval
   ├── Phase 2  Architect   dissect, partition files, write docs/research/components/*.spec.md
   │                         → dispatch plan (builder|spec|owned files|tag|wave|depends-on)
   ├── Phase 3  Scaled gate  single simple builder → auto-proceed
   │                         multi-component / any [high] → wait for "go"
   ├── Phase 4  Build        waves: parallel within (disjoint files), sequential across
   │                         route [low|med|high] → haiku/sonnet/opus; spec + disciplines inline
   │                         root cause before fix · no ✅ without quoted verify output
   ├── Phase 5  QA           tiered: 1 qa-reviewer (simple) or 1-per-component (complex)
   │                         two verdicts (spec + code-quality); blockers routed back to builder
   └── Phase 6  Retro        distill generalizable lessons → promote to Obsidian hub
```

## Project-agnostic

The skill hardcodes no framework or house conventions. The architect **discovers** each
project's conventions at runtime — its `CLAUDE.md` / `AGENTS.md`, lint config, existing
patterns, and typecheck/lint/build commands — and encodes those into each spec. Run it in
any frontend repo and it adapts; run it in a repo with strict rules and it picks them up
from that repo.

## Self-learning (Obsidian memory)

The skill's long-term memory is the **Obsidian hub-and-spoke vault**, shared across repos.
Generalizable, cross-project lessons are promoted to the **hub** (`LEARNINGS`) as curated
atomic notes via the `sync-brain` Promotion gate at Phase 6; run summaries go to this repo's
**spoke** (`ACTIVE_CONTEXT`). Paths are resolved from the gitignored `CLAUDE.local.md` — never
hardcoded — and injected at Phase 0 (usually by the `obsidian-recall.sh` SessionStart hook).

If a repo isn't wired to a vault, Phase 0 asks for the vault path or offers to run
`/setup-obsidian-memory`. The skill-local `lessons.md` is **legacy local memory** (still read at
Phase 0 so nothing is stranded) and the **write fallback** when no vault is configured.

**Required companions:** `sync-brain` (runtime read/write) and `setup-obsidian-memory` (wiring).

## Skill discovery (no plugin dependency)

`using-skills.md` is a self-contained port of the "invoke relevant skills before acting"
discipline. The orchestrator and agents follow it without depending on any external plugin.
It deliberately carries **no auto-commit behavior** — committing stays the user's call.

## Why this exists

- **Architect on opus** — a bad decomposition poisons everything downstream.
- **Collision-free parallelism without worktrees** — file partitioning, not branches.
- **Spec per component** — auditable artifact; builders never guess from a half-remembered prompt.
- **Builder model is per-component**, routed by complexity tag — cheap work stays cheap.
- **QA always runs**; **Retro always runs** — the pipeline compounds knowledge over time.
- **Superpowers disciplines, ported in** — design-before-build, root-cause debugging, and evidence-before-claims raise quality without depending on the superpowers plugin.
- **No auto-commit, no test files** — ship the change; the human commits when ready.

## Trigger phrases

Auto-fires on: "implement X", "build X", "add X", "create X", "fix X", "refactor X",
"plan and build". Or invoke explicitly: `use plan-and-build to <task>`.

## Hard rules (baked into every agent)

- **NO** `git commit` / `git push` / `gh pr create` without explicit user instruction. (Finishing-a-branch / commit is the one superpowers piece deliberately excluded.)
- **NO** test file writes (`*.test.*`, `*.spec.*`, `__tests__/`). Debugging may use a throwaway repro, deleted after — never committed. Verification is build/lint/typecheck/manual.
- **NO** build of non-trivial work without a design + approval first (brainstorm gate).
- **NO** "done / passing / fixed" claim from any layer without fresh, quoted verification evidence.
- **NO** symptom-patching — any verify failure / QA blocker is debugged to root cause first.
- **NO** builder without its spec file in `docs/research/components/`.
- **NO** two parallel builders editing the same file — partition or sequence.
- **NO** improvising when the spec is wrong — halt and surface.
- **NO** hardcoded vault paths — memory paths come from `CLAUDE.local.md`.

## Complexity tag heuristics

| Tag | Use for | Examples |
|-----|---------|----------|
| `[low]` | Mechanical, single-file, predictable | rename, copy boilerplate, route from template, doc edit |
| `[med]` | Typical feature work, framework idioms | multi-file CRUD, store/composable wiring, validators |
| `[high]` | Hard reasoning, perf, security, subtle bugs | algorithms, cross-cutting refactor, race conditions, auth |

Misclassification is caught by the escalation chain — a blocked haiku retries on sonnet, then opus.

## Install / sync

The **repo-root `sync.sh`** is the single command to install or update *every* skill in this
repo (incl. plan-and-build) plus their agents on a machine — idempotent, safe to re-run. It
mirrors each `skills/<name>/` into `~/.claude/skills/<name>` and registers every `agents/*.md`
into the flat `~/.claude/agents/` dir Claude Code dispatches from, then offers to wire the
Obsidian memory hooks into repos you pick.

```
../../sync.sh                # install / update ALL skills + agents, then pick repos for hooks
../../sync.sh --skills-only  # skills + agents only, skip hook wiring
../../sync.sh --check        # report drift only (no writes); exit 1 if out of sync
```

The **repo copy is the source of truth**; run `sync.sh` from it to propagate any edit. It
overwrites only each skill's own agents (never `--delete`s others in `~/.claude/agents/`).

## Extending

Drop a new agent in `agents/`, add a row to SKILL.md's agent table, wire it into the relevant
phase, then run the repo-root `./sync.sh` to register it. Naming: `<role>.md` for the
default-model variant, `<role>-<model>.md` for model-specific variants.
