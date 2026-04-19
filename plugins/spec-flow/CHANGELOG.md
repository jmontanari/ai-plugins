# Changelog

All notable changes to the `spec-flow` plugin. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the plugin uses [Semantic Versioning](https://semver.org/).

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
