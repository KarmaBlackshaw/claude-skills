---
name: tailwind-color-token
description: Converts arbitrary hex color values to named Tailwind design tokens. Invoke before writing any raw hex color in Vue, CSS, or JS/TS files.
---

# Tailwind Color Token

**Invoke this skill whenever you are about to write a raw hex color value** (`#RRGGBB` or `#RGB`) anywhere in code — Tailwind arbitrary values (`bg-[#...]`), inline styles, CSS, or JS/TS constants.

## Steps

### 1. Check for existing token

Search `tailwind.config.js` (or `tailwind.config.ts`) at the repo root. Look in `theme.extend.colors` for the exact hex value (case-insensitive).

- If found → use that token name. **Stop here — do not ask the user.**
- If not found → continue to step 2.

### 2. Ask user to name the color

Use `AskUserQuestion` — one question per unique hex (batch if multiple new hexes in the same edit). Show the hex value and suggest a name.

Look up the hex on [color-name.com](https://www.color-name.com/hex/1A73E8) (replace the hex in the URL) and use the **exact color name it returns**, camelCased. E.g. `#1A73E8` → "Tampa" → `tampa`. Do not invent descriptive or semantic names (`googleBlue`, `errorRed`) — the token name is whatever color-name.com calls that hex.

Example prompt: *"color-name.com calls `#1A73E8` \"Tampa\" — register it as `tampa`?"*

### 3. Add token to tailwind.config.js

Add the new entry at the **top level** of `theme.extend.colors` (not inside `custom`), following the existing pattern:

```js
// theme.extend.colors
tampa: "#1A73E8",
```

Use the Write or Edit tool to insert it. Keep entries alphabetically sorted within their group if the existing list is sorted; otherwise append.

### 4. Replace hex in code

Swap the raw hex for the token:

| Before | After |
|--------|-------|
| `bg-[#1A73E8]` | `bg-tampa` |
| `text-[#1A73E8]` | `text-tampa` |
| `border-[#1A73E8]` | `border-tampa` |
| `color: '#1A73E8'` (inline style) | `color: '#1A73E8'` ← keep if Tailwind class isn't applicable, but token is still registered |

## Rules

- **Never skip step 1** — duplicate tokens cause confusion.
- **Never add to the `custom` nested object** unless the user explicitly asks.
- If the user rejects the suggested name, use whatever they provide verbatim.
- After editing `tailwind.config.js`, do not restart the dev server — Tailwind picks up config changes automatically in watch mode.
