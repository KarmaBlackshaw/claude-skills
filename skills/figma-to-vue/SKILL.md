---
name: figma-to-vue
description: Convert Figma designs into Vue (2 or 3) + Tailwind CSS components with structural accuracy and design system fidelity. Use this skill whenever the user pastes a Figma URL, mentions "figma", asks to "build from figma", "implement this design", "match this mockup", or references a Figma frame, component, or design file — even if they don't explicitly ask for the skill. Also use when the user asks to inspect, audit, or map a Figma file to their Vue codebase, or asks how to match a Figma design in code. The skill auto-detects the project's Vue version (2.x, 2.7, or 3.x) and adapts conventions accordingly. It enforces a 4-step workflow (inspect → map → outline → build) that prevents the common failure modes of guessing hex codes, rounding spacing, and misreading component hierarchy.
---

# Figma to Vue

A deterministic 4-step workflow for converting Figma designs into Vue 3 + Tailwind components without guessing.

## Why this workflow exists

The default failure mode when converting a Figma design to code is optimistic pattern-matching: look at the rendered frame, guess hex codes, round spacing to the nearest Tailwind default, infer component structure from visual grouping. Output looks close but drifts from the design system, uses arbitrary values (`bg-[#3B82F6]`, `p-[17px]`), and doesn't match the actual component hierarchy.

This skill replaces guessing with inspection. Each step produces a structured artifact the next step consumes. Skipping steps brings back the guessing. Do not skip steps even when the design looks simple — simple-looking designs are the ones where pattern-matching feels safe and fails hardest.

## Prerequisites

Before starting, verify:

1. **Figma MCP connector is available.** Check for a Figma-related tool in the tool list. If not available, stop and tell the user to connect the Figma MCP before continuing. Do not proceed by asking the user to paste screenshots — that's a different workflow.

2. **The current project is a Vue 3 + Tailwind codebase.** Look for `tailwind.config.js`, `tailwind.config.ts`, or tailwind imports in CSS. If the project isn't Vue + Tailwind, ask the user to confirm before proceeding — the skill's output assumptions won't hold.

## The 4-step workflow

Run all four steps in order. **Pause for explicit user approval between step 3 (outline) and step 4 (build)** — structure mistakes are the most expensive to fix after code is written.

### Step 1: Inspect

Pull the selected Figma frame via the MCP and produce a structured report. Do not write code in this step.

The report has five sections:

1. **Component hierarchy** — indented tree of every node with its type (`Frame`, `Component`, `Instance`, `Text`, `Vector`, etc.) and parent-child relationship. Mark Figma `Component` and `Instance` nodes distinctly — these usually map to separate Vue SFCs.

2. **Auto-layout properties** — for each frame: direction (row/column), gap, padding (top/right/bottom/left separately), primary-axis alignment, counter-axis alignment.

3. **Colors** — every fill and stroke. Report as the bound variable name if present (e.g. `primary/500`), or raw hex if unbound. **Flag every unbound color as a problem** — unbound colors in Figma produce unbound code.

4. **Text styles** — every text node. Report as the bound style name if present (e.g. `body/md`), or raw properties (font-family, size, line-height, weight, letter-spacing) if unbound. **Flag every unbound text style as a problem.**

5. **Spacing values** — distinct padding and gap values across the frame. Flag any that aren't multiples of 4 (these usually indicate pixel-pushing rather than token use).

See `references/inspection-template.md` for the exact output format.

If more than 30% of colors or text styles are unbound, pause and tell the user: "This Figma file has substantial unbound values. The output will propose many new tokens. Do you want to proceed, or have the designer bind variables first?"

### Step 2: Map to Tailwind tokens

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
- **Existing components to reuse** — scan the project for components that already cover parts of the design. Don't rebuild a Button if `components/ui/Button.vue` already exists. List matches.
- **Open questions** — anything ambiguous from the Figma: interaction states (hover/active/disabled) that weren't shown, loading/empty states, responsive behavior, keyboard behavior.

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

**After writing each file:**
1. Run the project's linter (`npm run lint`, `pnpm lint`, or whatever the package.json defines)
2. Run a typecheck if TS (`vue-tsc --noEmit` or `npm run typecheck`)
3. If either fails, fix before moving to the next file
4. Report the final diff and any proposed `tailwind.config.js` additions separately — the user applies config changes themselves

### Verify

After all files are written, verify against Figma:

- For each generated component, re-query the Figma MCP for the source frame
- Compare: structure, spacing, colors, typography
- Produce a diff report: what matches, what differs, and why

Do not silently fix discrepancies. Report them and let the user decide whether the code or the design is wrong.

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

Step 4 outputs the code files directly via the file-writing tools, with a summary of what was created.

## Reference files

- `references/inspection-template.md` — exact format for the step 1 report
- `references/token-mapping.md` — decision rules and examples for step 2
- `references/vue-detection.md` — Vue version detection logic (load first in step 4)
- `references/vue3-conventions.md` — Vue 3 SFC patterns (load only if Vue 3 detected)
- `references/vue2-conventions.md` — Vue 2 / Vue 2.7 SFC patterns (load only if Vue 2 detected)

**Loading order in step 4:** `vue-detection.md` first, then *one* of `vue3-conventions.md` or `vue2-conventions.md` based on the detection result. Never both.
