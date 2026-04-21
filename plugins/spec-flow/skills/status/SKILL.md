---
name: status
description: Use when starting a session on a spec-flow project, checking progress on the spec-flow pipeline, or asking what to work on next (e.g. "where are we", "what's next", "pipeline status", "anything in flight"). Shows PRD coverage, current piece state, phase progress, and recommends the next spec-flow action. Use whenever the user wants a snapshot of spec-flow pipeline state, even if they don't say "status" explicitly.
---

# Pipeline Status

Show the current state of the development pipeline and recommend what to work on next.

## Workflow

0. **Load config:** Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

1. **Read manifest:** Look first for `<docs_root>/prd/manifest.yaml` (v2.0.0 layout), then `<docs_root>/manifest.yaml` (legacy). If neither exists, report: "No pipeline initialized. Run the `prd` skill to import a PRD and create the manifest."

1a. **Read charter state.** Check `<docs_root>/charter/` directory. If present, read each file's `last_updated:` front-matter. If absent, note charter is missing (only surface if `charter.required: true` in config).

2. **Parse manifest:** Read the YAML file. Extract the pieces list with their statuses and the coverage section.

3. **Scan active specs:** For each piece with status `specced`, `planned`, or `implementing` (a piece is `implementing` while `execute` is running against it):
   - Check if `<docs_root>/specs/<piece-name>/spec.md` exists
   - Check if `<docs_root>/specs/<piece-name>/plan.md` exists
   - If plan.md exists, count `- [x]` vs `- [ ]` checkboxes to determine phase progress
   - **Charter divergence check.** Read the piece's `charter_snapshot:` front-matter from spec.md and plan.md. For each charter file listed, compare its snapshot date to the current `<docs_root>/charter/<name>.md` `last_updated:` date. If any current date > snapshot date, the piece is **diverged**. Record which files changed. (If the piece predates charter — no snapshot front-matter — skip this check silently.)

4. **Check worktrees:** Run `git worktree list` to identify active worktrees matching the `spec/<piece-name>` branch pattern.

5. **Present status:**

Display a dashboard like:
```
Charter: present (last_updated 2026-04-20)    <-- omit line if docs/charter/ absent
PRD Coverage: ■■■■■□□□□□  N/M pieces done

Current: <piece-name>
  Worktree: spec/<piece-name>
  Status: <status> (Phase X of Y)
  ⚠ Charter diverged: non-negotiables (2026-03-01 → 2026-04-20), architecture    <-- only if divergence detected
  
  Phase 1: <name>     ✓ done
  Phase 2: <name>     ● in-progress (<current-step>)
  Phase 3: <name>       pending

Next up: <next-piece> (<status>, ready to <action>)

Blocked: <blocked-pieces with unmet dependencies, or "nothing">
```

Charter divergence is informational — the status skill does NOT block or require resolution. When the flag surfaces on a `specced` or `planned` piece, recommend (without forcing) that the user consider re-running the `spec` or `plan` step against the updated charter, or document in the spec why the divergence is acceptable for this piece.

6. **Recommend next action:**
   - No manifest → "Run `prd` to initialize the pipeline"
   - No active piece → "Run `spec` on the next `open` piece in the manifest"
   - Spec exists, no plan → "Run `plan` on `<piece>`"
   - Plan exists, not started → "Run `execute` on `<piece>`"
   - Mid-implementation → "Resume `execute` — Phase N, step `<step>`"
   - All pieces done → "All pieces complete. Run `prd --review` to validate full PRD fulfillment."

7. **Surface blocked pieces:** Check each piece's dependencies against the manifest. If a dependency is not `done`, report the piece as blocked.

## PRD Completion Detection

When all pieces in the manifest have status `done`, prompt:
> "All pieces are marked done. Run `prd --review` to validate full PRD fulfillment?"

## Divergence Resolution (`--resolve <piece>`)

Invoked as `/spec-flow:status --resolve <piece-name>`. Walks the user through each diverged charter file for the piece and offers three options per file.

### Preconditions
- Piece exists in manifest
- Piece status is `specced`, `planned`, or `implementing`
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
