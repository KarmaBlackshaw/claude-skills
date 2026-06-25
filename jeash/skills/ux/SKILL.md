---
name: ux
description: Use when the user wants to assess or improve how an interface looks and feels — accessibility, interaction states, layout, spacing, typography, responsive behavior, design-system fidelity — or to map a Figma design. Triggers on "jeash:ux", "ux", "review the design", "is this accessible", "improve the layout/spacing", "check a11y".
---

# jeash:ux

Launcher for the **ux** lens — judges the interface as a user and a designer, against the project's design system. **Recommends and suggests concrete fixes; defers code edits to `jeash:frontend` unless asked to apply them.**

## What to do

**Dispatch the `ux` subagent** (bundled in this plugin at `agents/ux.md`) with the scope.

If the subagent can't be dispatched, follow `agents/ux.md` inline — evaluate accessibility (semantics, ARIA, focus order, contrast, keyboard, reduced-motion), interaction states (hover/focus/active/disabled/loading/empty/error), layout & rhythm, typography, and design-system fidelity (exact tokens, not approximations). Lean on `ui-ux-pro-max`, `frontend-design`, `tailwind-design-system`, `tailwind-color-token` (never raw hex), `figma-to-vue` (inspect → map → outline before judging a design).

## Output

Prioritized findings: location, the UX/design issue, the concrete fix (specific token / class / state), and why it matters to the user.
