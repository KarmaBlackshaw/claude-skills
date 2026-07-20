---
name: figma-to-vue
description: Convert Figma designs into Vue (2 or 3) + Tailwind components with structural accuracy and design-system fidelity. Use whenever the user pastes a Figma URL, mentions "figma", or asks to "build from figma", "implement this design", "match this mockup", or inspect/audit/map a Figma file to their Vue codebase — even if they don't name the skill. Auto-detects the project's Vue version (2.x, 2.7, 3.x) and adapts conventions. Enforces a 5-step workflow (inspect → map → outline → build → visual-match) that replaces guessing with inspection, then drives a Playwright + pixel-diff loop that renders each component and page beside its Figma image and iterates until pixel-close.
---

# Figma to Vue

Deterministic 5-step workflow: **inspect → map → outline → build → visual-match**. Each step produces an artifact the next consumes.

The default failure mode is optimistic pattern-matching — eyeball the frame, guess hex, round spacing to the nearest Tailwind default, infer structure from visual grouping. It looks close but drifts from the design system and the real component hierarchy. Simple-looking designs fail hardest, because guessing feels safe. This skill replaces guessing with inspection.

## Core rules (every step)

1. **Inspect, never guess.** Every number — color, spacing, size, width — comes from `get_variable_defs` / `get_design_context` / `get_metadata`. Never read a value off a screenshot; never invent one to "look about right".
2. **No arbitrary Tailwind values, ever.** `bg-[#hex]`, `p-[17px]`, `text-[15px]`, `w-[342px]`, `rounded-[7px]` are banned in every step. No token for a value? Propose one (use the `tailwind-color-token` skill for hex). Arbitrary values are how design systems rot.
3. **Run all 5 steps in order. Never skip step 1.** Pause for explicit user approval after step 3, before any code.
4. **Report design bugs, don't silently fix them.** A discrepancy that stems from the design being wrong is reported — the user decides code vs design.

## Prerequisites

| Need | Check | If missing |
|------|-------|-----------|
| Figma MCP | `get_metadata`, `get_design_context`, `get_variable_defs`, `get_screenshot`, `download_assets`, `get_code_connect_map` in tool list (may be prefixed) | Stop, tell user to connect Figma MCP. Do **not** fall back to pasted screenshots. |
| Vue + Tailwind project | `tailwind.config.{js,ts}` or tailwind CSS imports present | Ask user to confirm before proceeding. |
| Playwright MCP | a Playwright browser tool in the list | Tell user to add `@playwright/mcp` and restart. Do **not** fall back to pasted screenshots. |
| Pixel-diff harness | Node (present in any Vue project) + `references/visual-diff.mjs` | Copy `visual-diff.mjs` to project root, `npm i -D pixelmatch pngjs`. See `references/visual-diff-harness.md`. |

Tool call order is cheap → expensive: `get_metadata` (structure/IDs) → `get_design_context` (layout/fills/variants) → `get_variable_defs` (bound tokens) → `get_screenshot` (match target) → `download_assets` (icons/images).

## Step 1: Inspect

No code this step. Call order:

1. `get_metadata` on the selection → node tree + IDs; build the hierarchy from this without paying for full context.
2. **List every top-level frame** it returns (files usually ship several — mobile+desktop, multiple states). Ask *"Which frame(s) / breakpoints are in scope?"* — never assume one. Chosen frame widths become the step-5 match targets.
3. `get_design_context` on in-scope node(s) → layout, spacing, fills, sizing.
4. `get_variable_defs` on in-scope node(s) → bound variables. This feeds step 2 directly.

Produce the 8-section report (exact format in `references/inspection-template.md`):

1. **Component hierarchy** — indented tree, each node's type; mark `Component`/`Instance` distinctly (they map to separate SFCs).
2. **Auto-layout** — per frame: direction, gap, padding (T/R/B/L separately), primary- and counter-axis alignment.
3. **Colors** — every fill/stroke as bound variable name, or raw hex. **Flag every unbound color.**
4. **Text styles** — every text node as bound style name, or raw props. **Flag every unbound style.**
5. **Spacing** — distinct padding/gap values; flag any not a multiple of 4.
6. **Layout sizing** — per frame/key node: `fill`/`hug`/`fixed`, fixed dims, and whether the root is **full-bleed or fixed-width/centered**. This is the most-guessed data — capture real numbers so nobody invents column/container widths at build time.
7. **Assets to export** — every `Vector`, image fill, icon with node ID + format (`SVG` vectors/icons, `PNG` raster). Pulled via `download_assets` in step 4 — capture IDs now so nothing becomes a `<!-- TODO icon -->`.
8. **Match-spec (JSON)** — one object per key node: `{ node, nodeId, expected: { widthPx, paddingPx, gapPx, fontSizePx, lineHeightPx, fontWeight, color, borderRadiusPx, layout, … } }`. Only fields Figma specifies. **Step 5 asserts against this; without it, step 5 falls back to eyeballing — the exact failure this skill prevents.**

