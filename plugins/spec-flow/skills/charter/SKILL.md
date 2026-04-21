---
name: charter
description: Use when bootstrapping a new spec-flow project's architectural foundation — producing binding project-wide constraints (architecture, non-negotiables, tools, processes, flows, coding rules) via Socratic dialogue. Also handles updating charter files later (update mode) and migrating existing pre-charter projects (retrofit mode). Use whenever the user mentions "set up the charter", "define architecture rules", "establish non-negotiables", "onboard project foundation", or runs `/spec-flow:charter` directly. Runs before `prd` in the pipeline — charter binds every subsequent PRD, spec, plan, and implementation.
---

# Charter — Project-Wide Binding Constraints

Produce a codified, binding set of project-wide constraints in `docs/charter/` via Socratic dialogue. Charter content is referenced by every downstream skill (`prd`, `spec`, `plan`, `execute`) and binds every implementation.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` for all paths below. If the file is missing, default to `docs`.

Charter-specific config keys (added in piece 2 — safe defaults if absent):
- `charter.required` — default `false` in piece 1; piece 2 changes default to `true`
- `charter.doctrine_load` — default `[non-negotiables, architecture]` when absent; piece 2 wires doctrine

## Modes

Detected from current state:

- **Bootstrap mode** — `docs/charter/` does not exist. Full Socratic flow → write six files → QA → sign-off.
- **Update mode** (v2.0.0 piece 5) — `docs/charter/` exists and no legacy signals. User wants to change a charter file.
- **Retrofit mode** (piece 6) — legacy `docs/prd.md` or unprefixed `NN-xxx` detected in existing PRD. Reclassify + migrate. Not implemented until piece 6.

Explicit mode flags (optional): `/spec-flow:charter --update`, `/spec-flow:charter --retrofit`. Without flags, mode is auto-detected.

If retrofit signals detected (legacy layout or unprefixed NN-xxx) and piece 6 isn't shipped yet, respond: `"Retrofit mode lands in v2.0.0 piece 6. To update existing charter files in the meantime, run /spec-flow:charter --update."`

## Bootstrap Mode Workflow

### Phase 1.1: Auto-detect signals

Read the following if present, as priors for Socratic questions:

- `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`
- Build manifests: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle`
- TS/lint configs: `tsconfig.json`, `.eslintrc*`, `.ruff.toml`, `.prettierrc*`
- CI: `.github/workflows/*`, `.pre-commit-config.yaml`
- Existing `docs/architecture/` or `docs/adr/`
- Recent `git log --oneline -n 50`

Synthesize into a signal summary (internal — not yet shown to user).

### Phase 1.2: Prompt user for additional sources

Ask:

> "Any other places I should look? This can include:
> - **Local paths** — folders or files in this repo I wouldn't auto-detect (e.g., `internal/handbook/`, `docs/rfcs/`, `.devcontainer/`)
> - **External URLs** — team wikis, Notion pages, Confluence spaces, engineering handbooks, design docs, RFCs, style guides
> - **Sibling repos** — shared convention repos (user provides local path to a cloned working copy)
>
> Paste paths/links, or say 'none'."

For each source:
- **Local paths:** read with `Read`/`Glob`/`Grep`. Fold content into signal summary.
- **External URLs:** attempt `WebFetch`. On success, summarize into signals. On failure (auth-walled, offline, rate-limited), record as pending reference and inform user: *"Couldn't fetch `<url>`; treating as unverified reference. You'll need to summarize what it binds us to during Socratic."*
- **Sibling repos:** treat provided local path as a local-path source.

### Phase 1.3: Confirm combined signal summary

Present the union of auto-detected + user-supplied signals:

> "Here's what I've gathered:
> - [language] [version] / [framework] / [test runner] / [CI]
> - [detected architecture patterns]
> - [external references the user provided]
>
> Does this look right? Anything to add or correct?"

Only proceed to Phase 2 after user confirms.

### Phase 2: Socratic by file, one question at a time

Authoritative order (earlier files seed context for later ones):

