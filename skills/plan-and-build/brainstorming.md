# Brainstorming (self-contained)

Design-before-build discipline ported into plan-and-build so it has **no dependency** on any
external plugin. The orchestrator runs this in **Phase 0.5**, before dispatching the architect.

**Core principle:** turn the request into an agreed design before any file is written. Building
the wrong thing well is still building the wrong thing.

## The gate (SCALED)

Not every request needs a full design pass. Scale the gate to the work:

- **Trivial** — one file, mechanical, unambiguous (rename, copy tweak, single prop, doc edit):
  state the design in **one sentence**, then go straight to the architect. No approval wait.
- **Non-trivial** — multi-component, new feature, ambiguous scope, or any user-facing behavior
  change: run the FULL flow below and **get explicit approval before Phase 2 (architect)**.

> When unsure which bucket you're in, treat it as non-trivial. "Too simple to design" is where
> unexamined assumptions cause the most wasted work.

<HARD-GATE>
For non-trivial work: do NOT dispatch the architect, write specs, or touch source until you
have presented a design and the user has approved it.
</HARD-GATE>

## The flow (non-trivial)

1. **Explore context.** Read the project's `CLAUDE.md` / `AGENTS.md`, relevant files, recent
   commits. Understand what already exists before proposing anything new.
2. **Assess scope first.** If the request is really several independent subsystems, say so and
   help decompose into sub-projects — each gets its own design → build cycle. Don't refine
   details of something that needs splitting first.
3. **Ask clarifying questions.** Purpose, constraints, success criteria, edge cases the user
   may not have considered. Use the `AskUserQuestion` tool (batch related questions; 2–4 options
   each + free-text fallback) — this matches the user's established preference. Keep asking until
   scope, architecture, and edge cases are locked; stop once you can build confidently.
4. **Propose 2–3 approaches** with trade-offs. Lead with your recommendation and why.
5. **Present the design.** Scale each section to its complexity (a sentence to a short paragraph).
   Cover: architecture, components, data flow, state, error handling. Ask after each section
   whether it looks right. Apply **YAGNI ruthlessly** — cut anything not needed.
6. **Get approval.** Only after the user approves does the run proceed to Phase 2 (architect).

## Terminal state

The one and only next step after an approved design is **Phase 2 — the `pb-architect` agent**,
which turns the design into per-component specs. Do NOT jump to any implementation skill from
here; the architect owns decomposition and skill assignment.

Optionally write the approved design to `docs/research/<topic>-design.md` for the architect to
consume — but see NO-COMMIT.

## Design for isolation

Break the work into units that each have ONE clear purpose and a well-defined interface — this
is what lets the architect partition files collision-free downstream. If describing a unit needs
the word "and", it is two units. Small, focused units also build more reliably.

## NO-COMMIT (carry-over guardrail)

This port carries **no** auto-commit behavior. If you write a design doc, do NOT `git commit` /
`push` / open a PR — committing is always the user's call. (Some external brainstorming skills
commit the design doc eagerly; this pipeline never does.)

## Red flags — you're skipping design when you shouldn't

| Thought | Reality |
|---------|---------|
| "This is too simple to design" | Only *truly trivial single-file* work skips. Everything else designs. |
| "I'll figure out the shape while building" | Wrong shape discovered mid-build = rework. Decide first. |
| "The user said build X, so just build" | "Build X" → design X, get a yes, then build. |
| "I already know what they want" | Confirm it. A one-line design + approval costs seconds. |
| "Asking questions wastes their time" | Building the wrong thing wastes far more. |
