# Changelog

All notable changes to the `spec-flow` plugin. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the plugin uses [Semantic Versioning](https://semver.org/).

## [2.0.0-piece.5] — 2026-04-20

### Added (piece 5 of 7 — update mode + divergence resolution)
- **Charter skill update mode.** `/spec-flow:charter` now supports editing existing charter files. Detected automatically when `docs/charter/` exists and no legacy signals present; also invocable as `/spec-flow:charter --update`. Six-phase flow (U1–U6): list files → scoped Socratic per selected file → write with bumped `last_updated` → QA on touched files → human sign-off → per-file commit → divergence awareness notice for in-flight pieces.
- **Retirement UX.** When a user removes an NN-C or CR entry, the skill asks whether to retire (tombstone — recommended) or delete (removes all trace). Retired entries keep the ID reserved; specs citing retired IDs are flagged must-fix by QA so teams can upgrade to superseding entries.
- **`/spec-flow:status --resolve <piece>` divergence resolution flow.** Walks the user through each diverged charter file with three options per file:
  - **Re-spec** — dispatch `spec` skill in citation-only mode to update Non-Negotiables Honored / Coding Rules Honored sections.
  - **Re-plan** — dispatch `plan` skill in allocation-only mode to regenerate per-phase charter slots.
  - **Accept** — append an `### Accepted Charter Divergence` section to the spec with a user-authored rationale.
  After resolution, `charter_snapshot` is updated to today's date for the touched file.
- **Charter skill Phase 7 doctrine reminder** now tells the user to run `/reload-plugins` so the SessionStart hook picks up the new charter (wired in v2.0.0 piece 2).

### Changed
- Charter skill mode detection: explicit `--update` and `--retrofit` flags supported alongside auto-detection. Retrofit still reports "deferred to piece 6" until piece 6 lands.
- Divergence is now resolvable via a skill, not just surfaced. Status's passive `⚠ Charter diverged` flag remains; the `--resolve` flag promotes it to an actionable flow.

### Deferred to pieces 6–7
- Piece 6: retrofit mode + migration pipeline
- Piece 7: README + diagrams

### Migration (piece 5)
- No breaking changes. Teams with existing charter can now iterate on it via update mode; teams without charter are unaffected.
- Divergence resolution is opt-in (`--resolve` flag). Pieces that pre-date `charter_snapshot` front-matter continue to skip divergence check silently.
- Run `/reload-plugins` to pick up skill updates.

## [2.0.0-piece.4] — 2026-04-20

### Added (piece 4 of 7 — agent updates)
- **`implementer.md` Rule 4** now explicitly lists `<docs_root>/charter/` (six files), legacy `<docs_root>/architecture/` + `<docs_root>/adr/`, PRD non-negotiables, and plan-cited `NN-C-xxx`/`NN-P-xxx`/`CR-xxx` IDs as binding sources. Architecture-conflict BLOCKED vocabulary expanded to cover charter breach.
- **`qa-spec` checks** now verify citation integrity (no hallucinated IDs, retired-entry citations must-fix), honoring specificity (vague "handles the rule" fails), and scope coverage (NN-C/NN-P/CR whose scope overlaps piece must be cited).
- **`qa-plan` checks** now verify per-phase charter allocation (every spec-cited entry appears in exactly one phase, no drops/dupes), per-phase honoring specificity, and charter_snapshot front-matter presence.
- **`qa-phase` checks** gain charter citation honoring — every NN-C/NN-P/CR cited by the phase's slot must be demonstrably honored in the phase diff.
- **`qa-prd-review`** audits NN-C/NN-P coverage across done pieces, CR drift spot-check, retired-entry citation detection.
- **`review-board/architecture`** expanded to cover CR-xxx compliance and flow honoring. Full charter (six files) is now primary context.
- **`review-board/spec-compliance`** verifies every NN/CR claim in the spec is backed up by the diff.
- **`review-board/prd-alignment`** verifies NN-P preservation across piece implementation.

### Changed
- Agents now read both new (`<docs_root>/charter/`) and legacy (`<docs_root>/architecture/`) layouts. Charter takes precedence when present.
- Retired charter entries (tombstoned with `RETIRED` marker) are must-fix when cited by any spec, plan, or code comment — preventing silent reliance on removed rules.

### Deferred to pieces 5–7
- Piece 5: update mode + divergence resolution flow (status already surfaces divergence in piece 3)
- Piece 6: retrofit mode + migration pipeline
- Piece 7: README + diagrams

### Migration (piece 4)
- **Backward compat preserved.** Agents check for charter first and fall back to legacy arch docs + unprefixed NN-xxx when charter is absent. Pre-charter projects' review loops continue to work.
- Run `/reload-plugins` to pick up agent updates.

## [2.0.0-piece.3] — 2026-04-20

### Added (piece 3 of 7 — downstream skill charter wiring)
- **Charter prerequisite check** in `skills/prd/SKILL.md` (Step 0.5). If `charter.required: true` and `<docs_root>/charter/` is missing, prd halts and directs the user to run `/spec-flow:charter` first. Legacy flat-layout detection surfaces a migration hint pointing to piece 6.
- **NN classification during PRD import.** `prd` skill now asks the user whether each extracted non-negotiable is project-wide (promoted to `NN-C-xxx` in `<docs_root>/charter/non-negotiables.md`) or product-specific (written as `NN-P-xxx` to PRD). Pre-charter projects fall back to unprefixed `NN-xxx`.
- **Charter loading in `skills/spec/SKILL.md`.** Phase 1 step 3 now reads `<docs_root>/charter/` (all six files) with fallback to legacy `<docs_root>/architecture/`. Phase 1 step 5 scans for binding rules across NN-C / NN-P / CR namespaces.
- **Phase 2 step 1a** in `skills/spec/SKILL.md` — identify charter constraints touched by the piece, confirm with user, record list for spec sections.
- **`charter_snapshot` front-matter** populated at spec write time (Phase 3) and plan write time (`skills/plan/SKILL.md` Phase 2). Used by piece 5 divergence detection.
- **Charter in exploration priors** in `skills/plan/SKILL.md` Phase 1.
- **Per-phase charter-constraints allocation** — plan skill distributes every NN-C/NN-P/CR cited by the spec into exactly one phase's "Charter constraints honored" slot (no drops, no duplicates).
- **Charter in QA prompts** — `qa-spec` and `qa-plan` iter-1 full prompts now interpolate charter files alongside spec/plan/PRD.
- **Charter in review-board dispatches** (`skills/execute/SKILL.md`): architecture reviewer receives all six charter files (or legacy arch docs); spec-compliance reviewer receives NN-C, NN-P, CR for claim verification.
- **Phase-QA prompt updates** — `## Non-negotiables` block sources from NN-C + NN-P; new `## Coding rules cited by this phase` block attaches specific CR entries cited by the phase.
- **Charter presence indicator + divergence flag** in `skills/status/SKILL.md`. Top-line `Charter: present (last_updated YYYY-MM-DD)` when charter exists; per-piece `⚠ Charter diverged` line when any current `last_updated` > snapshot.

### Changed
- **New layout is preferred for writes.** `prd` writes to `<docs_root>/prd/prd.md` + `<docs_root>/prd/manifest.yaml` on new projects. Legacy-layout projects continue to read/write the flat paths until they retrofit.
- **Status skill reads manifest from either layout** — checks `<docs_root>/prd/manifest.yaml` first, falls back to `<docs_root>/manifest.yaml`.

### Deferred to pieces 4–7
- Piece 4: agent updates (implementer, qa-spec, qa-plan, qa-phase, qa-prd-review, review-board/*)
- Piece 5: update mode + divergence detection (divergence is *surfaced* by status in piece 3 but the update-mode flow is piece 5)
- Piece 6: retrofit mode + migration pipeline
- Piece 7: README + diagrams

### Migration (piece 3)
- **Backward compat preserved.** All five skills read both new and legacy layouts. `charter.required` defaults to `false`, so pre-charter projects continue to work unchanged.
- **New projects are nudged toward new layout.** The `prd` skill writes to `<docs_root>/prd/` on new bootstraps. Run `/spec-flow:charter` first if `charter.required: true`.
- **Existing specs without `charter_snapshot` front-matter** are handled silently — divergence check skips those pieces (no false warnings).
- Run `/reload-plugins` to pick up skill changes.

## [2.0.0-piece.2] — 2026-04-20

### Added (piece 2 of 7 — templates, config, doctrine load)
- **`charter:` config block** in `templates/pipeline-config.yaml` with two keys:
  - `required` (default `false`) — piece 3 will wire this so `prd`/`spec`/`plan` fail fast when set to `true` and `docs/charter/` is missing
  - `doctrine_load` (default `[non-negotiables, architecture]`) — list of charter file base names to auto-load into session context
- **Session-start hook charter doctrine load** — `hooks/session-start` now conditionally reads the charter files listed in `doctrine_load` when `docs/charter/` exists, and injects them into `additionalContext` alongside the existing TDD doctrine. Silent no-op when charter is absent.
- **`charter_snapshot:` front-matter** in `templates/spec.md` and `templates/plan.md` capturing per-file `last_updated` dates at spec/plan write time. Used by piece 5 divergence detection.
- **Per-phase `Charter constraints honored in this phase` slot** in both TDD-track and Implement-track phase examples of `templates/plan.md`.

### Changed
- **`templates/prd.md`** — `## Non-Negotiables` section renamed to `## Non-Negotiables (Product)` with structured `NN-P-xxx` schema (Type / Statement / Scope / Rationale / How QA verifies). Header gains a `**Charter:** docs/charter/` reference line pointing to the project-wide `NN-C-xxx` namespace.
- **`templates/spec.md`** — `### Non-Negotiables (from PRD)` renamed to `### Non-Negotiables Honored` and split into **Project (NN-C)** and **Product (NN-P)** subsections. New `### Coding Rules Honored` section for `CR-xxx` citations. Header gains `**Charter:** docs/charter/` reference line.
- **`templates/plan.md`** — header gains `**Charter:** docs/charter/` reference line.

### Deferred to pieces 3–7
- Piece 3: downstream skills (`prd`, `spec`, `plan`, `execute`, `status`) read charter, enumerate NN-C/NN-P/CR, enforce `charter.required`
- Piece 4: agent updates
- Piece 5: update mode + divergence detection
- Piece 6: retrofit mode + migration pipeline
- Piece 7: README + diagrams

### Migration (piece 2)
- Backward compat preserved — `charter.required: false` is the default so pre-charter projects keep working. Session-start hook silently ignores charter when `docs/charter/` is missing.
- Existing specs/plans authored against v1.5.x templates continue to validate (the new template sections are additive, not replacing anything structurally).
- Run `/reload-plugins` after upgrading to pick up the hook change.

## [2.0.0-piece.1] — 2026-04-20

### Added (piece 1 of 7 — charter stage bootstrap)
- `/spec-flow:charter` skill (bootstrap mode only) at `skills/charter/SKILL.md`
- `qa-charter` adversarial review agent at `agents/qa-charter.md`
- Six charter templates in `templates/charter/`:
  - `architecture.md` — layers, dependency direction, component ownership
  - `non-negotiables.md` — `NN-C-xxx` structured schema (Type: Rule / Reference)
  - `tools.md` — language, framework, test runner, linter, CI, approved/banned libraries
  - `processes.md` — branching, review, release, CI gates, incident response
  - `flows.md` — request/auth/data-write and other critical flows
  - `coding-rules.md` — `CR-xxx` structured schema

### Deferred to pieces 2–7
- Piece 2: template updates + pipeline-config.yaml + session-start doctrine load
- Piece 3: downstream skill charter wiring (prd/spec/plan/execute/status)
- Piece 4: agent updates (implementer, qa-spec, qa-plan, qa-phase, review-board)
- Piece 5: update mode + divergence detection
- Piece 6: retrofit mode + migration pipeline
- Piece 7: README + full CHANGELOG for v2.0.0 + diagrams

### Migration (piece 1 only)
- No breaking changes in piece 1. Charter files are standalone; downstream skills are unchanged. Projects upgrading from v1.5.x pick up the new charter skill but continue to work without calling it.

## [1.5.0] — 2026-04-19

### Added
- **End-of-piece reflection stage (Step 4.5).** Two new Sonnet read-only agents — `agents/reflection/process-retro.md` and `agents/reflection/future-opportunities.md` — fire concurrently after Final Review's Human Sign-Off and before Capture Learnings. Process retro examines session metrics + escalation log + cumulative diff for orchestration improvements. Future opportunities examines spec/plan/diff/manifest for forward-looking work to consider in future pieces.
- **Project-level improvement backlog.** Reflection findings get appended to `<docs_root>/improvement-backlog.md` (committed, accumulates across pieces). The `spec` skill reads this file at brainstorm start to surface relevant past findings as candidate considerations for new pieces.
- **`reflection` config key** (`auto | off`, default `auto`) in `.spec-flow.yaml`. Disables Step 4.5 if needed.
- **Spec skill backlog integration.** Phase 1 step 6 (new) reads the backlog and surfaces ~5 most-relevant items during brainstorm. Phase 5 step 4 (new) prunes addressed/obsolete items after spec sign-off.

### Changed
- **Step 5 (Capture Learnings) restructured.** Now synthesizes `learnings.md` from the two reflection reports + cumulative diff, instead of free-form authoring. Falls back to pre-v1.5 behavior when `reflection: off`.
- **API encapsulation callout** in `skills/execute/SKILL.md` updated to include the two new reflection agents alongside the v1.4.0 phase-level agent list.

### Fixed
- **Agent identifier doubling** (regression from v1.4.0). Frontmatter `name:` fields had the `spec-flow-` prefix, causing agents to register as `spec-flow:spec-flow-<name>` instead of `spec-flow:<name>`. Stripped the prefix from all internal agents (implementer, tdd-red, verify, refactor, qa-phase, qa-phase-lite, fix-code) so legacy short-form callers (`spec-flow:tdd-red`, etc.) work again. Reflection agents use `name: reflection-<x>` to keep the directory-grouping signal in the identifier (`spec-flow:reflection-process-retro`).

### Notes for upgraders
- Plans authored before v1.5.0 work unchanged.
- New projects get `<docs_root>/improvement-backlog.md` created on first end-of-piece reflection. Existing projects can let it accumulate naturally.
- Set `reflection: off` to disable the new stage if you prefer the pre-v1.5 single-shot `learnings.md` flow.
- Run `/reload-plugins` after upgrading to pick up the agent identifier fix.

## [1.4.0] — 2026-04-19

### Added
- **Phase Groups with parallel sub-phase execution.** New plan-level hierarchy (`## Phase Group <letter>:` containing `#### Sub-Phase <letter>.<n> [P]:` sub-units) lets authors decompose parallelizable work (adapter patterns, independent endpoints, per-table migrations) into concurrently-dispatched sub-phases. Opt-in per plan — flat phases still work unchanged.
- **Phase Scheduler in `skills/execute/SKILL.md`.** Detects Phase Group headings, validates sub-phase scope disjointness, dispatches concurrent sub-phase pipelines (each runs its own Red → Build → Verify → QA-lite), waits at a barrier, then runs group-level Refactor and Opus QA on the cumulative diff.
- **`agents/qa-phase-lite.md`** — new Sonnet narrow review template for per-sub-phase QA. Complements the deep Opus QA that now runs at group level. Tiered QA drops net Opus cost as concurrency rises.
- **Autonomous triage decision matrix** for sub-phase failures. 12 failure signatures mapped to recovery actions (fix-code / Refactor / reset-and-re-dispatch / inline autofix / immediate escalation). Pass-1 recovery then pass-2 focused re-check. Hard cap: 2 passes then human escalation. Batched failure report covers the whole group in one review session.
- **`phase_groups` config key** (`auto | always | off`, default `auto`) in `.spec-flow.yaml`. Controls whether the Phase Scheduler is active.
- **Agent API encapsulation** across all internal agents (`implementer`, `tdd-red`, `verify`, `refactor`, `qa-phase`, `qa-phase-lite`, `fix-code`). Frontmatter descriptions now signal "do not call directly", and each agent has a Rule 0 first-turn entrypoint check that BLOCKs when called without the orchestrator-injected invariants (Mode flag, pre-flight snapshot, oracle anchors, AC matrix). Prevents direct-dispatch contamination.

### Changed
- **`skills/plan/SKILL.md` rule 8** introduces Phase Group authoring guidance with structure template, when-to-use / when-not-to-use criteria, scope discipline requirement, and Phase 0 Scaffold interaction.
- **`templates/plan.md`** gains a Phase Group example alongside the existing flat-phase examples.
- **`skills/execute/SKILL.md`** opens with an API-encapsulation doctrine callout reinforcing that this skill is the sole entrypoint for internal phase agents.
- **`agents/refactor.md` Rule 1** clarifies that when dispatched at Phase Group level (Step G7), "phase files" means the union of all sub-phase `**Scope:**` declarations. Orchestrator passes the union as the authoritative file list.

### Notes for upgraders
- Plans authored before v1.4.0 using only flat phases are fully backward-compatible.
- To pilot Phase Groups on an adapter-pattern piece, decompose in `plan` and let `phase_groups: auto` pick up the scheduler.
- Set `phase_groups: off` to disable the scheduler entirely if you hit issues during early rollout.

## [1.3.1] — 2026-04-19

### Added
- **Checkpoint-commit guidance in agent templates.** `agents/implementer.md`, `agents/tdd-red.md`, and `agents/refactor.md` now explicitly tell agents to commit at logical checkpoints during a dispatch (e.g. after each finished file, public-API surface, or plan bullet) and do a final commit when done. Each commit runs hooks; intermediate commits must be lint/type-clean, only the final commit must satisfy the mode's oracle. Benefits: faster error surfacing on small diffs, usable bisect-within-phase git history, natural recovery checkpoints.
- **Plan authoring guidance for checkpoint-friendly bullet ordering.** `skills/plan/SKILL.md` step 5 and `templates/plan.md` both now ask plan authors to order bullets inside `[Build]` / `[Implement]` blocks in a checkpoint-progression sequence (types → constructors → public API → internals → error paths). This gives the implementer agent natural checkpoint boundaries without needing prescriptive structure.

### Changed
- QA remains explicitly per-phase (unchanged design intent): adding more intermediate commits inside a single Build dispatch does NOT multiply QA/Verify/Refactor cost, since those agents consume the cumulative `git diff $phase_start_sha..HEAD` regardless of commit granularity.

## [1.3.0] — 2026-04-19

### Added
- **Mandatory AC Coverage Matrix in Build output.** `agents/implementer.md` requires a structured `## AC Coverage Matrix` table (`| AC ID | Test file:line / Verify assertion | Status |`) with either a concrete pointer per `covered` row or a specific reason + forward pointer per `NOT COVERED` row. The orchestrator validates the table at Step 3 before advancing.
- **Step 3 validation gate.** `skills/execute/SKILL.md` Step 3 item 7 parses the Build report's AC matrix and rejects + re-dispatches (within the 2-attempt oracle budget) when the section is missing, incomplete, or vague. A clean matrix unlocks Verify Audit mode (3 min) instead of Full mode (15 min).
- **Structured QA prompt composition.** `skills/execute/SKILL.md` Step 6 hands the iter-1 QA agent a pre-digested surface map (`## Files changed`, `## Public symbols`, `## Integration callers`, scoped `## Diff`, Build's `## AC Coverage Matrix`, `## Phase ACs`, `## Non-negotiables`) instead of dumping the raw diff + full spec + PRD sections. Opus does adversarial review rather than rediscovery.
- **QA iter-2 hard cap.** `agents/qa-phase.md` Focused re-review rule: reading any file outside the fix delta is a contract violation; return `BLOCKED — needs full re-review` instead of fetching.
- **`refactor` config key** (`auto | always | never`, default `auto`) in `.spec-flow.yaml`. In `auto`, Step 5 skips Refactor when Build reported oracle clean on first attempt + no plan deviations + clean AC matrix. Reclaims ~10–15 min per clean phase.
- **`qa_iter2` config key** (`auto | always`, default `auto`). In `auto`, Step 6 skips iter-M+1 QA re-dispatch when the fix diff is < 50 LOC + fix-code reported all resolved + oracle green — the fix-code agent's self-verification is the gate. Rationale: observed iter-2 hit rate was ~1 in 6, and the class of finding that hits tends to get caught by Final Review anyway.
- **Known pitfalls section in `agents/implementer.md`.** Descriptor binding in `patch.object`, relative-path `parents[N]` fixture paths, formula-vs-test-fit drift, mock-signature drift after contract changes, overly-broad `except` clauses. Python/pytest examples; the patterns generalize.
- **`CHANGELOG.md`** (this file).

### Changed
- **Reverted `--no-verify` intermediate commit cadence** (v1.2's P7). Every intermediate phase commit (Red, Build, Refactor, fix-code, final review) now runs pre-commit hooks normally. The one exception is Red for projects whose pre-commit config includes a test-running hook (would block the intentionally-failing tests) — Red's template uses a scoped `--no-verify` authorized by the orchestrator's pre-flight hook inventory. This revert presupposes the project moves expensive checks (test suites, whole-repo type checks) to `pre-push` or explicit orchestrator gates; see README.
- **Step 6b simplified** from a multi-counter consolidation loop to a single defensive sweep. Per-commit hooks catch issues at the commit that introduced them, so there is no accumulated lint/type debt for Step 6b to unwind. Step 6b runs pre-commit once over the phase's cumulative diff; one autofix re-run and one fix-code dispatch are allowed before escalation.
- **README pre-commit guidance.** Recommends pre-commit be lint + format + type-check only; test suites belong at `pre-push` stage or as explicit orchestrator gates. Tests run three times in the v1.3 flow: Step 3's oracle gate, Step 6b's sanity sweep, and CI — a fourth run on every commit is redundant.
- **Session-end summary fields** in `skills/execute/SKILL.md` Measurement section updated: adds `Refactor skipped`, `QA iter-2 skipped`, and `Step 6b outcome` alongside the existing Build duration / token count / Verify mode fields.

### Removed
- Step 6b's multi-round consolidation loop with `autofix_iter` / `error_fix_iter` counters.
- Per-iteration `(intermediate commit — pre-commit runs at phase consolidation)` commit-message tag.
- "Inline ruff --fix" shortcut branch in Step 6b (no longer needed without the consolidation loop).
- "Red lint pre-check" rule in `agents/tdd-red.md` (redundant with per-commit hooks catching lint at commit time).

## [1.2.1] — 2026-04-18

### Changed
- Version bump (patch, no functional changes recorded in git history).

## [1.2.0] — 2026-04-17

### Added
- **Conditional Verify (Audit/Full modes).** `skills/execute/SKILL.md` Step 4 picks Audit when Build reported oracle clean + no deviations + clean AC matrix; otherwise Full. Audit is ~3 min (AC matrix sanity check, no test re-run); Full is ~10–15 min (full oracle re-verification). Not yet reliably reached pre-1.3.0 because Builds inconsistently emitted a clean AC matrix — addressed in 1.3.0.
- **Race-safe `git add` by literal file paths.** `agents/tdd-red.md` and `agents/implementer.md` require staging by exact paths from the agent's own output section (never `git add .`, `git add tests/`, or any glob). Orchestrator reconciles the committed file list against the agent's reported paths. Prevents cross-agent contamination when two agents share the same worktree.
- **Single-commit-per-phase cadence via `--no-verify` intermediates.** *(Reverted in 1.3.0.)* Intermediate phase commits used `--no-verify`; pre-commit ran once at Step 6b against the full phase diff. Intended to save per-step hook cost when hooks ran slow test suites. In practice, surfaced lint debt late and created multi-round consolidation cycles — 1.3.0 reverts this in favor of cheap per-commit hooks and tests-at-pre-push.

### Changed
- Session-end summary tracks Verify mode chosen (Audit vs Full) and consolidation outcome counters.

## [1.1.1] — 2026-04-16

### Added
- **Orchestrator pre-flight snapshot.** `skills/execute/SKILL.md` Step 1b: the orchestrator collects read-only facts (LOC per file, schema samples for config families, symbol presence via `git grep`, pre-commit hook inventory) before dispatching Red and Build. Attached as `## Pre-flight snapshot` to both agents; replaces 5–15 agent-side rediscovery tool calls per dispatch.
- **Orchestrator plan-conditional resolution.** Pre-flight resolves two specific conditional phrasings in the plan — "extract ... if ... exceeds <N>" and "if <file/symbol> exists, reuse; otherwise create ..." — into binding `## Orchestrator pre-decisions` attached to the Build prompt. Agents treat pre-decisions as binding; re-deliberation is a contract violation.
- **Oracle block splicing from Red to Build.** Red's output includes a fenced `## Oracle block` (failing test identifiers + one-line causes). The orchestrator splices this verbatim into the Build prompt's `## Oracle` section. Build's oracle of done is exactly the tests Red wrote failing; no paraphrase.
- **Pre-commit self-check ban in agent templates.** Agents no longer run `pre-commit run` inside their turn — the commit itself triggers the hook. Avoids doubled hook wall time.
- **QA focused re-review mode.** `agents/qa-phase.md`: iteration 2+ receives only the fix agent's delta + prior must-fix findings, not the full phase diff/spec/plan. Narrows iter-2 scope to "verify the fix resolves the finding + scan for regressions on the touched surface."

## [1.0.0] — earlier baseline

### Added
- Initial release: two-track execution (TDD + Implement modes), unified implementer agent, phased orchestration (Red → Build → Verify → Refactor → QA → Progress), 5-agent final review board, worktree-per-piece workflow, PRD/manifest/spec/plan artifact hierarchy.
