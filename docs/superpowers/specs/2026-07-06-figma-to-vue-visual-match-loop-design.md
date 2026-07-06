# figma-to-vue: Playwright Visual Match Loop

**Date:** 2026-07-06
**Status:** Approved (design)
**Scope:** Extend the existing `figma-to-vue` skill. No new skill.

## Problem

The skill's current **Verify** step (SKILL.md:122–130) re-queries Figma *metadata* and compares data (structure, spacing, colors, typography). It never looks at the actual rendered page. A component can pass metadata verification and still render wrong — wrong flex wrapping, overflow, font fallback, z-index, hover state. There is no feedback loop from real pixels back into the code.

## Goal

Replace metadata Verify with a **rendered-image match loop**: screenshot the running Vue page with Playwright, compare it to the Figma design image, fix the code, repeat until they match — per page.

## Decisions (locked)

| Question | Decision |
|---|---|
| Match test | Agent eyeballs both screenshots (Figma image vs Playwright shot). No pixel-diff dependency. |
| Loop cap | 10 iterations per page, then stop and report remaining diffs. |
| Playwright MCP | Documented prerequisite — skill checks the tool list, tells the user to install if absent. No config write. |
| Page→frame pairing | Ask the user for base URL + route per built view. No router auto-parsing. |
| Skill sync | Edit the repo copy only. Flag that `sync.sh` must run to propagate to `~/.claude/skills`. Do not run it. |

## Half the work is free

- Figma MCP `get_screenshot` already yields the **target** image for a node.
- Playwright MCP supplies the **actual** image + navigation.
  No image-generation code to write — both sides come from MCP tools.

## Changes to SKILL.md

### 1. Prerequisites (SKILL.md:16–22)

Add two checks, mirroring the existing Figma-MCP check:

- **Playwright MCP available.** Check the tool list for a Playwright browser tool. If absent, stop and tell the user to install it (e.g. add `@playwright/mcp` to the MCP config) and restart. Do not fall back to asking for manual screenshots.
- **Running dev server.** Before the loop, ask the user once for the base dev URL and the route for each built view. Do not infer routes from the router.

### 2. Replace "Verify" with "Step 5: Visual match loop"

Per built page, in order:

1. **Target** — Figma `get_screenshot` of the source node.
2. **Actual** — Playwright: navigate to the page URL, set viewport width = Figma frame width (apply retina scale), screenshot the view.
3. **Compare (eyeball)** — produce a diff list ranked by visual impact: spacing, color, font size/weight, alignment, border radius, shadow, missing/extra nodes.
4. **No meaningful diff** → mark `✓ matched`, move to next page.
5. **Else** → fix the `.vue`/Tailwind, re-run lint + typecheck (reuse Step 4's checks), re-screenshot, re-compare.
6. **Cap 10 iterations/page.** Still off at 10 → stop that page, report remaining diffs + probable cause.

### 3. Guard rails (the part that keeps a naive loop from rotting the codebase)

- **No arbitrary Tailwind values to force a match.** `p-[17px]`, `bg-[#hex]`, `text-[15px]` are forbidden even mid-loop — this is the skill's core rule. If closing a diff requires an untokenized value, flag it as a blocker and stop chasing it; do not emit the arbitrary class.
- **No-progress detection.** If an iteration's diff list equals the previous iteration's, stop early before the cap and report. Do not spend the remaining rounds spinning on an unfixable diff.
- **Named false-diff sources — report, never loop on:** font not loaded in the local dev env, real vs Figma placeholder text, dynamic/live data, animation mid-frame. These are environment mismatches, not code bugs.

### 4. Output format

Per-page report line: `✓ matched (N iters)` or `⚠ remaining diffs after 10` followed by the diff list and any token/font blockers. Never silently fix a discrepancy that stems from the design being wrong — report and let the user decide (carry over the existing Verify rule).

## Non-goals (YAGNI)

- No pixel-diff library (pixelmatch/odiff), no numeric threshold, no baseline-image storage.
- No CI integration / headless regression suite.
- No router introspection.
- No auto-run of `sync.sh`.

## Follow-ups

- After SKILL.md edit: run `sync.sh` to propagate to `~/.claude/skills/figma-to-vue`.
- Consider a `references/visual-loop.md` only if Step 5 prose outgrows the main file (defer until it does).

<!-- session: ba530bf8-4761-4d15-bdf6-e1a4cbde8a66 -->
