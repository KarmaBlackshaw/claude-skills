---
name: figma-to-vue
description: Convert Figma designs into Vue (2 or 3) + Tailwind CSS components with structural accuracy and design system fidelity. Use this skill whenever the user pastes a Figma URL, mentions "figma", asks to "build from figma", "implement this design", "match this mockup", or references a Figma frame, component, or design file — even if they don't explicitly ask for the skill. Also use when the user asks to inspect, audit, or map a Figma file to their Vue codebase, or asks how to match a Figma design in code. The skill auto-detects the project's Vue version (2.x, 2.7, or 3.x) and adapts conventions accordingly. It enforces a 5-step workflow (inspect → map → outline → build → visual-match) that prevents the common failure modes of guessing hex codes, rounding spacing, and misreading component hierarchy. The final step drives a Playwright screenshot loop that compares each built component and each rendered page against the Figma image and iterates until they match.
---

# Figma to Vue

A deterministic 5-step workflow for converting Figma designs into Vue 3 + Tailwind components without guessing.

## Why this workflow exists

The default failure mode when converting a Figma design to code is optimistic pattern-matching: look at the rendered frame, guess hex codes, round spacing to the nearest Tailwind default, infer component structure from visual grouping. Output looks close but drifts from the design system, uses arbitrary values (`bg-[#3B82F6]`, `p-[17px]`), and doesn't match the actual component hierarchy.

This skill replaces guessing with inspection. Each step produces a structured artifact the next step consumes. Skipping steps brings back the guessing. Do not skip steps even when the design looks simple — simple-looking designs are the ones where pattern-matching feels safe and fails hardest.

## Prerequisites

Before starting, verify:

1. **Figma MCP connector is available.** Confirm these tools are in the tool list (names may be prefixed, e.g. `mcp__figma__get_metadata`):

   | Tool | Use | Step |
   |------|-----|------|
   | `get_metadata` | cheap node tree / structure — call **first** for hierarchy and node IDs | 1 |
   | `get_design_context` | full node data (layout, spacing, fills, variants) — call **after** metadata narrows scope; expensive | 1, 3 |
   | `get_variable_defs` | bound variables/tokens (colors, text, spacing) — **the source for step 2 mapping**, not eyeballed hex | 1, 2 |
   | `get_screenshot` | rendered image of a node — the target for the step 5 visual match | 5 |
   | `download_assets` | export vectors as SVG / raster as PNG — icons and images | 1, 4 |
   | `get_code_connect_map` | Figma node → existing code component mapping, if the team maintains Code Connect | 3 |

   If the Figma tools are absent, stop and tell the user to connect the Figma MCP. Do not fall back to asking for pasted screenshots — that's a different workflow.

2. **The current project is a Vue 3 + Tailwind codebase.** Look for `tailwind.config.js`, `tailwind.config.ts`, or tailwind imports in CSS. If the project isn't Vue + Tailwind, ask the user to confirm before proceeding — the skill's output assumptions won't hold.

3. **Playwright MCP is available (required for the visual match loop).** Check for a Playwright browser tool in the tool list. Phase A of the loop runs interleaved into Step 4 (per component, right after each build); Phase B runs in Step 5. Steps 1–3 proceed without Playwright, and Step 4 can build while deferring Phase A to Step 5. If it's still absent when matching begins, tell the user to install it (add `@playwright/mcp` to the MCP config and restart) — do not fall back to asking the user to paste screenshots.

## The 5-step workflow

Run all five steps in order. **Pause for explicit user approval between step 3 (outline) and step 4 (build)** — structure mistakes are the most expensive to fix after code is written.

### Step 1: Inspect

Pull the selected Figma frame via the MCP and produce a structured report. Do not write code in this step.

**Call order (cheap → expensive):**
1. `get_metadata` on the selection → node tree and IDs. Build the hierarchy (section 1) from this without paying for full context.
2. **List every top-level frame** metadata returns. Figma files usually ship more than one — mobile + desktop, or multiple states. Report them and ask: *"Which frame(s) / breakpoints are in scope?"* Do not assume a single frame. The chosen frame widths become the step-5 match targets.
3. `get_design_context` on the in-scope node(s) → layout, spacing, fills, sizing (sections 2, 5, 6).
4. `get_variable_defs` on the in-scope node(s) → bound variables. This resolves colors and text styles (sections 3, 4) to real token names and **feeds step 2 directly** — never read hex off the render.

The report has eight sections (7 human-readable + 1 machine-readable):

