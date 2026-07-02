---
name: plan-and-build
description: Use when the user asks to implement, build, create, add, fix, or refactor frontend work — any scope, from a one-line change to a multi-component feature. Triggers on "implement X", "build X", "add", "create", "refactor", "fix", "plan and build".
---

# Plan-and-Build — architect-orchestrated, spec-driven, self-learning

Every request flows through seven phases: **recall → brainstorm → architect → (scaled gate) → builders → QA → retro**. Discipline runs through all of them: skills-first, **design-before-build**, **root-cause debugging**, **evidence-before-claims**. The architect decides how many builders to spawn (1…N). Brainstorm scales to the work; QA and Retro ALWAYS run. The skill gets smarter each run by promoting lessons to long-term memory.

You are the orchestrator. You dispatch agents and route results — you do not write source yourself.

**This skill is project-agnostic.** It hardcodes no framework or house conventions. The architect and QA agents *discover* each project's conventions at runtime (its `CLAUDE.md` / `AGENTS.md`, lint config, existing patterns, typecheck/lint/build commands) and obey those. Run it in any frontend repo and it adapts.

## Ported disciplines (self-contained — no plugin dependency)

Read these at Phase 0 and apply them all run. Each is a self-contained port so the pipeline depends on no external plugin. Paste the relevant ones **inline** into subagent dispatches (subagents have zero context).

| File | Discipline | Applies at |
|------|-----------|-----------|
| `using-skills.md` | invoke relevant skills before acting | all phases |
| `brainstorming.md` | design-before-build (scaled) | Phase 1 |
| `systematic-debugging.md` | root cause before any fix | Phases 4–5 (fix loops) |
| `verifying.md` | no completion claim without fresh evidence | Phases 4–6 + report |

Memory (the accumulated DO/DON'T lessons) lives in **Obsidian**, not in this table — see Phase 0 and the Memory section.

## The loop

### Phase 0 — Recall (memory + disciplines)
1. Read the four ported discipline files above; apply them for the whole run.
2. Read `using-skills.md` and, per it, invoke any process/framework skill that applies before acting.
3. **Memory — Obsidian hub-and-spoke.** Resolve the vault from the repo's `CLAUDE.local.md`: `LEARNINGS=` (the cross-repo hub) and `ACTIVE_CONTEXT=` (this repo's spoke). The `obsidian-recall.sh` SessionStart hook usually injects both already; if not, read them (or run `/sync-brain pull`). These are the accumulated cross-project lessons — pass the relevant ones into every agent prompt below. Also read the skill-local `lessons.md` if it holds accumulated lessons (legacy local memory) so nothing is stranded.
4. **If the repo is NOT wired to a vault** (`CLAUDE.local.md` absent, or no `LEARNINGS=`): ASK the user — provide the Obsidian vault path, or run `/setup-obsidian-memory` to wire this repo up. If they decline, use the skill-local `lessons.md` for this run (read and write).

### Phase 1 — Brainstorm (scaled)
Follow `brainstorming.md`. **Trivial** single-file/mechanical/unambiguous work → state the design in one sentence and go straight to the architect. **Non-trivial** (multi-component, new feature, ambiguous scope, user-facing behavior change) → explore intent, propose 2–3 approaches with a recommendation, present the design, and **get explicit approval before Phase 2**. Use `AskUserQuestion` for clarifying questions (batch related ones). Hand the approved design to the architect.

### Phase 2 — Architect (always)
Dispatch the `pb-architect` agent (the plan-and-build spec-writer — **not** the `architect` orchestrator agent, which delegates teammates instead of writing specs). It takes the approved design as its starting point, **discovers the project's conventions**, decomposes into components, **splits the work so each builder has ONE single responsibility** (the bigger the job, the sloppier the output — split until each job can be done at its finest), **partitions files so no two parallel builders share a file**, **decides which skills each component needs** (baked guidance skills it applies itself + action skills the builder must invoke — recorded in each spec's `## Skills` section), writes one spec per component to `docs/research/components/<name>.spec.md`, and returns a **dispatch plan** (`builder | spec path | owned files | tag | wave | depends-on | skills`) plus a **gate recommendation**. The architect is the **single decision point** for skill relevance — builders never discover skills, they only invoke the ones their spec names.
- If the architect returns clarifying questions, ask the user via `AskUserQuestion` before continuing.

