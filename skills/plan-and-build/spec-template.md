# <ComponentName> Spec

> Architect fills this for EACH component, one file per component, at
> `docs/research/components/<name>.spec.md`. A builder with zero context must be able to
> build from this file alone. Use the project's ACTUAL framework syntax and conventions
> (the architect discovers them). Fill every section; use "N/A" only when truly inapplicable.

## Overview
- **Target file:** <path to the component file>
- **Owned files (this builder only):** <list — MUST be disjoint from every other builder>
- **Complexity:** `[low|med|high]`
- **Wave:** <parallel group #> · **Depends-on:** <other component(s) or none>

## Responsibility
<single clear purpose — what this component does and nothing more>
> If describing this needs the word "and", it is two components — split the spec into two.

## Skills
> Architect fills both lists (Phase 2, step 7). Builder reads this FIRST.
- **Baked — already applied by the architect, do NOT re-invoke:** <skill names, or "none"> — their concrete rules are folded into the Conventions checklist below.
- **Builder MUST invoke before coding (action skills):** <skill names, or "none"> — invoke each via the `Skill` tool, follow it, THEN build. Do not invoke any skill not listed here.

## Public API
- **Inputs / props:** <names + types>
- **Outputs / events:** <names + payloads>
- **Slots / children / composition:** <if any>
- **Two-way bindings:** <if any>

## State & data
- **State management:** <store/module + which pieces it reads/writes>
- **Data fetching:** <source + the project's data-fetching pattern + loading/error handling>
- **Shared logic:** <hooks / composables / utils — reuse existing where possible>

## Dependencies (imports)
- **Auto-provided by the project (DO NOT import):** <names>
- **Explicit imports needed:** <module → symbols>
- **Third-party:** <lib + why>

## i18n (only if the project is localized)
- Where strings live + the keys this component needs: <key: "value"> ...

## Conventions checklist (from the project, discovered by the architect)
- [ ] Follows the project's import rules (no redundant / auto-provided imports)
- [ ] Uses the project's design tokens / theme (no hardcoded style values)
- [ ] Matches the project's type-safety rules (no loose / unsafe types)
- [ ] Matches existing patterns for this kind of component
- [ ] User-facing strings externalized (if the project is localized)
- [ ] No test/spec files

## Acceptance criteria (Done when — the builder LOOPS against this)
> Concrete, checkable statements — the satisfaction contract. The builder iterates
> build → check against these → run Verify → fix, until EVERY box is true. QA re-checks the
> same boxes. If a box genuinely can't be met, the builder reports ❌ blocked naming the unmet
> criterion — it never ships a partial result.
- [ ] <observable behavior / output 1>
- [ ] <observable behavior / output 2>
- [ ] Public API matches this spec exactly (inputs, outputs, slots, bindings)
- [ ] Every Conventions-checklist box satisfied
- [ ] Verify command passes clean

## Verify
- `<the project's typecheck / lint / build command>` (builder runs before finishing)
