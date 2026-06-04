---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-01
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: pi-014-integ-tests — Integration Tests as a First-Class Pipeline Primitive

**PRD Sections:** G-2, FR-004, NFR-003, NN-P-002, NN-P-003
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** none (builds on merged state: pi-010-discovery, pi-012-single-branch, pi-013-goal-exec, and the v4.11.0 ground-truth reviewer)

> Full design rationale, research grounding, and the code-alignment deep-dive live in
> `plugins/spec-flow/proposals/review-board-integration/` (`spec.md`, `plan.md`,
> `concerns-and-integration-map.md`, `testing-foundations.md`, `alignment-findings.md`). This spec is
> the pipeline-authoritative restatement.

## Goal

Make **integration tests a first-class primitive** in the spec-flow pipeline so that **path coverage**
(does a test exercise the real wired path across a component boundary?) becomes a peer of AC coverage.
Today the pipeline guarantees AC coverage and component test quality but has no notion of path coverage;
the prop_firm calibration-2 audit showed the failure mode this leaves open — integration-boundary
defects that survive a green unit suite because each component is unit-tested in isolation with its
collaborator mocked, so the seam is never asserted. This piece threads an explicit `[integration]` test
tag, an `[Integration-Test]` phase block, mandated contract tests for doubled true externals, true
double-loop ordering, and a new `review-board-integration` reviewer through the whole pipeline
(doctrine → spec/plan authoring → RBVR → QA gates → execute integrity → review board), grounded in
established testing terminology (sociable / narrow integration tests; classical/Detroit TDD;
testing trophy/honeycomb).

## In Scope

- **A — Doctrine** (`reference/spec-flow-doctrine.md`): single source of truth for the definitions
  (integration boundary, integration test, path coverage, `[integration]` tag, contract test), the
  mocking policy, R1 + R3 (double-loop), the M1–M4 machinery, and the Verification-Checklist + ratios
  updates.
- **B — Spec authoring**: `skills/spec/SKILL.md` integration-surfacing step; `templates/spec.md`
  Integration Coverage block; `agents/qa-spec.md` allocation criterion.
- **C — Plan authoring**: `skills/plan/SKILL.md` integration-driven phase ordering + track/non-TDD
  handling + Contracts-vs-boundary distinction; `templates/plan.md` `[Integration-Test]` block +
  integration-test registry table; `agents/qa-plan.md` mapping/marker/contract criteria.
- **D — RBVR agents**: `agents/tdd-red.md`, `agents/implementer.md`, `agents/verify.md`,
  `agents/refactor.md`.
- **E — QA gates**: `agents/qa-tdd-red.md`, `agents/qa-phase.md`, `agents/qa-phase-lite.md`.
- **F — Execute orchestration + integrity** (`skills/execute/SKILL.md`): M1–M4.
- **G — Review board**: new `agents/review-board-integration.md` (+ `.agent.md` twin) and full wiring
  into `skills/execute/SKILL.md` Final Review + `skills/review-board/SKILL.md`, default everywhere.
- **H — Docs**: `README.md`, `docs/userguide/commands/{execute,review-board}.md`,
  `docs/userguide/concepts/{qa-loop,pipeline,tdd-loop}.md`.
- **I — Version**: bump 4.11.0 → 4.12.0 across the **four version-bearing files** per
  `plugins/spec-flow/docs/releasing.md` — the three JSON version strings (`plugins/spec-flow/plugin.json`,
  `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`) plus `CHANGELOG.md`.
- **J — Cross-cutting alignments**: `reference/ac-matrix-contract.md` `[integration]` pointer; doctrine
  as single source of truth.
- **K — Pipeline process-enforcement hardening** (additive edits to `skills/plan/SKILL.md` and
  `skills/execute/SKILL.md`): four process-enforcement gaps exposed by pi-014's own execution —
  (K1) cross-phase schema-consistency oracle when ≥2 phases declare overlapping schema-bearing files;
  (K2) Verify scope = actual-modified ∪ declared-scope before QA dispatch;
  (K3) anti-drift sweep must enumerate superseded count/ordinal strings alongside new patterns;
  (K4) CHANGELOG re-verification whenever a fix iteration lands after the CHANGELOG/version phase.

