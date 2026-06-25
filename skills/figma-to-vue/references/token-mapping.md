# Token Mapping Reference

Rules and examples for step 2 — mapping Figma values to Tailwind classes.

## The hard rule

**Never emit arbitrary value classes.** These are forbidden in output:

- `bg-[#3B82F6]`
- `p-[17px]`
- `text-[15px]`
- `w-[342px]`
- `rounded-[7px]`
- Any class with `[...]` in it

If a value has no token match, propose a new token instead. This is non-negotiable — arbitrary values make design systems unmaintainable, and the whole point of this skill is producing code the design system survives.

## Decision table

| Figma value | Tailwind config has... | Action |
|-------------|------------------------|--------|
| Exact match (`primary/500` → `primary.500`) | Exact value | Use the token class |
| Close match (spacing `15px`, config has `4 = 16px`) | Value within 1px / 1 shade | Flag as near-match; let user decide |
| No match (spacing `22px`, nothing close) | Nothing in range | Propose new token |
| Unbound color (raw hex from Figma) | — | Propose new token named semantically |

## Mapping table format

Output for step 2:

```markdown
## Step 2: Token mapping

### Exact matches
| Figma | Tailwind class | Notes |
|-------|----------------|-------|
| `primary/500` | `bg-primary-500` | |
| `heading/lg` | `text-heading-lg` | |
| spacing 16px | `p-4` | |
| spacing 24px | `gap-6` | |

### Near matches (user decision needed)
| Figma | Closest Tailwind | Diff | Recommendation |
|-------|-------------------|------|----------------|
| spacing 15px | `p-4` (16px) | -1px | Round to p-4 unless pixel-perfect required |

### Proposed new tokens
| Figma | Proposed | Config addition |
|-------|----------|-----------------|
| `#F3F4F6` (unbound) | `bg-surface-muted` | `colors.surface.muted: '#F3F4F6'` |
| Inter 14/20 medium (unbound) | `text-button` | See config diff below |

### Config diff

```js
// tailwind.config.js — add to theme.extend
colors: {
  surface: {
    muted: '#F3F4F6',
  },
},
fontSize: {
  button: ['14px', { lineHeight: '20px', fontWeight: '500' }],
},
```

**Apply the config diff yourself before I build in step 4.** I won't edit `tailwind.config.js` without explicit instruction — config changes affect the whole project.
```

## Naming proposed tokens

When proposing new tokens, name them semantically, not by appearance:

- ✅ `bg-surface-muted` (role-based)
- ❌ `bg-gray-100b` (appearance-based, collides with gray scale)
- ✅ `text-button` (usage-based)
- ❌ `text-14` (size-based, not reusable)

If the Figma file has a partial variable naming convention (e.g. some colors are bound as `surface/elevated`, `surface/base`), match that convention for proposed tokens. Consistency with the existing system beats "better" naming.

## Edge cases

**Gradients** — Figma gradients rarely map cleanly to Tailwind utility classes. Propose a CSS variable or a named bg-gradient class in the config rather than trying to force it into utilities.

**Shadows** — Figma allows multiple layered shadows. Tailwind has `shadow-sm`, `shadow`, `shadow-md`, etc. If the Figma shadow is custom, propose a new shadow token in `theme.extend.boxShadow`.

**Border radius** — single values map to `rounded-*`. Mixed corners (e.g. `8px 8px 0 0`) need `rounded-t-lg` or similar. If Figma has a truly custom radius, propose a token.

**Opacity applied to colors** — Figma often shows `#3B82F6 at 80%`. This should resolve to a Tailwind color with `/80` modifier (`bg-primary-500/80`) if the base color has a token. If not, propose the base first.
