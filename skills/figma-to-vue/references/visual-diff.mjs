// Side-by-side + pixel-diff harness for figma-to-vue step 5 (qa gate).
// usage: node visual-diff.mjs <target.png> <actual.png> <outDir> [sensitivity] [closeRatio] [localizedMinPx]
//   sensitivity   : pixelmatch per-pixel color threshold, 0..1 (default 0.1 — higher = more AA-tolerant)
//   closeRatio    : max fraction of differing pixels to count as "pixel-close" (default 0.005 = 0.5%)
//   localizedMinPx: min area of a single contiguous diff cluster to flag as a concentrated defect
//                   (default 400 device-px ≈ 10×10 CSS px @2x — catches a wrong icon/chip the global ratio hides)
// deps: pixelmatch + pngjs. Run from a dir whose node_modules has both — simplest is
// the Vue project root (copy this file there). If missing: npm i -D pixelmatch pngjs.
// Note: `npx --package` does NOT expose modules to an outside-path script — don't use it.
import { readFileSync, writeFileSync } from 'node:fs';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

const [, , targetPath, actualPath, outDir = '.', sens = '0.1', closeRatio = '0.005', localizedMinPx = '400'] = process.argv;
if (!targetPath || !actualPath) {
  console.error('usage: node visual-diff.mjs <target.png> <actual.png> <outDir> [sensitivity] [closeRatio] [localizedMinPx]');
  process.exit(1);
}

const t = PNG.sync.read(readFileSync(targetPath));
const a = PNG.sync.read(readFileSync(actualPath));

if (t.width !== a.width || t.height !== a.height) {
  // Wrong size is itself a HIGH diff — fix viewport / deviceScaleFactor / layout box, then re-run.
  console.log(JSON.stringify({ sizeMismatch: true, target: [t.width, t.height], actual: [a.width, a.height] }));
  process.exit(2);
}

// Flatten both over identical white so transparent (Figma export) vs opaque (page bg)
// doesn't read as a full-image diff. Both composited the same way → agreement holds;
// only genuine opaque-vs-opaque differences survive.
const flatten = (png, bg = 255) => {
  const d = png.data;
  for (let i = 0; i < d.length; i += 4) {
    const alpha = d[i + 3] / 255;
    d[i]     = Math.round(d[i]     * alpha + bg * (1 - alpha));
    d[i + 1] = Math.round(d[i + 1] * alpha + bg * (1 - alpha));
    d[i + 2] = Math.round(d[i + 2] * alpha + bg * (1 - alpha));
    d[i + 3] = 255;
  }
  return png;
};
flatten(t);
flatten(a);

const { width, height } = t;
const opts = { threshold: Number(sens), includeAA: false }; // includeAA:false → antialiased pixels never counted as drift

// Display pass: faded-original triptych look + total mismatch count.
const diff = new PNG({ width, height });
const mismatched = pixelmatch(t.data, a.data, diff.data, width, height, opts);
const ratio = mismatched / (width * height);

// Mask pass: clean boolean diff mask (opaque only on diff pixels) for clustering.
const mask = new PNG({ width, height });
pixelmatch(t.data, a.data, mask.data, width, height, { ...opts, diffMask: true });
const isDiff = (idx) => mask.data[(idx << 2) + 3] > 0;

// Largest contiguous diff cluster (8-connectivity). A concentrated cluster is a real
// defect even when the global ratio is tiny — the global gate can't see it.
const visited = new Uint8Array(width * height);
const stack = [];
let best = { area: 0, box: [0, 0, 0, 0] };
for (let i = 0; i < width * height; i++) {
  if (visited[i] || !isDiff(i)) continue;
  let area = 0, minX = width, minY = height, maxX = 0, maxY = 0;
  stack.push(i); visited[i] = 1;
  while (stack.length) {
    const p = stack.pop();
    const x = p % width, y = (p / width) | 0;
    area++;
    if (x < minX) minX = x; if (x > maxX) maxX = x;
    if (y < minY) minY = y; if (y > maxY) maxY = y;
    for (let dy = -1; dy <= 1; dy++)
      for (let dx = -1; dx <= 1; dx++) {
        if (!dx && !dy) continue;
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        const np = ny * width + nx;
        if (!visited[np] && isDiff(np)) { visited[np] = 1; stack.push(np); }
      }
  }
  if (area > best.area) best = { area, box: [minX, minY, maxX - minX + 1, maxY - minY + 1] };
}

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
  maxCluster: { area: best.area, box: best.box }, // box = [x, y, w, h] of the largest diff blob
  localized: best.area >= Number(localizedMinPx), // true ⇒ concentrated defect the global ratio hides
}));
