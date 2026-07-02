# Verification Before Completion (self-contained)

Evidence-before-claims discipline ported into plan-and-build so it has **no dependency** on any
external plugin. The orchestrator, builders, and QA all obey it.

**Core principle:** claiming work is done without fresh verification is dishonesty, not
efficiency. Evidence before claims, always.

## The Iron Law

```
NO COMPLETION CLAIM WITHOUT FRESH VERIFICATION EVIDENCE
```

If you have not run the verify command **in this message**, you cannot say it passes.

## The gate (run before ANY "done / passing / fixed / ✅")

1. **Identify** the command that proves the claim (typecheck / lint / build / manual run).
2. **Run** it fresh and in full — not a remembered result, not a partial check.
3. **Read** the actual output: exit code, error count.
4. **Compare** output to the claim.
   - Confirms it → state the claim **with** the quoted evidence.
   - Doesn't → state the ACTUAL status with the evidence.

Skipping any step is lying, not verifying.

## Applies at every layer

- **Builder:** no step marked ✅ without quoted verify output for that step. The self-fix loop
  exits only when every acceptance box is true AND verify passes — with the output quoted.
- **Orchestrator:** never trust a subagent's "success" at face value. Confirm against the actual
  diff / the re-run verify before treating a task as complete.
- **QA:** never return PASS without quoted typecheck / lint / build output.
- **Final report:** the spec-satisfaction gate — every acceptance criterion across all
  components confirmed met — before telling the user it's done.

## Common false claims

| Claim | Requires | Not sufficient |
|-------|----------|----------------|
| "Typecheck passes" | typecheck output: 0 errors | "should pass", a previous run |
| "Lint clean" | lint output: 0 errors | a partial / single-file check |
| "Build succeeds" | build: exit 0 | lint passed (lint ≠ compiler) |
| "Bug fixed" | original symptom re-tested: gone | code changed, assumed fixed |
| "Builder done" | diff shows the changes | the agent said "success" |
| "Spec met" | line-by-line acceptance checklist | "verify passed, close enough" |

## Red flags — STOP, you're about to claim without evidence

- "should work now", "probably", "seems to", "looks correct"
- "Great!" / "Perfect!" / "Done!" before running anything
- Trusting an agent's success report without checking the diff
- "Just this once" / "I'm confident" / "I'm tired, ship it"
- Any wording that implies success when no verify has run this message

## Rationalization table

| Excuse | Reality |
|--------|---------|
| "Should work now" | Run the verify. |
| "I'm confident" | Confidence ≠ evidence. |
| "Linter passed" | Linter ≠ compiler. Run the build/typecheck too. |
| "The agent said success" | Verify independently against the diff. |
| "Partial check is enough" | Partial proves nothing about the whole. |
| "Different words, so the rule doesn't apply" | Spirit over letter. Any success implication counts. |

## NO-COMMIT note

Verification never includes committing. Even a fully verified change is not committed / pushed /
PR'd automatically — that stays the user's call.
