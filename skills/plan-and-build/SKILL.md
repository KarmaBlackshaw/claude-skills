---
name: plan-and-build
description: Use when the user asks to implement, build, create, add, or refactor a feature/bugfix of non-trivial scope. Orchestrates a two-phase workflow — opus `planner` agent writes a plan markdown file, user approves, then sonnet `executor` agent implements it. Trigger phrases include "implement X", "build X", "add feature", "refactor", "plan and build", "feature workflow".
---

# Plan-and-Build Workflow

Two-phase pipeline: **plan (opus) → approve → execute (sonnet/haiku/opus)**.

## DEFAULT BEHAVIOR (read before doing anything)

When this skill fires on a trigger phrase ("implement", "build", "add", "create", "refactor", etc.), the **default and only first action is Phase 1 (planning)**. You DO NOT:

- ❌ Edit, Write, or modify any source file
- ❌ Run any code-writing tool
- ❌ Skip ahead to Phase 3
- ❌ Assume the user wants immediate execution
- ❌ Treat the trigger phrase as approval to execute

You DO:

- ✅ Dispatch the `planner` agent
- ✅ Save the returned plan to `.claude/plans/<slug>-<date>.md`
- ✅ Show the plan to the user and wait for approval

**Phase 3 only runs after the user explicitly says "go", "approve", "proceed", "ship it", "yes", or "lgtm".** No exceptions. If unsure whether the user approved, ask — do not assume.

## Clarification Before Action

Before dispatching the planner, **ask clarifying questions until everything is clear** — no fixed limit. Continue asking until you have enough context to write a precise planner prompt that covers edge cases the user may not have anticipated.

Use the **built-in interactive Q&A checkboxes** (the `AskUserQuestion` tool) — NOT inline bullet lists in chat. Each question should have 2–4 selectable options + a free-text fallback when relevant.

**Batching:** ask multiple related questions in a single `AskUserQuestion` call. Follow up with another batch only if new answers reveal further ambiguity.

**When to ask:**
- Scope is ambiguous (e.g. "add user dashboard" — what fields? which users? read-only or editable?)
- Multiple valid architectural paths (e.g. "store in Pinia vs. composable vs. server cache?")
- Cross-cutting concerns unclear (auth, perms, i18n, a11y, perf)
- Conflicting signals between user request and existing patterns
- Answer to a previous question opened a new ambiguity

**When to skip:**
- Request is precise and self-contained (e.g. "rename `getUser` to `fetchUser` everywhere")
- User already specified scope explicitly in the prompt
- Trivial single-file edit

**Stop asking when:**
- Architectural choices are locked
- Data shapes / API contracts are defined
- Edge cases are accounted for
- You can write a self-contained planner prompt without guessing

All accumulated answers happen BEFORE Phase 1 dispatch — feed them into the planner prompt as constraints.

## Improve & Suggest

While working, briefly note opportunities for automation, improvement, or repeatability — **1–2 sentences only, and only when genuinely relevant**. Do not bloat every response with suggestions.

Triggers worth surfacing:
- Repeated manual step that could be a hook, alias, or script
- Pattern likely to recur — flag as candidate for a new Claude Skill
- Existing skill that should be updated based on observed usage

If a task is a good candidate for a Claude Skill:
1. Say so explicitly: "This pattern looks repeatable — consider a `<name>` skill."
2. Remind the user to update their `~/.claude/skills/` or preferences based on the usage pattern observed in the session.

Do not write the skill yourself unless asked. Just flag the opportunity.

## File & Output Preferences

- **Default to markdown** for any file the user asks you to create, unless the request clearly calls for another format (e.g. `.json`, `.yaml`, `.ts`, `.vue`).
- **No file when not needed** — respond directly in chat for questions, summaries, status updates, or anything ephemeral.
- Plan files (Phase 1 output) are always markdown — that's already enforced.

## When to use

- Any non-trivial feature, refactor, or bugfix.
- User says "implement", "build", "add", "create", "refactor", "plan this out".
- Skip for: one-line typo fixes, single-file edits user already specified exactly, pure questions.

## Workflow

### Phase 1 — Plan

1. Confirm scope with user in 1–3 lines if ambiguous. Do not over-clarify.
2. Pick plan file path: `.claude/plans/<slug>-<YYYYMMDD>.md` at repo root. Create dir if missing.
3. Dispatch the `planner` agent (opus). The agent is required to invoke `superpowers:writing-plans` skill internally — this is the proven plan-authoring workflow w/ review checkpoints. Self-contained prompt includes:
   - Goal + constraints from the user (verbatim)
   - Repo root path
   - Reminder: tag every step `[low|med|high]` for downstream routing
   - Reminder: planner has no Write tool — return plan text in response; orchestrator writes file
