---
name: plan-and-build
description: Use when the user asks to implement, build, create, add, fix, or refactor frontend work — any scope, from a one-line change to a multi-component feature. Triggers on "implement X", "build X", "add", "create", "refactor", "fix", "plan and build".
---

# Plan-and-Build — architect-orchestrated, spec-driven, self-learning

Every request flows through seven phases: **recall → brainstorm → plan (specialists → synthesis) → (scaled gate) → builders → QA → retro**. **The pipeline right-sizes to the task via lanes — fast / standard / heavy (see *Velocity — right-size the ceremony* below) — but the floor gates run in every lane.** Discipline runs through all of them: skills-first, **design-before-build**, **root-cause debugging**, **evidence-before-claims**. The architect decides how many builders to spawn (1…N). Brainstorm scales to the work; QA ALWAYS runs; Retro ALWAYS runs but is **backgrounded** — it never blocks the report. The skill gets smarter each run by promoting lessons to long-term memory.

You are the orchestrator. You dispatch agents and route results — you do not write source yourself.

**This skill is project-agnostic.** It hardcodes no framework or house conventions. The architect and QA agents *discover* each project's conventions at runtime (its `CLAUDE.md` / `AGENTS.md`, lint config, existing patterns, typecheck/lint/build commands) and obey those. Run it in any frontend repo and it adapts.

