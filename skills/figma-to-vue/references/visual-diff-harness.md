# Visual diff harness (side-by-side + pixel gate)

Deterministic glue for step 5. Every match iteration produces a **side-by-side triptych** (`target | actual | diff`) the agent views, plus a **mismatch ratio** that is a hard gate. Don't re-derive this per run — call the script below.

## Inputs
- `target.png` — Figma `get_screenshot` of the node (component in Phase A, page in Phase B).
- `actual.png` — Playwright element/page screenshot, captured at the **same pixel dimensions** as the target (set viewport to the Figma frame width and `deviceScaleFactor` to the Figma export scale, usually 2). Same width AND height, or the harness reports a size mismatch — which is itself a HIGH diff (wrong viewport/scale/layout box), fix that before anything else.

## Script

`references/visual-diff.mjs`:

```js
// usage: node visual-diff.mjs <target.png> <actual.png> <outDir> [sensitivity] [closeRatio]
// sensitivity: pixelmatch per-pixel color threshold, 0..1 (default 0.1 — higher = more tolerant of AA)
// closeRatio : max fraction of differing pixels to count as "pixel-close" (default 0.005 = 0.5%)
import { readFileSync, writeFileSync } from 'node:fs';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

const [, , targetPath, actualPath, outDir = '.', sens = '0.1', closeRatio = '0.005'] = process.argv;
const t = PNG.sync.read(readFileSync(targetPath));
const a = PNG.sync.read(readFileSync(actualPath));

if (t.width !== a.width || t.height !== a.height) {
  console.log(JSON.stringify({ sizeMismatch: true, target: [t.width, t.height], actual: [a.width, a.height] }));
  process.exit(2); // wrong size — HIGH diff. Fix viewport/scale/layout box, then re-run.
}

const { width, height } = t;
const diff = new PNG({ width, height });
const mismatched = pixelmatch(t.data, a.data, diff.data, width, height, { threshold: Number(sens) });
const ratio = mismatched / (width * height);

// triptych: target | actual | diff (8px gutters)
const gap = 8;
const sbs = new PNG({ width: width * 3 + gap * 2, height, fill: true });
const blit = (src, dx) => {
  for (let y = 0; y < height; y++)
    for (let x = 0; x < width; x++) {
      const s = (y * width + x) << 2;
      const d = (y * sbs.width + (x + dx)) << 2;
      sbs.data[d] = src.data[s]; sbs.data[d + 1] = src.data[s + 1];
      sbs.data[d + 2] = src.data[s + 2]; sbs.data[d + 3] = src.data[s + 3];
    }
};
blit(t, 0); blit(a, width + gap); blit(diff, (width + gap) * 2);

writeFileSync(`${outDir}/diff.png`, PNG.sync.write(diff));
writeFileSync(`${outDir}/side-by-side.png`, PNG.sync.write(sbs));
console.log(JSON.stringify({
  mismatched, total: width * height, ratio: +ratio.toFixed(5),
  pixelClose: ratio <= Number(closeRatio),
}));
```

Deps: `pixelmatch` + `pngjs` (both tiny). ESM resolves them from the **script file's own directory upward**, so run it from a location where `node_modules` is reachable — simplest is to copy `visual-diff.mjs` into the Vue project root (its `node_modules` almost always already has `pngjs`; add `pixelmatch` if not) and run `node visual-diff.mjs …` from there. If the deps aren't present, install them at the project root first (`npm i -D pixelmatch pngjs`) — `npx --package` does **not** expose modules to a script referenced by an outside path.

## How the agent uses it each iteration

1. Capture `target.png` (Figma) and `actual.png` (Playwright) at matched dimensions.
2. Run the script. It writes `side-by-side.png` + `diff.png` and prints JSON.
3. **View `side-by-side.png`** (Read the PNG) — the diff panel's red pixels point straight at what's off. This is the "side by side" look: design, render, and delta in one frame. Use it to seed table rows the computed-style check can't catch (missing element, wrong icon, wrong image, gradient/shadow drift).
4. Gate on `ratio`:
   - `pixelClose: true` (ratio ≤ closeRatio) **and** the measured table has zero H/M rows → `✓ matched`.
   - Otherwise → `⚠ not matched`; fix using Figma / step-2 mapping values only (never an arbitrary class to force pixels down), re-screenshot, re-run.

## Threshold notes
- Antialiasing and font hinting make ratio `0` unattainable — `0.005` (0.5%) is "pixel-close" for real text. Tighten toward `0.001` for flat-color/icon components, loosen only for a **named** false-diff source (font not loaded locally, live vs placeholder text) — never for a layout/size/color diff.
- `ratio` never overrides the measured table: a high pixel ratio from swapped placeholder text is a false diff, while a *low* ratio never excuses a wrong token. Both gates must pass.
- No-progress stop still applies: if `ratio` and the table rows are unchanged from the previous iteration, stop and report — don't spin.