1. **Component hierarchy** — indented tree of every node with its type (`Frame`, `Component`, `Instance`, `Text`, `Vector`, etc.) and parent-child relationship. Mark Figma `Component` and `Instance` nodes distinctly — these usually map to separate Vue SFCs.

2. **Auto-layout properties** — for each frame: direction (row/column), gap, padding (top/right/bottom/left separately), primary-axis alignment, counter-axis alignment.

3. **Colors** — every fill and stroke. Report as the bound variable name if present (e.g. `primary/500`), or raw hex if unbound. **Flag every unbound color as a problem** — unbound colors in Figma produce unbound code.

4. **Text styles** — every text node. Report as the bound style name if present (e.g. `body/md`), or raw properties (font-family, size, line-height, weight, letter-spacing) if unbound. **Flag every unbound text style as a problem.**

5. **Spacing values** — distinct padding and gap values across the frame. Flag any that aren't multiples of 4 (these usually indicate pixel-pushing rather than token use).

6. **Layout sizing** — for each frame and key node: the width/height sizing mode (`fill` / `hug` / `fixed`), any fixed dimensions where set, and whether the root is **full-bleed or a fixed-width/centered container**. This is the data that gets guessed most — column widths, grid track sizes, and container max-width. Capture the real numbers from Figma here so nobody invents them at build time. Never derive a width by eyeballing a screenshot.

7. **Assets to export** — every `Vector`, image fill, and icon node. Icons and raster images cannot be rebuilt from tokens; they must be exported. List each with its node ID and target format (`SVG` for vectors/icons, `PNG` for raster). These get pulled via `download_assets` in step 4 — capture their IDs now so nothing gets hand-waved into a `<!-- TODO icon -->` at build time.

8. **Match-spec (machine-readable)** — a JSON array, one object per key node (root, each column, header, each distinct component), capturing the measured numbers step 5 asserts against: `{ node, nodeId, expected: { widthPx, paddingPx, gapPx, fontSizePx, lineHeightPx, fontWeight, color, borderRadiusPx, layout, ... } }`. Include only fields Figma actually specifies; pull every number from `get_design_context` / `get_variable_defs`, never the screenshot. Step 5 resolves each entry to a rendered selector and asserts against it — **without this JSON, step 5 falls back to eyeballing, which is the exact failure this skill exists to prevent.** See the match-spec block in `references/inspection-template.md`.

See `references/inspection-template.md` for the exact output format.

If more than 30% of colors or text styles are unbound, pause and tell the user: "This Figma file has substantial unbound values. The output will propose many new tokens. Do you want to proceed, or have the designer bind variables first?"

### Step 2: Map to Tailwind tokens

**Start from `get_variable_defs`, not the render.** The step-1 variable dump is the left column of the mapping — every bound Figma variable is a value to match to a Tailwind token. Only values with no Figma variable get read from raw node data.

Discover the Tailwind config at runtime. Search in this order:

1. `./tailwind.config.js` or `./tailwind.config.ts` at the project root
2. One level into common monorepo paths: `apps/*/tailwind.config.*`, `packages/*/tailwind.config.*`
3. If still not found, ask the user for the path

Read the config and extract the `theme.extend` block (colors, spacing, fontSize, borderRadius, etc.).

Produce a mapping table with three columns: **Figma value** | **Tailwind class** | **Source**.

Source categories:

- **Token match** — an existing Tailwind token maps exactly. Example: Figma fill bound to `primary/500` where `theme.extend.colors.primary[500]` exists → `bg-primary-500`.
- **Near match** — an existing token is within 1 unit (1px for spacing, closest shade for colors). Example: Figma spacing `15px` → `p-4` (16px). **Flag these.** Let the user decide: use near-match or add a new token.
- **Proposed new token** — no existing match. Propose the exact addition to `tailwind.config.js`, including key name and value. Show the diff.

**Hard rule: never output arbitrary value classes (`bg-[#hex]`, `p-[17px]`, `text-[15px]`, etc.).** If a value doesn't have a token, propose one. Arbitrary values are how design systems rot — once they're in the codebase, they spread.

For any raw hex that needs a token proposal, use the **`tailwind-color-token` skill** — it converts a hex to a named token consistent with the existing scale. Don't re-derive color naming by hand.

See `references/token-mapping.md` for the decision table and examples.

### Step 3: Outline (STOP for user approval)

Before writing any code, produce a structural outline:

- **Files to create** — list each `.vue` SFC with its path. One file per Figma Component node, usually.
- **Per-file outline** — for each file:
  - Props (name, type, default)
  - Emits (name, payload type)
  - Slots (if any)
  - Top-level template structure (just the element tree, no classes yet)
  - Dependencies on other new components

  Design each component's API with the **`web-component-design` skill's** principles: semantic prop names with sensible defaults, variants as typed props (not boolean explosions), slots over props for content injection, compound components (provide/inject) when children share state. A Figma `Component` node is a reusable API, not a one-off page partial.
- **Existing components to reuse** — first call `get_code_connect_map` on the in-scope nodes: where the team maintains Code Connect, it maps Figma components straight to the code component that implements them — deterministic, no grep-and-hope. For nodes it doesn't cover, scan the project by name/shape. Don't rebuild a Button if `components/ui/Button.vue` already exists. List matches with their source (Code Connect vs manual scan).
- **Component variants** — for any Figma `Component` that belongs to a component **set** (has variants), pull the variant definitions via `get_design_context` on the set. Hover / disabled / active / size variants are *in the file* — enumerate them as real prop values; don't dump them into open questions as if unknown.
- **Open questions** — only genuinely absent info: states not drawn anywhere in Figma, loading/empty states, keyboard behavior, responsive rules between the frames captured in step 1.

**STOP HERE.** Output the outline and say: "Review the outline above. Reply with approval or changes before I generate code." Do not proceed to step 4 without an explicit "yes", "approved", "go", "build it", or equivalent. Ambiguous responses like "looks good but..." mean keep iterating on the outline.

### Step 4: Build

Only after step 3 is approved.

**First, detect the Vue version.** Read `references/vue-detection.md` and run the detection sequence. State the result before generating any code:

> Detected: Vue 3.5.x. Loading vue3-conventions.md.

Then load **only the matching conventions file**:

- Vue 3.x → `references/vue3-conventions.md`
- Vue 2.x (any) → `references/vue2-conventions.md`

Do not load both. The non-matching file is dead weight in context.

After loading, generate the Vue SFCs following the conventions from that file plus the Tailwind conventions below.

**Tailwind conventions:**
- Classes from the mapping table only
- No arbitrary values — if one is needed, stop and flag it rather than emitting it
- Group classes in a consistent order: layout → spacing → sizing → typography → color → effects → state modifiers
- For conditional classes, use an object literal with `:class` rather than string concatenation

**Auto-layout → flex translation:**
- Figma auto-layout direction `HORIZONTAL` → `flex flex-row`
- Figma `VERTICAL` → `flex flex-col`
- Figma `itemSpacing` → `gap-N` from the mapping
- Figma padding → `p-N` or `px-N py-N` or `pt-N pr-N pb-N pl-N` based on whether values are symmetric
- Figma alignment → `justify-*` (primary axis) + `items-*` (counter axis)

**Assets:** export the step-1 asset inventory via `download_assets` (SVG for icons/vectors, PNG for raster) into the project's assets dir, and reference the real files. Never leave an icon as a placeholder comment or approximate it with an emoji/box.

**Build by component, bottom-up.** Order the step-3 file list by dependency: leaf components first, composites next, the page/view last. Each Figma `Component` node becomes a self-contained reusable SFC with the API designed in step 3 (composition patterns per the **`web-component-design` skill**) — never page markup to be split up later.

**After writing each file:**
1. Run the project's linter (`npm run lint`, `pnpm lint`, or whatever the package.json defines)
2. Run a typecheck if TS (`vue-tsc --noEmit` or `npm run typecheck`)
3. If either fails, fix before moving to the next file
4. **Run this component's Phase A visual match (step 5) before building the next component** — build → match → next, so a drifted leaf never gets composed into parents. If the dev server or Playwright isn't up yet, defer its Phase A to step 5 and flag the deferral.
5. Report the final diff and any proposed `tailwind.config.js` additions separately — the user applies config changes themselves

### Step 5: Visual match loop

Only after the build step is complete and the files pass lint/typecheck.

**Requires the Playwright MCP** (see Prerequisites) and a **running dev server**. Ask the user once for the base dev URL and the route for each built view — e.g. `http://localhost:5173/checkout`. Do not infer routes from the router config.

> **The rule: no screen may be marked `✓ matched` without a written itemized diff table whose HIGH/MEDIUM rows are all resolved.** A visual glance, structural presence (correct component, correct column names), or "looks right" is explicitly not sufficient. The table is the gate.

