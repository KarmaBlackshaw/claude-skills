# Design — `sprint-release-cherry-pick` skill

**Date:** 2026-07-16
**Status:** Approved, implemented

## Purpose

Automate cutting a QA release from a ClickUp sprint: take the active sprint's tickets at a configured status (`Ready for Release` by default), resolve each ticket's linked GitHub branch/commits, and — per repo — cut `qa-claude-<date>` off `qa`, cherry-pick those commits onto it, and open a PR back into `qa`.

## Locked decisions

| Decision | Choice |
|----------|--------|
| Deliverable | A reusable skill (not a one-off live run). |
| Targets | **4 separate GitHub repos**: `doctor-dashboard`, `admin-dashboard`, `patient-dashboard`, `patient-portal`. |
| Commit link | ClickUp↔GitHub integration — read the ticket's linked **branch + commits**; branch name is the key, fetch all commits on it. |
| Routing | By the repo the branch/commits live in. |
| Base / PR | New branch `qa-claude-<YYYY-MM-DD>` cut off `qa`; PR back **into `qa`**; one PR per repo. |
| Sprint find | The sprint List/Folder flagged **active / in-progress** by status. |
| Branch source of truth | **ClickUp first, git-verify** — trust ClickUp's branch name, then confirm it exists on the remote before picking. |
| Commit source of truth | `git rev-list --reverse origin/qa..origin/<branch>` (authoritative over ClickUp's raw SHA list). |
| Conflicts | Hand off to a **new companion skill `resolving-merge-conflicts`** (resolve & continue, never `--abort`). |
| Config | **Separate gitignored `config.yaml`** (copied from `config.example.yaml`) — holds org, repos, sprint ids, `ticket_status`. |
| `ticket_status` | In config; default `Ready for Release`, swap to `Ready for Testing - Staging` for test runs. |
| Safety | Dry-run plan + explicit confirm gate before any branch/push/PR; idempotent on the dated branch; no silent ticket drops. |

## Approach chosen

Pure-markdown procedure + `config.yaml` + companion conflict skill (Approach A). Matches the four existing skills (all script-free procedures), zero code to maintain, retarget by editing config. Rejected: bundled bash helper (over-built, awkward conflict handoff), fully-generic no-config (operator chose a config file).

## Files

```
skills/sprint-release-cherry-pick/
  SKILL.md              # 8-phase procedure
  config.example.yaml   # operator copies → config.yaml (gitignored)
  README.md
skills/resolving-merge-conflicts/
  SKILL.md              # companion, invoked on cherry-pick conflict
```
Plus: `.gitignore` += `skills/*/config.yaml`; `skills/README.md` table += 2 rows.

## Runtime phases

1. Load config (compute dated branch name once, reuse across repos).
2. Find active sprint in ClickUp (`by_status`; ask if ambiguous).
3. Collect tickets at `ticket_status`.
4. Resolve branch+commits per ticket — ClickUp first, git-verify; fallback = grep remote branches for ticket id; route to repo; commits = `origin/qa..origin/<branch>`; union+dedupe per repo; drop commits already on `qa`.
5. Dry-run plan → **confirm gate**.
6. Per repo: fetch, branch off `qa`, cherry-pick ordered union, push, `gh pr create --base qa`.
7. On conflict → invoke `resolving-merge-conflicts`, then `cherry-pick --continue`.
8. Report (branches, PRs, conflicts, UNRESOLVED tickets, skipped repos).

## Known risk

ClickUp's GitHub-linked commit/branch data may not surface cleanly via the MCP API (it's a UI integration). Mitigated by the id-grep fallback in Phase 4 and the git-verify step — git remains the source of truth for what actually gets picked.

## Prerequisites at run time

ClickUp MCP connector authorized; `gh` authenticated; `git` on PATH; the 4 repos cloned under `github.local_root`; `resolving-merge-conflicts` installed.