### Phase 3 — Scaled gate
- **Single simple builder** (one `[low]`/`[med]` component, architect says `auto-proceed`) → proceed, no stop.
- **Multi-component OR any `[high]`** → show the specs + dispatch plan, wait for explicit "go" / "approve".

### Phase 4 — Build (collision-free, model-routed)
Execute the dispatch plan wave by wave:
- **Parallel within a wave** — disjoint owned files → one message, multiple `Agent` calls.
- **Sequential across waves** — a wave that depends on an earlier one runs after it.
- **Route by tag:** `[low]` → `executor-haiku`, `[med]` → `executor`, `[high]` → `executor-opus`.

Every builder prompt contains, **inline**:
1. the FULL contents of its spec file (never "go read the spec") — including its `## Skills` section
2. its owned file paths + the rule: **touch ONLY these files**
3. the relevant memory lessons (from Obsidian, or the `lessons.md` fallback)
4. the contents of `systematic-debugging.md` and `verifying.md`
5. complexity tag + the project's verify command (whatever the architect discovered — e.g. the typecheck script)
6. the explicit instruction: **invoke every skill in the spec's "Builder MUST invoke" list before writing code**

**Builder self-verification loop (inner loop).** A builder does NOT one-shot. It runs:
build → self-check against the spec's **Acceptance criteria** + Conventions checklist → run the
verify command → **on failure, find the root cause before patching** (`systematic-debugging.md`) →
fix → repeat (up to **3 fix iterations**). It reports ✅ only when every acceptance box is true
and verify passes — **with the actual output quoted** (`verifying.md`); no evidence, no ✅.
Otherwise ❌ blocked, naming the unmet criterion. Quality over speed — never ship a partial or
unverified result.

Blocked builder → escalate one tier (haiku → sonnet → opus). Opus blocked → halt and surface.

### Phase 5 — QA (always, tiered) — two verdicts
- **Lightweight** (single/simple build): one `qa-reviewer` over the whole diff; orchestrator runs the project's build/lint/typecheck.
- **Heavy** (multi-component): one `qa-reviewer` **per component** (parallel, each scoped to its spec + owned files), then a final integration pass.

QA returns **two verdicts per component: spec-compliance AND code-quality** — plus the quoted typecheck/lint/build output (`verifying.md` — no PASS without evidence).

