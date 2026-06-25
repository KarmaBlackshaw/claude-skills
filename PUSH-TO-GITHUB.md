# Push `claude-skills` to GitHub

Step-by-step to get the repo live. Run these in order.

## Step 1: Create the repo on GitHub

Go to https://github.com/new and create a new repo:

- **Owner:** KarmaBlackshaw
- **Repository name:** `claude-skills`
- **Description:** Personal collection of Claude Code skills for dev workflow automation
- **Visibility:** Public
- **Do NOT initialize** with README, .gitignore, or license — we have those locally

Click "Create repository". Don't follow the setup instructions GitHub shows — use the ones below instead.

## Step 2: Extract the local files

```bash
cd ~/Downloads   # or wherever you saved claude-skills.tar.gz
tar -xzf claude-skills.tar.gz
cd claude-skills
```

You should see:

```
LICENSE
README.md
install.sh
.gitignore
figma-to-vue/
```

## Step 3: Initialize git and push

```bash
git init
git add .
git commit -m "Initial commit: figma-to-vue skill"
git branch -M main
git remote add origin https://github.com/KarmaBlackshaw/claude-skills.git
git push -u origin main
```

If you use SSH instead of HTTPS:

```bash
git remote add origin git@github.com:KarmaBlackshaw/claude-skills.git
```

## Step 4: Verify the install command works

After the push completes, test the install script from a fresh shell:

```bash
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s figma-to-vue
```

Expected output:
- "Cloning claude-skills repo..."
- "Installing figma-to-vue..."
- "✓ figma-to-vue installed → /home/you/.claude/skills/figma-to-vue"
- "Done. Installed 1 skill(s)."
- "! Restart Claude Code fully to load the skills."

If the install already exists from earlier sessions, the script will back it up to `figma-to-vue.bak` first.

## Step 5: Add repo topics for discoverability

On the GitHub repo page, click the gear icon next to "About" and add topics:

- `claude-code`
- `claude-skill`
- `claude-skills`
- `figma`
- `vue`
- `vue3`
- `tailwindcss`
- `developer-tools`

These make the repo findable when others search GitHub for Claude Code skills.

## Step 6: Optional polish

These aren't blockers but improve the repo:

**Add a screenshot or GIF** of the skill in action. Drop it in `figma-to-vue/docs/demo.gif` and reference it in the per-skill README under a "Demo" section.

**Add a release tag** so the install script can pin to a stable version:

```bash
git tag v0.1.0
git push origin v0.1.0
```

You can then update `install.sh` later to optionally fetch a specific tag instead of `main`.

**Pin the repo on your GitHub profile** — go to your profile, "Customize your pins", select claude-skills. This puts it on your portfolio without extra work.

## Troubleshooting

**"Permission denied (publickey)" on push** — your SSH key isn't added to GitHub, or you used the SSH URL without one. Either set up SSH keys or use the HTTPS URL.

**`install.sh` fails with "git is required"** — the user running the install doesn't have git. Tell them to install git first.

**Install script copies but skill doesn't fire in Claude Code** — check Claude Code was fully restarted. On macOS, use Cmd+Q from the menu, not just window close.

**Adding more skills later** — just create a new directory at the repo root with a `SKILL.md` file. The install script auto-discovers any directory containing a `SKILL.md`. Update the top-level `README.md` to list the new skill in the table.
