# Using Skills (self-contained)

Skill-discovery discipline ported into plan-and-build so it has **no dependency** on any
external plugin. Orchestrator and agents follow this.

## The rule

Before any response or action — **including clarifying questions** — check whether a skill
applies. If there's even a ~1% chance a skill is relevant, invoke it to check. If it turns
out to be the wrong fit, you don't have to use it.

## Order of precedence

1. **Process skills first** (brainstorming, debugging, planning) — they decide HOW to approach.
2. **Implementation skills second** (framework / design / domain skills) — they guide execution.

"Build X" → brainstorm/plan first, then the implementation skill. "Fix bug" → debug first.

## Flow

1. Message or task received.
2. Might any skill apply? Yes (even 1%) → invoke and check. Definitely not → proceed.
3. Announce: "Using [skill] to [purpose]".
4. If the skill has a checklist, create one todo per item.
5. Follow the skill, then respond.

## Red flags — you're rationalizing, STOP and check for a skill

| Thought | Reality |
|---------|---------|
| "Just a simple question" | Questions are tasks. Check. |
| "Need more context first" | Skill check comes BEFORE clarifying. |
| "Let me explore first" | Skills tell you HOW to explore. Check first. |
| "I remember this skill" | Skills evolve. Re-read the current version. |
| "Skill is overkill" | Simple turns complex. Use it. |
| "I'll do one thing first" | Check BEFORE doing anything. |

## Priority

**User instructions** (CLAUDE.md / AGENTS.md / direct requests) > **skills** > **default behavior**.
If a user rule conflicts with a skill, follow the user.

## NO-COMMIT (carry-over guardrail)

This port deliberately does NOT include any auto-commit behavior. Never `git commit` / `push`
/ open a PR automatically — that is always the user's call. Some external skills commit
eagerly; this pipeline never does.

## Subagent note

A subagent dispatched for one specific task skips the *discovery* overhead — it does NOT scan
for relevant skills itself. But the architect (Phase 2) decides skill relevance once and records
it in each spec's `## Skills` section. So a builder still **invokes the skills its spec names**
(the "Builder MUST invoke" list) before coding — it just doesn't go discover them on its own.
Skills in the spec's "Baked" list are already distilled into the spec; do not re-invoke those.
