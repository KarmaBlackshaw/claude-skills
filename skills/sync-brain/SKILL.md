---
name: sync-brain
description: Pull or push long-term memory between the current repo and a centralized Obsidian vault (hub-and-spoke), or write a coding rule into a chosen Standards tier. Use for "/sync-brain", "sync brain", "/sync-brain global <rule>", "/sync-brain org <rule>", "/sync-brain repo <rule>", "pull context", "push learnings", "save session to obsidian", or at the start/end of a session. Also fires without a slash command when the user states a durable convention and names a scope: "global rule", "make this global", "applies to all my projects", "org rule", "org standard", "repo rule", "just this repo", "add this to the standards", "always do X from now on".
---

# sync-brain

Hub-and-spoke long-term memory. The **hub** is a global `Learnings.md` in an Obsidian vault; each repo is a **spoke** — a folder-note `Projects/<repo>/<repo>.md` session log (conventions sit in the sibling `<repo> — Coding Rules.md`). Always resolve the spoke path from `ACTIVE_CONTEXT` in `CLAUDE.local.md`, never by hardcoded filename. This skill moves context between the current repo and the vault.

## Path discovery (do this first, every time)

**Never hardcode vault paths.** Read them from the repo root's `CLAUDE.local.md` (gitignored). Grep the machine-readable `KEY=value` block for:

- `ACTIVE_CONTEXT=` → this repo's session log
- `LEARNINGS=` → global cross-repo learnings
- `CODING_RULES=` → this repo's conventions synced from `CLAUDE.md`
- `STANDARDS=` → org-shared coding standards (one per vault; injected in full every session)
- `GLOBAL_STANDARDS=` → **cross-org, cross-stack** standards — one file for ALL repos, every vault. Rarely set explicitly: the recall hook defaults to `$HOME/Documents/obsidian/Standards.md` (override with the `OBSIDIAN_GLOBAL_STANDARDS` env var) and injects it **ungated**, so it reaches repos with no `CLAUDE.local.md`. Resolve it the same way when pushing.
- `THREADS=` → this repo's open-threads ledger (durable follow-ups; survives session rotation)
- `DOMAINS=` → (optional override) the Learnings spokes this repo uses. Normally **auto-detected** from the repo's manifests by `obsidian-domains.sh` (Workflow always; `all` = every spoke); it narrows the session-start index and point-of-use retrieval.
- `GLOBAL_LEARNINGS=` → **cross-org, cross-stack lessons** — `<vaults-root>/Learnings.md` index + `Learnings/` spokes, one dir above the vaults (the lessons twin of `GLOBAL_STANDARDS`). Rarely set: derived as `$(dirname "$(dirname "$LEARNINGS")")/Learnings`.

```bash
grep -m1 '^ACTIVE_CONTEXT=' CLAUDE.local.md | cut -d= -f2-
grep -m1 '^LEARNINGS=' CLAUDE.local.md | cut -d= -f2-
```

Lesson **bodies** reach a session on demand: `obsidian-retrieve.sh` scores every memory unit — each `###` lesson in the org and global spokes, each legacy atomic note, and each `- **rule** —` bullet in the three Standards tiers — against each prompt and each file about to be edited, and injects the top matches in full (header hits weigh 3×, body hits 1×). So a lesson's `###` header — and a rule's bold lead clause — is its **retrieval key**: write it with the concrete words a future prompt or filename will contain (the API name, the error string, the symptom), not an abstract moral.

The lesson **detail** lives in four **domain spokes** under `<notes-dir>/` (the `LEARNINGS` path with its extension removed, `…/Learnings.md` → `…/Learnings/`): `Frontend.md` (Vue / TS / data-model & UI), `Backend-Data.md` (Supabase / PostgREST / API), `Mobile.md` (React Native / Expo), `Workflow.md` (memory / agents / build pipeline / shell). Each groups lessons under `##`/`###` headers. `LEARNINGS` itself is only the index — the SessionStart hook injects it alone; spokes are read on demand. (Legacy per-lesson atomic notes are archived under `<notes-dir>/_archive/`.)

If `CLAUDE.local.md` is missing, tell the user this repo isn't wired to the vault yet and stop.

## Modes

