# Vue Version Detection

Run this **before** loading any conventions file. Detection is deterministic — never ask the user when a scan can answer.

## Detection sequence

Try in order. Stop at the first one that returns a definitive answer.

### 1. Read `package.json` at the project root

```bash
cat package.json | grep -E '"vue"\s*:'
```

Parse the version string (strip `^`, `~`, `>=`, etc.):

- Starts with `3.` → **Vue 3**, load `vue3-conventions.md`
- Starts with `2.7.` → **Vue 2.7** (Composition API backported), load `vue2-conventions.md` and check for `<script setup>` usage
- Starts with `2.` (anything else) → **Vue 2 Options API**, load `vue2-conventions.md`

### 2. Check monorepo paths if root has no Vue

If `package.json` doesn't list Vue, search:

```bash
find . -maxdepth 3 -name "package.json" -not -path "*/node_modules/*" | xargs grep -l '"vue"' 2>/dev/null
```

Read the first match. Apply the same version logic.

### 3. Check for compiler hints

If still no Vue version found, check build config:

- `vite.config.*` with `@vitejs/plugin-vue` → Vue 3
- `vite.config.*` with `@vitejs/plugin-vue2` → Vue 2
- `vue.config.js` (Vue CLI) → usually Vue 2, but verify with package.json again
- `nuxt.config.*` with `compatibilityVersion: 4` or Nuxt 3+ → Vue 3
- Nuxt 2 → Vue 2

### 4. Last resort: ask the user

Only if all three above fail (no `package.json`, no build config, no Vue dep visible):

> I couldn't detect the Vue version from package.json or build config. Is this Vue 2 or Vue 3?

Don't ask any other clarifying questions at this point — version is the only thing detection couldn't resolve.

## Edge cases

### Vue 2.7 specifically

Vue 2.7 backported Composition API and `<script setup>`, but with subtle differences from Vue 3:
- No `defineModel` macro
- No reactive props destructuring (the thing we just added for Vue 3)
- Different reactivity internals (still uses `Object.defineProperty`, not Proxy)
- TypeScript support exists but is weaker

If the project is on 2.7, after loading `vue2-conventions.md`, scan 2-3 existing `.vue` files:
- If they use `<script setup>` → use the Vue 2.7 Composition API patterns from `vue2-conventions.md`
- If they use Options API → use Options API patterns from the same file
- Match what's in the codebase, don't impose

### Mixed Vue 2 + Vue 3 monorepo

If multiple `package.json` files show different Vue versions, the **target file's location** decides. Check which package the file you're generating belongs to:

```bash
# If generating into apps/admin/src/components/Foo.vue
cat apps/admin/package.json | grep '"vue"'
```

Use the version from that specific package, not the root.

### `peerDependencies` only

If Vue is only in `peerDependencies` (you're working in a library, not an app), check the highest version supported and ask the user which target version to write for. Library code that needs to support both Vue 2 and 3 has additional constraints (`vue-demi` etc.) that are out of scope for this skill — flag and stop.

## Output

After detection, state the result clearly before proceeding:

> Detected: Vue 3.5.x at project root. Loading vue3-conventions.md.

This makes the assumption visible — if it's wrong, the user catches it before code is written.
