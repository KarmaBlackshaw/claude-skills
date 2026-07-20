// Side-by-side + pixel-diff harness for figma-to-vue step 5.
// usage: node visual-diff.mjs <target.png> <actual.png> <outDir> [sensitivity] [closeRatio]
//   sensitivity: pixelmatch per-pixel color threshold, 0..1 (default 0.1 — higher = more AA-tolerant)
//   closeRatio : max fraction of differing pixels to count as "pixel-close" (default 0.005 = 0.5%)
// deps: pixelmatch + pngjs. Run from a dir whose node_modules has both — simplest is
// the Vue project root (copy this file there). If missing: npm i -D pixelmatch pngjs.
// Note: `npx --package` does NOT expose modules to an outside-path script — don't use it.
import { readFileSync, writeFileSync } from 'node:fs';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

const [, , targetPath, actualPath, outDir = '.', sens = '0.1', closeRatio = '0.005'] = process.argv;
if (!targetPath || !actualPath) {
  console.error('usage: node visual-diff.mjs <target.png> <actual.png> <outDir> [sensitivity] [closeRatio]');
  process.exit(1);
}

const t = PNG.sync.read(readFileSync(targetPath));
const a = PNG.sync.read(readFileSync(actualPath));

if (t.width !== a.width || t.height !== a.height) {
  // Wrong size is itself a HIGH diff — fix viewport / deviceScaleFactor / layout box, then re-run.
  console.log(JSON.stringify({ sizeMismatch: true, target: [t.width, t.height], actual: [a.width, a.height] }));
  process.exit(2);
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
