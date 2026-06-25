# tailwind-color-token

A Claude Code skill that replaces raw hex color values with named Tailwind design tokens — automatically, without breaking your config.

## The problem

Raw hex values in Tailwind projects (`bg-[#1A73E8]`, `color: '#FF5733'`) accumulate fast. They bypass your design system, can't be refactored globally, and make it impossible to theme or audit colors. Every new hex is a design-system leak.

This skill intercepts hex values before they land in code and routes them through your `tailwind.config.js`.

## How it works

Three steps, in order:

```
1. Check   → Search tailwind.config.js for the exact hex. If found, use the 
             existing token name. Done.
2. Ask     → If new, prompt you to name it (batches multiple new hexes). 
             Suggests a name based on hue and role.
3. Add     → Inserts the token into theme.extend.colors, then rewrites the 
             hex in code to use the new class.
```

Step 1 is silent — no prompt if the token exists. Step 2 fires only for genuinely new colors.

## Install

### Prerequisites

- [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) installed and runnable from your terminal
- `git` and `curl` available on `PATH`
- A project with `tailwind.config.js` or `tailwind.config.ts` at the root

### Recommended: one-liner install

```bash
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s tailwind-color-token
```

### Manual install

```bash
git clone https://github.com/KarmaBlackshaw/claude-skills.git
mkdir -p ~/.claude/skills
cp -r claude-skills/tailwind-color-token ~/.claude/skills/
```

### Verify

```bash
ls ~/.claude/skills/tailwind-color-token
# Should show: README.md  SKILL.md
```

Then **fully quit Claude Code** (Cmd+Q on macOS — not just close the window) and reopen.

### Update

Re-run the one-liner. Existing install is backed up to `tailwind-color-token.bak` before overwrite.

### Uninstall

```bash
rm -rf ~/.claude/skills/tailwind-color-token ~/.claude/skills/tailwind-color-token.bak
```

Restart Claude Code.

### Troubleshooting

| Symptom | Fix |
|---------|-----|
| Skill not in `/skills` list after install | You didn't fully quit Claude Code. Cmd+Q, reopen. |
| Claude still writes `bg-[#hex]` | Remind it: "use the tailwind-color-token skill". |
| Token added but class doesn't work | Check that `tailwind.config.js` is in the scan path. |
| Skill triggers in Cursor / Windsurf and does nothing | Expected — only Claude Code reads `~/.claude/skills/`. |

## Usage

The skill fires automatically whenever Claude is about to write a raw hex value. You don't need to invoke it manually.

If you want to trigger it explicitly:

```
add the color #1A73E8 to our Tailwind config
```

Or just paste a hex anywhere in your request and the skill handles the rest.

## What it enforces

- **No duplicate tokens.** Always checks `tailwind.config.js` before asking.
- **No silent additions.** You name every new color — nothing lands in config without your input.
- **No `custom` nesting.** Tokens go at the top level of `theme.extend.colors` unless you say otherwise.
- **Alphabetical order respected.** If the existing list is sorted, new entries are inserted in order.

## Requirements

- **Claude Code** — won't load in Windsurf Cascade, Cursor, or other editors
- **Tailwind CSS project** — `tailwind.config.js` or `tailwind.config.ts` required at root
- No additional MCPs or external tools needed

## File structure

```
tailwind-color-token/
├── SKILL.md    # Workflow + hard rules
└── README.md   # This file
```

## Development

To modify the skill:

1. Clone the repo: `git clone https://github.com/KarmaBlackshaw/claude-skills.git`
2. Edit `tailwind-color-token/SKILL.md`
3. Reinstall: `cp -r claude-skills/tailwind-color-token ~/.claude/skills/`
4. Restart Claude Code

## License

[MIT](../LICENSE)