Modes, parsed from the argument after `/sync-brain` (default `pull`):

| Command | Does |
|---|---|
| `/sync-brain pull` | load memory into context |
| `/sync-brain push [global\|org\|repo]` | persist the session; optional tier overrides routing for what it promotes |
| **`/sync-brain global <rule>`** | write one rule to `GLOBAL_STANDARDS` — every repo, every org, every stack |
| **`/sync-brain org <rule>`** | write one rule to `STANDARDS` — this vault's repos |
| **`/sync-brain repo <rule>`** | write one rule to `CODING_RULES` — this repo only |
| `/sync-brain rule <text>` | write one rule, tier undecided → run the A→D decision and report which it picked |

`global` / `org` / `repo` are the tier the user chose. **Obey it — never re-derive the tier or argue it.** They all run the same **`rule`** flow below.

**Also accepted without a slash command.** When the user states a durable convention and names a scope in plain English, map it to the matching command and run it — don't make them re-issue it as `/sync-brain`:

| The user says | Read as |
|---|---|
| "global rule — X", "make this global", "applies to all my projects", "every repo", "all orgs" | `/sync-brain global X` |
| "org rule — X", "org standard", "for all winona repos", "all the axpi apps", "everything in this vault" | `/sync-brain org X` |
| "repo rule — X", "just this repo", "only here", "this project only" | `/sync-brain repo X` |
| "add this to the standards", "remember this rule", "always do X from now on" — **no scope named** | `/sync-brain rule X` → run A→D, then state the tier you picked |

Scope words beat everything: if the user names a tier, that tier wins even when A→D would disagree. Say the tier back in the output line so a wrong read is caught immediately.

### `pull`
Load memory into context so you start informed.
1. Read `LEARNINGS` and `ACTIVE_CONTEXT`.
2. Summarize back: the current active-context state + any learnings relevant to what the user is about to do.

The `obsidian-recall.sh` SessionStart hook already auto-pulls; use this for a manual mid-session refresh.

### `rule` flow — `/sync-brain {global|org|repo|rule} <text>`
Write ONE always-on rule straight into a Standards tier, now — no session push, no inference. Use it the moment you decide a convention, instead of hoping the end-of-session push routes it right.

- **Tier given** (`global` / `org` / `repo`) — that's an explicit override. **Obey it; do not re-run the step-4 A→D decision or argue the tier.** The user knows which tier they mean.
- **Tier omitted** — run the step-4 A→D decision, then say which tier you picked.

Resolve the target, then write:

| Tier | File |
|---|---|
| `global` | `$GLOBAL_STANDARDS` → `obsidian/Standards.md` (every repo, every org, every stack) |
| `org` | `$STANDARDS` → `<vault>/Standards.md` |
| `repo` | `$CODING_RULES` |

1. **Tighten the text into one bullet** — bold lead clause, then the *why* or the counter-example. Match the file's existing voice; don't paste the user's sentence verbatim if it's loose. `- **<imperative>** — <why / what instead>.`
2. **Dedup before writing.** Grep the target for the same rule. Already there ⇒ refine that bullet in place, don't add a second. On `global`, also strip the rule from every org file that restates it: `grep -ril '<phrase>' "$(dirname "$G")"/*/Standards.md`.
3. **Pick the `##` section** by matching an existing heading in the file; only add a new `##` if none fits.
4. **Bump the file's `updated:`** to today.
5. Print the tier line and the final bullet — nothing else:
   ```
   → global: obsidian/Standards.md § Principles
   - **Never mutate a prop** — emit an event and let the owner write; a mutated prop desyncs on the next parent render.
   ```

Rules are edits to a tiny always-on file, so an Edit here is fine — unlike the session upsert, the diff is worth seeing.

### `push [global|org|repo]`
Persist this session's outcome. **A tier argument overrides step-4 routing for everything this session promotes** — `/sync-brain push global` sends every rule it promotes to `$GLOBAL_STANDARDS`, `push org` to `$STANDARDS`, `push repo` to `$CODING_RULES`. Situational insights still go to a Learnings spoke regardless (they aren't rules). With no tier, step 4 decides per takeaway as normal.

