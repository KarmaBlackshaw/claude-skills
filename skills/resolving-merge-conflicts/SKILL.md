---
name: resolving-merge-conflicts
description: "Use when you need to resolve an in-progress git merge, rebase, or cherry-pick conflict — including conflicts raised by the sprint-release-cherry-pick skill."
---

# Resolving Merge Conflicts

1. **See the current state** of the merge/rebase/cherry-pick. Check git history, and the conflicting files.

2. **Find the primary sources** for each conflict. Understand deeply why each change was made, and what the original intent was. Read the commit messages, check the PRs, check original issues/tickets.

3. **Resolve each hunk.** Preserve both intents where possible. Where incompatible, pick the one matching the merge's stated goal and note the trade-off. Do **not** invent new behaviour. Always resolve; never `--abort`.

4. Discover the project's **automated checks** and run them — typically typecheck, then tests, then format. Fix anything the merge broke.

5. **Finish the merge/rebase/cherry-pick.** Stage everything and commit (`git rebase --continue` / `git cherry-pick --continue`). If rebasing or cherry-picking a series, continue until all commits are applied.
