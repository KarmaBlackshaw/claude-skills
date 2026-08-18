---
name: plan-and-build
description: Use when the user asks to implement, build, create, add, fix, or refactor frontend work — any scope, from a one-line change to a multi-component feature. Triggers on "implement X", "build X", "add", "create", "refactor", "fix", "plan and build".
---

# Plan-and-Build — architect-orchestrated, spec-driven, self-learning

Every request flows through seven phases: **recall → brainstorm → architect → (scaled gate) → builders → QA → retro**. Discipline runs through all of them: skills-first, **design-before-build**, **root-cause debugging**, **evidence-before-claims**. The architect decides how many builders to spawn (1…N). Brainstorm scales to the work; QA and Retro ALWAYS run. The skill gets smarter each run by promoting lessons to long-term memory.

You are the orchestrator. You dispatch agents and route results — you do not write source yourself.

**This skill is project-agnostic.** It hardcodes no framework or house conventions. The architect and QA agents *discover* each project's conventions at runtime (its `CLAUDE.md` / `AGENTS.md`, lint config, existing patterns, typecheck/lint/build commands) and obey those. Run it in any frontend repo and it adapts.

**This skill REQUIRES [gstack](https://github.com/gstack).** gstack supplies the design, debugging, plan-review, and runtime-QA disciplines the pipeline runs on — there is no self-contained fallback. Phase 0 preflights for it and halts with an install instruction if it's missing.

## Disciplines (gstack + two local ports)

Apply these all run. Where a gstack skill owns the discipline, **invoke it** at the phase named; the two remaining local ports (`using-skills.md`, `verifying.md`) have no gstack equivalent and are pasted **inline** into subagent dispatches (subagents have zero context).

| Discipline | Owned by | Applies at |
|-----------|----------|-----------|
| invoke relevant skills before acting | `using-skills.md` (local port) | all phases |
| design-before-build → precise spec | **gstack `spec`** | Phase 1 |
| plan review before dispatch | **gstack `autoplan`** | Phase 3 (multi-component / `[high]`) |
| root cause before any fix | **gstack `investigate`** | Phases 4–5 (fix loops) |
| runtime + multi-lens verification | **gstack `qa` / `browse` / `review` / `design-review` / `health`** | Phase 5 |
| no completion claim without fresh evidence | `verifying.md` (local port) | Phases 4–6 + report |

Memory (the accumulated DO/DON'T lessons) lives in **Obsidian**, not in this table — see Phase 0 and the Memory section.

## The loop

### Phase 0 — Recall (preflight + memory + disciplines)
0. **gstack preflight (hard gate).** This skill requires gstack. Check it's installed —
   `[ -d "$HOME/.claude/skills/gstack" ] || command -v gstack` — and confirm the skills it
   depends on are present (`spec`, `autoplan`, `investigate`, `qa`, `browse`, `review`,
   `design-review`, `health`). **If gstack is missing, HALT** and tell the user to install it
   (there is no fallback); do not run a degraded pipeline.
1. Read the two local ports (`using-skills.md`, `verifying.md`); apply them for the whole run. The gstack-owned disciplines are invoked at their phases per the table above.
2. Read `using-skills.md` and, per it, invoke any process/framework skill that applies before acting.
3. **Memory — Obsidian hub-and-spoke.** Resolve the vault from the repo's `CLAUDE.local.md`: `LEARNINGS=` (the cross-repo hub) and `ACTIVE_CONTEXT=` (this repo's spoke). The `obsidian-recall.sh` SessionStart hook usually injects both already; if not, read them (or run `/sync-brain pull`). These are the accumulated cross-project lessons — pass the relevant ones into every agent prompt below. Also read the skill-local `lessons.md` if it holds accumulated lessons (legacy local memory) so nothing is stranded.
4. **If the repo is NOT wired to a vault** (`CLAUDE.local.md` absent, or no `LEARNINGS=`): ASK the user — provide the Obsidian vault path, or run `/setup-obsidian-memory` to wire this repo up. If they decline, use the skill-local `lessons.md` for this run (read and write).

### Phase 1 — Brainstorm → spec (scaled, gstack `spec`)
**Trivial** single-file/mechanical/unambiguous work → state the design in one sentence and go straight to the architect. **Non-trivial** (multi-component, new feature, ambiguous scope, user-facing behavior change) → **invoke gstack `spec`** to turn the request into a precise, executable spec: it explores intent, surfaces edge cases, and produces the "what / why / acceptance" contract. Present it and **get explicit approval before Phase 2**. Use `AskUserQuestion` for clarifying questions (batch related ones). Hand the approved `spec` output to the architect as its starting point (the architect decomposes it into per-component build specs — no overlap).

### Phase 2 — Architect (always)
Dispatch the `pb-architect` agent (the plan-and-build spec-writer — **not** the `architect` orchestrator agent, which delegates teammates instead of writing specs). It takes the approved design as its starting point, **discovers the project's conventions**, decomposes into components, **splits the work so each builder has ONE single responsibility** (the bigger the job, the sloppier the output — split until each job can be done at its finest), **partitions files so no two parallel builders share a file**, **decides which skills each component needs** (baked guidance skills it applies itself + action skills the builder must invoke — recorded in each spec's `## Skills` section), writes one spec per component to `docs/research/components/<name>.spec.md`, and returns a **dispatch plan** (`builder | spec path | owned files | tag | wave | depends-on | skills`) plus a **gate recommendation**. The architect is the **single decision point** for skill relevance — builders never discover skills, they only invoke the ones their spec names.
- If the architect returns clarifying questions, ask the user via `AskUserQuestion` before continuing.