## Out of Scope / Non-Goals

- Not rewriting `review-board-ground-truth` — component-correctness depth stays its own agent (this
  reviewer owns boundary correctness + path coverage; de-confliction below).
- Not duplicating `edge-case`'s in-diff branch/boundary walking.
- No agent runs the app or auto-fixes — all reviewers stay read-only/advisory (path coverage is judged
  by reading tests, never by executing).
- Not a contract-testing framework — we mandate that doubled true externals *have* a contract test, not
  a specific tool.
- No CI/lint gate for board membership (none exists in the repo; out of scope).
- Migration: pre-4.12.0 in-flight pieces are NOT retrofitted (D10 — silent).

## Requirements

### Functional Requirements

- **FR-INT-01 (definitions):** The doctrine defines integration boundary, integration test, path
  coverage, the `[integration]` tag, and contract test, and states the mocking policy: real *inside*
  the boundary, stub/fake only *outside* it (never mock inside), every doubled true external backed by
  a contract test.
- **FR-INT-02 (R1):** The doctrine reframes the per-test scope rule as "one wired path per integration
  test" (integration-scope sibling of "one behavior per unit test").
- **FR-INT-03 (R3 double-loop):** The integration test is authored up front, drives the unit cycles, and
  is greened in the integration-completing phase (the phase introducing the last in-boundary component).
- **FR-INT-04 (M1 registry):** A per-piece integration-test registry table lives in `plan.md`, built
  from the plan + Red authoring (never from Build), and is carried across all phases by execute.
- **FR-INT-05 (M2 tag-separation):** The per-phase oracle and fast-mode direct run scope to the
  non-integration suite via an explicit marker exclusion (with a documented path-dir fallback for
  runners lacking markers); the up-front outer `[integration]` test is authored at piece start and is
  not in the per-phase gate until its completing phase.
- **FR-INT-06 (M3 edit window):** The content-hash integrity gate keeps registered `[integration]` test
  paths immutable at the skeleton hash until their completing phase, where it permits exactly one
  plan-authorized, path-confined, phase-gated skeleton→completed edit (covering the test's fixture/
  helper dependency-closure), records the completed hash, and is immutable thereafter.
- **FR-INT-07 (M4 oracle split + sub-cycle):** Per-phase invariants apply to the non-integration suite;
  a parallel invariant requires every `[integration]` test with `completes_in_phase ≤ current` to be
  green; the completing-phase `[Integration-Test]` sub-cycle (complete + green the outer test, run its
  contract tests) runs between `[Verify]` and `[Refactor]`.
- **FR-INT-08 (authoring affordances):** Spec authoring surfaces integrations + boundaries + doubled
  externals into a structured Integration Coverage block; plan authoring allocates each to a
  completing-phase `[Integration-Test]` block with a `completes_in_phase` marker and a contract test per
  doubled external; qa-spec/qa-plan enforce these.
- **FR-INT-09 (RBVR + QA enforcement):** tdd-red authors the outer `[integration]` test (one wired path,
  nothing in-boundary doubled); implementer greens it as wiring glue (no spurious BLOCK) and writes the
  contract tests; verify checks boundary authenticity + path coverage + contract faithfulness; refactor
  enforces integration-preservation; qa-tdd-red/qa-phase/qa-phase-lite check boundary authenticity.
- **FR-INT-10 (review board):** A new `review-board-integration` reviewer audits each path on two axes —
  boundary correctness (`SOUND/DIVERGES/UNTRACED`) and path coverage (`COVERED/UNIT-ONLY/UNCOVERED`,
  including the piece-only mock-avalanche and un-contract-tested-external-double cases) — and runs by
  default in both the piece-track Final Review (standard 7→8, fast 8→9) and the change-track board
  (6→7).
- **FR-INT-11 (anti-drift consistency):** Every board count, member-name list, fix-loop re-dispatch,
  amendment re-entry, and Step 8 source-agent enumeration that names the board members is updated
  consistently; no self-description still reads "7 standard / 8 fast" or omits `integration`.
