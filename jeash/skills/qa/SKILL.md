---
name: qa
description: Use when the user wants to validate built work before merge — check correctness against the spec, verify conventions, and run the project's typecheck / lint / build / tests. Triggers on "jeash:qa", "qa", "verify this", "does this pass", "check before merge", "run the typecheck/lint/build/tests".
---

# jeash:qa

Launcher for **qa** — the final quality gate. Finds what's wrong and proves it. **Reports — does not fix.**

## What to do

**Dispatch the `qa` subagent** (bundled in this plugin at `agents/qa.md`) with the scope and spec.

If the subagent can't be dispatched, follow `agents/qa.md` inline: check correctness vs spec (incl. edge cases) → conventions (CLAUDE.md, lint, surrounding patterns) → run the project's actual commands — typecheck (`vue-tsc`/`tsc`), lint, build, tests — and **quote the real output**. Never say "passing" without having run the command and seen the result; quote exact errors. Use the `verification-before-completion` discipline.

## Output

Findings ordered by severity: `file:line`, problem, suggested fix, and the command-output evidence backing it. End with a clear verdict and which field should address each item.