Default target is the **spoke** (`ACTIVE_CONTEXT`). The **hub** (`LEARNINGS`) is a small curated set — not a dump. Nothing important is lost on rotation because the two things worth keeping have durable homes: **learnings** graduate to the hub (gate below), and **follow-ups** land in the **THREADS ledger**.

**Two paths persist sessions — they promote differently.** The **unattended auto-capture path** (`obsidian-capture.sh` SessionEnd → `obsidian-drain.sh` headless synthesizer) judges every session with no human in the loop, so it errs toward silence: headline to the spoke, hub promotion **rare**. A **manual `/sync-brain push`** is the opposite signal — you ran it because this session mattered, so it errs toward capturing: when a takeaway clears the three criteria below, promote it to the hub **immediately**, don't defer it as "too rare." Same gate, two postures. (No collision between the paths: the drain dedups against what's already recorded, so a session you push manually won't get re-promoted unattended.)
1. **Upsert** this session's entry in the Sessions list (newest first) using the **Session-End Template** below (a single ≤12-word headline line). **Do this with one shell command, not the Edit tool** — an Edit renders a diff block in the chat, which the user does not want to see. The command is a single upsert keyed on the `<!-- session: <id> -->` marker: if that marker already exists (you saved earlier this session, now correcting the headline), it replaces the `### ` headline line above the marker in place; otherwise it prepends a new entry under the `## Sessions (newest first)` line:

   ```bash
   S="$(grep -m1 '^ACTIVE_CONTEXT=' CLAUDE.local.md | cut -d= -f2-)"; awk -v h="### $(date +%F) — <HEADLINE>" -v m='<!-- session: <id> -->' '{a[NR]=$0} $0==m{seen=1} /^## Sessions \(newest first\)/{hdr=NR} END{if(seen){for(i=1;i<=NR;i++){if(a[i+1]==m&&a[i]~/^### /)a[i]=h; print a[i]}}else{for(i=1;i<=NR;i++){print a[i]; if(i==hdr){print ""; print h; print m}}}}' "$S" > "$S.tmp" && mv "$S.tmp" "$S"
   ```

   If a Stop-hook checkpoint handed you a `<!-- session: <id> -->` marker, use it (the checkpoint greps for it to verify the write landed). Re-running with the same marker updates the existing headline in place instead of duplicating — so a corrected outcome overwrites the first pass. After the command, print only `Saved.`.
2. **No rotation by default.** Entries are one line each, so the spoke grows slowly; leave old entries in place. <!-- ponytail: the recall hook injects the whole spoke every session, so this grows context ~1 line/session — a far ceiling. If it ever bloats, add a trim to the awk command (keep newest ~20 `### ` blocks). -->
3. **Optional — only if it matters:** if a follow-up genuinely needs to survive, append one `open` row to the `THREADS` ledger the same one-command way. Skip otherwise.

**Promotion gate — the three criteria.** This gate decides *whether* a takeaway earns a durable home at all; **step 4 decides which of the four homes it gets** — never let the gate itself imply `LEARNINGS`. Promote when ALL hold. On a **manual push**, meeting all three IS the trigger — promote now. On the **auto-drain**, apply them conservatively (err toward not promoting):
- **Reusable** beyond this one session — you'd genuinely apply it again.
- **Behavior-changing** — it would alter a future decision, not just record what happened.
- **Not already covered** — grep the hub first; no existing entry says the same thing.

A takeaway failing any gate stays in `ACTIVE_CONTEXT`. Anything that passes goes through the step-4 routing decision below — stack-specific material (Supabase, TS, Vue…) is promotable, but it files under a stack heading in the **org** tier or a Learnings spoke, never as a loose top-level note and never in the global file.

