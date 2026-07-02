# Systematic Debugging (self-contained)

Root-cause discipline ported into plan-and-build so it has **no dependency** on any external
plugin. Builders apply this inside their fix loop; the orchestrator applies it when routing QA
findings back.

**Core principle:** find the root cause BEFORE attempting a fix. Symptom patches waste time and
create new bugs.

## The Iron Law

```
NO FIX WITHOUT ROOT-CAUSE INVESTIGATION FIRST
```

Applies to any verify failure, unexpected behavior, or QA blocker — even when the fix "looks
obvious" and even under time pressure. Simple bugs have root causes too.

## The four phases (complete each before the next)

### 1. Investigate
- Read the error / stack trace / type error completely. It often names the fix. Note exact
  file:line.
- Reproduce reliably. If you can't, gather more data — don't guess.
- Check what changed (this run's diff, recent edits) that could cause it.
- Multi-layer symptom? Add temporary logging at each boundary to see WHERE it breaks before
  deciding WHAT broke.

### 2. Pattern-match
- Find working code of the same kind in this project. What's different between it and the broken
  code? List every difference — don't dismiss any as "can't matter".

### 3. Hypothesize & test minimally
- State one hypothesis: "X is the root cause because Y."
- Make the SMALLEST change that tests it. One variable at a time — never bundle fixes.
- Worked? → step 4. Didn't? → new hypothesis. Don't stack fixes on top of each other.

### 4. Fix the cause, not the symptom
- Fix at the source, not where the symptom surfaced.
- ONE change. No "while I'm here" cleanup.
- Re-run the verify command and confirm the ORIGINAL symptom is gone (see `verifying.md`).

## Repro without test files (PB rule)

plan-and-build forbids committed test files. To prove a fix you may write a **throwaway**
reproduction (a scratch script, a temporary log line, a REPL snippet), but:

- put it outside the source tree or in the scratchpad, never as `*.test.*` / `*.spec.*` / under
  `__tests__/`;
- **delete it once the fix is confirmed** — it is never committed;
- the durable verification is still the project's build / lint / typecheck / manual run.

## The 3-fix ceiling

Count your fix attempts. **After 3 failed fixes, STOP** — do not attempt a 4th. Three failures
where each reveals a new problem elsewhere means the approach or the spec is wrong, not that you
need another patch. Halt and surface to the orchestrator: the spec may need the architect to
revise it. (This is the same ceiling as the builder self-fix loop and the QA↔fix loop.)

## Red flags — STOP and return to phase 1

- "Quick fix now, investigate later"
- "Just try changing X and see"
- "Change several things, then re-run"
- "I don't fully get it but this might work"
- Proposing a fix before reading the full error / tracing the data flow
- "One more attempt" after 2+ failures

## Rationalization table

| Excuse | Reality |
|--------|---------|
| "Bug is simple, skip the process" | Simple bugs have root causes; the process is fast for them. |
| "No time to investigate" | Systematic is FASTER than guess-and-check thrashing. |
| "I'll add a repro after it works" | An unverified fix doesn't stick. Prove it, then delete the repro. |
| "Fix several things at once" | Can't tell what worked; introduces new bugs. |
| "It's probably X" | "Probably" is a hypothesis, not a diagnosis. Test it minimally. |