1. `tools.md` — language/runtime, framework(s), test runner + coverage, linter + formatter, package manager, CI platform, approved/banned libraries
2. `architecture.md` — top-level layers, dependency direction, component ownership, boundaries
3. `flows.md` — request flow, auth flow, data-write path, other critical end-to-end flows
4. `coding-rules.md` — numbered `CR-xxx` entries, each tagged `Type: Rule` (inline) or `Type: Reference` (external Source)
5. `processes.md` — branching model, review policy, release cadence, CI gates, incident response
6. `non-negotiables.md` — numbered `NN-C-xxx` entries, structured schema (Type, Scope, Rationale, How QA verifies)

Rules:
- One question at a time. Multiple choice preferred.
- Use detection signals + user-supplied sources as priors. Don't ask questions whose answers were already captured.
- Any unresolved answer becomes a `[NEEDS CLARIFICATION]` marker in the draft. QA treats these as must-fix.
- For numbered entries, confirm `Type` explicitly: "Is this a **Rule** (inline body) or a **Reference** (link to external source)?"

### Phase 3: Write files

Load templates from `${CLAUDE_PLUGIN_ROOT}/templates/charter/`. Populate placeholders from Socratic answers. Write to `<docs_root>/charter/` (default `docs/charter/`). Each file gets front-matter:

```yaml
---
last_updated: YYYY-MM-DD   # today's date in ISO format
---
```

Charter files live on `main` (not a worktree — charter is project-global, not piece-scoped).

### Phase 4: QA loop

Read the agent template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-charter.md`.

**Iteration 1 (full review):** Compose prompt with `Input Mode: Full` — interpolate all six charter files, detection signal summary, user-supplied source list. Dispatch:

```
Agent({
  description: "Charter QA (iter 1, full)",
  prompt: <composed>,
  model: "opus"
})
```

**Iterations 2+ (focused re-review):** If iteration M-1 returned must-fix findings:

1. Read the fix template: `${CLAUDE_PLUGIN_ROOT}/agents/fix-doc.md` (existing agent — no `fix-charter` exists).
2. Dispatch fix-doc with prior findings + charter files + context. The fix agent does NOT commit; it ends its report with `## Diff of changes` containing its `git diff` of the charter files.
3. Extract that diff string. Hold it in orchestrator state as `charter_iter_M_fix_diff`.
4. Re-dispatch `qa-charter` with `Input Mode: Focused re-review`, prior iteration's must-fix findings, and `charter_iter_M_fix_diff`. Do NOT re-send the full charter.
5. **Circuit breaker:** after 3 QA iterations, escalate to human.
6. If fix-doc returns `Diff of changes: (none)` (all blocked), escalate.

**Clean iteration → Phase 5.**

### Phase 5: Human sign-off

Present the six charter files to the user for review. User approves → continue. User requests changes → make them (back to Phase 2 or 3 scoped to the requested change) → back to Phase 4 QA.

### Phase 6: Commit per file

One commit per file so `git blame` is useful:

```bash
git add <docs_root>/charter/architecture.md && git commit -m "charter: add architecture"
git add <docs_root>/charter/tools.md && git commit -m "charter: add tools"
git add <docs_root>/charter/flows.md && git commit -m "charter: add flows"
git add <docs_root>/charter/coding-rules.md && git commit -m "charter: add coding-rules"
git add <docs_root>/charter/processes.md && git commit -m "charter: add processes"
git add <docs_root>/charter/non-negotiables.md && git commit -m "charter: add non-negotiables"
```

### Phase 7: Doctrine wiring reminder

Since v2.0.0 piece 2, the SessionStart hook auto-loads charter files listed in `.spec-flow.yaml`'s `charter.doctrine_load` (default `[non-negotiables, architecture]`). Users need to run `/reload-plugins` (or start a new session) to pick up newly-authored charter into agent doctrine context.

Inform the user after Phase 6:
> "Charter files committed. Run `/reload-plugins` (or start a new session) so downstream skills and agents pick up the charter via SessionStart doctrine load. Future runs of `prd`, `spec`, `plan`, `execute`, and `status` will read from these files automatically."

