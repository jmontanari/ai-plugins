---
name: status
description: Use when starting a session on a spec-flow project, checking progress on the spec-flow pipeline, or asking what to work on next (e.g. "where are we", "what's next", "pipeline status", "anything in flight"). Shows PRD coverage, current piece state, phase progress, and recommends the next spec-flow action. Use whenever the user wants a snapshot of spec-flow pipeline state, even if they don't say "status" explicitly.
---

# Pipeline Status

Show the current state of the development pipeline and recommend what to work on next.

## Invocation forms

- `/spec-flow:status` — all-PRDs default view (hides archived PRDs).
- `/spec-flow:status --include-archived` (or `-a`) — all-PRDs view including any PRD whose `prd.md` front-matter has `status: archived`.
- `/spec-flow:status <prd-slug>` — drill-in mode for one PRD, piece-by-piece detail.
- `/spec-flow:status --resolve <piece-slug>` — divergence-resolution walk-through for a single piece (see "Divergence Resolution" below; unrelated to the scan flow).

Argument parsing order: check for `--resolve` first (if present, jump to the Divergence Resolution section). Otherwise, any non-flag positional argument is treated as a `<prd-slug>` and routes to drill-in mode. `--include-archived` / `-a` is only meaningful in the default all-PRDs view; in drill-in mode the named PRD is always shown regardless of its lifecycle state.

## Workflow (scan flow)

**Order:** PRD discovery → all-PRDs default view → drill-in mode → archive filter → drift surfacing.

0. **Load config:** Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

1. **PRD discovery (FR-007):** Scan `<docs_root>/prds/` for subdirectories containing `prd.md`. Each `<docs_root>/prds/<prd-slug>/prd.md` is one PRD. Read its YAML front-matter: `slug:`, `status:` (one of `drafting | active | shipped | archived`), `version:`.

   **Pre-v3 fallback:** If the scan of `<docs_root>/prds/` finds no `prd.md` files (directory missing, empty, or no subdirectory contains a `prd.md`), print exactly one line and stop:

   > ``No PRDs found at `docs/prds/`. Run `/spec-flow:migrate` to upgrade from v1.x/v2.x layout, or `/spec-flow:prd <slug>` to create the first PRD.``

   Do not walk legacy `<docs_root>/prd/` or `<docs_root>/specs/` paths — v1.x/v2.x runtime coexistence is out of scope. The user must run `/spec-flow:migrate` to advance.

1a. **Read charter state:** Check `<docs_root>/charter/` directory. If present, read each file's `last_updated:` front-matter into memory for the drift comparison in step 4. If absent, note charter is missing (only surface if `charter.required: true` in config).

2. **Archive filter (FR-020 / AC-8):** Partition the discovered PRDs into `active-set` (lifecycle state ≠ `archived`) and `archived-set` (lifecycle state == `archived`).

   - Default invocation: present only the `active-set`.
   - `--include-archived` / `-a`: present both sets (archived PRDs are grouped in a separate "Archived" section of the dashboard).
   - Archive state is determined solely by the `prd.md` front-matter `status:` value — there is no `docs/archive/` directory (per FR-020, archival is in-place).

3. **Per-PRD parse (default all-PRDs view — FR-007):** For each PRD in the presentation set, read its manifest at `<docs_root>/prds/<prd-slug>/manifest.yaml`. Extract the pieces list and aggregate piece counts by status. Use the piece-status state machine vocabulary verbatim:

   | Status | Meaning |
   |--------|---------|
   | `open` | Listed in manifest; no spec yet. |
   | `specced` | `spec.md` written and signed off; no plan yet. |
   | `planned` | `plan.md` written and signed off; ready for execute. |
   | `in-progress` | `execute` is running on the piece. |
   | `merged` | Piece's branch merged to `main`/`master`. |
   | `done` | Backward-compatible alias for `merged`. |
   | `superseded` | Abandoned and replaced. |
   | `blocked` | External dependency or unresolved decision halts progress. |

