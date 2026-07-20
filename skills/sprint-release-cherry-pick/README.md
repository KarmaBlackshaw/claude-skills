# sprint-release-cherry-pick

Cut a QA release from a ClickUp sprint. Reads the **active sprint**, finds tickets at a configured status (`Ready for Release` by default), resolves each ticket's linked GitHub branch/commits, and — per repo — cuts `qa-claude-<date>` off `qa`, cherry-picks the commits onto it, and opens a PR back into `qa`.

Built for a 4-repo setup (`doctor-dashboard`, `admin-dashboard`, `patient-dashboard`, `patient-portal`), but the repo list, org, sprint, and status all live in `config.yaml` — retarget by editing config.

## What it does

1. Load `config.yaml`.
2. Find the active sprint in ClickUp.
3. Collect tickets at `ticket_status`.
4. For each ticket, read the linked branch/commits from ClickUp, then **verify against the remote** (branches move) and compute the commits unique to that branch vs. `qa`. Route each ticket to whichever repo holds its branch.
5. Print a **dry-run plan** (repo → branch → commits → tickets) and wait for your OK.
6. Per repo: branch off `qa`, cherry-pick the ordered union of commits, push, open a PR into `qa`.
7. On a cherry-pick conflict, hand off to the **`resolving-merge-conflicts`** skill (resolves and continues — never aborts).

Nothing writes to a real repo before you approve the dry-run.

## Prerequisites

- [Claude Code](https://docs.claude.com/en/docs/claude-code/overview).
- **ClickUp MCP** connector authorized (the `clickup_*` tools must be available).
- **`gh`** CLI authenticated (`gh auth status`) and **`git`** on PATH.
- The repos in `config.yaml` cloned under `github.local_root`.
- **`resolving-merge-conflicts`** skill installed (companion — same repo). Without it, conflicts stop the run instead of self-resolving.

## Setup

```bash
cd ~/.claude/skills/sprint-release-cherry-pick   # after install
cp config.example.yaml config.yaml
$EDITOR config.yaml                               # fill workspace/space ids, org, repos
```

`config.yaml` is gitignored — your ids and org stay local.

Find the ClickUp `workspace_id` and `sprint_space_id` in a ClickUp URL, or ask Claude to enumerate them with the ClickUp MCP tools.

## Usage

In a session with the ClickUp connector on:

> "Cut the release."  ·  "Sprint release — Ready for Release tickets."  ·  "Cherry-pick the ready tickets into qa branches and open PRs."

To rehearse safely, set `ticket_status: "Ready for Testing - Staging"` in `config.yaml` first — the flow runs end-to-end against staging tickets without touching real release work.

## Safety

- **Confirm gate:** no branch/push/PR before you approve the dry-run.
- **Idempotent:** a pre-existing `qa-claude-<date>` branch stops that repo rather than duplicating commits.
- **No silent drops:** tickets whose branch can't be resolved ride through to the report as `UNRESOLVED`.
- **One PR per repo:** four separate repos can't share a PR.

## Install

Part of the [claude-skills](../../README.md) repo. The installer takes one skill per run, so install this skill and its companion separately (or run with no argument to install everything):

```bash
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s sprint-release-cherry-pick
curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s resolving-merge-conflicts
```

Then do the **Setup** step above.