## Update Mode Workflow (v2.0.0 piece 5)

Triggered when `docs/charter/` exists and no legacy signals are detected. Purpose: edit one or more charter files with the same Socratic+QA rigor as bootstrap, but scoped to only the touched files.

### Phase U1 — Ask which file(s) to edit

Present the six files with their current `last_updated` dates:

```
docs/charter/
  architecture.md        last_updated: 2026-02-15
  non-negotiables.md     last_updated: 2026-03-20
  tools.md               last_updated: 2026-02-15
  processes.md           last_updated: 2026-02-15
  flows.md               last_updated: 2026-02-15
  coding-rules.md        last_updated: 2026-04-01
```

Ask: "Which file(s) do you want to change? (comma-separated, or 'all')."

### Phase U2 — Scoped Socratic per selected file

For each selected file, run a Socratic flow scoped to that file's subject area (reuse the bootstrap Phase 2 question set for just that file). The skill proposes edits based on user answers — adds, modifications, or retirements.

**Retirement handling:** If the user wants to remove an `NN-C-xxx` or `CR-xxx` entry, ask:

> "Retire this entry (keep as tombstone in file for historical traceability — recommended) or delete entirely (removes all trace)? Retire is safer — pieces that previously cited this ID will have their citations flagged by QA, giving you a chance to upgrade them. Delete breaks that trail."

Default is **retire**. Retired entries get the tombstone format (strikethrough title + `RETIRED YYYY-MM-DD` marker + reason + list of pieces that cited them).

**Add handling:** New NN-C or CR entries get the next sequential unused ID (continuing past retired IDs — never reuse).

**Modify handling:** Keep the same ID, replace the body, bump `last_updated`.

### Phase U3 — Write and front-matter bump

Write each touched file to `<docs_root>/charter/<name>.md`. Update `last_updated: YYYY-MM-DD` in front-matter to today's date.

### Phase U4 — QA on touched files only

Dispatch `qa-charter` with `Input Mode: Full`, but pass only the touched files in the prompt (not all six). The agent's cross-file consistency checks still run — it will refer to non-touched files if the orchestrator attaches them as read-only context, but only findings on touched files are must-fix (non-touched-file drift is a different update run).

Iteration loop is the same as bootstrap mode's Phase 4 (fix-doc diff, focused re-review, 3-iter circuit breaker).

### Phase U5 — Sign-off and per-file commit

Human reviews diffs. On approval, commit each touched file separately:

```bash
git add <docs_root>/charter/<file>.md && git commit -m "charter: update <file> — <brief summary>"
```

### Phase U6 — Divergence awareness

After commit, check the manifest for pieces at `specced`, `planned`, or `implementing` status. For any piece whose `charter_snapshot` on any touched file is older than the new `last_updated`, inform the user:

> "The following pieces are now diverged: [list]. Run `/spec-flow:status --resolve <piece-name>` to walk through divergence resolution options."

Do NOT automatically re-spec or re-plan — human decides per piece.

## Retrofit Mode Workflow (v2.0.0 piece 6)

Triggered when retrofit signals are detected: legacy `<docs_root>/prd.md` at the flat path, unprefixed `NN-xxx` entries in PRD, or `<docs_root>/manifest.yaml` at the legacy path. Also invocable explicitly as `/spec-flow:charter --retrofit`.

### Entry confirmation

Before any file change, announce:

> "Detected a pre-charter spec-flow project (v1.5.x or earlier). Retrofit mode migrates to v2.0.0:
> - Reclassifies existing NN-xxx entries into NN-C (project-wide) and NN-P (product-specific)
> - Migrates docs/ layout to the new structure (prd/, backlog/, specs/ stays)
> - Rewrites existing specs and plans to cite the new namespaces
>
> This produces a series of review-gated commits — no destructive operations, every step is revertable.
>
> Proceed? (yes / dry-run / cancel)"