- **FR-PROC-01 (cross-phase schema-consistency oracle):** When a plan declares ≥2 phases that each
  reference or mutate the same schema-bearing file (i.e., a file whose internal shape — field names,
  required keys, or structural invariants — is set in one phase and consumed or enforced in another),
  `skills/plan/SKILL.md` must instruct the plan author to insert a dedicated cross-phase consistency
  `[Verify]` step (executed after the last schema-touching phase) that checks every file referencing
  that schema for internal consistency. Addresses AC-13.
- **FR-PROC-02 (Verify-scope union):** `skills/execute/SKILL.md` must require the implementer to
  report its complete list of actually-modified files at the end of each phase, and must instruct the
  orchestrator to run the phase's `[Verify]` oracle and phase-level sweep against the UNION of the
  implementer's actual-modified-file list and the plan's declared scope for that phase — before
  dispatching QA, not after QA reports errors. Addresses AC-14.
- **FR-PROC-03 (anti-drift sweep superseded-ordinal coverage):** When a phase mutates a list-length
  or count invariant (e.g., a board member count or an Nth-member ordinal string), the anti-drift
  sweep pattern for that phase must include the SUPERSEDED ordinal/count strings (the values that
  were true before the phase), not only the new target pattern. `skills/plan/SKILL.md` (and/or
  `skills/execute/SKILL.md`) must prompt the author to enumerate superseded count/ordinal strings and
  require the sweep to search all in-scope files for each superseded string. Addresses AC-15.
- **FR-PROC-04 (post-CHANGELOG fix re-verification):** `skills/execute/SKILL.md` must instruct the
  orchestrator to re-check the CHANGELOG entry for accuracy whenever a fix iteration (Final Review
  fixes, late-phase corrections) lands after the CHANGELOG/version phase has run — because such fixes
  alter the ground truth the CHANGELOG describes. The re-check must confirm that every claim in the
  CHANGELOG entry accurately reflects the current state of the shipped changes. Addresses AC-16.

### Non-Functional Requirements

- **NFR-INT-01 (anti-cheat preservation):** The only new test-edit permission (M3) is plan-derived,
  qa-plan-reviewed, single-shot, path-confined, and phase-gated; Build cannot create a registry row,
  move a `completes_in_phase`, or edit a registered test outside the window. The immutability guarantee
  holds for every other test and outside the window.
- **NFR-INT-02 (backward compatibility — NN-C-003):** Additive/optional. Pre-4.12.0 specs/plans with no
  Integration Coverage / `[Integration-Test]` block / registry are not rejected; absence = "no
  integrations declared." Minor version bump.
- **NFR-INT-03 (graceful degradation — NN-C-005):** The tag-marker convention degrades to a path-dir
  fallback when the runner lacks markers; exclusions/inclusions are always stated explicitly, never
  silent.
- **NFR-INT-04 (human-readable — NN-P-001):** The registry is a markdown table in `plan.md`; all new
  artifacts are markdown/YAML.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-003 (semver / backward-compat): additive, opt-in stricter behavior → minor bump (4.12.0); no
  breaking change to existing specs/plans.
- NN-C-004 (bare agent names): the new `review-board-integration` agent's `name:` is bare, no plugin
  prefix.
- NN-C-005 (degrade silently when a capability is absent): tag-marker → path-dir fallback; missing
  integration sections treated as "none declared."
- NN-C-007 (CHANGELOG): a `## [4.12.0]` Keep-a-Changelog entry is added.
- NN-C-009 (version sync): 4.12.0 in all four version-bearing files per `releasing.md` — the three JSON
  version strings (`plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`,
  `.claude-plugin/marketplace.json`) plus `CHANGELOG.md` (the 4th).

**Product (NN-P — from `docs/prds/shared/prd.md`):**
- NN-P-001 (artifacts human-readable): the integration-test registry is a plain-markdown table in
  `plan.md`; no binary/obfuscated formats.
- NN-P-002 (two human sign-off gates, no auto-merge): M3/M4 and the new board member do **not** bypass
  per-phase QA or end-of-piece review-board sign-off; the new reviewer is additive to the human-gated
  board. The M3 edit window is a gate *tightening* mechanism, never a merge path.