**QA → fix outer loop (bounded).** Handle findings like received code review, not orders:
evaluate each technically first — verify it against the codebase, and **push back with reasoning
if a finding is wrong** (don't blind-implement, no performative agreement). Route the real blocker
findings to the OWNING builder (spec inline; builder debugs to root cause, then fixes), then
re-run QA on the SAME scope. Repeat until both verdicts pass or **3 rounds**. Still failing after
3 → halt and surface to the user; do not ship. `warn` findings are surfaced but do not block.

**Spec-satisfaction gate.** Before reporting done, confirm every spec's Acceptance criteria are met
across all components. The spec is the contract — no spec satisfied, not done.

### Phase 6 — Retro (always, self-learning → Obsidian)
Dispatch the `retro` agent with: what required rework, repeated QA findings, user corrections, and what worked. It distills **generalizable** (cross-project) lessons and **promotes them to the Obsidian hub via the sync-brain Promotion gate** — an atomic note in the `LEARNINGS` notes dir + one index line — while the run summary goes to the spoke (`ACTIVE_CONTEXT`). Deduped; most runs promote nothing to the hub. When the repo isn't wired to a vault, it appends to the skill-local `lessons.md` fallback instead. This is how the skill knows what and what NOT to do next time.

### Report
Components built · specs written (count should match builders) · files changed · build/lint/typecheck status (quoted) · QA findings (both verdicts) · lessons promoted. **No "done" without fresh verification evidence** (`verifying.md`) and the spec-satisfaction gate passed. Then ask before any git op.

## Agents (all bundled in this skill)

| Phase | Agent | Model | Role |
|-------|-------|-------|------|
| 2 | `pb-architect` | opus | consume design + discover conventions + dissect + partition + **assign skills per spec** + write specs |
| 4 | `executor-haiku` / `executor` / `executor-opus` | haiku / sonnet / opus | **invoke the spec's named skills**, build owned files, debug to root cause, verify with evidence |
| 5 | `qa-reviewer` | sonnet | verify diff vs spec + **code quality** + project conventions (two verdicts) |
| 6 | `retro` | sonnet | promote generalizable lessons to Obsidian (sync-brain gate); `lessons.md` fallback |

> `pb-architect` + all three executors hold the `Skill` tool. `pb-architect` invokes guidance skills (and bakes their rules into specs) and names action skills per component; builders invoke only the action skills their spec lists. qa-reviewer + retro do not invoke skills.

## Memory — Obsidian hub-and-spoke (with local fallback)

The skill's long-term memory is the **Obsidian vault**, shared across repos via hub-and-spoke:
- **Hub** (`LEARNINGS`) — cross-repo, cross-project lessons, curated as atomic notes (one `[[wikilink]]` index line each). This is where plan-and-project **generalizable** lessons live.
- **Spoke** (`ACTIVE_CONTEXT`) — this repo's session log; run summaries go here.

Paths are resolved from the repo's gitignored `CLAUDE.local.md` (`LEARNINGS=`, `ACTIVE_CONTEXT=`) — **never hardcoded**. Read at Phase 0 (usually auto-injected by `obsidian-recall.sh`), written at Phase 6 via **sync-brain's Promotion gate** (reusable + behavior-changing + not-already-covered; most takeaways never reach the hub).

**REQUIRED COMPANIONS:** the `sync-brain` skill (runtime read/write) and `setup-obsidian-memory` skill (wires a repo to the vault). If a repo isn't wired, Phase 0 asks for the vault path or offers `/setup-obsidian-memory`.

**`lessons.md` — legacy local memory + write fallback.** It is *read* at Phase 0 alongside the Obsidian hub (so its accumulated lessons are never stranded), but it is *written* at Phase 6 only when the repo isn't wired to a vault. It holds only generalizable, cross-project lessons; project-specific conventions are discovered live. Its durable subset can be migrated into the Obsidian hub as atomic notes via `/sync-brain` (a one-time curation, gated by the Promotion rule).

## Skill discovery — `using-skills.md`

`using-skills.md` is a self-contained port of the skill-discovery discipline (invoke relevant skills before acting; user instructions > skills > defaults). No dependency on any external plugin. It deliberately carries **no auto-commit behavior**.

## Collision-free parallelism (replaces git worktrees)

No worktrees. Safety comes from the architect's file partitioning: each builder owns a **disjoint** set of files and edits the shared tree directly. If two pieces of work must touch the same file, they go in the SAME builder or in SEQUENTIAL waves — never parallel.

## Guardrails (non-negotiable)

- **NO AUTO-COMMIT.** Never `git commit` / `git push` / `gh pr create` automatically. Ask after the report.
- **NO TEST FILES.** No `*.test.*` / `*.spec.*` / `__tests__/`. Verification = build / lint / typecheck / manual run. Debugging may use a **throwaway repro**, but it is never committed and never a test file — delete it once the fix is confirmed (`systematic-debugging.md`).
- **DESIGN BEFORE BUILD** for non-trivial work — brainstorm and get approval before the architect (`brainstorming.md`). Trivial single-file work may skip with a one-line design.
- **EVIDENCE BEFORE CLAIMS.** No "done / passing / fixed" from any layer without fresh, quoted verification output (`verifying.md`).
- **ROOT CAUSE BEFORE FIX.** Any verify failure / QA blocker is debugged to its root cause first — no symptom patches (`systematic-debugging.md`).
- **Memory is Obsidian** when the repo is wired; ask for the vault or offer `/setup-obsidian-memory` when it isn't. Never hardcode vault paths.
- **Specs are mandatory.** No builder without its spec file in `docs/research/components/`.
- **Self-contained subagent prompts.** Subagents have zero context — brief every dispatch from scratch and paste the spec + lessons + disciplines inline. No "as discussed above".
- **QA and Retro always run** — even for a single-builder task.
- **Conventions come from the project**, never hardcoded — discover and obey them.
- **One builder = one job.** The architect splits until each builder has a single responsibility; big multi-purpose dispatches produce sloppy work. See the architect's split triggers.

## Dispatch templates

### Builder (per wave member)
```
Repo root: <abs path>

Build this component. Touch ONLY your owned files — no others.
Owned files: <paths>

--- COMPONENT SPEC (build from this alone) ---
<full spec file contents — includes its ## Skills section>
--- END SPEC ---

--- SKILLS (invoke BEFORE writing code) ---
Invoke each skill in the spec's "Builder MUST invoke" list via the Skill tool, follow it,
then build. The "Baked" skills are already distilled into the spec — do NOT re-invoke them.
Invoke nothing the spec does not name. If a skill suggests committing, ignore + surface.
--- END SKILLS ---

--- DISCIPLINES (obey both) ---
<systematic-debugging.md contents>
<verifying.md contents>
--- END DISCIPLINES ---

--- LESSONS (obey all) ---
<relevant memory lessons — from Obsidian LEARNINGS/spoke, or lessons.md fallback>
--- END LESSONS ---

Follow the project's conventions (per the spec). Then LOOP: self-check your output against the
spec's Acceptance criteria + Conventions checklist, run `<project verify cmd>`, and on failure
find the ROOT CAUSE before patching, then fix — repeat (up to 3 fix iterations) until every
acceptance box is true and verify passes. Quote the final verify output — no ✅ without evidence.
Report ✅ done ONLY when fully satisfied; otherwise ❌ blocked naming the unmet criterion. Do not
improvise if the spec is wrong — halt and surface. Never ship a partial result.
```

### QA (per component in heavy tier, or whole diff in lightweight)
```
Repo root: <abs path>
Review these owned files against their spec: <paths>

--- SPEC ---
<spec contents>
--- LESSONS / CHECKLIST ---
<relevant memory lessons>

Discover the project's conventions (its CLAUDE.md / lint). Check the built files against the spec's
Acceptance criteria + Conventions checklist. Return TWO verdicts — spec-compliance AND code-quality
— plus a findings table. Run the project's typecheck + lint + build and QUOTE the actual output; no
PASS without evidence. Report findings for the orchestrator to evaluate — do not pre-judge or omit
issues. Do not edit.
```

## Failure modes

| Mistake | Fix |
|---------|-----|
| Two parallel builders edit one file | Architect must partition; same file → same builder or sequential wave |
| Builder told "see the spec file" | Paste full spec inline |
| Skipping QA / Retro on a small task | Both always run |
| Skipping brainstorm on non-trivial work | Design + approval before the architect; only trivial single-file work skips |
| Briefing a subagent with "as discussed above" | Subagents have no memory — brief from scratch |
| Hardcoding one project's conventions into another | Discover conventions from the current project |
| Symptom-patching a bug (it comes back) | Root cause first (`systematic-debugging.md`); throwaway repro, never committed |
| Claiming done/passing without running verify | Evidence before claims (`verifying.md`) — quote fresh output |
| Blind-implementing or performatively agreeing to a QA finding | Evaluate technically; push back with reasoning if the finding is wrong |
| Auto-committing | Ask the user first |
| Writing lessons to `lessons.md` while a vault is wired | Promote to Obsidian via sync-brain; `lessons.md` is fallback only |
| Repo not wired to a vault and no memory | Ask for the vault path or offer `/setup-obsidian-memory` |
| Editing specs from memory | Re-dispatch `pb-architect` for any structural change |
| One-shot build, no self-check | Builder loops vs acceptance criteria until satisfied (max 3 iterations) |
| Endless QA ↔ fix ping-pong | Bound to 3 rounds, then halt + surface — never ship unsatisfied |
| Reporting done with unmet criteria | Spec-satisfaction gate: every acceptance box must be true first |