If >30% of colors or text styles are unbound, pause: *"This file has substantial unbound values; output will propose many new tokens. Proceed, or have the designer bind variables first?"*

## Step 2: Map to Tailwind tokens

Start from the `get_variable_defs` dump (left column), not the render. Discover the config: `./tailwind.config.{js,ts}` → `apps/*` / `packages/*` for monorepos → ask user. Read `theme.extend`.

Mapping table — **Figma value | Tailwind class | Source**:

- **Token match** — existing token maps exactly (`primary/500` → `bg-primary-500`).
- **Near match** — existing token within 1 unit (1px / closest shade). **Flag it** — user picks near-match vs new token.
- **Proposed new token** — no match; propose the exact `tailwind.config` addition (key + value) as a diff.

Decision table and examples: `references/token-mapping.md`. (Core rule 2 applies — no arbitrary values.)

## Step 3: Outline — STOP for approval

Before any code, output a structural outline:

- **Files to create** — each `.vue` SFC + path (one per Figma `Component`, usually).
- **Per-file** — props (name/type/default), emits (name/payload), slots, top-level template tree (elements, no classes yet), deps on other new components. Design each API with the **`web-component-design` skill** — semantic props with defaults, variants as typed props (not boolean explosions), slots over props for content, provide/inject for shared child state. A Figma `Component` is a reusable API, not a page partial.
- **Reuse** — call `get_code_connect_map` first (deterministic Figma→code mapping where the team maintains it); scan by name/shape for the rest. Don't rebuild an existing `Button`. List matches + source.
- **Variants** — for any `Component` in a set, pull variant defs via `get_design_context` and enumerate them as real prop values. They're in the file; don't dump them into open questions.
- **Open questions** — only genuinely absent info (undrawn states, loading/empty, keyboard behavior, responsive rules between captured frames).

**STOP.** Say: *"Review the outline. Reply with approval or changes before I generate code."* Proceed only on an explicit "yes / approved / go / build it". "Looks good but…" means keep iterating.

## Step 4: Build

Only after step 3 is approved.

**Detect the Vue version first** (`references/vue-detection.md`), state it, then load **only** the matching conventions file — never both:

> Detected: Vue 3.5.x. Loading vue3-conventions.md.

- Vue 3.x → `references/vue3-conventions.md`
- Vue 2.x → `references/vue2-conventions.md`

**Tailwind:** classes from the step-2 mapping only; group layout → spacing → sizing → typography → color → effects → state; use `:class` object literals for conditionals.

**Auto-layout → flex:** `HORIZONTAL` → `flex flex-row`, `VERTICAL` → `flex flex-col`, `itemSpacing` → `gap-N`, padding → `p/px/py/pt…-N` (symmetric-aware), alignment → `justify-*` (primary) + `items-*` (counter).

**Assets:** export the step-1 inventory via `download_assets` into the assets dir; reference real files. Never a placeholder comment, emoji, or box. **Never substitute a visually-similar library icon** (lucide/heroicons/etc.) by eye — a lookalike is not the icon. Use a library icon only when step-3 reuse mapping explicitly maps that node to it; otherwise the exported SVG from the exact node ID is the icon.

**Build bottom-up** — leaves first, composites next, page last. Each `Component` node becomes a self-contained SFC with its step-3 API, never page markup to split later.

**After each file:** (1) lint, (2) typecheck if TS, (3) fix failures before the next file, (4) run its **Phase A visual match** (step 5) before building the next — build → match → next, so a drifted leaf never gets composed. If the dev server/Playwright isn't up, defer Phase A to step 5 and flag it. (5) Report the diff + any `tailwind.config` additions separately (user applies config changes).

## Step 5: Visual match loop

Only after build passes lint/typecheck. Requires Playwright + a **running dev server**. Ask the user once for the base URL + route per view (`http://localhost:5173/checkout`) — never infer routes from the router.

**The two-gate rule.** No screen is `✓ matched` until BOTH pass: (1) an itemized diff table with **zero HIGH/MEDIUM rows**, and (2) the pixel-diff ratio is **`pixelClose: true`**. A visual glance, "looks right", or correct-component/correct-structure is not sufficient. The table catches wrong tokens/structure the pixels would let slide; the ratio catches visual drift no measured field covers.

**Two phases:** Phase A per component (normally interleaved with step 4), then Phase B per page. Phase B starts only when every component is `✓ matched` or reported blocked.

### The gate (run this on every target — component in A, page in B)