4. **Route every takeaway that passed the gate — run the decision, never default.** *(Tier given on the command line — `push global|org|repo` — or named in plain English? That's the answer for every rule this session; skip A→D, keep only branch A's rule-vs-insight split, and go write.)* Each takeaway lands in exactly ONE of four files. Do not skip this and dump everything in `LEARNINGS`; do not guess the tier from vibes. Resolve the paths first, then answer A→D **in order** and stop at the first answer that fires:

   ```bash
   G="$(grep -m1 '^GLOBAL_STANDARDS=' CLAUDE.local.md | cut -d= -f2-)"; : "${G:=${OBSIDIAN_GLOBAL_STANDARDS:-$HOME/Documents/obsidian/Standards.md}}"
   S="$(grep -m1 '^STANDARDS=' CLAUDE.local.md | cut -d= -f2-)"
   R="$(grep -m1 '^CODING_RULES=' CLAUDE.local.md | cut -d= -f2-)"
   L="$(grep -m1 '^LEARNINGS=' CLAUDE.local.md | cut -d= -f2-)"
   GL="$(grep -m1 '^GLOBAL_LEARNINGS=' CLAUDE.local.md | cut -d= -f2-)"; : "${GL:=$(dirname "$(dirname "$L")")/Learnings}"
   ```

   **A. Is it an always-on rule?** An imperative you'd follow on every applicable line with no trigger ("no `any`", "NativeWind only", "import lodash per-method"). A *situational* insight — it only matters once you hit a specific bug, API, or condition ("PostgREST returns 200 with an empty array when RLS blocks the row") — is **not** a rule.
   → **No** ⇒ a **lesson**. Apply check **D** to it (would it hold in a repo of a different org AND a different stack?): **Yes** ⇒ the **global** spoke `$GL/<Spoke>.md` + one index line in `$GL.md` (`→ global lesson:`); **No** ⇒ this vault's spoke `Learnings/<Spoke>.md` (`→ lesson:`). Stop. (See **Curate in domain spokes** below — same format in both tiers.)
   → Yes ⇒ B.

   **B. Does the rule name something only THIS repo has?** A private component/composable/store, a path, a service, a config that exists nowhere else.
   → **Yes** ⇒ **`CODING_RULES`** (`$R`). Stop.
   → No ⇒ C.

   **C. Evidence check — is the same rule already written in another org's `Standards.md`?** A rule you've independently restated for a second org IS proven cross-org; that's the strongest signal available, so check it before judging.

   ```bash
   grep -ril '<distinctive phrase from the rule>' "$(dirname "$G")"/*/Standards.md
   ```

   → **Hit in ≥1 org file other than `$S`** ⇒ **`GLOBAL_STANDARDS`** (`$G`), and **strip the duplicate bullets from every org file** in the same pass — a rule restated per-org is exactly the drift this ladder exists to kill. Stop.
   → No hit ⇒ D.

   **D. Would you follow it in a repo of a different org AND a different stack?** Test it concretely: name a repo in another vault with a different stack and ask whether the rule still reads as correct there. A rule that mentions a framework, a vendor, or a domain (Vue, Supabase, NativeWind, patient data, the `axi` library) is **org-tier**, not global — the global file must stay stack-agnostic.
   → **Yes** ⇒ **`GLOBAL_STANDARDS`** (`$G`).
   → **No** ⇒ **`STANDARDS`** (`$S`).

   **Write it** as one tight bullet under the matching `##` in the chosen file, bump that file's `updated:`, and say which tier you picked in one line (`→ global: <rule>`) so the choice is auditable. **Then stop** — never write the same rule to two tiers. Keep `$G` especially tight: every line there costs tokens in every session in every repo, so a rule that only *might* be global goes to `$S` and gets promoted later by check C when a second org proves it.