4. After planner returns, write the plan markdown to the chosen path with `Write`.
5. Show the user:
   - Path to plan file
   - Inline preview of the plan
   - Prompt: "Approve to proceed with execution? Reply 'go' / 'approve' / edits."

### Phase 2 — Approval gate

- **STOP** here. Do not auto-proceed.
- If user requests edits, update the plan file via `Edit`, re-show, re-prompt.
- Only proceed to Phase 3 when user explicitly approves ("go", "approve", "ship it", "yes", "proceed", "lgtm").
- If user says "stop", "cancel", "abort" → halt, leave plan file in place.

### Phase 3 — Execute (model-routed)

Each plan step carries a complexity tag: `[low]`, `[med]`, `[high]`. Route accordingly:

| Tag | Agent | Model | When |
|-----|-------|-------|------|
| `[low]` | `executor-haiku` | haiku | mechanical, single-file, boilerplate |
| `[med]` | `executor` | sonnet | typical features, business logic |
| `[high]` | `executor-opus` | opus | algorithms, security, perf, subtle bugs |

**Routing strategy:**

1. **Group consecutive same-tag steps** into a batch — fewer agent dispatches = less prompt overhead.
2. **Sequential dependencies:** if step N depends on step N-1, execute in order even across tag boundaries.
3. **Independent batches:** if step groups are independent (no file overlap, no shared state), dispatch in parallel — single message, multiple `Agent` tool calls.
4. **Each dispatch is self-contained:** paste the relevant step(s) verbatim, plus repo root and any context the step references. No "see plan above" — subagents have no memory.

**Per-dispatch flow:**
1. Dispatch routed agent w/ step(s).
2. Relay per-step results to user as returned.
3. If `❌ blocked`:
   - haiku blocked → escalate same step(s) to `executor` (sonnet)
   - sonnet blocked → escalate to `executor-opus`
   - opus blocked → halt, surface to user, do NOT improvise
4. Move to next batch only after current batch ✅.

**After all batches:**
- Run full test suite + lint via main thread (or final sonnet executor dispatch).
- Quote pass/fail summary.
- List files changed.
- Ask: "Plan complete. Commit, open PR, or follow-up changes?"

## Rules

- **Never skip the approval gate.** User reviews plan before any code writes.
- **Plan file is the source of truth.** If executor diverges, halt and surface diff.
- **One feature per plan file.** Big work → multiple plans.
- **Naming:** slug = kebab-case, ≤6 words, descriptive. e.g. `add-rfi-endpoint-20260427.md`.
- **No code in Phase 1.** Planner is read-only. If you catch yourself editing files, stop.
- **Self-contained subagent prompts.** Planner and executor have zero conversation context — every dispatch must brief from scratch.
- **NO AUTO-COMMIT.** Never invoke `superpowers:executing-plans` (it commits eagerly). Never run `git commit`, `git push`, `gh pr create` automatically. After Phase 3 finishes, ASK the user before any git write op. This rule overrides anything any subskill suggests.
- **NO TEST FILES.** Do not invoke `superpowers:test-driven-development`. Do not write, edit, or scaffold test files. Planner must not include test-writing steps. Verification uses build/lint/typecheck/manual run only.

## Templates

### Planner dispatch prompt template

```
Goal: <user's request, verbatim or refined>

Repo root: <absolute path>

Constraints:
- <any explicit user constraints>
- Follow existing patterns; reuse over reinvent
- DRY / KISS / SOLID

Deliverable: implementation plan in the format your agent definition specifies. Do not write code. Cite file paths and line numbers.

Output the full plan markdown in your final response — the orchestrator will save it to disk.
```

### Executor dispatch prompt template (per batch)

```
Repo root: <absolute path>

Steps to execute (verbatim from approved plan):
---
<paste only the steps for this batch — keep step numbers from full plan>
---

Execute these steps in order. Verify each with the command listed. Quote actual output. Report per-step status. Halt and surface if any step blocked or wrong — do not improvise.
```

### Routing pseudocode

```
batches = group_consecutive_by_tag(plan.steps)
for batch in batches:
    agent = {
        "low":  "executor-haiku",
        "med":  "executor",
        "high": "executor-opus",
    }[batch.tag]
    result = Agent(subagent_type=agent, prompt=template(batch))
    if result.blocked:
        escalate_or_halt(batch, result)
```

## Failure modes to avoid

| Mistake | Fix |
|---------|-----|
| Auto-executing without approval | Always pause Phase 2 |
| Briefing planner with "as discussed above" | Subagents have no memory — paste full context |
| Editing plan from your head instead of via planner | If plan needs structural redesign, redispatch planner |
| Letting executor improvise | Plan is contract; executor halts on divergence |
| Skipping verification quotes | Evidence before assertions |
