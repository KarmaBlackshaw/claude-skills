# Vue 2 SFC Conventions

Patterns for Vue 2 projects. Match the project's existing style first — if files use Options API, generate Options API; if they use `<script setup>` (Vue 2.7+), generate that.

## Detecting which sub-pattern

Before generating code, scan 2-3 existing `.vue` files:

- `<script>` with `export default { data() { ... }, methods: { ... } }` → **Options API** (default for Vue 2.0–2.6, common in 2.7)
- `<script setup>` → **Vue 2.7 Composition API**
- `<script>` with `export default defineComponent({ setup() { ... } })` → **Vue 2.7 Composition API** (verbose form)

Match what's there.

## Options API template (Vue 2.0–2.6, or 2.7 codebases that use it)

```vue
<script>
export default {
  name: 'Button',
  props: {
    label: {
      type: String,
      required: true,
    },
    variant: {
      type: String,
      default: 'primary',
      validator: (v) => ['primary', 'secondary'].includes(v),
    },
    disabled: {
      type: Boolean,
      default: false,
    },
  },
  methods: {
    handleClick(event) {
      if (this.disabled) return
      this.$emit('click', event)
    },
  },
}
</script>

<template>
  <button
    type="button"
    :class="[
      'inline-flex items-center justify-center',
      'px-4 py-2 rounded-md',
      'text-button font-medium',
      variant === 'primary' && 'bg-primary-500 text-white hover:bg-primary-600',
      variant === 'secondary' && 'bg-surface-muted text-content-default',
      disabled && 'opacity-50 cursor-not-allowed',
    ]"
    :disabled="disabled"
    @click="handleClick"
  >
    {{ label }}
  </button>
</template>
```

### Options API key differences from Vue 3

- `props` is an object, not a generic — type via `type: String` etc., not TypeScript generics
- `methods` block holds functions, accessed via `this.methodName`
- `data()` returns reactive state, accessed via `this.propertyName`
- `computed` block for derived values
- `watch` block for watchers
- Emits declared in `emits: ['click', 'select']` array (Vue 2.6+) or just used directly via `this.$emit`
- No `<script setup>` — always full `<script>` block with `export default`

### Vue 2 reactivity caveats

- Adding new properties to objects requires `Vue.set(obj, key, value)` or `this.$set(obj, key, value)` — direct assignment isn't reactive
- Replacing array indices requires `Vue.set(arr, index, value)` — `arr[index] = value` isn't reactive
- This affects how you write components that mutate complex state — flag if Figma design implies dynamic property addition

## Vue 2.7 Composition API template (`<script setup>`)

```vue
<script setup>
import { ref } from 'vue'

const props = defineProps({
  label: {
    type: String,
    required: true,
  },
  variant: {
    type: String,
    default: 'primary',
  },
  disabled: {
    type: Boolean,
    default: false,
  },
})

const emit = defineEmits(['click'])

function handleClick(event) {
  if (props.disabled) return
  emit('click', event)
}
</script>

<template>
  <button
    type="button"
    :class="[
      'inline-flex items-center justify-center',
      'px-4 py-2 rounded-md',
      'text-button font-medium',
      variant === 'primary' && 'bg-primary-500 text-white hover:bg-primary-600',
      variant === 'secondary' && 'bg-surface-muted text-content-default',
      disabled && 'opacity-50 cursor-not-allowed',
    ]"
    :disabled="disabled"
    @click="handleClick"
  >
    {{ label }}
  </button>
</template>
```

### Vue 2.7 Composition API differences from Vue 3

- **No reactive props destructuring** — use `props.foo`, not destructured. The compiler magic that makes `const { foo } = defineProps()` reactive is Vue 3.5+ only.
- **No `defineModel` macro** — use the verbose `props` + `emit('update:modelValue')` pattern for v-model
- **TypeScript-only macros (`defineProps<{}>()`) work but are weaker** — type validation at runtime is less reliable; the runtime form (`defineProps({ ... })`) is recommended for Vue 2.7
- **No `Suspense`, no `Teleport` to `body` by default** (Teleport works but is less battle-tested)
- **Reactivity is `Object.defineProperty`-based** — same caveats as Options API: `Vue.set` for new properties, `Vue.set` for array index replacement

## Class organization order

Same as Vue 3 — group Tailwind classes:

1. Layout → 2. Flex/grid children → 3. Positioning → 4. Spacing → 5. Sizing → 6. Typography → 7. Color → 8. Border & radius → 9. Effects → 10. State modifiers

## Conditional classes

Use array syntax with object literals:

```vue
<!-- ✅ Good (works in Vue 2 and 3) -->
<div :class="[
  'base classes',
  isActive && 'bg-primary-500',
  { 'opacity-50': disabled },
]">

<!-- ❌ Bad — string concatenation -->
<div :class="`base ${isActive ? 'bg-primary-500' : ''}`">
```

## Vue 2-specific things to avoid

- **Don't use `defineModel`** — Vue 3.4+ only. For Vue 2, write the prop + emit pattern manually:
  ```vue
  <script setup>
  const props = defineProps({ modelValue: String })
  const emit = defineEmits(['update:modelValue'])
  
  function update(value) {
    emit('update:modelValue', value)
  }
  </script>
  ```
- **Don't use multiple v-model bindings without checking Vue version** — Vue 2.6+ supports it via `.sync`, Vue 2.7+ via `v-model:propName`, syntax differs.
- **Don't use Fragment templates (multiple root elements)** — Vue 2 requires a single root element. Wrap in a `<div>` or use functional component if absolutely needed.
- **Don't use `<style scoped>` with `:deep()` selector** — Vue 2 uses `::v-deep` or `/deep/`. The `:deep()` syntax is Vue 3+.

## File organization

Same as Vue 3 — match the project's existing pattern. Don't impose a different structure.

## Migration awareness

If you spot Vue 2 code with patterns that suggest impending Vue 3 migration (e.g., already using Composition API in 2.7, already using `<script setup>`), generate code that's as forward-compatible as possible:

- Use Composition API + `<script setup>` over Options API (when project already uses it)
- Avoid Vue 2-only patterns (filters, `Vue.set`, event bus) unless the rest of the codebase relies on them
- Note migration concerns in the build summary

This makes the eventual Vue 3 migration cheaper, without forcing it.