### Phase 3 — Scaled gate (gstack `autoplan` on the plan)
- **Single simple builder** (one `[low]`/`[med]` component, architect says `auto-proceed`) → proceed, no stop.
- **Multi-component OR any `[high]`** → **run gstack `autoplan`** over the architect's specs + dispatch plan first (auto CEO/design/eng/DX review — catches a bad decomposition before any code is written), fold its decisions into the plan, then show the plan + review outcome and wait for explicit "go" / "approve".

### Phase 4 — Build (collision-free, model-routed)
Execute the dispatch plan wave by wave:
- **Parallel within a wave** — disjoint owned files → one message, multiple `Agent` calls.
- **Sequential across waves** — a wave that depends on an earlier one runs after it.
- **Route by tag:** `[low]` → `executor-haiku`, `[med]` → `executor`, `[high]` → `executor-opus`.

Every builder prompt contains, **inline**:
1. the FULL contents of its spec file (never "go read the spec") — including its `## Skills` section
2. its owned file paths + the rule: **touch ONLY these files**
3. the relevant memory lessons (from Obsidian, or the `lessons.md` fallback)
4. the contents of `verifying.md` + the instruction: **on any verify failure, invoke gstack `investigate`** to find the root cause before patching (it holds the `Skill` tool — invoke, don't guess)
5. complexity tag + the project's verify command (whatever the architect discovered — e.g. the typecheck script)
6. the explicit instruction: **invoke every skill in the spec's "Builder MUST invoke" list before writing code**

**Builder self-verification loop (inner loop).** A builder does NOT one-shot. It runs:
build → self-check against the spec's **Acceptance criteria** + Conventions checklist → run the
verify command → **on failure, root-cause it with gstack `investigate` before patching** →
fix → repeat (up to **3 fix iterations**). It reports ✅ only when every acceptance box is true
and verify passes — **with the actual output quoted** (`verifying.md`); no evidence, no ✅.
Otherwise ❌ blocked, naming the unmet criterion. Quality over speed — never ship a partial or
unverified result.

Blocked builder → escalate one tier (haiku → sonnet → opus). Opus blocked → halt and surface.

### Phase 5 — QA (always, tiered) — two verdicts + runtime
**Static (`qa-reviewer` subagent):**
- **Lightweight** (single/simple build): one `qa-reviewer` over the whole diff; orchestrator runs the project's build/lint/typecheck.
- **Heavy** (multi-component): one `qa-reviewer` **per component** (parallel, each scoped to its spec + owned files), then a final integration pass.

QA returns **two verdicts per component: spec-compliance AND code-quality** — plus the quoted typecheck/lint/build output (`verifying.md` — no PASS without evidence).

**Runtime + multi-lens (gstack, orchestrator-invoked after the static pass):** a green build is not a working feature.
- **gstack `qa`** — drive the running app through the changed flow (click-test, console errors, broken states) whenever the work is user-facing. This is the runtime gate.
- **gstack `review`** — a pre-landing multi-lens read of the whole diff (architecture / reuse / conventions), complementing per-component spec checks.
- **gstack `design-review`** — designer's-eye pass (spacing, hierarchy, AI-slop, slow interactions) when the change touches UI.
- **gstack `health`** — code-quality dashboard to confirm the change didn't drag quality down.

Fold every real finding from these into the fix loop below alongside the `qa-reviewer` verdicts.

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

`using-skills.md` is a self-contained port of the skill-discovery discipline (invoke relevant skills before acting; user instructions > skills > defaults). It is the one discipline with no gstack owner, so it stays a local port. It deliberately carries **no auto-commit behavior**.

## Collision-free parallelism (replaces git worktrees)

No worktrees. Safety comes from the architect's file partitioning: each builder owns a **disjoint** set of files and edits the shared tree directly. If two pieces of work must touch the same file, they go in the SAME builder or in SEQUENTIAL waves — never parallel.

## Guardrails (non-negotiable)

- **REQUIRES GSTACK.** Phase 0 preflights for gstack; if it's missing, HALT with an install instruction. No degraded/fallback run.
- **NO AUTO-COMMIT.** Never `git commit` / `git push` / `gh pr create` automatically. Ask after the report. (No ship/deploy phase — the pipeline ends at the report.)
- **NO TEST FILES.** No `*.test.*` / `*.spec.*` / `__tests__/`. Verification = build / lint / typecheck / manual run. Debugging may use a **throwaway repro**, but it is never committed and never a test file — delete it once the fix is confirmed (gstack `investigate`).
- **DESIGN BEFORE BUILD** for non-trivial work — produce a spec with gstack `spec` and get approval before the architect. Trivial single-file work may skip with a one-line design.
- **EVIDENCE BEFORE CLAIMS.** No "done / passing / fixed" from any layer without fresh, quoted verification output (`verifying.md`).
- **ROOT CAUSE BEFORE FIX.** Any verify failure / QA blocker is debugged to its root cause first — no symptom patches (gstack `investigate`).
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

--- DISCIPLINES ---
<verifying.md contents>
On ANY verify failure, invoke gstack `investigate` (Skill tool) to find the ROOT CAUSE before
patching — no symptom fixes. A throwaway repro is fine; delete it after, never commit it.
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
| Skipping brainstorm on non-trivial work | Spec via gstack `spec` + approval before the architect; only trivial single-file work skips |
| Briefing a subagent with "as discussed above" | Subagents have no memory — brief from scratch |
| Hardcoding one project's conventions into another | Discover conventions from the current project |
| Running the pipeline without gstack | Phase 0 preflight halts — install gstack, there is no fallback |
| Symptom-patching a bug (it comes back) | Root cause first (gstack `investigate`); throwaway repro, never committed |
| Calling a green build "working" without driving it | Runtime gate: gstack `qa`/`browse` on user-facing work |
| Claiming done/passing without running verify | Evidence before claims (`verifying.md`) — quote fresh output |
| Blind-implementing or performatively agreeing to a QA finding | Evaluate technically; push back with reasoning if the finding is wrong |
| Auto-committing | Ask the user first |
| Writing lessons to `lessons.md` while a vault is wired | Promote to Obsidian via sync-brain; `lessons.md` is fallback only |
| Repo not wired to a vault and no memory | Ask for the vault path or offer `/setup-obsidian-memory` |
| Editing specs from memory | Re-dispatch `pb-architect` for any structural change |
| One-shot build, no self-check | Builder loops vs acceptance criteria until satisfied (max 3 iterations) |
| Endless QA ↔ fix ping-pong | Bound to 3 rounds, then halt + surface — never ship unsatisfied |
| Reporting done with unmet criteria | Spec-satisfaction gate: every acceptance box must be true first |
