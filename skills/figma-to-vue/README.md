# figma-to-vue

A Claude Code skill that converts Figma designs into Vue + Tailwind components — without guessing.

## The problem

The default failure mode when LLMs convert Figma to code is optimistic pattern-matching:

- Looks at the rendered frame, **guesses hex codes** (`bg-[#3B82F6]` everywhere)
- **Rounds spacing** to the nearest Tailwind default (`p-4` instead of the actual 15px)
- **Misreads component structure** — turns three nested components into one big div
- Produces output that *looks* close but drifts from the design system within weeks

This skill replaces guessing with inspection. Every step produces a structured artifact the next step consumes.

## How it works

A 4-step workflow, enforced by the skill:

```
1. Inspect  → Pull frame structure via Figma MCP. Report hierarchy, 
              auto-layout, colors, text styles, spacing. Flag unbound values.
2. Map      → Read tailwind.config.js. Map every Figma value to a token 
              class or propose a new token. Refuses arbitrary values.
3. Outline  → Propose component structure, props, emits. STOP for approval.
4. Build    → Detect Vue 2 vs 3, load matching conventions, generate SFCs.
              Run linter and typecheck. Report diffs.
```

Step 3 pauses for explicit approval — structure mistakes are the most expensive to fix after the code is written.

## Install

### Prerequisites

- [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) installed and runnable from your terminal
- `git` and `curl` available on `PATH`
- A Vue + Tailwind project to use the skill in (see [Requirements](#requirements) below)
- [Figma MCP connector](https://help.figma.com/hc/en-us/articles/32132100833559) configured in Claude Code

### Recommended: one-liner install

```bash
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s figma-to-vue
```

The script clones the repo to a temp dir, copies `figma-to-vue/` into `~/.claude/skills/`, and backs up any existing install to `figma-to-vue.bak` first.

### Manual install

If you'd rather not pipe to bash:

```bash
git clone https://github.com/KarmaBlackshaw/claude-skills.git
mkdir -p ~/.claude/skills
cp -r claude-skills/figma-to-vue ~/.claude/skills/
```

### Verify

```bash
ls ~/.claude/skills/figma-to-vue
# Should show: README.md  SKILL.md  references
```

Then **fully quit Claude Code** (Cmd+Q on macOS — not just close the window) and reopen. In a new session, type `/skills` or trigger a Figma URL — the skill should appear in the active list as `figma-to-vue`.

### Update

Re-run the one-liner. The script overwrites the existing install (after backing it up):

```bash
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s figma-to-vue
```

### Uninstall

```bash
rm -rf ~/.claude/skills/figma-to-vue ~/.claude/skills/figma-to-vue.bak
```

Restart Claude Code to drop it from the active skill list.

### Troubleshooting

| Symptom | Fix |
|---------|-----|
| Skill not in `/skills` list after install | You didn't fully quit Claude Code. Cmd+Q, reopen. |
| `git is required` from installer | Install git, retry. |
| Skill fires but says "Figma MCP missing" | Connect the Figma MCP in Claude Code settings → MCP connectors. |
| Skill triggers in Cursor / Windsurf and does nothing | Expected — only Claude Code reads `~/.claude/skills/`. |
| Want to pin a version | Replace `main` in the curl URL with a tag, e.g. `.../v0.1.0/install.sh`. |

## Usage

In a Claude Code session inside a Vue + Tailwind project, with a Figma frame selected:

```
build this figma: https://www.figma.com/file/abc/...
```

Or paste the URL alone — the skill matches on Figma URLs in the message.

The skill will:

1. Run inspection and show you the report
2. Map Figma values to your Tailwind tokens (or propose new ones)
3. Show the component outline and **wait for your approval**
4. Generate the Vue files, run lint and typecheck, report results

## Requirements

- **Claude Code** — won't load in Windsurf Cascade, Cursor, or other editors
- **Figma MCP connector** — required for live design access. Skill stops and tells you to connect it if missing.
- **Vue 3 or Vue 2 project** — auto-detected from `package.json`. Vue 2.7's Composition API is supported.
- **Tailwind CSS** — `tailwind.config.js` or `.ts` somewhere in the project (root or monorepo packages)

## What it enforces

Hard rules baked into the skill:

- **No arbitrary Tailwind values.** `bg-[#hex]`, `p-[17px]`, `text-[15px]` are refused. New tokens get proposed instead.
- **Inspect before mapping.** Skipping inspection is the cause of every "this doesn't match the design" complaint.
- **Pause before building.** No code without an approved outline.
- **Match project conventions.** Scans existing `.vue` files to detect Options API vs Composition, TS vs JS, naming, etc. Imposes nothing.

## Vue version handling

Auto-detects the Vue version from `package.json`:

| Detected | Loads | Notes |
|----------|-------|-------|
| Vue 3.x | `vue3-conventions.md` | Reactive props destructuring (3.5+) |
| Vue 2.7 | `vue2-conventions.md` | Composition API + `<script setup>` patterns |
| Vue 2.0–2.6 | `vue2-conventions.md` | Options API patterns |
| Monorepo with mixed | reads the package.json closest to the target file | |
| Can't detect | asks you once | Last resort, not first |

Only the matching conventions file loads — the other never enters context. Token-efficient by design.

## File structure

```
figma-to-vue/
├── SKILL.md                              # Workflow + hard rules
└── references/
    ├── inspection-template.md            # Step 1 output format
    ├── token-mapping.md                  # Step 2 decision rules
    ├── vue-detection.md                  # Step 4 version detection
    ├── vue3-conventions.md               # Vue 3 patterns
    └── vue2-conventions.md               # Vue 2 patterns
```

`SKILL.md` is short and stable — loaded on every fire. Reference files are loaded only when needed.

## Limitations

- **Won't fire in Windsurf Cascade or Cursor.** Only Claude Code reads `~/.claude/skills/`. If you use those editors' built-in AI alongside Claude Code, only the Claude Code invocations will trigger the skill.
- **Figma MCP version assumptions.** The skill assumes the MCP returns `boundVariables` and `styles` fields. If your Figma MCP version returns data differently, the inspection step may misidentify what's bound vs. unbound. Test on a known-good frame first.
- **Pause discipline imperfect.** Step 3 says "STOP" but Claude Code occasionally barrels past it. If it skips the outline approval, tell it "go back to step 3 and wait."
- **Designer-side requirement.** If the Figma file uses raw hex codes without variables, the skill will propose many new tokens. Garbage in, garbage out — the skill flags this but can't fix the source file.

## Development

To modify the skill:

1. Clone the repo: `git clone https://github.com/KarmaBlackshaw/claude-skills.git`
2. Edit files in `figma-to-vue/`
3. Reinstall: `cd claude-skills && cp -r figma-to-vue ~/.claude/skills/`
4. Restart Claude Code

## License

[MIT](../LICENSE)
