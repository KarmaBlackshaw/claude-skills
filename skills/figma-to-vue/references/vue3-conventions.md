# Vue 3 SFC Conventions

Patterns for step 4 code generation. Match the project's existing conventions first — if the project uses a specific pattern, follow it rather than what's written here.

## Detecting project conventions

Before generating code, scan 2-3 existing `.vue` files in the project to detect:

- Script setup vs. Options API (almost always `<script setup>` in new Vue 3 projects)
- TypeScript vs. JavaScript
- Props declaration style — prefer reactive destructuring (`const { foo = 'x' } = defineProps<Props>()`) for Vue 3.5+; fall back to `withDefaults` only if the project is on older Vue or already uses that pattern consistently
- Import path alias (`@/components` vs. `~/components` vs. relative)
- File naming (PascalCase vs. kebab-case)
- CSS approach (Tailwind-only vs. Tailwind + scoped `<style>`)

Match what you find. Don't impose a different convention.

## Default template (use when project is fresh or conventions unclear)

```vue
<script setup lang="ts">
interface Props {
  label: string
  variant?: 'primary' | 'secondary'
  disabled?: boolean
}

const { label, variant = 'primary', disabled = false } = defineProps<Props>()

const emit = defineEmits<{
  click: [event: MouseEvent]
}>()

function handleClick(event: MouseEvent) {
  if (disabled) return
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
      variant === 'secondary' && 'bg-surface-muted text-content-default hover:bg-surface-muted-hover',
      disabled && 'opacity-50 cursor-not-allowed',
    ]"
    :disabled="disabled"
    @click="handleClick"
  >
    {{ label }}
  </button>
</template>
```

## Class organization order

Group Tailwind classes in this order inside each string:

1. **Layout** — `flex`, `grid`, `block`, `inline-flex`, `relative`, `absolute`
2. **Flex/grid children** — `justify-*`, `items-*`, `gap-*`
3. **Positioning** — `top-*`, `left-*`, `z-*`
4. **Spacing** — `p-*`, `m-*`
5. **Sizing** — `w-*`, `h-*`, `min-w-*`, `max-w-*`
6. **Typography** — `text-*`, `font-*`, `leading-*`, `tracking-*`
7. **Color** — `bg-*`, `text-*` (color), `border-*`
8. **Border & radius** — `border`, `rounded-*`
9. **Effects** — `shadow-*`, `opacity-*`
10. **State modifiers** — `hover:*`, `focus:*`, `disabled:*` (grouped by base property)

This matches how most teams read Tailwind classes and reduces bike-shedding.

## Conditional classes

Use array syntax with object literals — not string concatenation:

```vue
<!-- ✅ Good -->
<div :class="[
  'base classes here',
  isActive && 'bg-primary-500',
  { 'opacity-50': disabled },
]">

<!-- ❌ Bad -->
<div :class="`base ${isActive ? 'bg-primary-500' : ''} ${disabled ? 'opacity-50' : ''}`">
```

## When to split into multiple components

Split when any of these are true:

- Template exceeds ~80 lines
- A block has its own props interface (not just visual grouping)
- The same block appears in multiple places in the design
- Figma has it as a separate Component (not just a Frame)

Don't split just because something "feels like a component" — premature splitting creates tiny wrapper components that add import overhead without reuse.

## File organization

Match the project. Common patterns:

- Feature-based: `components/dashboard/DashboardHeader.vue`
- Type-based: `components/ui/Button.vue`, `components/layouts/Header.vue`
- Flat: `components/DashboardHeader.vue`

If the project has an existing pattern, use it. If not, ask the user — don't pick arbitrarily.

## Emits payload typing

Always type emit payloads:

```ts
// ✅ Good
const emit = defineEmits<{
  select: [id: string, metadata: { timestamp: number }]
  close: []
}>()

// ❌ Bad — untyped
const emit = defineEmits(['select', 'close'])
```

## Don't

- Don't use `v-if` + `v-else` for binary visual states when a class toggle works — `v-if` unmounts, which loses state
- Don't inline complex logic in templates — extract to computed or methods
- Don't use `any` in TypeScript — if the Figma spec is unclear, ask rather than reach for `any`
- Don't add scoped styles for things Tailwind can do — only use `<style>` for things Tailwind genuinely can't express (complex animations, deeply nested child selectors)
