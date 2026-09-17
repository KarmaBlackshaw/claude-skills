# Inspection Report Template

Use this exact structure for the step 1 output. Keep it scannable — the user will read it to spot problems before you proceed.

## Format

```markdown
## Step 1: Inspection

**Frames in file:** [all top-level frames]
**In scope:** [chosen frame(s)] — widths [e.g. 375, 1440] (these are the step-5 match targets)
**Node ID:** [id]

### 1. Component hierarchy

- Frame: RootContainer (auto-layout: vertical)
  - Component: Header
    - Frame: LogoContainer
      - Vector: logo
    - Text: "Dashboard"
  - Instance: Button (main-component: PrimaryButton)
    - Text: "Save"

### 2. Auto-layout

| Node | Direction | Gap | Padding (t/r/b/l) | Primary align | Counter align |
|------|-----------|-----|-------------------|---------------|---------------|
| RootContainer | column | 24 | 32/32/32/32 | start | stretch |
| Header | row | 12 | 0/0/0/0 | space-between | center |

### 3. Colors

| Node | Property | Value | Status |
|------|----------|-------|--------|
| RootContainer | fill | `surface/default` | ✅ bound |
| Header | fill | `#F3F4F6` | ⚠️ UNBOUND |
| Button | fill | `primary/500` | ✅ bound |

**Unbound colors: 1** — will propose tokens in step 2.

### 4. Text styles

| Node | Content | Style | Status |
|------|---------|-------|--------|
| "Dashboard" | heading | `heading/lg` | ✅ bound |
| "Save" | button label | — (Inter 14/20 medium) | ⚠️ UNBOUND |

**Unbound text styles: 1** — will propose tokens in step 2.

### 5. Spacing values used

| Value | Where | Multiple of 4? |
|-------|-------|----------------|
| 32px | RootContainer padding | ✅ |
| 24px | RootContainer gap | ✅ |
| 12px | Header gap | ✅ |
| 15px | Button padding | ❌ flagged |

**Off-grid spacing: 1 value** — will flag in mapping.

### 6. Layout sizing

| Node | Width mode | Height mode | Fixed dims | Notes |
|------|-----------|-------------|-----------|-------|
| RootContainer | fill | hug | — | **full-bleed** (fills viewport, no max-width) |
| Header | fill | hug | — | |
| Table col: Name | fixed | — | 240px | |
| Table col: Status | fixed | — | 120px | |

**Container: full-bleed** — do NOT wrap in a centered `max-w-*` at build time. Width modes and fixed dims above are measured from Figma, never eyeballed.

### 7. Assets to export

| Node | Type | Export as | Node ID |
|------|------|-----------|---------|
| logo | Vector | SVG | 12:34 |
| hero-photo | Image fill | PNG @2x | 12:40 |

**Assets: 2** — exported via `download_assets` in step 4, not rebuilt or placeholdered.

### 8. Match-spec (machine-readable)

The step-5 verifier asserts rendered computed styles against this, field by field. One object per key node; include only fields Figma specifies. Numbers come from `get_design_context` / `get_variable_defs`, never the screenshot.

```json
[
  {
    "node": "RootContainer",
    "nodeId": "12:2",
    "expected": {
      "layout": "full-bleed",
      "maxWidthPx": null,
      "paddingPx": [32, 32, 32, 32],
      "gapPx": 24,
      "color": "surface/default"
    }
  },
  { "node": "Table col: Name",   "nodeId": "12:8", "expected": { "widthPx": 240 } },
  { "node": "Table col: Status", "nodeId": "12:9", "expected": { "widthPx": 120 } },
  {
    "node": "Header text \"Dashboard\"",
    "nodeId": "12:5",
    "expected": { "fontSizePx": 24, "lineHeightPx": 32, "fontWeight": 700, "color": "heading/lg" }
  }
]
```

**Tolerances the verifier applies:** spacing exact, sizing ±1px, color exact (both sides normalized to `rgb()`). Any field outside tolerance is an automatic HIGH/MEDIUM diff row — see step 5.

### Summary

- Nodes: 6 (1 Component, 1 Instance, 3 Frames, 2 Text, 1 Vector)
- Unbound colors: 1
- Unbound text styles: 1
- Off-grid spacing: 1
- Assets to export: 2
- Match-spec: 4 nodes captured (step-5 assertion source)
- Mapping recommendation: [clean / needs-tokens / needs-designer-fix]
```

## Recommendation thresholds

- **clean** — 0 unbound values, 0 off-grid spacing
- **needs-tokens** — some unbound values but under 30% of total
- **needs-designer-fix** — over 30% unbound; ask user whether to proceed

## What to do with Figma MCP responses

Sources per section, by what each tool actually returns:

- `get_metadata` → XML tree, one element per node with `id`, `name`, `x`, `y`, `width`, `height`, `hidden`. Section 1 (tree) + the box dims in section 6. A page-level node can return megabytes — call it on the in-scope frame, not the page.
- `get_design_context` → React + Tailwind **reference code**, one element per node with `data-node-id`. Its classes are Figma's computed values (the Dev Mode Inspect panel): `flex`/`flex-col` = direction, `gap-[Npx]` / `gap-[var(--spacing-10,10px)]` = item spacing, `px-[…]`/`py-[…]`/`p-[…]`/`pt-[…]` = padding, `items-*`/`justify-*` = alignment, `w-[Npx]`/`h-[Npx]`/`size-[Npx]` = fixed dims, `w-full`/`size-full`/`flex-[1_0_0]` = fill, no size class = hug, `rounded-[…]`, `border`, `bg-[var(--token,#hex)]`, `text-[length:var(--font/size/small,13px)]`, `leading-[20px]`, `font-['Poppins:Medium']`. Sections 2, 5, 6. A `var(--name, fallback)` names the bound variable; a bare `[#hex]`/`[Npx]` is unbound. Transcribe the number inside the brackets exactly — 35 stays 35.
- `get_variable_defs` → the bound-variable list (name → value). Sections 3, 4; authoritative for bound vs unbound.
- `download_assets` → section 7 exports.
- Section 8 (match-spec) reprojects the same numbers (sections 2/5/6) and colors/text (sections 3/4) into per-node JSON — no new Figma calls, just restructured for machine assertion.

If a framelink-style `get_figma_data` server is the one available, the same data sits in each node's `layout` block (`mode`, `dimensions`, `padding`, `gap`, `sizing`) and `fills`/`textStyle`.

- Prefer `get_variable_defs` to decide bound vs unbound: a color/text style is **bound** when it appears there as a named variable.
- Fallback from the reference code: `bg-[var(--backgrounds/bg-base,white)]` is bound to `backgrounds/bg-base`; `bg-[#efefef]` is unbound. A named text style appears in the response footer ("These styles are contained in the design: Subtitle/Bold: …"); a text node with only `font-[…]`/`text-[length:…]` classes has no named style.

Do not treat "color is defined in a local style but not published" as bound — for the purposes of this skill, only variables and published styles count as bound. Local styles still require a token proposal.
