---
name: sprint-release-cherry-pick
description: Use when cutting a QA release from pasted ClickUp tickets — the user says "cut the release", "sprint release", "release these tickets", "cherry-pick these tickets", or pastes ClickUp ticket links/ids to be turned into fresh qa-based branches with their commits cherry-picked and PRs opened. Resolves each ticket's linked GitHub branch/commits, and per repo cuts a qa-claude-<date> branch off qa, cherry-picks the commits, and opens a PR into qa. Requires config.yaml.
---

# Sprint Release Cherry-Pick

Turn the ClickUp tickets the operator pastes into per-repo release branches: for each repo, cut `qa-claude-<date>` off `qa`, cherry-pick the tickets' commits onto it, and open a PR back into `qa`.

**Never mutate a real repo (branch, push, PR) before the operator approves the dry-run plan.** Read freely; write only after the confirm gate in Phase 4.

## Prerequisites

- `config.yaml` present in this skill folder (copy `config.example.yaml` and fill it). If missing, tell the operator to do that and stop.
- ClickUp MCP tools available (`clickup_*`). If not, tell the operator the ClickUp connector needs authorizing and stop.
- `gh` CLI authenticated (`gh auth status`) and `git` on PATH.
- The 4 repos cloned under `github.local_root`. Any missing repo → report it and skip that repo (don't clone silently).

## Config

Read every specific from `config.yaml` — **never hardcode** org or repo names. Shape:

```yaml
clickup:
  workspace_id: "..."          # team/workspace id (needed to resolve custom ticket ids)
github:
  org: your-org
  base_branch: qa
  release_branch_prefix: "qa-claude-"
  local_root: "~/code"
  repos: [doctor-dashboard, admin-dashboard, patient-dashboard, patient-portal]
pr:
  base: qa
  title_template: "Release {date}"
```

## Workflow

Create one todo per phase. Do them in order. Do not skip the dry-run gate.

### Phase 1 — Load config

Read `config.yaml`. Resolve `local_root` (`~` → `$HOME`). Compute the release branch name once: `<release_branch_prefix><today>` where `today = $(date +%F)` (e.g. `qa-claude-2026-07-16`). Use the SAME name for every repo this run.

### Phase 2 — Collect the pasted tickets

The operator pastes the tickets to release in their request — ClickUp URLs, custom ids (e.g. `CU-123`), or task ids. If none were pasted, ask for them and stop.

For each pasted ref, resolve the task via ClickUp MCP (`clickup_get_task`; custom ids need `clickup.workspace_id`) and capture: task id, custom id, name, url. If a ref doesn't resolve, **report it and ask** — don't guess.

### Phase 3 — Resolve branches + commits (ClickUp first, git verify)

ClickUp's GitHub integration attaches linked **branches and commits** to a task. For each ticket:

1. **Read the linked branch + commits from ClickUp** — inspect the task (`clickup_get_task`; also check custom fields, attachments, and comments — the integration surfaces branch/commit data in varying places). Record the branch name and any commit SHAs ClickUp reports, plus which repo they belong to.
2. **Fallback if ClickUp returns nothing** — grep each repo's remote branches for the ticket's id: `git -C <repo> ls-remote --heads origin | grep -i <ticket-id>`. A branch whose name embeds the ticket id is the linked branch.
3. **Route to a repo** — the repo is whichever of `github.repos` actually contains that branch. A ticket may touch more than one repo; handle each repo hit independently.
4. **Git-verify the branch** (do NOT trust ClickUp's name blindly): `git -C <repo> fetch origin` then confirm `origin/<branch>` exists. If ClickUp's branch name is stale/renamed/deleted, fall back to the id-grep from step 2; if still unresolved, mark the ticket **UNRESOLVED** and carry it into the dry-run report rather than silently dropping it.
5. **Compute the commits to pick** — the commits unique to the branch vs. qa, in chronological order:
   `git -C <repo> rev-list --reverse origin/<base_branch>..origin/<branch>`.
   Prefer this over ClickUp's raw SHA list (branches move; this is authoritative). If ClickUp reported specific SHAs that fall outside this range, note the discrepancy in the report.

**Union per repo:** a commit reachable from several tickets' branches must be cherry-picked once. Collect each repo's commits into one ordered, de-duplicated list (preserve chronological/topological order across the union). Also drop any commit already reachable from `origin/qa` (already released).

### Phase 4 — Dry-run plan + confirm gate

Print a plan, grouped by repo:

```
doctor-dashboard  →  qa-claude-2026-07-16  (off origin/qa)
  tickets: CU-123 "Fix X", CU-140 "Add Y"
  commits (in order):
    a1b2c3d  fix: X null guard
    d4e5f6a  feat: Y panel
admin-dashboard   →  qa-claude-2026-07-16
  ...
UNRESOLVED: CU-155 "Z" — no linked branch found in any repo
Skipped repos: patient-portal (no tickets)
```

**Stop and require the operator's explicit OK.** Do not create branches, push, or open PRs until they approve. If they approve a subset, act only on that subset.

### Phase 5 — Execute per repo

For each repo with commits (skip repos with none):

```bash
git -C <repo> fetch origin
# Idempotency: if the release branch already exists locally or on origin, STOP for this repo and report — do not duplicate.
git -C <repo> switch -c <release-branch> origin/<base_branch>
# Cherry-pick the ordered union, one commit at a time so a conflict is isolated:
git -C <repo> cherry-pick <sha>        # repeat for each sha, in order
git -C <repo> push -u origin <release-branch>
gh pr create --repo <org>/<repo> --base <pr.base> --head <release-branch> \
  --title "<rendered pr.title_template>" --body "<ticket list + commit summary>"
```

Render `pr.title_template` with `{date}`. PR body: the tickets rolled into this repo (name + url) and the commit shortlog. **One PR per repo** — four separate repos cannot share a PR.

### Phase 6 — On cherry-pick conflict

When `git cherry-pick` reports a conflict, **invoke the `resolving-merge-conflicts` skill** to resolve it (it resolves and continues — it never `--abort`s), then run `git -C <repo> cherry-pick --continue` and proceed to the next commit. After resolving, keep going through the remaining commits for that repo.

### Phase 7 — Report

Summarize: per repo — branch created, commits picked, PR url; any conflicts resolved; any UNRESOLVED tickets or skipped repos. Surface anything the operator must follow up on (unresolved tickets, discrepant SHAs, skipped repos).

## Guardrails

- **Config-driven, never hardcoded.** Org, repos, base branch all come from `config.yaml`.
- **Confirm gate is mandatory.** No branch/push/PR before Phase 4 approval.
- **Idempotent.** A pre-existing `qa-claude-<date>` branch means the run already happened — stop for that repo, don't duplicate commits.
- **Never drop a ticket silently.** Unresolved tickets ride through to the report.
- **Read is free, write is gated.** Fetching, listing, and diffing need no approval; branching/pushing/PRs do.
