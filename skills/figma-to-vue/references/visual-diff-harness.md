# Visual diff harness (side-by-side + pixel gate)

Deterministic glue for step 5. Every match iteration produces a **side-by-side triptych** (`target | actual | diff`) the qa subagent views, plus two hard gates: a **global mismatch ratio** (`pixelClose`) and a **largest-cluster** check (`localized`) that catches a small wrong element the ratio would hide. Don't re-derive this per run — call `references/visual-diff.mjs`.

## Inputs
- `target.png` — Figma `get_screenshot` of the node (component in Phase A, page in Phase B).
- `actual.png` — Playwright element/page screenshot, captured **deterministically** (fonts loaded, animations/caret off, exact copy seeded, dynamic regions masked — see SKILL.md gate step 2) at the **same pixel dimensions** as the target (viewport = Figma frame width, `deviceScaleFactor` = Figma export scale, usually 2). Same width AND height, or the harness reports a size mismatch — itself a HIGH diff (wrong viewport/scale/layout box), fix that before anything else.

Transparency is handled: the script flattens both images over identical white before comparing, so a transparent Figma export vs an opaque page background is not a spurious full-image diff.

## Script — `references/visual-diff.mjs`

The runnable source lives in the sibling `visual-diff.mjs` (not pasted here — a copy in the doc drifts from the code). Run it, don't re-derive it.

```
node visual-diff.mjs <target.png> <actual.png> <outDir> [sensitivity] [closeRatio] [localizedMinPx]
```

- `sensitivity` — pixelmatch per-pixel color threshold `0..1` (default `0.1`; higher = more AA-tolerant). Antialiased pixels are never counted as diffs (`includeAA: false`).
- `closeRatio` — max fraction of differing pixels still counted "pixel-close" (default `0.005` = 0.5%).
- `localizedMinPx` — min area (device px) of one contiguous diff cluster to flag as a concentrated defect (default `400` ≈ 10×10 CSS px @2x).

**Writes** `diff.png` + `side-by-side.png` to `<outDir>`. **Prints JSON:**

```
{ mismatched, total, ratio, pixelClose,          // global drift gate
  maxCluster: { area, box: [x,y,w,h] }, localized // concentrated-defect gate
}
```

On a size mismatch it prints `{ sizeMismatch: true, target, actual }` and exits `2`.

Deps: `pixelmatch` + `pngjs` (both tiny). ESM resolves them from the **script file's own directory upward**, so run it where `node_modules` is reachable — simplest is to copy `visual-diff.mjs` into the Vue project root (its `node_modules` almost always already has `pngjs`; add `pixelmatch` if not) and run `node visual-diff.mjs …` from there. If deps aren't present, install at the project root first (`npm i -D pixelmatch pngjs`) — `npx --package` does **not** expose modules to a script referenced by an outside path.

## How the agent uses it each iteration

1. Capture `target.png` (Figma) and `actual.png` (Playwright) at matched dimensions.
2. Run the script. It writes `side-by-side.png` + `diff.png` and prints JSON.
3. **View `side-by-side.png`** (Read the PNG) — the diff panel's red pixels point straight at what's off. This is the "side by side" look: design, render, and delta in one frame. Use it to seed table rows the computed-style check can't catch (missing element, wrong icon, wrong image, gradient/shadow drift). If `localized: true`, look at `maxCluster.box` first — that's where the concentrated defect is.
4. Gate on both pixel signals:
   - `✓ matched` only if `pixelClose: true` (ratio ≤ closeRatio) **and** `localized: false` **and** the measured table has zero H/M rows.
   - Any of not-pixel-close, `localized: true`, or an H/M row → `⚠ not matched`; qa returns findings, develop fixes using Figma / step-2 mapping values only (never an arbitrary class to force pixels down), then a fresh qa re-screenshots and re-runs.

## Threshold notes
- Antialiasing and font hinting make ratio `0` unattainable — `0.005` (0.5%) is "pixel-close" for real text. Tighten toward `0.001` for flat-color/icon components. Don't loosen `closeRatio` to hide a diff: false-diff sources (font, animation, placeholder copy, dynamic data) are removed at capture (gate step 2), not tolerated by a fatter threshold — and a layout/size/color diff is never loosened away.
- **Global vs local, both required.** `pixelClose` (global ratio) misses a small wrong element — a swapped 24px icon is ~0.1% of a page. `localized` (largest contiguous cluster ≥ `localizedMinPx`) catches exactly that. A pass needs `pixelClose: true` AND `localized: false`. Raise `localizedMinPx` only if AA/subpixel specks trip it on a genuinely-matched target; never to wave through a real element.
- `ratio` never overrides the measured table: a high ratio from a real layout shift is a true diff; a *low* ratio never excuses a wrong token. Table + both pixel gates must all pass.
- No-progress stop still applies: if `ratio`, `maxCluster`, and the table rows are all unchanged from the previous iteration, stop and report — don't spin.
