---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: test-data-up

**PRD Sections:** FR-003, G-1
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** plan-concrete (merged)

## Goal

Move test-case *design* out of execute and into the plan. Every plan phase that **authors tests** — TDD-track `[TDD-Red]` phases and Non-TDD-mode `[Write-Tests]` phases — carries a **`Test Data` block**: one entry per behavior-under-test, each giving concrete input(s) and the expected output/oracle. The test-authoring agents then **transcribe** that oracle rather than designing it live: `tdd-red` (for `[TDD-Red]`) and the execute Step 2.7 Write-Tests dispatch (for `[Write-Tests]`) invent no input or expected outcome absent from the plan. Test-case design becomes an Opus plan-stage decision; execution is mechanical transcription. The primary enforcement is a new `qa-plan` concreteness criterion (#31) that must-fixes a test-authoring phase whose `Test Data` block is absent or incomplete; the agents' refuse-to-invent behavior is the defense-in-depth backstop.

A genuinely unpredictable expected outcome (real external / non-deterministic behavior) is surfaced with a **per-case `[SPIKE: <unknown>]` marker** — reusing the marker defined authoritatively in `plugins/spec-flow/reference/plan-concreteness.md` §2 verbatim (no new marker family) — so that case alone awaits resolution while predictable cases in the same phase keep concrete data.

## In Scope

- A new authoritative section **§5 (Test Data contract)** in `plugins/spec-flow/reference/plan-concreteness.md` defining: (a) which phases require a `Test Data` block (any phase containing a `[TDD-Red]` or `[Write-Tests]` step); (b) the per-case block schema (case ID + concrete input(s) + expected output/oracle); (c) the completeness rule (every behavior the test step names maps to a covering case; every case has both an input and an expected outcome); (d) per-case `[SPIKE: <unknown>]` for unpredictable outcomes, citing §2 for the marker syntax and scan-scoping (define-once: §5 does **not** restate the marker grammar); (e) the transcribe-only execution contract and the legacy `[TEST-DATA-ABSENT]` fallback.
- A Phase-2 authoring rule in `plugins/spec-flow/skills/plan/SKILL.md` (a new sub-rule, sibling to §2f) instructing the plan author to give every `[TDD-Red]` / `[Write-Tests]` phase a `Test Data` block per §5, with predictable cases concrete and unpredictable cases marked per-case `[SPIKE]` — citing the reference doc, not restating it.
- A `Test Data` slot in `plugins/spec-flow/templates/plan.md` on **both** the TDD-track `[TDD-Red]` exemplar (Phase 1) and the Non-TDD-mode `[Write-Tests]` exemplar (Phase 2 / the Non-TDD example), in the existing conditional-comment style, citing reference §5.
- A transcribe-only contract added to `plugins/spec-flow/agents/tdd-red.md`: its **Context Provided** gains the phase `Test Data` block; a new rule requires authoring the failing tests **from** that block and forbids inventing inputs/outcomes absent from it; a present-but-incomplete block → `BLOCKED` (route to plan amendment / Step 6c); an absent block → the legacy `[TEST-DATA-ABSENT]` fallback (design from the `[TDD-Red]` assertions as today).
- The same transcribe-only contract added to `plugins/spec-flow/skills/execute/SKILL.md` Step 2.7 (Write-Tests, Non-TDD mode) dispatch instructions: transcribe the phase's `Test Data` block, invent nothing, `BLOCKED` on a present-but-incomplete gap, `[TEST-DATA-ABSENT]` fallback when absent.
- A new must-fix criterion **#31** in `plugins/spec-flow/agents/qa-plan.md`: for each phase containing `[TDD-Red]` or `[Write-Tests]`, the `Test Data` block must be present and complete (or carry a per-case `[SPIKE]`); absence or incompleteness is must-fix. Carries the standard activation guard + **Evidence:** + **Must-fix.** convention of criteria #28–#30.
- Plugin version bump (minor: 5.4.0 → 5.5.0) synced across `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, and the repo-root `.claude-plugin/marketplace.json`; CHANGELOG entry.

## Out of Scope / Non-Goals

- **The spike resolver** — the Opus spike agent (`agents/spike.md`) that resolves a `[SPIKE]` into recorded test data, its isolated dispatch, and execute-time `[SPIKE]` handling are FR-005 / the `spike-agent` piece. This piece only *authors* the per-case `[SPIKE]` marker and relies on the existing plan-finalize spike-scan (shipped by `plan-concrete`) to block advancing while one survives. No edit to the finalize gate.
- **Re-defining or extending the `[SPIKE: <unknown>]` marker** — its syntax, scan-scoping, and accept/reject semantics live in `reference/plan-concreteness.md` §2 (shipped by `plan-concrete`). This piece cites §2 and introduces **no** new marker token (no `[SPIKE-DATA]`).
- **The per-phase concreteness floor and branch-enumeration-AC rule** (FR-002a/c, criteria #28/#30) — already shipped by `plan-concrete`. This piece adds the orthogonal test-data criterion (#31) only.
- **Checking that an expected *value* is correct** — `qa-plan` has no codebase/oracle access; whether `TokenExpired` is the *right* expectation is the Opus plan author's judgment (exactly where the PRD wants test design to live). `qa-plan` checks presence + structural completeness, not semantic correctness.
- **Integration-test data** — the outer `[integration]` test's wiring/contract requirements remain governed by the existing integration criteria (#26) and the Integration-Test Registry; this piece does not add a `Test Data` requirement to `[Integration-Test]` blocks.
- **Final Review circuit-breaker, model policy, flywheel** — other exec-ready pieces (`sonnet-coord`, `flywheel-*`). Untouched here.

## Requirements

### Functional Requirements

- **FR-003a (Test Data block required on test-authoring phases):** Every plan phase that contains a `[TDD-Red]` or `[Write-Tests]` step must carry a `Test Data` block — one entry per behavior-under-test, each with a case ID, concrete input(s), and an expected output/oracle. The block is **complete** when every behavior the test step names maps to a covering case and every case has both an input and an expected outcome. `qa-plan` criterion #31 must-fixes an absent or incomplete block (a per-case `[SPIKE]` on an unpredictable case satisfies "covered").
- **FR-003b (per-case `[SPIKE]` for unpredictable outcomes):** A case whose expected outcome genuinely cannot be predicted carries `[SPIKE: <unknown>]` in its expected-outcome position (syntax/scoping per reference §2); predictable cases in the same phase keep concrete data. A surviving per-case `[SPIKE]` is caught by the existing plan-finalize spike-scan (interim, until FR-005).
- **FR-003c (transcribe-only execution):** `tdd-red` (for `[TDD-Red]`) and the execute Step 2.7 dispatch (for `[Write-Tests]`) author tests **from** the phase's `Test Data` block and invent no input or expected outcome not present in the plan. A present-but-incomplete block → the agent emits `BLOCKED` naming the missing/incomplete case and routes to plan amendment (Step 6c); it writes no partial test set.
- **FR-003d (backward-compatible legacy fallback):** When a phase has **no** `Test Data` block at all (a plan authored before this contract), `tdd-red` / Step 2.7 emit `[TEST-DATA-ABSENT: <reason>]` and fall back to today's behavior (design tests from the `[TDD-Red]` assertions / from the implementation), without blocking. Distinguishing absence (legacy fallback) from present-but-incomplete (`BLOCKED`) is the contract that keeps the change additive under NN-C-003.
- **FR-003e (single authoritative contract home):** The Test Data contract is defined once in `reference/plan-concreteness.md` §5; `plan/SKILL.md`, `qa-plan.md`, `templates/plan.md`, `tdd-red.md`, and `execute/SKILL.md` Step 2.7 cite §5 and do not restate its definitions. §5 cites §2 for the `[SPIKE]` marker rather than redefining it.

### Non-Functional Requirements

- **NFR-TDU-1 (additive):** A piece whose plan lacks `Test Data` blocks runs current plan/execute behavior via the `[TEST-DATA-ABSENT]` fallback; no existing plan is broken and no committed artifact is rewritten. (Honors NN-C-003.)
- **NFR-TDU-2 (agent self-containment):** The edited `tdd-red.md` remains self-contained with a bare `name:` and assumes no conversation history; the Step 2.7 dispatch instructions remain inline and self-contained. (Honors NN-C-004, NN-C-008.)

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-001 (version/marketplace sync): the 5.4.0 → 5.5.0 bump is applied identically to both `plugin.json` files and the marketplace entry.
- NN-C-003 (backward compatibility within a major): the absent-vs-incomplete split (FR-003d) keeps the contract additive — legacy plans fall back, only new-contract plans are gated.
- NN-C-004 (agent `name:` is the bare agent name): the `tdd-red.md` edit preserves its bare `name: tdd-red` frontmatter.
- NN-C-007 (CHANGELOG in Keep a Changelog format): a 5.5.0 entry is added.
- NN-C-008 (agent prompts are self-contained): the new tdd-red transcribe rule and the Step 2.7 instructions assume only their injected context, no brainstorm/coordinator history.
- NN-C-009 (always bump plugin version on changes): plugin-behavior change → minor bump per semver scope.

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-001 (human approval gate on spec and plan): unchanged — this piece moves test design earlier but the plan still passes the human sign-off gate; nothing auto-advances.
- NN-P-002 (no silent execute-time discovery or self-resolution): the transcribe-only contract is a direct embodiment — a test-data gap surfaces as `BLOCKED` → Step 6c, never a silently-invented oracle. Genuine unknowns are explicit per-case `[SPIKE]` markers.
- NN-P-005 (thinking on Opus, mechanics on Sonnet): test-case design (the thinking) moves to the Opus plan stage; `tdd-red` / Step 2.7 (the mechanics, on Sonnet) only transcribe.

### Coding Rules Honored

- CR-001 (agent frontmatter schema): `tdd-red.md` keeps its `name:` + `description:` YAML schema.
- CR-003 (template placeholder syntax): the new `Test Data` slot in `templates/plan.md` uses the existing `{{...}}` placeholder + conditional-comment style.
- CR-005 (absolute file paths in documentation): all cross-file references (to `reference/plan-concreteness.md` §5/§2, etc.) use repo-absolute paths.
- CR-006 (CHANGELOG — Keep a Changelog): the 5.5.0 entry follows the format.
- CR-008 (thin-orchestrator skills, narrow-executor agents): the contract is defined in the reference doc and cited; `plan/SKILL.md` instructs, `tdd-red`/Step 2.7 execute narrowly, `qa-plan` reviews — no logic duplicated across them.
- CR-009 (markdown heading hierarchy): §5 is added at the reference doc's existing `##` section level; criterion #31 continues the numbered list.

## Acceptance Criteria

AC-1: Given a plan phase containing a `[TDD-Red]` or `[Write-Tests]` step, When `qa-plan` reviews it, Then a `Test Data` block must be present with one covering case (case ID + concrete input + expected outcome) per named behavior; an absent block, a named behavior with no covering case, or a case missing its input or its expected outcome is flagged must-fix (criterion #31). A per-case `[SPIKE: <unknown>]` in a case's expected-outcome position counts as covered for that case.
  Independent Test: dispatch `qa-plan` against fixture plans — (i) a `[TDD-Red]` phase with a complete per-case block → no #31 finding; (ii) the same phase with the block removed → #31 must-fix; (iii) a block whose listed behavior has no covering case → #31 must-fix; (iv) a `[Write-Tests]` (Non-TDD-mode) phase missing the block → #31 must-fix. Confirm each verdict from plan text alone.

AC-2: Given a TDD/Write-Tests phase with a case whose expected outcome cannot be predicted, When the plan author writes that case, Then its expected-outcome position is `[SPIKE: <unknown>]` (syntax per `reference/plan-concreteness.md` §2) while predictable cases in the same phase keep concrete data; the surviving per-case `[SPIKE]` is caught by the existing plan-finalize spike-scan and no new `[SPIKE-DATA]`-style token is introduced.
  Independent Test: read `reference/plan-concreteness.md` §5 and confirm it cites §2 for the marker (does not restate the grammar) and shows a mixed block (concrete case + `[SPIKE]` case); grep the six edited locations (`reference/plan-concreteness.md` §5, `plan/SKILL.md`, `qa-plan.md`, `templates/plan.md`, `tdd-red.md`, `execute/SKILL.md` Step 2.7) and confirm no new marker token besides `[SPIKE:`; confirm `plan/SKILL.md`'s existing finalize spike-scan text is unchanged (this piece adds no finalize edit).

AC-3: Given a dispatched `tdd-red` agent for a `[TDD-Red]` phase whose `Test Data` block is present and complete, When it authors the failing tests, Then every input and expected assertion traces to a case in the block and it invents none; given a present-but-incomplete block, Then it emits `BLOCKED` naming the missing/incomplete case, writes no partial test set, and routes to plan amendment (Step 6c).
  Independent Test: read `agents/tdd-red.md` and confirm (a) **Context Provided** lists the phase `Test Data` block; (b) a transcribe-only rule forbids inventing inputs/outcomes absent from the block and cites §5; (c) the present-but-incomplete → `BLOCKED` (no partial authoring) path exists, parallel to the existing Rule 0 / Rule 8 BLOCKED idioms.

AC-4: Given a Non-TDD-mode `[Write-Tests]` phase, When the execute Step 2.7 dispatch authors tests, Then it transcribes the phase's `Test Data` block, invents no input/outcome absent from it, and emits `BLOCKED` on a present-but-incomplete gap — the same contract as `tdd-red`.
  Independent Test: read `skills/execute/SKILL.md` Step 2.7 and confirm the dispatch instructions add the transcribe-from-`Test Data` directive, the no-invention rule, and the `BLOCKED`-on-gap path, citing reference §5.

AC-5: Given a plan phase with **no** `Test Data` block (a plan predating this contract), When `tdd-red` / Step 2.7 run, Then they emit `[TEST-DATA-ABSENT: <reason>]` and fall back to today's design-from-assertions behavior without blocking; the absent-vs-incomplete distinction is stated explicitly so absence never triggers the `BLOCKED` path.
  Independent Test: read `agents/tdd-red.md` and `skills/execute/SKILL.md` Step 2.7 and confirm the `[TEST-DATA-ABSENT]` fallback is documented as distinct from the present-but-incomplete `BLOCKED` path; confirm §5 documents the marker and the fallback semantics.

AC-6: Given the five consuming files, When each references the Test Data contract, Then `reference/plan-concreteness.md` §5 is the sole authoritative definition and `plan/SKILL.md`, `qa-plan.md`, `templates/plan.md`, `tdd-red.md`, and `execute/SKILL.md` Step 2.7 each cite §5 (define-once, cite-everywhere) without restating its definitions.
  Independent Test: read §5 and confirm it carries the schema + completeness rule + fallback; grep each of the five consuming locations for a citation to `reference/plan-concreteness.md` §5 and confirm none restates the block schema independently.

AC-7: Given the version-bearing files, When the piece ships, Then `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, and the repo-root `.claude-plugin/marketplace.json` all read `5.5.0`, and `CHANGELOG.md` has a `## [5.5.0]` entry describing the Test Data contract.
  Independent Test: grep the three version strings (all `5.5.0`, none `5.4.0`); read the CHANGELOG `## [5.5.0]` heading and its bullet list.

## Technical Approach

**Define-once, cite-everywhere.** Mirror the just-merged `plan-concrete` pattern exactly: extend the authoritative `reference/plan-concreteness.md` with a new `## 5. Test Data contract` section, then have all consumers cite it. §5 owns the schema, the completeness rule, the per-case `[SPIKE]` usage (citing §2), the transcribe-only contract, and the `[TEST-DATA-ABSENT]` fallback. No consumer restates these.

**Block schema (per-case).** A `Test Data:` block under the `[TDD-Red]` / `[Write-Tests]` step, one entry per behavior:
```
**Test Data:**
- TD-1: input `<concrete input>` → expect `<concrete expected outcome / oracle>`
- TD-2: input `<concrete input>` → [SPIKE: <what is unpredictable>]
```
The `[TDD-Red]` / `[Write-Tests]` test entries reference cases by ID (`test_foo → TD-1`), so the oracle is authored once and the agent transcribes data → assertions without a second copy to drift.

**Data flow.** Opus plan author writes the `Test Data` block → `qa-plan` #31 validates presence + completeness (primary gate) → human sign-off → plan finalize (existing spike-scan blocks any surviving per-case `[SPIKE]`) → execute dispatches `tdd-red` / Step 2.7 → agent transcribes block → no invention. A gap that slips past `qa-plan` (shouldn't, but) → agent `BLOCKED` → Step 6c amendment.

**Backward-compat split (the key invariant).** Two distinct conditions with two distinct responses, stated explicitly in §5 and in both agents so they cannot be conflated:
- **Block absent** (legacy plan) → `[TEST-DATA-ABSENT]` + legacy design-from-assertions. Additive (NN-C-003).
- **Block present but incomplete** (new-contract gap) → `BLOCKED` + Step 6c. Enforces the contract.
`qa-plan` #31 gates new plans so absence at execute time means "legacy," letting the fallback be safe.

**qa-plan #31 shape.** A sibling to #28–#30: activation guard "(activate per phase containing a `[TDD-Red]` or `[Write-Tests]` step; a phase with neither authors no tests — skip)", a **Flag:** list (absent block; named behavior with no covering case; case missing input or expected), a **Do NOT flag:** note (a case whose expected position is a well-formed `[SPIKE:]`; a pure `[Implement]` phase with no test step), an **Evidence:** requirement, and **Must-fix.** Evaluable from plan text alone (the test entries cite case IDs).

**Dogfood.** This piece's own plan is an Implement-track / doc-as-code plan with no `[TDD-Red]` or `[Write-Tests]` phases (per pi-011 testing doctrine — SKILL/agent/template/reference prose is verified by structural reads, not unit tests), so criterion #31 does not self-apply; its phases remain subject to the #28/#30 floor and branch-AC rules from `plan-concrete`.

## Testing Strategy

- **Unit focus:** N/A — the deliverables are SKILL/agent/template/reference prose, not executable code (pi-011 doctrine). "Tests" are structural reads + adversarial review.
- **Verification (Implement-track `[Verify]` steps):** crit-presence reads — confirm §5 contains the schema + completeness rule + `[SPIKE]`-via-§2 citation + `[TEST-DATA-ABSENT]` fallback; confirm `qa-plan.md` #31 text + activation guard + Flag list; confirm `plan/SKILL.md` authoring sub-rule + §5 citation; confirm both template slots; confirm `tdd-red.md` transcribe rule + Context Provided + BLOCKED/fallback split; confirm `execute/SKILL.md` Step 2.7 directives; confirm version strings + CHANGELOG.
- **Adversarial gate:** `qa-plan` against fixture plans (AC-1 cases i–iv: complete vs absent vs incomplete-case vs Write-Tests-missing; plus a mixed-block-with-`[SPIKE]` case; plus a pre-contract block-free plan for backward-compat → no #31 must-fix triggered inappropriately). These are the AC Independent Tests.
- **Edge cases:** a `[SPIKE:]` inside a fenced block / HTML comment in a Test Data area (not counted — §2 scan-scoping); a pure `[Implement]` (no-test) phase (#31 does not activate); a phase with both `[Write-Tests]` and a doc-as-code conditional (subject to both #30 and #31 independently); a block-absent legacy plan (fallback, not BLOCKED).

## Integration Coverage

None in scope. This piece is coordinated doc-as-code edits across six locations (`reference/plan-concreteness.md`, `plan/SKILL.md`, `qa-plan.md`, `templates/plan.md`, `tdd-red.md`, `execute/SKILL.md` Step 2.7) with no cross-component runtime wiring and no true externals to double. The cross-file consistency concern (one authoritative §5 vs five citers, and the `[SPIKE]` token shared with §2) is the codebase's standard cross-phase schema-consistency discipline, verified by the per-file `[Verify]` crit-presence reads, not an integration boundary.

## Open Questions

All brainstorm open questions resolved:
- **Test Data block shape (Q1)** → resolved: per-case labeled block (case ID + input + expected); `[TDD-Red]`/`[Write-Tests]` entries cite case IDs.
- **`[SPIKE]` granularity for unpredictable outcomes (PRD open question / Q2)** → resolved: per-case `[SPIKE]`, reusing §2 verbatim; predictable cases stay concrete; existing finalize spike-scan is the interim guard.
- **`tdd-red` on a gap (Q3)** → resolved: primary enforcement at `qa-plan` #31 completeness; agent `BLOCKED` on present-but-incomplete is the backstop; absent block → legacy fallback.
- **Scope: which test-authoring phases (Q4)** → resolved: both `[TDD-Red]` and Non-TDD-mode `[Write-Tests]`; pure `[Implement]` (no-test) phases excluded.

## Explicitly Out of Scope / Deferred

- **Spike resolver (Opus spike agent + execute-time `[SPIKE]` dispatch + spike→test-data recording)** → owned by `spike-agent` (FR-005). This piece authors the per-case `[SPIKE]` and relies on `plan-concrete`'s finalize spike-scan as the interim guard.
- **`[Integration-Test]` test-data requirement** → governed by the existing integration criteria (#26) / Integration-Test Registry; not extended here.
- **Semantic correctness of expected values** → inherently the Opus plan author's judgment; `qa-plan` checks presence + completeness only (no codebase/oracle access).
