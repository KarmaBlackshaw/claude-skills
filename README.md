# Claude Skills

A personal collection of [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) skills for dev workflow automation. Each skill lives in its own folder with its own README.

## Skills

| Skill | Description |
|-------|-------------|
| [`figma-to-vue`](./skills/figma-to-vue) | Convert Figma designs into Vue 3 + Tailwind components via a 4-step workflow (inspect → map → outline → build) that prevents the usual failure modes — guessing hex codes, rounding spacing, misreading hierarchy. |
| [`plan-and-build`](./skills/plan-and-build) | Two-phase feature workflow — opus planner writes a markdown plan, user approves, then sonnet/haiku/opus executors implement step-by-step, routed by complexity tag. No auto-commit. No test-file writes. Bundles 4 subagents (planner + 3 executors). |
| [`tailwind-color-token`](./skills/tailwind-color-token) | Converts arbitrary hex color values to named Tailwind design tokens. Checks `tailwind.config.js` before asking, batches multiple new hexes, inserts tokens into `theme.extend.colors`, and rewrites the raw hex in code. |

> The `jeash:*` launcher skills (architect, frontend, ux, dx, review, qa) live in the **`jeash` plugin** ([`./jeash/`](./jeash/)) — invoke as `jeash:review`, `jeash:qa`, … The portable agent roster source is in [`./agents/`](./agents/).

More skills coming as I build them.

## Install all skills

One-liner that installs every skill in this repo into your global Claude Code skills directory (`~/.claude/skills/`):

```bash
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash
```

## Install a single skill

```bash
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s <skill-name>
```

Example:

```bash
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s tailwind-color-token
```

After installing, restart Claude Code (quit fully — not just close the window).

## Manual install

If you'd rather not pipe to bash:

```bash
git clone https://github.com/KarmaBlackshaw/claude-skills.git
mkdir -p ~/.claude/skills
cp -r claude-skills/skills/<skill-name> ~/.claude/skills/
```

## Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) installed (these skills don't load in Windsurf Cascade, Cursor, or other Claude-using editors — only Claude Code reads `~/.claude/skills/`)
- Skill-specific requirements listed in each skill's README

## Adding a new skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter (`name`, `description`).
2. Add `skills/<skill-name>/README.md` covering problem, workflow, install, requirements, troubleshooting.
3. Optionally add `agents/` (bundled subagents) or `references/` (lazy-loaded docs) inside the skill folder.
4. Add a row to the Skills table in both `skills/README.md` and this file.
5. Push to `main` — the `curl` one-liner always pulls from `main`.

Full maintenance guide: [skills/README.md#maintaining-this-repo](./skills/README.md#maintaining-this-repo)

## Why these exist

Skills turn repetitive parts of my workflow into one-line invocations. Instead of re-explaining conventions every session, the skill encodes them once and Claude follows them silently. The principles I've followed building these:

- **Short `SKILL.md`** — it loads on every fire, keep it lean
- **Lazy-loaded references** — detail goes in reference files, loaded only when needed
- **Detection over questions** — scan files, don't ask the user, when a deterministic answer exists
- **Hard rules, not preferences** — make the skill refuse bad output rather than warn about it

## Contributing

This is a personal repo — I'm not actively soliciting contributions, but if you've got suggestions or find bugs, open an issue. Forks are encouraged if you want to adapt these to your own stack.

## License

[MIT](./LICENSE)

---

Built by [Ernie](https://github.com/KarmaBlackshaw) — software developer in the Philippines, documenting the build at [Ernie & Yel's Adventure](https://www.facebook.com/ernieandyel).