4. **Drift surfacing per active PRD (FR-008 passive):** For each non-archived PRD, iterate its pieces whose status is `specced`, `planned`, or `in-progress`. For each such piece, read its `charter_snapshot:` front-matter from `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/spec.md` (and `plan.md` if present). Compare every snapshot date against the current `<docs_root>/charter/<file>.md` `last_updated:` value loaded in step 1a. If any current `last_updated:` is newer than the corresponding snapshot, flag the piece as **diverged** and record which file(s) changed.

   Status surfaces drift only — it does NOT dispatch the drift-mode `qa-spec` agent. Active resolution (FR-009) is the job of `spec`, `plan`, `execute`, and `prd --update` during their Phase-1 context load. When this skill surfaces drift, it points the user at `/spec-flow:spec <piece>` / `/spec-flow:plan <piece>` / `/spec-flow:execute <piece>` (each of which triggers resolution) or at `/spec-flow:status --resolve <piece>` for the walk-through flow documented below.

   Pieces with no `charter_snapshot:` front-matter (pre-charter pieces) are skipped silently.

5. **Check worktrees:** Run `git worktree list` to identify active worktrees. Match against the v3 branch/path convention `worktrees/prd-<prd-slug>/piece-<piece-slug>/` with branches `{spec,plan,execute}/<prd-slug>-<piece-slug>` so the correct PRD grouping is displayed alongside each piece.

6. **Present status — all-PRDs default view:** Group output by PRD. For each PRD in the `active-set` (and the `archived-set` if `--include-archived`):

   ```
   Charter: present (last_updated 2026-04-20)    <-- omit line if docs/charter/ absent

   PRD: auth (active, v1)                        <-- from docs/prds/auth/prd.md
     Pieces: 5 total — 2 merged, 1 in-progress, 1 planned, 1 open
     ⚠ Drift flagged on 1 piece (token-refresh: non-negotiables)

   PRD: billing (drafting, v1)                   <-- from docs/prds/billing/prd.md
     Pieces: 3 total — 3 open

   PRD: reports (shipped, v2)                    <-- from docs/prds/reports/prd.md
     Pieces: 4 total — 4 merged

   Archived (shown because --include-archived):  <-- header only when flag is set
     PRD: legacy (archived, v1)                  <-- from docs/prds/legacy/prd.md

   Next up: auth/token-refresh (in-progress, resume execute — Phase 3)
   Blocked: billing/invoice-pdf (depends_on: auth/token-refresh, currently in-progress)
   ```

   Archived PRDs are hidden in the default view and surfaced only under the "Archived" header when `--include-archived` is passed (FR-020 / AC-8).

7. **Present status — drill-in mode (FR-007 / AC-9):** When invoked as `/spec-flow:status <prd-slug>`, narrow output to the named PRD only. Resolve it against `<docs_root>/prds/<prd-slug>/prd.md`. If the PRD folder does not exist, print: ``PRD \`<prd-slug>\` not found under `docs/prds/`. Available PRDs: <list of discovered slugs>.`` The named PRD is shown regardless of its archive state (drill-in bypasses the default archive filter).

   Display every piece individually with spec/plan/execute branch presence and drift flags:

   ```
   PRD: auth (active, v1)
   Manifest: docs/prds/auth/manifest.yaml
   Pieces: 5

     ● token-refresh       in-progress   spec ✓   plan ✓   execute ✓   ⚠ drift: non-negotiables
         Worktree: worktrees/prd-auth/piece-token-refresh/
         Branch:   execute/auth-token-refresh
         Phase:    3 of 5 (Refactor)

     ○ login-flow          merged        spec ✓   plan ✓   execute ✓
         Branch:   execute/auth-login-flow (merged to main)

     ○ oauth-provider      planned       spec ✓   plan ✓   execute —
         Branch:   plan/auth-oauth-provider

     ○ session-store       specced       spec ✓   plan —   execute —
         Branch:   spec/auth-session-store

     ○ mfa-enrollment      open          spec —   plan —   execute —

   Next up: oauth-provider (planned, ready to run /spec-flow:execute auth/oauth-provider)
   ```

   "Branch presence" means: scan `git branch --list` for `{spec,plan,execute}/<prd-slug>-<piece-slug>`; mark `✓` if the branch exists, `—` if it does not. A merged piece's execute branch will typically be gone post-merge — that is expected and does not warrant a warning.

   Drift is surfaced passively per piece with the changed file(s) listed; the user is pointed at `/spec-flow:status --resolve <piece>` or at re-running the relevant skill.

8. **Recommend next action:**
   - No PRDs discovered → pre-v3 fallback message (see step 1).
   - All PRDs present, no active piece anywhere → "Run `/spec-flow:spec <prd-slug>/<piece-slug>` on the next `open` piece."
   - Spec exists, no plan → "Run `/spec-flow:plan <prd-slug>/<piece-slug>`."
   - Plan exists, not started → "Run `/spec-flow:execute <prd-slug>/<piece-slug>`."
   - Mid-implementation → "Resume `/spec-flow:execute <prd-slug>/<piece-slug>` — Phase N."
   - All pieces in a PRD reach `merged`/`done` → "All pieces in `<prd-slug>` complete. Run `/spec-flow:prd --review <prd-slug>` to validate full PRD fulfillment."

9. **Surface blocked pieces:** For every piece whose manifest entry has `depends_on:`, resolve each qualified ref (`<prd-slug>/<piece-slug>`) or bare ref (same-PRD `<piece-slug>`) against the discovered manifests. If any dependency's status is not `merged` or `done`, report the piece as blocked and name the failing dependency with its current status. This mirrors `/spec-flow:execute`'s FR-011 precondition but is purely informational at the status surface — no refusal, no dispatch.

## PRD Completion Detection

When all pieces in the manifest have status `merged` or `done` (the two terminal states per the spec's piece-status state machine), prompt:
> "All pieces are merged. Run `prd --review` to validate full PRD fulfillment?"

## Divergence Resolution (`--resolve <piece>`)

Invoked as `/spec-flow:status --resolve <piece-name>`. Walks the user through each diverged charter file for the piece and offers three options per file.

### Preconditions
- Piece exists in manifest
- Piece status is `specced`, `planned`, or `in-progress` (per the v3 piece-status state machine — `implementing` is the pre-v3 alias and may also be present in legacy manifests)
- At least one charter file's current `last_updated` > piece's `charter_snapshot` for that file

If no divergence exists, respond: *"No divergence detected for `<piece-name>`. `charter_snapshot` matches current charter."*

### Per-file flow

For each diverged file (in order of the `charter_snapshot` block in spec.md), present:

```
<piece-name> diverges on charter/non-negotiables.md
  Snapshot: 2026-03-01
  Current:  2026-04-20
  Changes since snapshot:
    + NN-C-014 (no PII in logs) — added 2026-03-15
    ~ NN-C-007 (transactional boundaries) — modified 2026-04-05
    - NN-C-012 — RETIRED 2026-04-18

