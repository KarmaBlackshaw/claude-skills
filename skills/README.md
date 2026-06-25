# Claude Skills

A personal collection of [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) skills for dev workflow automation. Each skill lives in its own folder with its own README.

## Skills

| Skill | Description |
|-------|-------------|
| [`figma-to-vue`](./figma-to-vue) | Convert Figma designs into Vue 3 + Tailwind components via a 4-step workflow (inspect → map → outline → build) that prevents the usual failure modes — guessing hex codes, rounding spacing, misreading hierarchy. |
| [`plan-and-build`](./plan-and-build) | Two-phase feature workflow — opus planner writes a markdown plan, user approves, then sonnet/haiku/opus executors implement step-by-step, routed by complexity tag. No auto-commit. No test-file writes. Bundles 4 subagents (planner + 3 executors). |
| [`tailwind-color-token`](./tailwind-color-token) | Converts arbitrary hex color values to named Tailwind design tokens. Checks `tailwind.config.js` before asking, batches multiple new hexes, inserts tokens into `theme.extend.colors`, and rewrites the raw hex in code. |

> The `jeash:*` launcher skills (architect, frontend, ux, dx, review, qa) moved to the **`jeash` plugin** (`../jeash/`) — invoke as `jeash:review`, `jeash:qa`, … See [`../jeash/README.md`](../jeash/README.md).

More skills coming as I build them.

### Bundled agents

Some skills ship subagent definitions under their `agents/` subdirectory. The installer copies them to `~/.claude/agents/` automatically. Currently bundled:

| Agent | Bundled by | Model | Role |
|-------|-----------|-------|------|
| `planner` | plan-and-build | opus | Writes implementation plan, no code |
| `executor` | plan-and-build | sonnet | Default executor for `[med]` steps |
| `executor-haiku` | plan-and-build | haiku | Mechanical `[low]` steps — cheap |
| `executor-opus` | plan-and-build | opus | Hard `[high]` steps — algorithms, security, perf |

Agents differ from `references/` (used by `figma-to-vue`):
- `references/` are lazy-loaded markdown docs, read in-place by the skill from inside its folder
- `agents/` are subagent definitions that Claude Code loads at session startup from `~/.claude/agents/*.md` (must be flat, frontmatter required)

A skill can ship both.

## Installation

Each skill has a full install guide in its own README (prerequisites, verification, update, uninstall, troubleshooting). Quick reference below.

### Prerequisites (all skills)

- [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) installed (won't load in Windsurf Cascade, Cursor, or other editors — only Claude Code reads `~/.claude/skills/`)
- `git` and `curl` on `PATH`
- Skill-specific prerequisites — see the skill's README

### Install all skills

```bash
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash
```

### Install a single skill

```bash
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s <skill-name>
```

Example:

```bash
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s figma-to-vue
```

### Manual install

```bash
git clone https://github.com/KarmaBlackshaw/claude-skills.git
mkdir -p ~/.claude/skills
cp -r claude-skills/skills/<skill-name> ~/.claude/skills/
```

### After install

**Fully quit Claude Code** (Cmd+Q on macOS — closing the window is not enough) and reopen. Skills load on startup.

### Verify

```bash
ls ~/.claude/skills/   # installed skills
ls ~/.claude/agents/   # installed agents (from skills with bundled agents/)
```

Each installed skill appears as a directory. In Claude Code, `/skills` lists active skills and `/agents` lists active subagents.

### Update

Re-run the one-liner. Existing installs are backed up to `<skill>.bak` before overwrite.

### Uninstall

```bash
rm -rf ~/.claude/skills/<skill-name> ~/.claude/skills/<skill-name>.bak
```

If the skill bundled agents, also remove them:

```bash
# example for plan-and-build's bundled agents
rm -f ~/.claude/agents/{planner,executor,executor-haiku,executor-opus}.md{,.bak}
```

Restart Claude Code.

### Per-skill install guides

| Skill | Install guide |
|-------|---------------|
| `figma-to-vue` | [figma-to-vue/README.md#install](./figma-to-vue/README.md#install) |
| `plan-and-build` | [plan-and-build/README.md#install](./plan-and-build/README.md#install) |
| `tailwind-color-token` | [tailwind-color-token/README.md#install](./tailwind-color-token/README.md#install) |

## Maintaining this repo

### Adding a new skill

1. Create a folder: `skills/<skill-name>/`
2. Add `SKILL.md` with valid YAML frontmatter at the top:
   ```markdown
   ---
   name: skill-name
   description: One-line description shown in /skills list.
   ---
   ```
3. Add a `README.md` covering: what problem it solves, how it works, install/verify/update/uninstall steps, requirements, and troubleshooting.
4. If the skill ships subagents, put them in `<skill-name>/agents/*.md` (flat, each with frontmatter).
5. If the skill uses lazy-loaded docs, put them in `<skill-name>/references/`.
6. Update **both** READMEs:
   - `skills/README.md` — add row to the Skills table and Per-skill install guides table
   - `README.md` (repo root) — add row to the Skills table
7. Push to `main`. The `curl` one-liner always pulls from `main`, so users get it on their next install/update run.

### Updating an existing skill

1. Edit the skill's files (`SKILL.md`, reference docs, agent files, `README.md`).
2. If the change affects install steps or requirements, update the skill's `README.md` accordingly.
3. If the skill description changed, update the Skills table in both `skills/README.md` and `README.md`.
4. Push to `main`.

Users update by re-running:
```bash
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s <skill-name>
```
The installer backs up the existing install to `<skill>.bak` before overwriting.

### Updating the installer

`install.sh` at the repo root is the authoritative installer (used by the `curl` one-liner). It discovers skills under `skills/<skill-name>/SKILL.md`.

When adding agent support or new install-time behavior, update `install.sh` and verify manually from the repo root:
```bash
bash install.sh <skill-name>
```

### Doc-only changes

For README edits that don't affect the skill files themselves, no reinstall is needed on the user side — docs are not copied to `~/.claude/skills/`. Merge to `main` and the GitHub-hosted docs update immediately.

## Why these exist

Skills turn repetitive parts of my workflow into one-line invocations. Instead of re-explaining conventions every session, the skill encodes them once and Claude follows them silently. The principles I've followed building these:

- **Short `SKILL.md`** — it loads on every fire, keep it lean
- **Lazy-loaded references** — detail goes in reference files, loaded only when needed
- **Detection over questions** — scan files, don't ask the user, when a deterministic answer exists
- **Hard rules, not preferences** — make the skill refuse bad output rather than warn about it

## Contributing

This is a personal repo — I'm not actively soliciting contributions, but if you've got suggestions or find bugs, open an issue. Forks are encouraged if you want to adapt these to your own stack.

## License

[MIT](../LICENSE)

---

Built by [Ernie](https://github.com/KarmaBlackshaw) — software developer in the Philippines, documenting the build at [Ernie & Yel's Adventure](https://www.facebook.com/ernieandyel).