**The loop runs in two phases: Phase A per component, then Phase B per page.** Phase A normally runs **interleaved with step 4** — each component is matched right after it's built (build → match → next). At step 5, run Phase A only for components whose match was deferred or is still unmatched, then run Phase B. Phase B starts only when every component is `✓ matched` or reported blocked — component drift caught in isolation never reaches the page compare.

#### Phase A: per-component loop

Iterate over **every SFC built in step 4** that maps to a Figma `Component` / `Instance` node (the step-1 hierarchy marks them; pair each file to its node ID from the step-3 outline).

1. **Target** — Figma `get_screenshot` of that Component node (the component alone, not the parent frame).
2. **Actual** — via Playwright on the live page where the component renders: set the viewport to the Figma frame width, locate the component's **root element** and screenshot just that element (element screenshot, not full page). Use a stable selector for the root; if none exists, add a `data-figma-node="<nodeId>"` attribute to the SFC root and select on that.
3. **Compare** — same measure-then-table gate as Phase B below (steps 3–5), asserting only against that component's match-spec entries. Same tolerances, same H/M verdict gate, same forbidden arbitrary values.
4. **Interactive states live here** — drive each Figma-drawn variant (hover, focus, disabled, selected …) on the isolated element and compare against the matching variant node, per Phase B step 6.
5. **No iteration cap.** Loop until the component's table has **zero H/M rows** — exact per the measured tolerances, not a pixel diff. The only exits besides `✓ matched (N iterations)` are a named blocker (missing token, font) or the no-progress stop below.

#### Phase B: per-page loop

Run this loop **per page**:

1. **Target** — Figma `get_screenshot` of the source node. This is the design you're matching against.
2. **Actual — match the container, not just the frame width.** Via Playwright: navigate to the page's URL, set the viewport width to the Figma frame's width (apply the device-scale/retina factor so the capture resolution matches the design), and screenshot the view. Also replicate the frame's **layout box**: if the Figma frame sits at `x=0` full-bleed, the render must be full-bleed too — do not wrap it in a centered `max-w-* mx-auto`. Reproduce the actual left/right insets from Figma, never an invented container width.
3. **Measure, then compare — programmatic assertion first, table second.** Before eyeballing anything, pull the rendered node's computed styles via Playwright (`getComputedStyle` on the matched selector: padding, gap, `font-size`, `line-height`, `font-weight`, `color`, `width`, `border-radius`) and assert each numerically against the step-1 **match-spec** JSON. Tolerances: spacing exact, sizing ±1px, color exact (convert both sides to `rgb()` and compare). Every field outside tolerance is an **automatic diff row — the eye gets no vote on numbers.** Then output the itemized table, one row per difference, seeded with every failed assertion plus the visual-only aspects a computed style can't catch (missing/extra element, wrong image, wrong icon):

   | # | Aspect | Figma | Render | Impact (H/M/L) |
   |---|--------|-------|--------|----------------|

   Walk *every* aspect below explicitly — an aspect you don't write a row for is one you didn't check, not one that passed. At minimum: **overall width (full-bleed vs centered)**, container max-width, **column count + each column width**, header text alignment, header fill color, **row count**, row/cell height, footers/toolbars, toggles/segmented controls, heading/subheading, page background, any missing or extra element — plus the usual spacing, typography, border radius, shadow.

   **Impact:** `H` = wrong layout / size / structure / color a user would see; `M` = off-by-a-token spacing, size, or weight; `L` = sub-pixel / antialias cosmetic. Pull every Figma number from `get_design_context` / `get_variable_defs` / `get_metadata` / the step-1 sizing report — never off the screenshot, never invented (`width: 200` pulled from thin air is banned).

   *Optional (L-rows only):* an automated pixel diff (`pixelmatch`, `odiff`) between the two screenshots catches sub-pixel cosmetic drift faster than eyeballing. It does **not** replace the table — H/M rows are judged by measured Figma values, not pixel deltas.
