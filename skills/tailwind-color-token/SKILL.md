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

Example prompt: *"What should `#1A73E8` be named in the Tailwind config?"*

Suggested name rules:
- camelCase
- Descriptive: prefer color name (`googleBlue`, `navyDark`) or semantic role (`errorRed`, `brandPrimary`)
- Check [color-name.com](https://www.color-name.com/hex) mentally if you recognize the hue

### 3. Add token to tailwind.config.js

Add the new entry at the **top level** of `theme.extend.colors` (not inside `custom`), following the existing pattern:

```js
// theme.extend.colors
myColorName: "#1A73E8",
```

Use the Write or Edit tool to insert it. Keep entries alphabetically sorted within their group if the existing list is sorted; otherwise append.

### 4. Replace hex in code

Swap the raw hex for the token:

| Before | After |
|--------|-------|
| `bg-[#1A73E8]` | `bg-googleBlue` |
| `text-[#1A73E8]` | `text-googleBlue` |
| `border-[#1A73E8]` | `border-googleBlue` |
| `color: '#1A73E8'` (inline style) | `color: '#1A73E8'` ← keep if Tailwind class isn't applicable, but token is still registered |

## Rules

- **Never skip step 1** — duplicate tokens cause confusion.
- **Never add to the `custom` nested object** unless the user explicitly asks.
- If the user rejects the suggested name, use whatever they provide verbatim.
- After editing `tailwind.config.js`, do not restart the dev server — Tailwind picks up config changes automatically in watch mode.