**Curate in domain spokes.** The hub `LEARNINGS` is an **index** — one summary line per lesson, grouped under its domain-spoke section. Each lesson's full detail is a `###` subsection inside the matching spoke (`Frontend` / `Backend-Data` / `Mobile` / `Workflow`). To promote a lesson that passed the gate:
- **Pick the spoke by domain**, and let the `###` header be the lesson's one-line claim (the dedup key — scan the spoke's existing headers first). It is also the **retrieval key**: front-load the concrete trigger words (API/prop/error/symptom) a future prompt or filename will contain — `\`@focus\` dead on wrapper-div components` retrieves; `Events can be surprising` never will.
- **Existing lesson on the topic?** Refine that `###` subsection in place (tighten, add the nuance, bump the spoke's `updated:`). Do NOT add a near-duplicate; leave its index line as-is.
- **New lesson?** Append a `###` subsection under the right `##` area in the spoke (create the spoke file with `tags: [learning]` frontmatter if it doesn't exist yet; body = the mechanism + fix, keep a `Source:` line), then add ONE index line under that spoke's section in `LEARNINGS`: `- **<one-line summary>** — <terse how>`.
- **Never** put a lesson body in `LEARNINGS`, and **never** create a new per-lesson file — the SessionStart hook injects only the index; bloating it or re-fragmenting into atomic notes defeats the token budget the spokes exist to protect.

**Soft cap.** If a spoke's `##` area passes ~15–20 lessons or reads noisy, merge related `###` subsections into one sharper lesson (merge the bodies, collapse their index lines).

5. Only if step 4 routed a takeaway to a **Learnings spoke** (branch A): write it to that spoke + refresh the hub index (an Edit is fine here — a promotion is worth seeing). Otherwise there is nothing else to write.

   **Visible output = `Saved.`, plus one line per promotion naming its tier** — nothing else. No summary, no counts, no narration of these steps. If nothing was promoted, `Saved.` alone (or `Nothing to save.` when the session was trivial/read-only).

   ```
   → global: Import lodash per-method, never the barrel import
   → org: Model the FULL API response in its DTO
   Saved.
   ```

## Session-End Template

A short headline — **≤ 12 words, one clause**. No bullet block, no semicolons, no "and… and…" chaining, no parenthetical detail. Just the single most important thing that changed. The durable detail lives elsewhere (follow-ups → THREADS ledger, learnings → the hub via the Promotion gate), so the entry is only a title:

```markdown
### YYYY-MM-DD — <≤12-word headline>
```

Good: `### 2026-07-17 — Collapse header arrow-circle into one IconArrowCircle SVG`
Too long: `### 2026-07-17 — Collapsed arrow-circle into IconArrowCircle SVG (ring+arrow, filled prop…); deleted TheHeaderArrowCircle, moved color to text-* at 4 call sites, typecheck clean`

If a Stop-hook checkpoint handed you a `<!-- session: <id> -->` marker, put it on the next line so the checkpoint can verify the write landed.

## Threads-Ledger Template (`THREADS` — `<repo> — Threads.md`)

Durable open action items — the one place follow-ups outlive session rotation. New follow-ups land as `open`; resolved ones flip to `done` (keep the row for history). The recall hook injects only the `open` rows each session start.

```markdown
| status | thread | opened | source |
|--------|--------|--------|--------|
| open | <short, actionable — what to do next> | YYYY-MM-DD | <session title or [[wikilink]]> |
| done | <resolved item> | YYYY-MM-DD | <session title> |
```

## Domain-Spoke Lesson format (`<notes-dir>/{Frontend,Backend-Data,Mobile,Workflow}.md`)

Each spoke carries `tags: [learning]` frontmatter and an `updated:` date. A lesson is a `###` subsection under a `##` area:

```markdown
### <Lesson title — the claim in one line>

<the mechanism: what happens, why, and the fix — a short paragraph, not a session log>

Source: <repo> · YYYY-MM-DD
```

## Rules
- Summarize only what actually happened this session — never invent entries.
- Use the real current date.
- On the **auto-drain** path, promotion is the exception — most unattended sessions add nothing beyond the spoke headline. On a **manual `/sync-brain push`**, promote any takeaway that clears the three criteria immediately — you running push is the signal it's worth keeping.
- **Never skip the step-4 routing decision.** A push that promotes anything must name the tier it chose (`→ global:` / `→ org:` / `→ repo:` / `→ global lesson:` / `→ lesson:`). Defaulting everything to `LEARNINGS` is the failure mode this step exists to prevent.
- Keep the spoke (`<repo>.md`, resolved from `ACTIVE_CONTEXT`) lean; keep `Learnings.md` small and curated — refine existing entries over appending new ones.
- Pass file content through unchanged except for the edits above — in particular, preserve the spoke's `tags: [project/<repo>]` frontmatter (it's the note's graph hub label; see setup-obsidian-memory → **Graph project tag**).
- Domain spokes (`Learnings/{Frontend,Backend-Data,Mobile,Workflow}.md`) stay tagged `[learning]` only — never add a `project/<repo>` tag; they're cross-repo and hub to `[[Learnings]]`.