**This skill REQUIRES [gstack](https://github.com/gstack).** gstack supplies the design, debugging, plan-review, and runtime-QA disciplines the pipeline runs on — there is no self-contained fallback. Phase 0 preflights for it and halts with an install instruction if it's missing.

## Disciplines (gstack + two local ports)

Apply these all run. Where a gstack skill owns the discipline, **invoke it** at the phase named; the two remaining local ports (`using-skills.md`, `verifying.md`) have no gstack equivalent and are pasted **inline** into subagent dispatches (subagents have zero context).

| Discipline | Owned by | Applies at |
|-----------|----------|-----------|
| invoke relevant skills before acting | `using-skills.md` (local port) | all phases |
| design-before-build → precise spec | **gstack `spec`** | Phase 1 |
| plan review before dispatch | **gstack `autoplan`** | Phase 3 (**heavy lane** only) |
| root cause before any fix | **gstack `investigate`** | Phases 4–5 (fix loops) |
| runtime + multi-lens verification | **gstack `qa` / `browse` / `review` / `design-review` / `health`** | Phase 5 |
| pixel-fidelity to a cited Figma node | **`figma-to-vue` skill** + the Figma-match discipline below | Phases 1, 2b, 4, 5 (any Figma task) |
| no completion claim without fresh evidence | `verifying.md` (local port) | Phases 4–6 + report |

Memory (the accumulated DO/DON'T lessons) lives in **Obsidian**, not in this table — see Phase 0 and the Memory section.

## Figma-match discipline (when the task cites a Figma node)

A task that says "match / implement / build from Figma" (or pastes a `figma.com` URL) is a **pixel-fidelity** task, not a "make a plausible component" task. The failure mode this prevents: fixing the one element the ticket names, eyeballing it once, and shipping while the rest of the node still mismatches. Apply all four, every Figma task:

1. **Route the build through the `figma-to-vue` skill's visual-match loop** — not a hand-written spec + one screenshot. `figma-to-vue` runs `inspect → map → outline → build → visual-match` (Playwright render-vs-node pixel diff, iterate until close). The bespoke spec still frames scope, but **acceptance = "the render matches the Figma node"**, never "matches my spec bullets".
2. **Scope from the node's full element tree, not the file/ticket name.** Enumerate EVERY element in the node (heading, body, button, spacing, icon, color…) and compare each to the current render. Every element is in scope until a comparison proves it already matches. **Never write "assume X unchanged" / "already matches" without a Figma check** — that one unverified line is the classic miss.
3. **Verify on the production data shape / live route, not a lone story variant.** A fixture that omits a field can silently dodge the exact branch that's broken (e.g. a title-only fixture centers, hiding a title+body left-align bug). Add/execute the fixture that matches real data, or drive the live route.
4. **Measure, don't eyeball.** Pull the node's tokens (`get_variable_defs` / text styles: font-size, weight, line-height, alignment, spacing, color) and diff them against the code's *resolved* values (px → nearest Tailwind step, weight → `font-*`, alignment → `text-*`). A side-by-side render-vs-node screenshot is the final gate, at **every breakpoint the node defines**.

## Velocity — right-size the ceremony (lanes)

The pipeline scales to the task. Ceremony applied to a task that didn't need it adds latency, not quality — two reviewers finding the same bug isn't 2× quality. Route each request to a lane; the **floor gates run in EVERY lane**, only the scalable layer changes.

**The floor (lane-independent — no lane may skip these):**
- a spec / acceptance contract (≥1 sentence) — you can't verify "done" without it
- build verification with **quoted** evidence (typecheck / lint / build) — the correctness floor
- ≥1 `qa-reviewer` pass against the spec
- root cause before any fix
- runtime gate on user-facing work (a green build ≠ a working feature)
- evidence-before-claims + no auto-commit

**Lanes (scale ONLY the layer above the floor):**

| Lane | When | Adds above the floor | Skips |
|------|------|----------------------|-------|
| **Fast** | trivial / small, unambiguous, low-risk, no `[high]` (≤ a couple of files) | nothing — one-line design, pb-architect plans directly, build, floor QA | gstack `spec`, Phase 2a fan-out, `autoplan`, per-component QA, whole-diff `review`, unflagged lenses |
| **Standard** | typical feature / multi-file, some ambiguity, no `[high]` | gstack `spec`, Phase 2a→2b, QA runs only the lenses `QA emphasis` flags | `autoplan`, per-component QA split, whole-diff `review` |
| **Heavy** | large / ambiguous / cross-cutting / any `[high]` | `autoplan` gate, per-component QA + integration pass, whole-diff `review`, all flagged lenses | — |

**Routing rules (non-negotiable):**
- **Ambiguity routes UP, never down.** Unsure between two lanes → take the heavier. Cheaper to over-review than ship a bug.
- **Auto-escalate — upgrade the Phase-5 layer, don't rewind.** A lane whose QA surfaces a real blocker upgrades its **Phase-5 depth** for the re-run (per-component `qa-reviewer` + integration pass, whole-diff `review`, all flagged lenses), then re-enters the QA→fix loop. It does **not** rewind to Phase 3 — `autoplan` reviews a decomposition *before code exists*, so it can no longer do its job once builders have run. A blocker that is **decompositional** (wrong split, wrong partition) is the exception: re-dispatch `pb-architect`, and that re-plan takes the heavy lane.
- **The floor is not part of the lane choice** — it always runs, whichever lane you picked.

## The loop

### Phase 0 — Recall (preflight + memory + disciplines)
0. **gstack preflight (hard gate).** This skill requires gstack. Check it's installed —
   `[ -d "$HOME/.claude/skills/gstack" ] || command -v gstack` — and confirm the skills it
   depends on are present (`spec`, `autoplan`, `investigate`, `qa`, `browse`, `review`,
   `design-review`, `health`). **If gstack is missing, HALT** and tell the user to install it
   (there is no fallback); do not run a degraded pipeline.
1. Read the two local ports (`using-skills.md`, `verifying.md`); apply them for the whole run. The gstack-owned disciplines are invoked at their phases per the table above.
2. Read `using-skills.md` and, per it, invoke any process/framework skill that applies before acting.
3. **Memory — Obsidian hub-and-spoke (ALWAYS read when wired).** If the repo is wired to a vault, recall it on EVERY run — never skip it, never assume it is already loaded. Resolve the vault from the repo's `CLAUDE.local.md`: `LEARNINGS=` (the cross-repo hub) and `ACTIVE_CONTEXT=` (this repo's spoke). The `obsidian-recall.sh` SessionStart hook usually injects both, but **confirm they are actually present in this context — if not, read the files yourself** (or run `/sync-brain pull`). Subagents get NO SessionStart injection, so the recalled lessons must be **pasted inline into every agent prompt** below (architect, builders, QA, retro). Also read the skill-local `lessons.md` (legacy) so nothing is stranded.
4. **If the repo is NOT wired to a vault** (`CLAUDE.local.md` absent, or no `LEARNINGS=`): **memory is best-effort — proceed without it, this is not a blocker.** Offer `/setup-obsidian-memory` once as a suggestion (never nag, never halt), and fall back to the skill-local `lessons.md` (read + write) for this run.

### Phase 1 — Brainstorm → spec (scaled, gstack `spec`)
**Trivial** single-file/mechanical/unambiguous work (**fast lane**) → state the design in one sentence and go straight to the architect. **Non-trivial** (multi-component, new feature, ambiguous scope, user-facing behavior change — **standard / heavy lane**) → **invoke gstack `spec`** to turn the request into a precise, executable spec: it explores intent, surfaces edge cases, and produces the "what / why / acceptance" contract. Present it and **get explicit approval before Phase 2**. Use `AskUserQuestion` for clarifying questions (batch related ones). Hand the approved `spec` output to the architect as its starting point (the architect decomposes it into per-component build specs — no overlap).

**Figma tasks are never "trivial" on scope.** A cited Figma node/URL means the whole node is the contract, so apply the **Figma-match discipline** above: route the build through the `figma-to-vue` skill's visual-match loop, scope from the node's full element tree (not the file the ticket names), and make the acceptance criterion "render matches the node." A one-element fix on a Figma screen is the classic under-scope.

### Phase 2 — Plan (specialist fan-out → synthesis)
Planning is split: **domain specialists plan their own slice, then one synthesizer partitions the whole.** This mirrors the skill's core rule — one agent planning every domain at once is itself a big, sloppy job (the bigger the job, the sloppier the output). It is also DRY: the specialists ARE the jeash role agents, so improving a jeash agent improves this pipeline too.

**Phase 2a — Specialist planning (parallel, read-only).** Fan out ONLY the jeash specialist fields the task touches — `jeash:frontend` (Vue components/views/stores), `jeash:ux` (design/a11y/layout/design-system), `jeash:dx` (refactor/quality/type-safety) — one `Agent` call each in a single message. Each gets the approved design + a **read-only PLANNING contract** (template below): it explores the project for ITS domain and returns a **spec-fragment** (proposed units, the files it would own, the project conventions it found, the skills its domain needs, risks). **Specialists plan; they do not edit** — nothing is partitioned yet. Spawn one field or all three; skip fields the task doesn't touch. `jeash:review` and `jeash:qa` are **Phase-5 QA lenses, not planners** — their blocker findings route back to the owning executor via the Phase-5 fix loop; `jeash:architect` is unused here — pb-architect is the synthesizer.

**Phase 2b — Synthesis (`pb-architect`, always).** Dispatch `pb-architect` (the plan-and-build synthesizer — **not** the `architect` orchestrator agent, which delegates teammates instead of writing specs) with every fragment pasted inline. It **integrates** the fragments (does NOT re-plan each domain — it trusts each specialist's domain call and resolves only cross-domain conflicts): reconciles overlaps and duplicated units, **discovers/confirms the project's conventions**, **splits so each builder has ONE single responsibility** (split until each job can be done at its finest), **partitions files so no two parallel builders share a file** (it is the **single partition authority**), groups into waves, tags complexity, **assigns per-spec skills + a per-component `QA emphasis`** from its **skill palette** (baked guidance skills, builder-invoke action skills, and the Phase-5 lenses) — all in each spec's `## Skills` section, writes one spec per component to `docs/research/components/<name>.spec.md`, and returns a **dispatch plan** (`builder | spec path | owned files | tag | wave | depends-on | skills`) + a **lane recommendation** (`fast` / `standard` / `heavy`) — pb-architect is the only agent that sees the whole decomposition, so it makes the lane call that drives Phase 3 and Phase 5 depth. It is the **single decision point** for skill relevance — builders never discover skills, they only invoke the ones their spec names. Trivial work with no fragments → it plans directly from the design, as before.
- **Model:** pb-architect runs on **opus** — pinned in `agents/pb-architect.md`. A bad decomposition poisons everything downstream: every builder is briefed ONLY from its spec, and a bad split or partition isn't caught until QA, after the code exists. This is **one agent per run** — the cheapest place in the pipeline to buy judgment, and the lane gates never review it on fast/standard. Do not downgrade it to shave latency. (Unconditional by design: an `[high]`-keyed switch is unimplementable — `[high]` is pb-architect's *own output*, so it cannot be read before dispatching it. If a cheaper fast-lane synthesis is ever wanted it costs a file — a sonnet sibling routed by **lane**, which IS known at Phase 2 — never a sentence no dispatch path can perform.)
- If any specialist or pb-architect returns clarifying questions, ask the user via `AskUserQuestion` before continuing.
- **Figma tasks:** pb-architect scopes each spec from the node's **full element tree** (Figma-match discipline #2), never from the file/ticket name — no element is out of scope until a render-vs-node comparison shows it already matches. The spec's Acceptance criteria must include "render matches the node at every breakpoint it defines," and its `QA emphasis` must name the render-vs-node visual-match gate.

### Phase 3 — Scaled gate (lane-based)
**Take the lane from pb-architect's `lane recommendation` (Phase 2b)** — it saw the whole decomposition. Override it only upward, never downward.
- **Fast lane** (one `[low]`/`[med]` component, `auto-proceed`) → proceed, no stop.
- **Standard lane** (multi-file, no `[high]`) → show the plan + dispatch plan, wait for explicit "go" — **no `autoplan`** (a well-understood decomposition doesn't need the quad review).
- **Heavy lane** (any `[high]`, or cross-cutting / ambiguous multi-component) → **run gstack `autoplan`** over the specs + dispatch plan first (auto CEO/design/eng/DX review — catches a bad decomposition before any code is written), fold its decisions in, then show the plan + review outcome and wait for explicit "go" / "approve".

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
- **Fast / standard lane** (single/simple build): one `qa-reviewer` over the whole diff; orchestrator runs the project's build/lint/typecheck.
- **Heavy lane** (multi-component): one `qa-reviewer` **per component** (parallel, each scoped to its spec + owned files), then a final integration pass.

QA returns **two verdicts per component: spec-compliance AND code-quality** — plus the quoted typecheck/lint/build output (`verifying.md` — no PASS without evidence).

**Runtime + multi-lens (gstack, orchestrator-invoked after the static pass):** a green build is not a working feature. **Run ONLY the lenses the spec's `QA emphasis` flags, and run them in parallel** — one message, multiple invocations; they are independent read passes, so never serialize them, and an unflagged lens does not run. UI component → `qa`/`design-review`; risky logic → `review`/`health`. Add one whole-diff `review` on the **heavy lane** only. (The runtime gate on user-facing work is floor — it runs in every lane, so `qa` is always flagged when the change is user-facing.)
- **gstack `qa`** — drive the running app through the changed flow (click-test, console errors, broken states) whenever the work is user-facing. This is the runtime gate.
- **gstack `review`** — a pre-landing multi-lens read of the whole diff (architecture / reuse / conventions), complementing per-component spec checks.
- **gstack `design-review`** — designer's-eye pass (spacing, hierarchy, AI-slop, slow interactions) when the change touches UI.
- **gstack `health`** — code-quality dashboard to confirm the change didn't drag quality down.
- **Figma tasks — render-vs-node visual-match gate.** The runtime gate is a **side-by-side of the render against the Figma node at every breakpoint the node defines**, driven on the **production data shape / live route** (never a lone story variant that can dodge the broken branch), with the node's tokens diffed against the code's resolved values (Figma-match discipline #3–#4). "Looks right in one story" is not the gate — "matches the node" is.

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
**Runs in the background — the Report ships without waiting on it; retro writes memory async.** Dispatch the `retro` agent with: what required rework, repeated QA findings, user corrections, and what worked. It distills **generalizable** (cross-project) lessons and **promotes them to the Obsidian hub via the sync-brain Promotion gate** — an atomic note in the `LEARNINGS` notes dir + one index line — while the run summary goes to the spoke (`ACTIVE_CONTEXT`). Deduped; most runs promote nothing to the hub. When the repo isn't wired to a vault, it appends to the skill-local `lessons.md` fallback instead. This is how the skill knows what and what NOT to do next time.

### Report
Components built · specs written (count should match builders) · files changed · build/lint/typecheck status (quoted) · QA findings (both verdicts) · lessons promoted. **No "done" without fresh verification evidence** (`verifying.md`) and the spec-satisfaction gate passed. **Deliver the report immediately — Retro (Phase 6) runs async and never gates it.** Then ask before any git op.

## Agents (all bundled in this skill)

| Phase | Agent | Model | Role |
|-------|-------|-------|------|
| 2a | `jeash:frontend` / `jeash:ux` / `jeash:dx` (only the fields the task needs) | per-agent | plan their own domain slice, read-only → **spec-fragment** |
| 2b | `pb-architect` | opus | **integrate the fragments** + discover conventions + dissect + partition + **assign skills per spec** + write specs |
| 4 | `executor-haiku` / `executor` / `executor-opus` | haiku / sonnet / opus | **invoke the spec's named skills**, build owned files, debug to root cause, verify with evidence |
| 5 | `qa-reviewer` | sonnet | verify diff vs spec + **code quality** + project conventions (two verdicts) |
| 6 | `retro` | sonnet | promote generalizable lessons to Obsidian (sync-brain gate); `lessons.md` fallback |

> `pb-architect` + all three executors hold the `Skill` tool. `pb-architect` invokes guidance skills (and bakes their rules into specs) and names action skills per component; builders invoke only the action skills their spec lists. qa-reviewer + retro do not invoke skills.

## Memory — Obsidian hub-and-spoke (with local fallback)

The skill's long-term memory is the **Obsidian vault**, shared across repos via hub-and-spoke:
- **Hub** (`LEARNINGS`) — cross-repo, cross-project lessons, curated as atomic notes (one `[[wikilink]]` index line each). This is where plan-and-project **generalizable** lessons live.
- **Spoke** (`ACTIVE_CONTEXT`) — this repo's session log; run summaries go here.

Paths are resolved from the repo's gitignored `CLAUDE.local.md` (`LEARNINGS=`, `ACTIVE_CONTEXT=`) — **never hardcoded**. **When wired, ALWAYS read at Phase 0** (confirm the `obsidian-recall.sh` hook actually injected it — if not, read the files yourself; never skip a wired vault), written at Phase 6 via **sync-brain's Promotion gate** (reusable + behavior-changing + not-already-covered; most takeaways never reach the hub).

**REQUIRED COMPANIONS:** the `sync-brain` skill (runtime read/write) and `setup-obsidian-memory` skill (wires a repo to the vault). Memory is **best-effort** — if a repo isn't wired, Phase 0 proceeds without it (offers `/setup-obsidian-memory` once; never blocks).

**`lessons.md` — legacy local memory + write fallback.** It is *read* at Phase 0 alongside the Obsidian hub (so its accumulated lessons are never stranded), and it is the read/write fallback at Phase 6 **only when the repo isn't wired to a vault**. It holds only generalizable, cross-project lessons; project-specific conventions are discovered live. Its durable subset can be migrated into the hub as atomic notes via `/sync-brain` (a one-time curation, gated by the Promotion rule).

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
- **ALWAYS recall Obsidian memory when the repo is wired** — every run, confirmed present (not assumed), and injected into every agent prompt. Not wired → memory is best-effort; **proceed without it (never a blocker)**, offer `/setup-obsidian-memory` once. Never hardcode vault paths.
- **Specs are mandatory.** No builder without its spec file in `docs/research/components/`.
- **Self-contained subagent prompts.** Subagents have zero context — brief every dispatch from scratch and paste the spec + lessons + disciplines inline. No "as discussed above".
- **QA and Retro always run** — even for a single-builder task. Retro runs **in the background** and never blocks the report. **Lanes scale ceremony but NEVER skip a floor gate** (see Velocity — spec/verify/QA/root-cause/runtime-on-UI run in every lane).
- **Conventions come from the project**, never hardcoded — discover and obey them.
- **One builder = one job.** The architect splits until each builder has a single responsibility; big multi-purpose dispatches produce sloppy work. See the architect's split triggers.

## Dispatch templates

### Specialist planner (Phase 2a, one per jeash field the task needs)
```
Repo root: <abs path>

You are PLANNING your domain, not building. READ-ONLY: do not edit or create any source file.
Your domain: <frontend: components/views/stores | ux: design/a11y/layout/design-system | dx: refactor/quality/type-safety>.

--- APPROVED DESIGN ---
<the approved design/spec from Phase 1>
--- END DESIGN ---

--- LESSONS (obey all) ---
<relevant memory lessons — from Obsidian LEARNINGS/spoke, or lessons.md fallback>
--- END LESSONS ---

Explore the project (its CLAUDE.md / conventions / existing patterns) for YOUR domain only, then
return a domain SPEC-FRAGMENT in markdown — no code:
- Units you'd build/change in your domain, one-line responsibility each (no "and")
- Files you propose to own (exact paths)
- Project conventions that apply, with quoted paths (framework syntax, tokens, house patterns)
- Skills your domain needs (baked guidance vs builder-invoke action)
- Risks / edge cases / where your slice depends on another domain
Do NOT partition files across domains or resolve cross-domain overlaps — pb-architect does that in 2b.
If the design is ambiguous for your domain, return `## Clarifying questions` instead of a fragment.
```

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
Ignore the spec's "QA emphasis" list — those are the orchestrator's Phase-5 lenses, not yours.
Invoke nothing else the spec does not name. If a skill suggests committing, ignore + surface.
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
| Writing lessons to `lessons.md` while a vault is wired | Promote to Obsidian via sync-brain; `lessons.md` is the fallback only |
| Skipping a wired vault / assuming the SessionStart hook loaded it | Confirm memory is present; if not, read the files yourself — never skip a wired vault |
| Briefing an agent (architect/builder/QA/retro) without the recalled memory | Paste the recalled lessons inline into every dispatch (subagents get no injection) |
| Repo not wired to a vault | Proceed best-effort (not a blocker); offer `/setup-obsidian-memory` once, fall back to `lessons.md` |
| Editing specs from memory | Re-dispatch `pb-architect` for any structural change |
| A Phase-2a specialist edits source | Planning is read-only — only builders edit, after pb-architect partitions |
| pb-architect re-plans each domain from scratch | It integrates fragments — trust the domain call, resolve only cross-domain overlaps |
| Fanning out planners for a one-line change | Trivial work skips 2a — pb-architect plans directly from the design |
| One-shot build, no self-check | Builder loops vs acceptance criteria until satisfied (max 3 iterations) |
| Endless QA ↔ fix ping-pong | Bound to 3 rounds, then halt + surface — never ship unsatisfied |
| Reporting done with unmet criteria | Spec-satisfaction gate: every acceptance box must be true first |
| Figma task: fixing only the element the ticket names, rest of the node still off | Scope from the node's full element tree — every element in scope until compared (Figma-match #2) |
| "Heading already matches — don't change it" with no Figma check | Ban unverified "unchanged"/"already matches" on a Figma task; compare every element (Figma-match #2) |
| QA'd against a story fixture that dodged the broken branch | Verify on the production data shape / live route (Figma-match #3) |
| Eyeballing a Figma match instead of measuring; one screenshot ≠ the gate | Diff node tokens vs resolved Tailwind values + side-by-side render at each breakpoint (Figma-match #1, #4) |
| Same ceremony for a one-line change and a big feature | Right-size via lanes — fast / standard / heavy (see Velocity) |
| Fast/standard lane skips a floor gate (spec / verify / QA / root-cause / runtime-on-UI) | The floor is lane-independent — every lane runs it; lanes scale only the layer above it |
| Unsure which lane → picked the lighter one | Ambiguity routes UP; unsure → heavier lane, then auto-escalate if QA finds a blocker |
| Running all four gstack lenses on every change | Run ONLY the lenses `QA emphasis` flags, in parallel; whole-diff `review` on heavy lane only |
| Serializing the Phase-5 lenses | They're independent read passes — one message, parallel |
| Blocking the report on Retro | Retro is backgrounded — ship the report, retro writes memory async |
| Downgrading pb-architect to shave latency | Synthesis always runs on **opus** — one agent per run, and on fast/standard lanes no gate reviews its decomposition. A bad partition costs a rebuild; the latency saved is seconds |
| Describing a conditional model switch in prose | No dispatch path can perform it — frontmatter `model:` binds. A real switch costs a sibling agent file routed by **lane** (known at Phase 2), never by `[high]` (pb-architect's own output) |
| Spec ships with an empty/absent `QA emphasis` on user-facing work | Phase 5 then runs ZERO lenses — pb-architect MUST flag gstack `qa` on anything user-facing (floor); every spec carries the line, `none` only with a stated reason |
| A spec flags whole-diff `review` on a fast/standard lane | `review` is heavy-lane-only — flagging it elsewhere puts two written rules in conflict |
| `autoplan` on every multi-component task | `autoplan` is the heavy lane only (any `[high]` / cross-cutting / ambiguous) |