4. **Verdict — gated on the table.** `✓ matched` is allowed ONLY when the table has **zero HIGH and zero MEDIUM rows**. Any H or M row ⇒ verdict is `⚠ not matched`; fix and re-screenshot. A page with no written table cannot be marked matched at all. Reusing the correct component is **not** a match — "right mechanism" ≠ "matches the design".
5. **Otherwise (any H/M row)** → fix the `.vue`/Tailwind to close it, using values from Figma or the step-2 mapping only (never invented to "look about right"). If the page reuses a component, diff that component's *built-in* styling (header fill, alignment, footers, default column widths) against Figma too — differences are H/M rows, not "close enough". Re-run lint + typecheck, then re-screenshot and re-compare.
6. **Interactive states — verify every drawn variant, not just the resting state.** For each state the component set defines in Figma (hover, focus, active, disabled, selected — enumerated in the step-3 outline), drive it in Playwright (`page.hover`, force `:focus`, set the `disabled` prop / `aria-disabled`, etc.), `get_screenshot` the matching Figma variant node, and run the same measure-then-table compare (step 3) for that state. A resting-state match with a broken hover/disabled state is `⚠ not matched`. Skip only states Figma never drew — and states already `✓ matched` per component in Phase A (re-check only page-level states, e.g. a row hover that spans multiple components).
7. **No iteration cap.** Keep looping until the table has **zero H/M rows** — exact match means every measured assertion within tolerance, not a pixel-identical diff image. The only legitimate early exits are a named blocker (missing token, font) or the no-progress stop in the guard rails — report either with the remaining diffs and their probable cause.

**Guard rails — these keep the loop from rotting the codebase:**

- **Never emit an arbitrary Tailwind value to force a pixel match.** `p-[17px]`, `bg-[#hex]`, `text-[15px]` are forbidden mid-loop exactly as they are in the build step. If closing a diff requires a value with no token, flag it as a blocker and stop chasing that diff — do not hack in the arbitrary class.
- **No-progress detection.** If an iteration's diff list is the same as the previous iteration's, stop and report — with no iteration cap this is the backstop that keeps the loop from spinning forever on a diff it can't close.
- **Named false-diff sources — report, never loop on them:** a font not loaded in the local dev environment, real/live data vs Figma placeholder text, or a mid-animation frame. These are environment mismatches, not code bugs. **Layout, size, and color diffs are never "noise"** — do not wave them away as environment; they are always real H/M rows.
- **Fresh eyes are mandatory — the builder's own "matched" doesn't count.** The agent that wrote the code is biased toward declaring it done, especially under pressure to show progress. The step-3 compare MUST run as a **separate subagent that never saw the build** — hand it only the Figma match-spec (step 1), the target `get_screenshot`, and the page URL, and tell it to assume the render is wrong until the numbers prove otherwise. The builder does not mark its own work matched. Treat every diff the verifier returns as real until a measurement closes it. "Looks matched to me" is exactly the failure this loop exists to catch.

**Regression case this gate exists to prevent:** a full-bleed Figma table (frame at `x=0`) rendered as a centered `max-w-[1400px] mx-auto`, with guessed narrow column widths and 1 seeded row instead of 6 — all declared `✓ matched` with no diff table written. That verdict is now impossible: the missing table blocks the verdict outright, and full-bleed→centered, wrong column widths, and 6→1 row count are each HIGH rows that force `⚠ not matched`.

**Output** — per component (Phase A), then per page (Phase B): `✓ matched (N iterations)` or `⚠ blocked / no progress` followed by the diff list and any token/font blockers. As everywhere else in this skill: do not silently "fix" a discrepancy that stems from the design being wrong — report it and let the user decide whether the code or the design is off.

## When the user wants to skip steps

If the user explicitly says "just build it" or "skip the outline", comply — but warn once: "Skipping the outline step is the most common cause of structural mismatches. I'll proceed, but flagging this for the record." Do not warn repeatedly.

Do not skip step 1 (inspect) under any circumstances. Without inspection, everything downstream is guessing.

## Output format

Each step produces a clearly-labeled section in the response:

```
## Step 1: Inspection
[inspection report]

## Step 2: Token mapping
[mapping table + proposed config additions]

## Step 3: Outline
[file structure + per-file outline]

**STOP — approve before I build.**
```

Step 4 outputs the code files directly via the file-writing tools, with a summary of what was created. Step 5 outputs a per-component match report (Phase A), then a per-page match report (Phase B) — each `✓ matched (N iterations)` or `⚠ blocked / no progress` + blockers.

## Reference files

- `references/inspection-template.md` — exact format for the step 1 report
- `references/token-mapping.md` — decision rules and examples for step 2
- `references/vue-detection.md` — Vue version detection logic (load first in step 4)
- `references/vue3-conventions.md` — Vue 3 SFC patterns (load only if Vue 3 detected)
- `references/vue2-conventions.md` — Vue 2 / Vue 2.7 SFC patterns (load only if Vue 2 detected)

**Loading order in step 4:** `vue-detection.md` first, then *one* of `vue3-conventions.md` or `vue2-conventions.md` based on the detection result. Never both.