Options:
  1. Re-spec — dispatch `spec` skill to update Non-Negotiables Honored
     and Coding Rules Honored sections. Best if new entries (+) apply to
     this piece's scope.
  2. Re-plan — dispatch `plan` skill to update per-phase charter
     allocation. Best if the phase decomposition shifts because of
     modified entries (~).
  3. Accept — document the divergence in the spec without changing
     citations. Best if none of the changes actually apply to this
     piece's scope.

Which option? (1/2/3, default 3)
```

### Option 1 — Re-spec

1. Dispatch `spec` skill in a constrained mode: only the `### Non-Negotiables Honored` and `### Coding Rules Honored` sections are eligible for edit. Phase 1 context reload reads the new charter; Phase 2 Socratic is skipped for non-NN/CR sections.
2. After `qa-spec` and user sign-off, update `charter_snapshot` for the touched file in spec.md front-matter to today's date.
3. If the piece status is `planned`, the new citation may require a new phase allocation — offer Option 2 as a follow-up.
4. Commit: `spec(<piece>): re-spec NN/CR citations against updated charter`.

### Option 2 — Re-plan

1. Dispatch `plan` skill to re-run Phase 2 allocation-only (phases, ACs, implementation tracks unchanged; only the "Charter constraints honored in this phase" slots regenerate).
2. `qa-plan` re-runs allocation checks. Human sign-off.
3. Update `charter_snapshot` in plan.md for the touched file to today's date.
4. Commit: `plan(<piece>): re-allocate charter citations against updated charter`.

### Option 3 — Accept

1. Append a new `### Accepted Charter Divergence` section to spec.md if not present. Add an entry:
   ```markdown
   ### Accepted Charter Divergence
   
   - **charter/<file>.md** (snapshot 2026-03-01, current 2026-04-20) accepted on 2026-04-20.
     - Reason: <user-provided paragraph explaining why the changes don't apply to this piece>
   ```
2. Update `charter_snapshot` for the touched file in spec.md to today's date (marks the divergence as resolved).
3. No QA dispatch. User's rationale is the audit trail.
4. Commit: `spec(<piece>): accept charter divergence for <file>`.

### Post-resolution

After processing all diverged files, re-run divergence detection. If any file is still diverged (e.g., user aborted mid-flow), leave those flags in place. Otherwise report: *"Divergence resolved for `<piece-name>`."*
