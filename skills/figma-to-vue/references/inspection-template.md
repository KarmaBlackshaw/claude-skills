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

### Summary

- Nodes: 6 (1 Component, 1 Instance, 3 Frames, 2 Text, 1 Vector)
- Unbound colors: 1
- Unbound text styles: 1
- Off-grid spacing: 1
- Assets to export: 2
- Mapping recommendation: [clean / needs-tokens / needs-designer-fix]
```

## Recommendation thresholds

- **clean** — 0 unbound values, 0 off-grid spacing
- **needs-tokens** — some unbound values but under 30% of total
- **needs-designer-fix** — over 30% unbound; ask user whether to proceed

## What to do with Figma MCP responses

Sources per section: `get_metadata` → section 1 (tree). `get_design_context` → sections 2, 5, 6 (`fills`, `strokes`, `layoutMode`, `itemSpacing`, `paddingTop/Right/Bottom/Left`, `styles`, `layoutSizingHorizontal` / `layoutSizingVertical` = `FILL` / `HUG` / `FIXED`, `width` / `height`, `absoluteBoundingBox`). `get_variable_defs` → sections 3, 4 (the authoritative bound-variable list). `download_assets` → section 7 exports.

- Prefer `get_variable_defs` to decide bound vs unbound: a color/text style is **bound** when it appears there as a named variable.
- Fallback from node data: a color is bound when `boundVariables.fills[0]` resolves to a variable name; a text style is bound when `styles.text` is set — resolve it to the style name.
- Raw hex in `fills[0].color` with no matching variable is **unbound**.

Do not treat "color is defined in a local style but not published" as bound — for the purposes of this skill, only variables and published styles count as bound. Local styles still require a token proposal.
