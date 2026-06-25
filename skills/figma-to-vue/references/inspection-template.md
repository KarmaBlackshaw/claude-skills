# Inspection Report Template

Use this exact structure for the step 1 output. Keep it scannable — the user will read it to spot problems before you proceed.

## Format

```markdown
## Step 1: Inspection

**Frame:** [Figma frame name]
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

### Summary

- Nodes: 6 (1 Component, 1 Instance, 3 Frames, 2 Text, 1 Vector)
- Unbound colors: 1
- Unbound text styles: 1
- Off-grid spacing: 1
- Mapping recommendation: [clean / needs-tokens / needs-designer-fix]
```

## Recommendation thresholds

- **clean** — 0 unbound values, 0 off-grid spacing
- **needs-tokens** — some unbound values but under 30% of total
- **needs-designer-fix** — over 30% unbound; ask user whether to proceed

## What to do with Figma MCP responses

The Figma MCP typically returns node data with fields like `fills`, `strokes`, `layoutMode`, `itemSpacing`, `paddingTop/Right/Bottom/Left`, `boundVariables`, and `styles`.

- A color is **bound** when `boundVariables.fills[0]` exists and resolves to a variable name.
- A text style is **bound** when `styles.text` is set (Figma text style ID) — resolve it to the style name.
- If the MCP returns raw hex in `fills[0].color` without a `boundVariables` entry, it's unbound.

Do not treat "color is defined in a local style but not published" as bound — for the purposes of this skill, only variables and published styles count as bound. Local styles still require a token proposal.
