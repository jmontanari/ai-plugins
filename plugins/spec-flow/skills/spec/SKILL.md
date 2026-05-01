---
name: spec
description: Use when authoring a detailed specification for a piece from the spec-flow manifest — including when the user says "spec out X", "write a spec for Y", "let's design the next piece", or wants to start work on the next `open` piece. Brainstorms with the user one question at a time, creates a worktree on a feature branch, writes the spec, runs adversarial QA review, and gets human sign-off before advancing. Use whenever the pipeline is in a state where the next move is to spec a piece — even if the user doesn't explicitly say "spec".
---

# Spec — Author Spec for One Piece

Author a detailed specification for one piece from the manifest through Socratic dialogue, adversarial QA review, and human sign-off.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

## Prerequisites

- `docs/prds/<prd-slug>/manifest.yaml` must exist (run `prd` first). `<prd-slug>` is the slug of the PRD that owns the target piece — the manifest lives under that PRD's folder per `plugins/spec-flow/reference/v3-path-conventions.md`.
- The piece must have status `open` in the manifest

## Workflow

### Phase 1: Load Context

> Phase 1 includes a **dependency precondition check** (step 6a below) that runs the resolution + status + triage logic specified in `plugins/spec-flow/reference/depends-on-precondition.md` against the target piece's `depends_on:` list before authoring begins.