- **yes** → run the full pipeline (steps 1–9 below)
- **dry-run** → run pipeline in dry-run mode: walk each step, produce a combined diff preview, no commits. User reviews; can then re-invoke without dry-run to apply.
- **cancel** → abort, no changes made

### Step 1 — Snapshot pre-state

Create `<docs_root>/archive/pre-charter-migration-<YYYY-MM-DD>/` and copy current:
- `<docs_root>/prd.md` (or `<docs_root>/prd/prd.md` if already partially migrated)
- `<docs_root>/manifest.yaml` (or new location)
- `<docs_root>/specs/<piece>/spec.md` and `plan.md` for every piece

Commit: `chore: snapshot pre-charter state to archive/ before retrofit`

Pure safety net — if any later step is wrong, user has the pre-migration state verbatim. Print the commit SHA to the user so they know the rollback target.

### Step 2 — Reclassify NN-xxx

Socratic, one entry at a time. For each existing `NN-xxx` in the PRD:

> "NN-003: **[entry statement]**
>
> - **C** — project-wide rule (charter; applies across all pieces and products in this repo)
> - **P** — product-specific rule (stays in PRD; tied to this PRD only)
> - **R** — retire (no longer binding; will be tombstoned)"

Record all user choices in an in-memory mapping table. No file changes yet.

### Step 3 — Bootstrap Socratic for other five charter files

Run Phase 2 Socratic (from bootstrap mode above) for the five non-NN files: `architecture.md`, `tools.md`, `processes.md`, `flows.md`, `coding-rules.md`. Use detection signals (Phase 1.1) + any user-supplied sources (Phase 1.2) as priors.

Additionally, promote the **C** classified NN entries into `<docs_root>/charter/non-negotiables.md` with new sequential `NN-C-001`... IDs. Keep the mapping in state:

```
old NN-003 → NN-C-001
old NN-007 → NN-C-002
old NN-001 → NN-P-001 (stays in PRD, renumber on next step)
old NN-012 → RETIRED (tombstone)
```

Persist the mapping table to `<docs_root>/archive/pre-charter-migration-<date>/nn-mapping.md` for post-migration traceability.

Commit per charter file:
```bash
git add <docs_root>/charter/architecture.md && git commit -m "charter: add architecture (retrofit)"
git add <docs_root>/charter/tools.md && git commit -m "charter: add tools (retrofit)"
# ... and so on
git add <docs_root>/charter/non-negotiables.md && git commit -m "charter: add non-negotiables (from migrated NN-xxx)"
```

### Step 4 — Layout migration via `git mv`

Use `git mv` to preserve history:

```bash
git mv <docs_root>/prd.md <docs_root>/prd/prd.md
git mv <docs_root>/manifest.yaml <docs_root>/prd/manifest.yaml
git mv <docs_root>/improvement-backlog.md <docs_root>/backlog/backlog.md   # if exists
```

(Per-piece artifacts at `<docs_root>/specs/<piece>/` already match the new layout — no moves needed.)

Commit: `chore: migrate docs/ layout to charter structure (retrofit)`

### Step 5 — Rewrite PRD

Update `<docs_root>/prd/prd.md`:

1. Drop the unprefixed `## Non-Negotiables` section.
2. Add `## Non-Negotiables (Product)` section. Each NN-P classified entry gets renumbered per the mapping (NN-P-001, NN-P-002, ...) and converted to structured schema (Type / Statement / Scope / Rationale / How QA verifies).
3. Add `**Charter:** docs/charter/ (NN-C namespace — project-wide binding rules; applies to every piece)` reference line near the top (matches `templates/prd.md`).
4. Update any inline references in the PRD body text (e.g., "see NN-003" → "see NN-C-001").

Commit: `prd: promote NN to namespaces, reference charter (retrofit)`

### Step 6 — Per-piece spec rewrite (dispatch fix-doc)

For every `<docs_root>/specs/<piece>/spec.md` that cites unprefixed `NN-xxx`:

1. Read the spec.
2. Dispatch `fix-doc` with the mapping table + spec content:

   ```
   Agent({
     description: "Retrofit: rewrite NN citations in spec/<piece>",
     prompt: <fix-doc.md + mapping table + spec content + "Rewrite every NN-xxx citation to use the new NN-C-xxx or NN-P-xxx ID per this mapping. Retired entries → return BLOCKED citing the piece cannot drop the reference without human judgment.">,
     model: "sonnet"
   })
   ```

3. `fix-doc` returns a diff. Orchestrator applies and stages.
4. Update `charter_snapshot` front-matter with today's date for every charter file.
5. If any citation maps to RETIRED, escalate: *"Piece `<piece>`'s spec cites NN-012 which you retired during reclassification. How should I handle this — drop the citation, upgrade to a specific superseding entry, or re-open the piece for re-spec?"*

Commit per piece: `spec(<piece>): update NN citations to charter namespaces (retrofit)`

### Step 7 — Per-piece plan rewrite

Same loop as step 6 for every `<docs_root>/specs/<piece>/plan.md` where plans exist. Updates per-phase "Charter constraints honored in this phase" slots (if they exist; older plans without the slot just get citation rewrites in the body).

Retrofit also auto-populates per-phase slots by allocating each cited entry to the phase whose scope overlaps — if ambiguous, escalate to the user.

Commit per piece: `plan(<piece>): update NN citations to charter namespaces (retrofit)`

### Step 8 — Update `.spec-flow.yaml`

Ensure `.spec-flow.yaml` has the charter block with retrofit-appropriate defaults:

```yaml
charter:
  required: true                                    # retrofitted project has charter; enforce on future PRDs
  doctrine_load: [non-negotiables, architecture]
```

If the file already has these keys, leave them as-is. If `required: false`, flip to `true` only with user confirmation.

Commit: `config: enable charter stage (retrofit)`

### Step 9 — Full QA sweep

Dispatch reviewers sequentially (not parallel — the orchestrator's single-window context budget and each review's must-fix resolution may depend on the prior):

1. `qa-charter` on the new charter (iter-1 full + loop — see bootstrap Phase 4). Retrofit-mode additions (checks 14 + 15 in qa-charter.md) are active: re-keying completeness + spec back-reference integrity.
2. For every rewritten spec: `qa-spec` iter-1 full.
3. For every rewritten plan: `qa-plan` iter-1 full.

Any must-fix finding loops back to the appropriate fix-doc + re-review. Human sign-off before calling retrofit complete.

### Dry-run mode (`--retrofit --dry-run`)

Walks all nine steps using an internal staging area (e.g., orchestrator's in-memory buffer or a scratch `git stash`). Produces a combined unified diff preview of every planned change. No commits. No file writes outside the staging area. Output: human-readable summary of each step's planned changes, plus the full diff.

Users can then re-invoke without `--dry-run` to apply for real.

### Opt-out (`/spec-flow:charter --decline`)

Writes `.spec-flow.yaml` with `charter.required: false` and creates a marker file `<docs_root>/.charter-declined` with a short note:

```
Charter declined on 2026-04-20.
Reason: <user-supplied>
Reversible: run /spec-flow:charter at any time to enter retrofit mode.
```

Downstream skills (prd, spec, plan, execute, status) skip all charter checks when `charter.required: false`. Existing v1.5.x behavior is fully preserved. Retrofit can be run at any time later — the decline is reversible.

Commit: `config: decline charter stage (reversible)`

### Rollback

No destructive commands anywhere in the pipeline. Options to revert:

- `git revert <step-N-sha>` — reverts a specific step while preserving later commits (may introduce conflicts if later steps build on the reverted step; resolve per normal git workflow).
- `git reset --hard <pre-state-snapshot-sha>` — nuclear option. Moves back to the snapshot commit from step 1. Requires user confirmation since it rewrites history locally.

The pre-state snapshot in step 1 is always available via `git log --follow <docs_root>/archive/pre-charter-migration-<date>/` — even if the user discards the migration commits, the snapshot copies remain.

## No QA Gate Between Charter Skill and User

User is directly involved throughout Socratic. The `qa-charter` agent is the only automated review.