1. **Target** — `get_screenshot` of the node.
2. **Actual** — via Playwright: set viewport to the Figma frame width and `deviceScaleFactor` to the export scale (usually 2) so target/actual share pixel dimensions. Screenshot the matched element (Phase A: the component's root, not the parent; Phase B: the page). Use a stable selector; if none, add `data-figma-node="<nodeId>"` to the SFC root and select on it.
3. **Measure, then table — numbers first, eye second.** Pull computed styles (`getComputedStyle`: padding, gap, `font-size`, `line-height`, `font-weight`, `color`, `width`, `border-radius`) and assert each against the step-1 match-spec. Tolerances: **spacing exact, sizing ±1px, color exact** (compare as `rgb()`). Every out-of-tolerance field is an **automatic diff row — the eye gets no vote on numbers.** Then write the table, seeded with failed assertions + visual-only aspects (missing/extra element, wrong image/icon):

   | # | Aspect | Figma | Render | Impact (H/M/L) |
   |---|--------|-------|--------|----------------|

   Walk *every* aspect explicitly — one you don't write a row for is one you didn't check: overall width (full-bleed vs centered), container max-width, column count + each width, row count, row/cell height, header alignment + fill, footers/toolbars, toggles, headings, page background, plus spacing, typography, radius, shadow. **H** = wrong layout/size/structure/color a user sees; **M** = off-by-a-token spacing/size/weight; **L** = sub-pixel/AA.
4. **Side-by-side pixel diff (required).** Run `references/visual-diff.mjs target.png actual.png <outDir>` → writes `side-by-side.png` (`target | actual | diff`) + prints `{ ratio, pixelClose }`. **View `side-by-side.png`** — the red panel points at what's off; seed a row for every visual-only diff it exposes. A `sizeMismatch` = wrong viewport/scale, fix that first.
5. **Verdict.** `✓ matched` only if **zero H/M rows AND `pixelClose`**. Any H/M row or not-pixel-close ⇒ `⚠ not matched`: fix the `.vue`/Tailwind using Figma/mapping values only, re-lint + re-typecheck, re-screenshot. No written table or no pixel run ⇒ can't be marked matched at all.
6. **Interactive states.** For each state the Figma set draws (hover/focus/active/disabled/selected, enumerated in step 3), drive it in Playwright, `get_screenshot` the matching variant node, and re-run this gate for that state. A resting match with a broken hover/disabled is `⚠ not matched`. Phase A owns per-component states; Phase B re-checks only page-level states (e.g. a row hover spanning components).
7. **No iteration cap.** Loop until zero H/M rows AND `pixelClose`. Only exits: a named blocker (missing token/font) or the no-progress stop.

### Guard rails

- **Icon/image diffs are asset diffs, never style diffs.** Don't eyeball paths, tweak size, or swap a similar icon — re-export via `download_assets` from the node ID in §7 and replace the file. Compare = rendered asset **is** that node's export + size/color match spec.
- **Never emit an arbitrary value to force a pixel match** (Core rule 2). If closing a diff needs a token-less value, flag it as a blocker and stop chasing that diff.
- **No-progress stop.** If both the diff list **and** the pixel ratio are unchanged from the prior iteration, stop and report. A dropping ratio is progress; a stuck one with an unchanged table is not.
- **Named false-diff sources — report, never loop:** font not loaded locally, live vs Figma placeholder data, mid-animation frame. These are environment mismatches. **Layout/size/color diffs are never "noise"** — always real H/M rows.
- **Fresh eyes are mandatory.** The compare runs as a **separate subagent that never saw the build** — hand it only the match-spec, the target `get_screenshot`, and the URL, and tell it to assume the render is wrong until numbers prove otherwise. The builder never marks its own work matched.

The gate exists to make this impossible: a full-bleed table (frame at `x=0`) rendered as centered `max-w-[1400px] mx-auto` with guessed column widths and 1 row instead of 6, declared `✓ matched` with no table. Now the missing table blocks the verdict and each of those is a HIGH row.

**Output** — per component (A), then per page (B): `✓ matched (N iterations)` or `⚠ blocked / no progress` + the diff list, last side-by-side image, and any token/font blockers.

## Skipping steps

"Just build it" / "skip the outline" → comply, but warn **once**: *"Skipping the outline is the most common cause of structural mismatches; flagging it for the record."* Don't repeat the warning. **Never skip step 1** — without inspection everything downstream is guessing.

## Output format

One labeled section per step:

```
## Step 1: Inspection      [report]
## Step 2: Token mapping   [table + proposed config additions]
## Step 3: Outline         [files + per-file outline]
**STOP — approve before I build.**
```

Step 4 writes the files + a summary. Step 5 outputs the Phase A (per-component) then Phase B (per-page) match reports.

## Reference files

- `references/inspection-template.md` — exact step-1 report format
- `references/token-mapping.md` — step-2 decision rules + examples
- `references/visual-diff-harness.md` — step-5 harness, thresholds, two-gate rule
- `references/vue-detection.md` — Vue version detection (load first in step 4)
- `references/vue3-conventions.md` — Vue 3 SFC patterns (load only if Vue 3)
- `references/vue2-conventions.md` — Vue 2 / 2.7 SFC patterns (load only if Vue 2)