1. Read `docs/prds/<prd-slug>/manifest.yaml` — find the target piece (from user argument or next `open` piece). Resolve `<prd-slug>` from the user's argument or by scanning `docs/prds/*/manifest.yaml` for the next `open` piece across PRDs. Capture both `<prd-slug>` (owning PRD) and `<piece-slug>` (target piece) for use throughout the skill — every path below is parameterized on these two slugs.
2. Read `docs/prds/<prd-slug>/prd.md` — extract the PRD sections mapped to this piece
3. Read `<docs_root>/charter/` — load any charter files present (architecture.md, non-negotiables.md, tools.md, processes.md, flows.md, coding-rules.md). If the charter directory is absent, fall back to reading the legacy `<docs_root>/architecture/` folder. Capture each charter file's `last_updated:` front-matter value for the `charter_snapshot` front-matter written in Phase 3.
4. Scan `<docs_root>/prds/<prd-slug>/specs/*/learnings.md` — load learnings from previously completed pieces in this PRD
5. Scan for binding rules across namespaces: `<docs_root>/charter/non-negotiables.md` (NN-C), `<docs_root>/prds/<prd-slug>/prd.md` for `NN-P-xxx` entries in the Non-Negotiables (Product) section, `<docs_root>/charter/coding-rules.md` (CR), and any `NN-xxx` entries in `CLAUDE.md`. Pre-charter projects with unprefixed `NN-xxx` in the PRD still work — treat them as legacy and mention in Phase 2 that retrofitting would reclassify them.
6. Read `<docs_root>/prds/<prd-slug>/backlog.md` if it exists. This is the PRD-local backlog — it accumulates end-of-piece reflection findings from prior pieces in this PRD (future opportunities deferred to later pieces of the same PRD). For each item recorded, semantic-match against this piece's name (from manifest) and the user's brainstorm prompt; surface the ~5 most-relevant items as candidate considerations during Phase 2 brainstorm. Track user responses in orchestrator state for Phase 5 prune (statuses: `incorporated` — addressed by this piece's spec; `deferred` — still relevant but not in this piece's scope; `obsolete` — no longer applies). If the file does not exist (first piece on a new PRD), skip silently. If `reflection: off` is set but the file exists from a previous run, still read it — stale findings from past reflections may still be useful brainstorm context. (Process-retro items live in the global `<docs_root>/improvement-backlog.md`; that file is touched only by the reflection-process-retro agent and is out of scope for this skill.)
6a. **Dependency precondition check (FR-4 of pi-010-discovery, AC-5).** Run the resolution + status + triage logic specified in `plugins/spec-flow/reference/depends-on-precondition.md` against the target piece's `depends_on:` list, read from the manifest entry loaded in step 1 (`docs/prds/<prd-slug>/manifest.yaml`). For each ref, resolve per the reference doc's "Reference resolution" section (qualified `<dep-prd-slug>/<dep-piece-slug>` against `docs/prds/<dep-prd-slug>/manifest.yaml`; bare `<dep-piece-slug>` against the current PRD's manifest). On resolution failure, refuse with the exact resolution-failure refusal string from the reference doc — do NOT prompt for triage on a malformed/missing ref. On successful resolution, classify each dep's `status:` per the reference doc's "Status interpretation" section. If every resolved dep is `merged` or `done`, this step is a silent no-op (no prompt, no recorded state) and Phase 1 continues to step 7 (NN-C-005). If any resolved dep has a transient or structural-failure status, render the three-option triage prompt verbatim from the reference doc's "Triage options at spec/plan time" section (literal `(1) pull-deps-in`, `(2) fork`, `(3) proceed` markers; one bullet per unmet dep). Record the operator's choice and the per-dep status snapshot in orchestrator state keyed for Phase 3's spec.md authoring step to read. **Structural-failure statuses (`superseded`, `blocked`) refuse the `(3) proceed` option** — apply that rule symmetrically to the spec-time prompt per the reference doc.
7. **Charter-drift check.** If the target piece's `spec.md` already exists and carries a `charter_snapshot:` front-matter (i.e., this is an update/amend re-run, not a greenfield first-run), execute the charter-drift procedure specified in `plugins/spec-flow/reference/charter-drift-check.md`: compare the spec's `charter_snapshot:` values against the `last_updated:` values captured in step 3, and on any drift dispatch `qa-spec` with `Input Mode: Focused charter re-review` per that reference. On `clean`: auto-advance the snapshot and continue. On `must-fix`: halt the skill and surface findings — no escape hatch. Skip this step on greenfield runs (no spec yet, nothing to drift).
8. **Integration config load.** If `integrations.issue_tracker.enabled: true` in `.spec-flow.yaml`, read `<docs_root>/charter/<charter_file>.md` (default `charter/integrations.md`) for task naming and status transition rules. If the file is absent, proceed with built-in defaults (see `plugins/spec-flow/reference/integration-capability-check.md`). Store the resolved config as `integration_cfg` for use in later steps. If integration is disabled or the key is absent, set `integration_cfg = null` and skip all integration steps below.

### Phase 2: Brainstorm

**Integration — create piece issue (if `integration_cfg != null` and `auto_create_tasks: true`):**
Run the capability check from `plugins/spec-flow/reference/integration-capability-check.md`
for operation `create_piece_issue`. If the tool is available:
- Read `parent_key:` from `<docs_root>/prds/<prd-slug>/prd.md` front-matter. If present,
  use it as the parent when creating the piece issue (links to the parent in the hierarchy).
- Create an issue of type `integration_cfg.piece_issue_type` using the piece naming convention
  from `integration_cfg` (default: `{piece-slug} — {piece description from manifest}`).
- Record the returned issue key as `epic_key` in orchestrator state AND write it to
  spec.md front-matter as `epic_key: <key>` so plan and execute skills can find it.
On tool unavailable → emit warning → skip.

Socratic dialogue with the user, one question at a time:

1. Confirm the piece scope: "This piece covers [PRD sections]. Does that match your intent?"
1a. **Identify charter constraints this piece touches.** From the charter files loaded in Phase 1 step 3, enumerate which `NN-C-xxx` entries, `NN-P-xxx` entries, and `CR-xxx` entries are in scope for this piece. Ask the user to confirm the list (e.g., "This piece touches NN-C-003, NN-P-001, CR-007 and CR-012. Miss anything?"). Record the confirmed list — it becomes the `### Non-Negotiables Honored` and `### Coding Rules Honored` sections of spec.md in Phase 3.
2. **Surface backlog items.** If Phase 1 step 6 loaded items from `<docs_root>/prds/<prd-slug>/backlog.md`, present the top ~5 most-relevant to the user with their concrete references and ask "for each, is this `incorporated` in this piece's spec, `deferred` to a later piece, or `obsolete`?" Record each response in orchestrator state keyed by backlog item — Phase 5 step 4 reads this state to prune `incorporated` and `obsolete` entries from the file. If no items were surfaced (file did not exist, or no relevant matches), skip this step.
3. Explore purpose and boundaries
3a. **Identify and document codebase conventions.** If the piece touches a component type that exists elsewhere in the codebase (e.g., roles, modules, services, playbooks, handlers), scan 2-3 peer components to identify empirical conventions that differ from generic framework documentation (e.g., file structure, metadata wrappers, naming patterns, shared config idioms). Ask the user to confirm: "I see all existing roles use [X pattern] — should this spec require that too?" Document confirmed conventions in a `### Codebase Conventions` section of the spec. This prevents spec-compliance reviewers from flagging idiomatic local patterns as violations and prevents implementers from following generic docs over project norms.
4. PRD compliance check: if the manifest maps requirements the user hasn't mentioned, ask about them
5. Propose 2-3 approaches with trade-offs and your recommendation
6. Resolve all open questions — no `[NEEDS CLARIFICATION]` markers may survive

### Phase 3: Create Worktree and Write Spec

1. Check if `worktrees/` is in `.gitignore` — add it if missing
2. **Validate slugs before any branch or worktree creation.** Run both `<prd-slug>` and `<piece-slug>` through the rules in `plugins/spec-flow/reference/slug-validator.md` (max 20 chars, charset `[a-z0-9-]`, no leading/trailing `-`, total branch length ≤ 50 chars). On any violation, refuse with the exact error contract from that reference doc — name which slug is offending, its actual value, the current length or offending character, and the limit. There is no silent truncation, no auto-fix; the user must edit `docs/prds/<prd-slug>/manifest.yaml` (or rename the PRD) and re-run.
3. Create worktree (before writing, so all work lives on the feature branch). Worktree path and branch name follow `plugins/spec-flow/reference/v3-path-conventions.md`:
   ```bash
   git worktree add {{worktree_root}} -b piece/<prd-slug>-<piece-slug>
   ```
4. Write `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/spec.md` in the worktree directory. Read the dependency-triage choice recorded by Phase 1 step 6a from orchestrator state and branch as follows (per FR-6 of pi-010-discovery and the `## Dependency Triage` section format in `plugins/spec-flow/reference/depends-on-precondition.md`):
   - **No unmet deps recorded** (every dep was already `merged`/`done` at the time of step 6a, or the piece had no `depends_on:` entries): write spec.md normally with no `## Dependency Triage` section. The section is required only when at least one dep was unmet at the moment of authoring.
   - **Operator chose `(1) pull-deps-in`:** write spec.md and append a `## Dependency Triage` section using the format from the reference doc — one bullet per unmet dep, each rendered as ``- `<ref>` (status: `<status>` at <YYYY-MM-DD>) — Operator chose pull-deps-in; spec covers prerequisite behavior in §<section>.`` (or the Phase 0 variant per the reference doc's "Resolution values" list, depending on whether the absorption is documented in the spec body or deferred to plan-time Phase 0). The Goal / Scope / FR / AC sections of spec.md must be authored to also cover the dep's behavior — the unmet-dep entry should only be removed from `depends_on:` once the prerequisite is actually covered in this spec.
   - **Operator chose `(2) fork`:** halt the skill immediately with the exact refusal string `Refused — fork chosen; spec the prerequisite piece <ref> first.` (substituting each unmet dep's `<ref>` if more than one is unmet, one refusal line per dep). Write NO spec.md, create NO commits, do not advance to Phase 4. The operator's next action is to switch to the prerequisite piece and run `/spec-flow:spec` on it.
   - **Operator chose `(3) proceed --ignore-deps`:** write spec.md and append a `## Dependency Triage` section with one bullet per unmet dep rendered as ``- `<ref>` (status: `<status>` at <YYYY-MM-DD>) — Operator override; deps remain unmet at spec time.`` Recall that `(3) proceed` is refused for structural-failure statuses (`superseded`, `blocked`) at step 6a — if execution reaches this branch, every unmet dep is in a transient-status class.
5. Use the template at `${CLAUDE_PLUGIN_ROOT}/templates/spec.md` as the structural guide. Populate the `charter_snapshot:` front-matter with each charter file's `last_updated` date captured in Phase 1 step 3. If a charter file is absent, omit its key from the snapshot block (do not write a blank/null value).

### Phase 4: QA Loop

Iteration policy: see plugins/spec-flow/reference/qa-iteration-loop.md (iter-until-clean; 3-iter circuit breaker).

1. Read the agent template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-spec.md`

2. **Iteration 1 (full review):** Compose prompt with `Input Mode: Full`: interpolate the full spec, PRD sections, charter files (all six if present — architecture, non-negotiables (NN-C), tools, processes, flows, coding-rules (CR); else legacy `docs/architecture/`), manifest piece, and NN-P from the PRD's Non-Negotiables (Product) section. Dispatch:
   ```
   Agent({
     description: "Spec QA for <prd-slug>/<piece-slug> (iter 1, full)",
     prompt: <composed>,
     model: "opus"
   })
   ```

3. **QA loop (iterations 2+, focused):** If iteration M-1 returned must-fix findings:
   - Read the fix template: `${CLAUDE_PLUGIN_ROOT}/agents/fix-doc.md`
   - Dispatch fix agent with prior findings + spec + context. The fix agent does NOT commit; it ends its report with `## Diff of changes` containing its `git diff` of spec.md.
   - Extract that diff string and hold it in orchestrator state as `spec_iter_M_fix_diff`.
   - Re-dispatch QA agent (fresh) with `Input Mode: Focused re-review`, the prior iteration's must-fix findings, and `spec_iter_M_fix_diff`. Do NOT re-send the full spec.
   - **Circuit breaker:** After 3 QA iterations, escalate to human.
   - If the fix agent returns `Diff of changes: (none)` (all blocked), escalate.

4. When QA returns clean: present spec to user for sign-off.

**Limitation:** The QA agent cannot assess brainstorming trade-offs not captured in the spec. The human sign-off covers this gap.

### Phase 5: Finalize

1. User approves → continue. User requests changes → make them → back to QA loop.
2. Update `docs/prds/<prd-slug>/manifest.yaml` on the piece branch (the current
   working branch — no checkout needed):
   ```bash
   # update docs/prds/<prd-slug>/manifest.yaml status for this piece
   git add docs/prds/<prd-slug>/manifest.yaml
   git commit -m "manifest: mark <prd-slug>/<piece-slug> as specced"
   ```
   > **Branch ownership:** The manifest update stays on the piece branch
   > (`piece/<prd-slug>-<piece-slug>`). Main's manifest advances when this branch
   > is merged or a PR is opened after execute completes. For PR-based repos, the
   > human merges the piece branch to main as part of the normal review workflow.
3. Commit spec on worktree branch:
   ```bash
   git add docs/prds/<prd-slug>/specs/<piece-slug>/spec.md
   git commit -m "spec: add <prd-slug>/<piece-slug> specification"
   ```
4. **Prune addressed backlog items.** If Phase 1 step 6 surfaced backlog items from `<docs_root>/prds/<prd-slug>/backlog.md` and the user marked any as `incorporated` or `obsolete` during brainstorm, remove those entries from that PRD-local backlog file. `deferred` items stay in the file. Commit the prune as a separate commit on the worktree branch:
   ```bash
   git add <docs_root>/prds/<prd-slug>/backlog.md
   git commit -m "chore: prune backlog items addressed by <prd-slug>/<piece-slug>"
   ```
   If no items were marked or no PRD-local backlog existed, skip this step.
5. **Integration — no additional Jira items at spec sign-off.** The Epic was created at Phase 2 start and represents the entire piece. Phase Tasks are created by the plan skill at sign-off. No action needed here.

## NEEDS CLARIFICATION Lifecycle

These markers flag unresolved questions during brainstorming. The skill MUST resolve all markers with the user before writing the final spec. The QA agent treats any surviving marker as a must-fix finding.