- NN-P-003 (dog-food before recommend): this very piece runs the spec-flow pipeline on this repo,
  satisfying the dog-food rule for the new process before it is recommended to users.

### Coding Rules Honored

- CR-001 (agent frontmatter schema): `review-board-integration.md` carries `name:` + `description:`
  (+ `model: opus`) per the existing review-board agent pattern.
- CR-002 (skill frontmatter schema): any skill prose edits preserve the existing `name:`/`description:`
  frontmatter contract.

(The `.md` + `.agent.md` twin convention is a Copilot-CLI loader convention, not a charter rule — it is
stated in Technical Approach, not cited here.)

## Acceptance Criteria

AC-1: Given the doctrine, When read, Then it defines integration boundary / integration test / path
coverage / `[integration]` tag / contract test + the mocking policy, states R1, R3 double-loop, the M1–M4
machinery and the Implementer's-Dilemma resolution, has a path-coverage + contract line in the
Verification Checklist, and forbids mocking inside the boundary.
  Independent Test: in `spec-flow-doctrine.md` grep one anchor per claimed element — the five term
  definitions; mocking policy ("never mock inside the boundary"); R1 ("one wired path per integration
  test"); R3 ("double-loop" + "authored up front"); each of "M1"/"M2"/"M3"/"M4"; the
  Implementer's-Dilemma resolution ("wiring glue"); and the Verification-Checklist path-coverage +
  contract line.

AC-2: Given a spec being authored, When it declares an integration, Then `templates/spec.md` provides an
Integration Coverage block and `qa-spec` flags any declared integration not allocated to an AC with its
boundary stated.
  Independent Test: `templates/spec.md` contains the Integration Coverage block; `qa-spec.md` lists the
  allocation criterion.

AC-3: Given a plan, When a phase completes an integration, Then `templates/plan.md` provides the
`[Integration-Test]` block (boundary, contract tests, `completes_in_phase`) and the registry table, and
`qa-plan` flags any integration without a completing-phase block, marker, or per-external contract test.
  Independent Test: template + `qa-plan.md` criteria present; grep `[Integration-Test]` and the registry
  table in `templates/plan.md`.

AC-4: Given the RBVR agents, When read, Then tdd-red authors a one-wired-path `[integration]` test with
nothing in-boundary doubled; implementer treats integration Build as wiring glue without spurious BLOCK
and writes contract tests; verify has the boundary-authenticity / path-coverage / contract check;
refactor has the integration-preservation rule.
  Independent Test: grep the new clauses in `tdd-red.md`, `implementer.md`, `verify.md`, `refactor.md`
  (and twins).

AC-5: Given the QA gates, When read, Then `qa-tdd-red`, `qa-phase` (criterion 7), and `qa-phase-lite`
check boundary authenticity (nothing inside doubled) + contract faithfulness + a valid
`completes_in_phase`.
  Independent Test: grep the criteria in the three agent files (and twins).

AC-6: Given execute, When a piece declares integrations, Then the registry table is built from plan+Red
and carried across phases; the per-phase oracle and fast mode scope to the non-integration suite via an
explicit marker exclusion; the immutability gate enforces the single plan-authorized/path-confined/
phase-gated skeleton→completed edit window (incl. fixture/helper closure) and records the completed hash;
the completing-phase `[Integration-Test]` sub-cycle gates on the due integration test + contract tests.
  Independent Test: grep the M1–M4 prose in `execute/SKILL.md`; confirm the `not integration` exclusion
  text and the edit-window description appear.

AC-7: Given the immutability gate, When Build attempts to create a registry row, move a
`completes_in_phase`, or edit a registered test outside the window, Then it is rejected.
  Independent Test: `execute/SKILL.md` contains the explicit anti-cheat assertion that Build cannot
  self-authorize; the edit window is described as plan-derived, single-shot, path-confined, phase-gated.

AC-8: Given `agents/review-board-integration.md` (+ `.agent.md`), When read, Then they are byte-identical,
`name:` is bare, `model: opus`, read-only, with path-enumeration-first, 7 boundary probes + the coverage
probe (mock-avalanche + un-contract-tested external double), the two-axis verdict, Full + Focused
re-review modes, and explicit de-confliction vs ground-truth/edge-case/architecture.
  Independent Test: `cmp` the twins; grep frontmatter + the two-axis verdict + de-confliction section.

AC-9: Given Final Review and the out-of-band board, When dispatched, Then `review-board-integration` runs
by default in the piece-track set (standard 7→8, fast 8→9) and the change-track set (6→7); every count /
member list / fix-loop re-dispatch / amendment re-entry / Step 8 source-agent enumeration is consistent.
  Independent Test: dispatch-parity grep over `execute/SKILL.md`; `review-board/SKILL.md` default lens
  set + frontmatter + Step 3 include `integration`.

AC-10: Given the repo after the change, When grep-swept, Then no self-description reads "7 standard / 8
fast", "ALL SEVEN", or enumerates board members without `integration`; every place listing `ground-truth`
as a board member also lists `integration`.
  Independent Test: the anti-drift grep sweep returns no offending current-state hits (historical
  CHANGELOG entries excepted).

AC-11: Given `reference/ac-matrix-contract.md`, When an AC is covered by an integration test, Then a
concrete `tests/x.py:N [integration]` pointer is accepted (path coverage tracked orthogonally to AC
coverage); a bare category reference ("integration tests") remains invalid.
  Independent Test: grep the `[integration]` pointer allowance in `ac-matrix-contract.md`.

AC-12: Given the release, When inspected, Then the version is 4.12.0 in the three JSON version strings
(`plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`,
`.claude-plugin/marketplace.json`) and `CHANGELOG.md` is headed by a `## [4.12.0]` entry containing a
backward-compat migration note — the four version-bearing files per `releasing.md`, all in agreement.
  Independent Test: version-sync check across the four files (three JSON strings + CHANGELOG header) per
  `plugins/spec-flow/docs/releasing.md`.

AC-13: Given `skills/plan/SKILL.md`, When ≥2 phases in a plan reference or mutate the same
  schema-bearing file, Then the skill instructs the plan author to insert a dedicated cross-phase
  consistency `[Verify]` step after the last schema-touching phase, naming the overlapping files and
  the invariants to check.
  Independent Test: grep `skills/plan/SKILL.md` for a prose block containing "cross-phase" alongside
  "schema" (or "consistency") and "Verify" — confirming the file carries guidance to enumerate
  overlapping schema-bearing files and insert the dedicated verify step.

AC-14: Given `skills/execute/SKILL.md`, When a phase completes, Then the skill instructs the
  orchestrator to collect the implementer's actual-modified-file list and run the `[Verify]` oracle
  and phase-level sweep against the UNION of that list and the plan's declared scope — before
  dispatching QA.
  Independent Test: grep `skills/execute/SKILL.md` for a prose block containing "actual" alongside
  "modified" (or "touched") and "union" (or "declared scope") — confirming the instruction positions
  this scope check before QA dispatch.

AC-15: Given `skills/plan/SKILL.md` and/or `skills/execute/SKILL.md`, When a phase mutates a
  list-length or count invariant, Then the skill instructs the author to enumerate the superseded
  ordinal/count strings and include them in the anti-drift sweep alongside the new target patterns.
  Independent Test: grep the target file(s) for a prose block containing "superseded" alongside
  "ordinal" (or "count" or "prior") in the sweep guidance — confirming both the new-pattern
  requirement and the superseded-pattern requirement are present.

AC-16: Given `skills/execute/SKILL.md`, When a fix iteration lands after the CHANGELOG/version phase
  has run (e.g., a Final Review fix or a late-phase correction that changes shipped behavior), Then
  the skill instructs the orchestrator to re-verify the CHANGELOG entry for accuracy before the
  piece is considered complete.
  Independent Test: grep `skills/execute/SKILL.md` for a prose block containing "CHANGELOG" alongside
  "re-ver" (or "re-check") and "fix" (or "after") — confirming the instruction applies to fixes that
  land after the CHANGELOG phase.

## Technical Approach

**Terminology & grounding.** "Integration test" (not "seam test" — Feathers' *seam* is a substitution
point, not a junction). An integration test exercises the real wired path across an *integration
boundary*: real inside, stub/fake (not "mock" — Meszaros) only true externals outside, each backed by a
contract test. This is a *sociable* / *narrow integration test* in the classical/Detroit TDD tradition;
the testing trophy/honeycomb "mostly integration" movement is the lineage cited in the doctrine.

**Doctrine resolution R1 + R3.** R1: "one wired path per integration test" (not a new canon — "one assert
per test" is folklore, not a Beck law). R3: true double-loop / outside-in — the outer test is authored up
front and drives the unit cycles, greened in the completing phase. The Implementer's Dilemma dissolves
because, by the completing phase, the in-boundary components already exist, so greening is just minimal
wiring glue.

**Machinery M1–M4** (the cost of true double-loop, designed anti-cheat-preserving). M1 cross-phase
registry (table in `plan.md`, plan+Red-derived). M2 tag-separated suites: per-phase gate + fast mode run
the non-integration suite (marker exclusion, path-dir fallback) — resolves the oracle, fast-mode, and
Red "fail-now" collisions cheaply. M3 immutability-gate edit window: the single new gate change — a
plan-authorized, path-confined, phase-gated skeleton→completed edit (covering the fixture/helper closure,
which also closes the refactor real→double blind spot). M4 oracle split + completing-phase sub-cycle.

**De-confliction.** ground-truth = computed-component correctness (skips plumbing); integration reviewer
axis 1 = boundary correctness; axis 2 + per-phase QA = path coverage; verify/qa-tdd-red = AC/component
test quality. Per-phase QA catches gaps as the integration is wired; the piece-scoped reviewer is the
backstop for cross-phase integrations + mock avalanche.

**Build order (for the plan):** A doctrine → J-ref → templates → authoring skills + QA → F machinery →
RBVR + QA agents → G board + wiring → H docs → I version. Definitions and machinery land before the
agents that depend on them. Expect a largely Implement-track piece (prose/markdown + one new agent),
with `[Verify]` oracles being grep/structural/anti-cheat checks rather than unit tests.

**Twin-file convention (not a charter rule).** Agents this piece *authors or edits* ship byte-identical
`.md` + `.agent.md` twins (the Copilot-CLI loader reads both). The guarantee binds only the agents this
piece touches — pre-existing divergent twins it does NOT touch (e.g. `review-board-security`, whose
`.agent.md` is currently a stub) are a known prior condition, out of scope for pi-014.

## Testing Strategy

This piece edits spec-flow's own prose (doctrine, skills, agents, templates, docs), adds one agent, and
adds one structural artifact (the registry table) — there is no runtime application code, so verification
is **structural, not unit-test-shaped** (claiming a 60/30/10 unit ratio here would be theater).
- **Structural/grep checks** per acceptance criterion: definition presence, criterion presence, the
  `not integration` exclusion text, the edit-window description, the anti-cheat assertion.
- **Twin-integrity:** `cmp` the `.md` vs `.agent.md` of every agent **this piece authors or edits** (not
  pre-existing divergent twins it does not touch).
- **Anti-drift sweep (AC-10):** the board-count / member-list grep sweep.
- **Version-sync (AC-12):** four-file + CHANGELOG match.
- **Dispatch-parity (AC-9):** the five board enumerations in `execute/SKILL.md` name the same set.
- **Area K structural/grep checks (AC-13..AC-16):** grep-based verification of the four new
  process-enforcement guidance blocks in `skills/plan/SKILL.md` and `skills/execute/SKILL.md`;
  identical structural/grep nature as the rest of this piece.

## Integration Coverage

**None in scope.** This piece has no cross-component runtime wiring of its own — it is documentation,
agent-prose, and template changes plus one new read-only reviewer agent. There are no real external
dependencies to double and no wired runtime path to assert, so no `[integration]` test is required for
*this* piece. (Dog-fooding note: the primitive this piece *introduces* will apply to future
behavior-bearing pieces; pi-014 itself is correctly "no integrations declared" per D10.)

## Open Questions

None — all design decisions resolved (D1–D10 in the proposal). Q-migration resolved: pre-4.12.0 in-flight
pieces continue silently (absence = "no integrations declared," never flagged).
