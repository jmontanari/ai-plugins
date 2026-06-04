---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-01
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
legacy_deferred_rows: false
tdd: false
fast: false
---

# Plan: pi-014-integ-tests — Integration Tests as a First-Class Pipeline Primitive (spec-flow 4.12.0)

**Spec:** docs/prds/shared/specs/pi-014-integ-tests/spec.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** final-review-pending

## Overview

This piece threads **integration tests as a first-class pipeline primitive** (path coverage as a peer of
AC coverage) through the entire spec-flow chain: doctrine → spec/plan authoring + QA → RBVR agents → QA
gates → execute orchestration + integrity gate → review board → docs → version. It adds the
`[integration]` test tag, the `[Integration-Test]` phase block, a per-piece integration-test registry,
mandated contract tests for doubled true externals, the M1–M4 machinery (true double-loop), and a new
`review-board-integration` reviewer, default everywhere.

**Track & mode.** `tdd: false`, `fast: false`. Every artifact this piece touches is markdown/agent-prose
plus one new agent — there is **no runtime application code and no test framework**. Per the spec's
Testing Strategy, verification is **structural** (grep / `cmp` twin-integrity / anti-drift sweep /
version-sync / dispatch-parity), not unit-test-shaped — "claiming a 60/30/10 unit ratio here would be
theater." All phases therefore use the **Implement track** (`[Implement]` → `[Verify]` → optional
`[Refactor]` → `[QA]`, per qa-plan criterion 3's Implement-track definition). There is no separate test
suite to author, so no `[Write-Tests]` block is used; each phase's structural oracles live directly in its
`[Verify]` block as copy-pasteable grep/`cmp`/`diff` commands with concrete expected output. An AC
Coverage Matrix and Executable AC Binding table are still generated (traceability for the 12 ACs).

**Build order (dependency-correct).** Definitions and machinery land before the agents/templates that
depend on them: **A doctrine + J ac-matrix → templates → spec authoring → plan authoring → execute M1+M2
→ execute M3+M4 → RBVR agents → QA gates → new reviewer agent → board wiring → docs → version + sweep.**

**Why serial (whole plan).** Several phases have disjoint file scopes (e.g. spec-authoring vs
plan-authoring; RBVR vs QA-gate agents) and could be parallelized. They are kept **serial by deliberate
choice** because (1) this is consistency-sensitive prose: the dominant risk is terminological drift
(single-source-of-truth definitions) and board-count/dispatch-parity drift (AC-9/AC-10/FR-INT-11) that is
best caught phase-by-phase by the standard-mode per-phase Opus QA (`fast: false`); (2) the build order is
a strict dependency chain anyway; (3) wall-clock savings from parallelizing markdown edits are negligible
against the consistency cost. Per-phase `Why serial:` lines head the affected chains.

**Twin convention.** Every agent file this piece authors or edits ships byte-identical `.md` + `.agent.md`
twins (Copilot-CLI loader convention). All 10 touched agents are currently identical; the new
`review-board-integration` agent is created as identical twins. Each phase that edits an agent edits BOTH
files identically and verifies with `cmp` in `[Verify]`.

**Cross-cutting charter constraints** (honored by all relevant phases, per qa-plan criterion 8's
cross-cutting allowance):
- **NN-P-003 (dog-food before recommend):** honored by ALL phases — this piece runs the spec-flow
  pipeline (spec→plan→execute) on this very repo to introduce the integration-test primitive before it is
  recommended to users.
- **CR-002 (skill frontmatter schema preserved):** honored by all skill-editing phases (3, 4, 5, 6, 10)
  via preserving each `SKILL.md`'s existing `name:`/`description:` frontmatter on every edit.

## Architectural Decisions

### ADR-1: Adopt True Option B (M1–M4 machinery) over the lower-risk B-lite
**Context:** The core mechanic — author the outer integration test up front, green it in a later
"completing" phase (true double-loop / outside-in) — collides with four load-bearing spec-flow mechanisms
(per-phase SHA-256 test-immutability gate; the "every Red test must pass" oracle; fast-mode raw exit-code
check; Red's "fail-now" contract). The design deep-dive (`proposals/.../alignment-findings.md`)
recommended **B-lite** (declare the scenario up front but author+green the test within one phase) to avoid
touching the safety-critical anti-cheat gate.
**Decision:** The spec adopted **True Option B** with the M1–M4 machinery (FR-INT-04..07): a cross-phase
integration-test registry (M1), tag-separated suites (M2), a single plan-authorized/path-confined/
phase-gated immutability-gate **edit window** (M3), and an oracle split + completing-phase sub-cycle (M4).
**Alternatives considered:** (a) **B-lite** — no anti-cheat gate change, but loses true double-loop
(outer test does not actually drive unit cycles across phases); (b) **Pure A** — author the integration
test last with no up-front declaration; simplest, but loses the planning-drive benefit entirely.
**Consequences:** Enables genuine outside-in double-loop and cross-phase integrations + mock-avalanche
detection; **costs** a controlled weakening of the immutability gate (the M3 edit window) — the
highest-stakes change in the piece, mitigated by making the window single-shot, plan-derived,
qa-plan-reviewed, path-confined (incl. fixture/helper closure), and phase-gated (NFR-INT-01). Rollback to
B-lite remains possible (drop M3, keep declared-scenario planning).
**Charter alignment:** Honors NN-P-002 (the M3 window is a gate *tightening* mechanism, never a merge
path; two human sign-off gates intact) and NFR-INT-01 (anti-cheat preservation); constrains
implementation of Phase 6.

### ADR-2: Name the tag `[integration]` (not the proposal's `[seam]`)
**Context:** The design drafts used a `[seam]` tag. "Seam" (Feathers) is precisely a *substitution point*,
not a *junction across a boundary* — using it for integration tests is a terminology mismatch.
**Decision:** Use `[integration]` for the test tag and `[Integration-Test]` for the phase block, grounded
in established testing vocabulary (sociable / narrow integration tests; classical/Detroit TDD; testing
trophy/honeycomb "mostly integration").
**Alternatives considered:** (a) **`[seam]`** — the proposal's original; rejected for the Feathers
mismatch; (b) **heuristic detection** (no explicit tag) — zero authoring burden but unreliable; the
integrity gate and QA agents could not cheaply key off "is this an integration test."
**Consequences:** Small explicit authoring burden; unambiguous keying for the M2 suite split, the M3 edit
window, and every QA/RBVR check; one canonical term defined once in the doctrine.
**Charter alignment:** Honors NN-P-001 (human-readable, self-describing tag in plain test source).

### ADR-3: The doctrine is the single source of truth for all integration definitions
**Context:** Definitions (integration boundary, integration test, path coverage, `[integration]` tag,
contract test, mocking policy) are referenced by templates, authoring skills, RBVR agents, QA gates, and
the review board. Defining them in each consumer would guarantee drift.
**Decision:** Define every term and the mocking policy + R1 + R3 + M1–M4 once in
`reference/spec-flow-doctrine.md` (Phase 1). All other artifacts **reference** the doctrine, never
redefine.
**Alternatives considered:** (a) define inline in each consuming agent/template (duplication → drift);
(b) leave definitions in the proposal only (not loaded at session start → invisible to agents).
**Consequences:** One place to update; the session-start hook already loads the doctrine, carrying the new
definitions into every agent's context for free; verification includes a "definition appears only in the
doctrine" grep (Phase 12).
**Charter alignment:** Supports NN-C-005 (the path-dir fallback is stated once, authoritatively).

### ADR-4: Ship as one comprehensive 4.12.0 piece (not staged across 2–3 versions)
**Context:** The concerns-map suggested staging the work across 2–3 versions (doctrine+tag+reviewer first;
enforcement second; authoring affordances third).
**Decision:** Ship the full chain in **one** 4.12.0 piece (spec In Scope A–J).
**Alternatives considered:** (a) **stage across versions** — smaller diffs per release, but the primitive
is non-functional until all tiers land (a reviewer with no `[integration]` tag, or a tag with no enforcing
gate, is half a feature); (b) **one piece** — larger diff, but the primitive is coherent and dog-foodable
the moment it lands.
**Consequences:** A larger, cross-cutting diff (mitigated by the dependency-correct build order and
per-phase QA); the additive/optional design (NFR-INT-02) keeps it a single minor bump; the anti-drift
sweep (Phase 12) is the backstop against partial-landing inconsistency.
**Charter alignment:** Honors NN-C-003 (additive, backward-compatible → minor bump 4.12.0).

## Phases

Each phase uses the **Implement track** (`[Implement]` → `[Verify]` → optional `[Refactor]` → `[QA]`).
`[Verify]` blocks hold structural oracles (grep / `cmp` / `diff` / version checks) with concrete expected
output — these ARE this piece's tests (no runtime suite exists). Agent edits always update `.md` + twin
`.agent.md` identically and `cmp` them.

---

### Phase 1: Doctrine + AC-matrix reference (Areas A + J)
**Exit Gate:** `spec-flow-doctrine.md` defines all five integration terms + mocking policy + R1 + R3 +
M1–M4 + Implementer's-Dilemma resolution, has the path-coverage + contract line in the Verification
Checklist, and forbids mocking inside the boundary; `ac-matrix-contract.md` accepts a concrete
`tests/x.py:N [integration]` pointer while still rejecting a bare category reference. All AC-1 and AC-11
independent-test greps pass.
**ACs Covered:** AC-1, AC-11
**In scope:** `plugins/spec-flow/reference/spec-flow-doctrine.md`, `plugins/spec-flow/reference/ac-matrix-contract.md`
**NOT in scope:** `templates/spec.md` Integration Coverage block (Phase 2); `templates/plan.md`
`[Integration-Test]` block + registry (Phase 2); any skill/agent edits (Phases 3–11). The doctrine
*defines* M1–M4; execute *implements* them (Phases 5–6).
**Charter constraints honored in this phase:**
- Cross-cutting only: NN-P-003 (dog-food) via running this through the pipeline. (Definitions phase;
  NN-C-005's fallback is *implemented* in Phase 5 — see Overview.)

- [x] **[Implement]** Add integration-test definitions, mocking policy, R1, R3, M1–M4, and the
  Verification-Checklist additions to the doctrine; relax the ac-matrix vague-pointer rule for tagged
  integration pointers.
  - Order: doctrine definitions block → mocking policy → R1 → R3 + M1–M4 → Verification-Checklist line →
    ratios clarification → then the ac-matrix-contract edits.
  - Architecture constraints: doctrine is the single source of truth (ADR-3). Match existing doctrine
    idioms: bold-term em-dash for definitions; numbered bold-label lists for hierarchies; `### CAPS
    (scope)` headings for cycle stages.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/reference/spec-flow-doctrine.md**
  - Anchor: `## Testing Strategy` → Ratios + Test-doubles hierarchy (lines 96–105)
  - Current:
    ```
    96  **Ratios (guideline, not rigid):**
    97  - ~60% unit tests (behavior of individual components)
    98  - ~30% integration tests (component interaction, data flow)
    99  - ~10% E2E / acceptance tests (critical paths from spec ACs)
    100
    101 **Test doubles hierarchy (preferred order):**
    102 1. Real object (best — if fast and deterministic)
    103 2. Fake (working but simplified — e.g., in-memory database)
    104 3. Stub (returns predetermined values)
    105 4. Mock (tracks interactions — only when verifying side effects)
    ```
  - Target: Immediately after line 99, clarify that the ~30% integration tier = the `[integration]`
    tests defined below, and cite the trophy/honeycomb "mostly integration" lineage. After the
    test-doubles hierarchy (line 105), add a **mocking policy** paragraph: "Real *inside* the integration
    boundary; stub/fake (Meszaros — not 'mock') only for *true externals* outside it; **never double
    anything inside the boundary**; every doubled true external is backed by a passing **contract test**."
  - Pattern (existing bold-label list idiom, lines 101–105 above): mirror the `**Label (note):**` +
    numbered/bulleted form.
  - Done: ratios reference `[integration]`; a mocking-policy paragraph exists containing the literal
    string "never mock inside the boundary" (or "never double anything inside the boundary" — see T-2
    Done for the exact required anchor).
  - Verify: `grep -n "never mock inside the boundary" plugins/spec-flow/reference/spec-flow-doctrine.md`

  **T-2: MODIFY plugins/spec-flow/reference/spec-flow-doctrine.md**
  - Anchor: new `## Integration Tests & Path Coverage` section, inserted after `## Testing Strategy`
    (after line 107, before `## Verification Checklist` at line 109)
  - Current (the boundary the new section is inserted between):
    ```
    105 4. Mock (tracks interactions — only when verifying side effects)
    106
    107 (end of Testing Strategy section)
    109 ## Verification Checklist
    ```
  - Target: Add a new `##` section defining, each as a **bold-term — em-dash** entry:
    - **Integration boundary** — the set of real components a wired path crosses; "inside" = these
      components, "outside" = true externals.
    - **Integration test** — exercises the real wired path across an integration boundary (real inside;
      stub/fake outside); a *sociable / narrow integration test* (classical/Detroit lineage). Define it
      explicitly to **exclude** the broad "live everything" reading.
    - **Path coverage** — does a test exercise the real wired path across a boundary? A peer of AC
      coverage, tracked orthogonally.
    - **`[integration]` tag** — the marker on an integration test; keys the M2 suite split, the M3 edit
      window, and every QA/RBVR check.
    - **Contract test** — verifies a stub/fake of a true external stays faithful to the real external's
      contract.
    Then add the explicit policy line containing **"never mock inside the boundary"**; **R1** ("one wired
    path per integration test" — sibling of "one behavior per unit test"; note "one assert per test" is
    folklore, not a Beck law); **R3** ("**double-loop**: the integration test is **authored up front**,
    drives the unit cycles, and is greened in the integration-completing phase"); and the
    **Implementer's-Dilemma resolution** ("by the completing phase the in-boundary components already
    exist, so greening the outer test is just minimal **wiring glue**"). Then document **M1/M2/M3/M4** as
    doctrine (each literal token present): M1 cross-phase integration-test **registry** (table in
    `plan.md`, built from plan+Red, never Build); M2 **tag-separated suites** (per-phase gate + fast mode
    run the non-integration suite via a marker exclusion such as `-m 'not integration'`, with a
    **path-dir fallback** for runners lacking markers; exclusions always stated explicitly, never
    silent); M3 immutability-gate **edit window** (single plan-authorized, path-confined incl.
    fixture/helper closure, phase-gated skeleton→completed edit); M4 **oracle split** + completing-phase
    `[Integration-Test]` sub-cycle.
  - Pattern (Theater Catalog bold-term em-dash idiom, doctrine lines 131–133):
    ```
    1. **Tautology as sole assertion** — `assert True` ... Passes regardless of the production code.
    2. **Self-referential** — `assert foo(5) == foo(5)`. Always true whatever `foo` does.
    ```
  - Done: every literal token present — the five term names, "never mock inside the boundary", "one wired
    path per integration test", "double-loop", "authored up front", "wiring glue", and each of
    "M1"/"M2"/"M3"/"M4" — all in this one section of the doctrine.
  - Verify: `grep -nE "integration boundary|path coverage|\[integration\]|contract test|never mock inside the boundary|one wired path per integration test|double-loop|authored up front|wiring glue|M1|M2|M3|M4" plugins/spec-flow/reference/spec-flow-doctrine.md` returns matches for each.

  **T-3: MODIFY plugins/spec-flow/reference/spec-flow-doctrine.md**
  - Anchor: `## Verification Checklist` (lines 109–121)
  - Current:
    ```
    116 - [ ] Minimal code written to pass each test
    117 - [ ] All tests pass, output clean (no warnings)
    118 - [ ] Tests use real code (mocks justified where used)
    119 - [ ] Edge cases and error paths covered
    120 - [ ] No over-engineering beyond test requirements
    121 - [ ] Refactoring stayed within phase scope
    ```
  - Target: Replace line 117 ("All tests pass…") with the M2-split form: "All **non-integration** tests
    pass; every due `[integration]` test (`completes_in_phase ≤ current`) is green; each doubled external
    has a passing contract test." Add a new checklist item: "Path coverage: each integration-bearing AC
    has a real-wired-path `[integration]` test (not unit-only)."
  - Pattern: existing `- [ ] ...` checklist item form (lines 116–121 above).
  - Done: the checklist contains a "non-integration" clause AND a "Path coverage" item.
  - Verify: `grep -nE "non-integration tests pass|Path coverage:" plugins/spec-flow/reference/spec-flow-doctrine.md` returns both.

  **T-4: MODIFY plugins/spec-flow/reference/ac-matrix-contract.md**
  - Anchor: Validation rule 4 "Vague `covered` pointer" (line 49) + Schema Pointer row (line 19)
  - Current:
    ```
    49  4. **Vague `covered` pointer.** A `covered` row whose Pointer column lacks a concrete `file:line` (TDD mode) or a concrete assertion reference inside the `[Verify]` command (Implement mode). Examples that fail validation: `see test file`, `covered by integration tests`, `tests/foo.py` (no line), `the build runs`. The pointer must be unambiguously verifiable.
    ```
  - Target: Amend rule 4 so a concrete **`tests/x.py:N [integration]`** pointer (path + line + tag) is
    **accepted** as a valid concrete pointer (path coverage tracked orthogonally to AC coverage), while a
    **bare category reference** ("covered by integration tests" with no file:line) remains invalid. Update
    the line-19 Schema Pointer description to list `tests/x.py:N [integration]` as a valid concrete
    pointer form. Do NOT change the matrix structure.
  - Pattern (existing rule idiom, same file rule 3 at line 48): `N. **Title.** <rule>. Examples that fail
    validation: ...`
  - Done: rule 4 explicitly allows the tagged `file:line` pointer and explicitly keeps the bare
    "covered by integration tests" invalid; line 19 mentions the `[integration]` pointer form.
  - Verify: `grep -nE "\[integration\]" plugins/spec-flow/reference/ac-matrix-contract.md` returns a
    match in both rule 4 and the schema row; the bare-category-invalid wording is preserved.

- [x] **[Verify]** Confirm doctrine definitions + ac-matrix pointer allowance (structural oracle = this
  piece's test for AC-1, AC-11)
  **Per-change checks:**
  - T-1: `grep -c "never mock inside the boundary" plugins/spec-flow/reference/spec-flow-doctrine.md` — Expected: ≥ 1
  - T-2: `grep -nE "integration boundary|integration test|path coverage|\[integration\]|contract test" plugins/spec-flow/reference/spec-flow-doctrine.md` — Expected: ≥ 1 match per term; and `grep -nE "M1|M2|M3|M4|wiring glue|double-loop|one wired path per integration test|authored up front" plugins/spec-flow/reference/spec-flow-doctrine.md` — Expected: a match for each token
  - T-3: `grep -nE "non-integration tests pass|Path coverage:" plugins/spec-flow/reference/spec-flow-doctrine.md` — Expected: 2 matches
  - T-4: `grep -n "\[integration\]" plugins/spec-flow/reference/ac-matrix-contract.md` — Expected: ≥ 2 matches; `grep -n "covered by integration tests" plugins/spec-flow/reference/ac-matrix-contract.md` — Expected: still present as a negative/invalid example
  **Phase-level check:**
  - Run (AC-1 independent test): `grep -nE "never mock inside the boundary|one wired path per integration test|double-loop|wiring glue|Path coverage:" plugins/spec-flow/reference/spec-flow-doctrine.md`
  - Expected: a match for every alternation (each appears at least once)
  - Failure: any token returns 0 matches → the doctrine is missing a required element

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-11
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 2: Templates — Integration Coverage block, `[Integration-Test]` block, registry table (Area: templates)
**Exit Gate:** `templates/spec.md` has a structured Integration Coverage block; `templates/plan.md` has an
`[Integration-Test]` block in all three phase examples (after `[Verify]`, before `[Refactor]`) and a
top-level integration-test registry table. Greps for both blocks succeed.
**ACs Covered:** AC-2 (template portion), AC-3 (template portion)
**In scope:** `plugins/spec-flow/templates/spec.md`, `plugins/spec-flow/templates/plan.md`
**NOT in scope:** `agents/qa-spec.md` allocation criterion (Phase 3); `agents/qa-plan.md` criteria
(Phase 4); `skills/spec/SKILL.md` surfacing step (Phase 3); execute building the registry (Phase 5).
**Charter constraints honored in this phase:**
- NN-P-001 (artifacts human-readable): the integration-test registry is added as a **plain-markdown
  table** in `templates/plan.md`; no binary/obfuscated format.
- Cross-cutting: NN-P-003 (dog-food).

- [x] **[Implement]** Add the Integration Coverage block to the spec template and the
  `[Integration-Test]` block + registry table to the plan template.
  - Order: spec template block → plan `[Integration-Test]` block (×3 examples) → plan registry table.
  - Architecture constraints: templates reference the doctrine's definitions (ADR-3), they do not
    redefine them. Match the existing `{{placeholder}}` + checkbox-marker idiom.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/templates/spec.md**
  - Anchor: `## Acceptance Criteria` (lines 53–55) + `## Testing Strategy` (lines 60–63)
  - Current:
    ```
    53 ## Acceptance Criteria
    54 AC-1: Given {{precondition}}, When {{action}}, Then {{outcome}}
    55   Independent Test: {{how_to_verify_in_isolation}}
    ...
    60 ## Testing Strategy
    61 - Unit test focus areas
    62 - Integration test boundaries
    63 - Edge cases to cover
    ```
  - Target: Add a new `## Integration Coverage` section (after `## Testing Strategy`) with a structured,
    per-integration template line: ``Integration: {{A}}→{{B}} — inside:{{components}}; doubled
    externals:{{ext}}(contract-tested); AC-{{id}}; completes phase {{N}}``, plus a note that a piece with
    no cross-component wiring writes "None in scope." Soften line 55's framing: append "(for an
    integration-bearing AC, the Independent Test may assert the real wired path, not isolation)".
  - Pattern (existing template section idiom, spec template lines 60–63 above): `## Heading` + `-` bullet
    placeholders.
  - Done: `## Integration Coverage` exists with the structured `Integration: A→B — inside:...;
    completes phase N` template line; line 55 carries the softened note.
  - Verify: `grep -nE "## Integration Coverage|inside:.*doubled externals|completes phase" plugins/spec-flow/templates/spec.md`

  **T-2: MODIFY plugins/spec-flow/templates/plan.md**
  - Anchor: TDD example `[Verify]`→`[Refactor]` boundary (lines 95–97); Implement example (after line
    143); Non-TDD example (after ~line 196)
  - Current (TDD example boundary):
    ```
    95   - Verify: no test files modified since TDD-Red step
    96
    97 - [ ] **[Refactor]** Clean up (scope: Phase 1 files only)
    ```
  - Target: In EACH of the three phase examples (TDD, Implement, Non-TDD), insert an `[Integration-Test]`
    checkbox block **after `[Verify]` and before `[Refactor]`**:
    ```
    - [ ] **[Integration-Test]** (completing-phase only) Complete + green the outer `[integration]` test
      - Boundary: {{which components are inside; which true externals are doubled}}
      - completes_in_phase: {{N}}
      - Contract tests: {{one per doubled true external}}
      - Run: {{real-wired-path test command}} — Expected: {{specific pass output}}
      - Note: omit this block on non-completing phases; the registered test stays skeleton-red until N.
    ```
  - Pattern (existing checkbox-marker idiom, plan template lines 87–95):
    ```
    - [ ] **[Verify]** Confirm tests pass
      **Phase-level check:**
      - Run: {{exact_test_command}}
    ```
  - Done: three `[Integration-Test]` blocks exist, each between its example's `[Verify]` and `[Refactor]`,
    each naming Boundary + completes_in_phase + Contract tests + a real-path Run command.
  - Verify: `grep -c "\[Integration-Test\]" plugins/spec-flow/templates/plan.md` — Expected: 3

  **T-3: MODIFY plugins/spec-flow/templates/plan.md**
  - Anchor: top-level section sequence — insert after the `## Phases` preamble (after line 48), before
    `### Phase 1 (TDD track example)` (line 49)
  - Current:
    ```
    47 A phase must have exactly one of these markers. The executor branches mechanically on the checkbox it finds.
    48
    49 ### Phase 1 (TDD track example): {{phase_name}}
    ```
  - Target: Add a `## Integration-Test Registry (M1)` section with a markdown table — columns:
    `| ID | Path | Boundary (inside) | Doubled externals (contract test) | AC | completes_in_phase | skeleton_sha256 | completed_sha256 |` — and a one-line note: "Built from plan + Red authoring (never from Build); carried across phases by execute; absent ⇒ no integrations declared (NFR-INT-02)."
  - Pattern (existing markdown-table idiom, plan template AC Coverage Matrix lines 259–261):
    ```
    | AC ID | Summary | Status | Covered By |
    |-------|---------|--------|------------|
    | {{ac_id}} | {{one_line_summary}} | COVERED | {{phase_reference}} |
    ```
  - Done: `## Integration-Test Registry` section + its 8-column table header + the "never from Build" note
    are present.
  - Verify: `grep -nE "## Integration-Test Registry|completes_in_phase|skeleton_sha256" plugins/spec-flow/templates/plan.md`

  **T-4: MODIFY plugins/spec-flow/templates/plan.md**
  - Anchor: fast-mode frontmatter comment (lines 10–14, "verify Mode: Piece Full as 7th board member")
  - Current:
    ```
    10 fast: false                  # true = fast mode: skips per-phase QA agents (qa-tdd-red, qa-phase, qa-phase-lite),
    11                              # replaces per-phase verify agent with direct test-command shell run, adds
    12                              # verify Mode: Piece Full as 7th board member at Final Review.
    ```
  - Target: Update line 12 "7th board member" → "9th board member" (post-change fast-mode board = 9; the
    integration reviewer makes standard 8, and verify-piece-full is the 9th in fast mode). This aligns the
    template comment with the board counts set in Phases 10–11.
  - Pattern: n/a (single-token comment edit).
  - Done: the comment reads "9th board member".
  - Verify: `grep -n "9th board member" plugins/spec-flow/templates/plan.md` returns line 12; `grep -n "7th board member" plugins/spec-flow/templates/plan.md` returns nothing.

- [x] **[Verify]** Confirm template blocks (structural oracle for AC-2/AC-3 template portion)
  **Per-change checks:**
  - T-1: `grep -nE "## Integration Coverage|completes phase" plugins/spec-flow/templates/spec.md` — Expected: ≥ 2 matches
  - T-2: `grep -c "\[Integration-Test\]" plugins/spec-flow/templates/plan.md` — Expected: 3
  - T-3: `grep -nE "## Integration-Test Registry|skeleton_sha256|completed_sha256" plugins/spec-flow/templates/plan.md` — Expected: ≥ 3 matches
  - T-4: `grep -c "7th board member" plugins/spec-flow/templates/plan.md` — Expected: 0
  **Phase-level check:**
  - Run: `grep -l "Integration Coverage" plugins/spec-flow/templates/spec.md && grep -l "Integration-Test Registry" plugins/spec-flow/templates/plan.md`
  - Expected: both file paths printed (both sections present)
  - Failure: either grep prints nothing → a template block is missing

- [x] **[QA]** Phase review
  - Review against: AC-2, AC-3
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 3: Spec authoring — surfacing step + qa-spec criterion (Area B)
Why serial: kept serial from Phase 4 (plan authoring) despite disjoint scopes — both extend authoring
prose that must stay terminologically consistent with the Phase 1 doctrine, and per-phase Opus QA
(`fast: false`) is the consistency backstop (see Overview "Why serial").
**Exit Gate:** `skills/spec/SKILL.md` brainstorm surfaces integrations/boundaries/doubled-externals;
`qa-spec.md` (+twin) has an allocation criterion flagging any declared integration not allocated to an AC
with its boundary stated; twins identical. AC-2 greps pass.
**ACs Covered:** AC-2
**In scope:** `plugins/spec-flow/skills/spec/SKILL.md`, `plugins/spec-flow/agents/qa-spec.md`,
`plugins/spec-flow/agents/qa-spec.agent.md`
**NOT in scope:** `templates/spec.md` (Phase 2, done); plan authoring (Phase 4); qa-plan (Phase 4).
**Charter constraints honored in this phase:**
- Cross-cutting: CR-002 (preserve `skills/spec/SKILL.md` `name:`/`description:` frontmatter on edit);
  NN-P-003 (dog-food).

- [x] **[Implement]** Add an integration-surfacing step to the spec brainstorm and an allocation
  criterion to qa-spec (both twins).
  - Order: spec SKILL surfacing step → qa-spec criterion (`.md` then identical `.agent.md`).
  - Architecture constraints: reference the doctrine's definitions (ADR-3); preserve frontmatter (CR-002).

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/skills/spec/SKILL.md**
  - Anchor: brainstorm "Testing approach" bullet (line 121)
  - Current:
    ```
    121    - **Testing approach:** Propose the testing strategy from TDD doctrine and work type: default ~60% unit / ~30% integration / ~10% e2e, with rationale tied to the specific components. State what "done" coverage looks like for this piece. Ask only if the user has constraints that override the defaults (e.g., no integration test infrastructure, charter-required E2E coverage).
    ```
  - Target: Add a new sibling bullet (after line 121) — "**Integration surfacing:** Identify each
    cross-component integration in scope: name the boundary (which components are inside), the true
    externals that must be doubled (each needing a contract test), and the AC each integration is
    allocated to. Record them in the spec's Integration Coverage block (per `templates/spec.md`); if there
    is no cross-component wiring, write 'None in scope.' Reference `reference/spec-flow-doctrine.md` for
    the definitions — do not redefine them here."
  - Pattern (existing brainstorm bullet idiom, line 121 above): `- **Label:** prose.`
  - Done: a brainstorm bullet exists naming "Integration surfacing" (or "integration") + boundary +
    doubled externals + Integration Coverage block reference.
  - Verify: `grep -niE "integration surfacing|surface.*integration|boundary.*doubled external" plugins/spec-flow/skills/spec/SKILL.md`

  **T-2: MODIFY plugins/spec-flow/agents/qa-spec.md AND plugins/spec-flow/agents/qa-spec.agent.md (identical edit to both)**
  - Anchor: Review Criteria list end — append after criterion 12 (currently last; criteria L22–43)
  - Current:
    ```
    (criterion 12, the current last criterion in ## Review Criteria — weasel-word detection)
    ```
  - Target: Add **criterion 13** — "**Integration allocation:** If the spec declares any integration in
    its Integration Coverage block, each must (a) state its boundary (which components are inside), (b)
    name the true externals to be doubled (each requiring a contract test), and (c) be allocated to a
    specific AC. A declared integration missing any of (a)/(b)/(c), or any integration silently deferred,
    is must-fix. Absence of an Integration Coverage block when the piece has no cross-component wiring is
    NOT a finding (NFR-INT-02 — absence = 'no integrations declared')."
  - Pattern (existing qa-spec criterion idiom, file lines 22/29): `N. **Title:** rule.`
  - Done: criterion 13 present in BOTH `qa-spec.md` and `qa-spec.agent.md`, byte-identical.
  - Verify: `grep -n "Integration allocation" plugins/spec-flow/agents/qa-spec.md plugins/spec-flow/agents/qa-spec.agent.md` (2 matches) and `cmp plugins/spec-flow/agents/qa-spec.md plugins/spec-flow/agents/qa-spec.agent.md` (no output)

- [x] **[Verify]** Confirm spec-authoring edits (structural oracle for AC-2)
  **Per-change checks:**
  - T-1: `grep -niE "integration surfacing|boundary.*doubled" plugins/spec-flow/skills/spec/SKILL.md` — Expected: ≥ 1 match
  - T-2: `grep -c "Integration allocation" plugins/spec-flow/agents/qa-spec.md` — Expected: 1; same for `.agent.md` — Expected: 1
  **Phase-level check:**
  - Run: `cmp plugins/spec-flow/agents/qa-spec.md plugins/spec-flow/agents/qa-spec.agent.md && echo TWIN_OK`
  - Expected: `TWIN_OK` (twins byte-identical)
  - Failure: `cmp` prints a differing byte → twins drifted; re-sync

- [x] **[QA]** Phase review
  - Review against: AC-2
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 4: Plan authoring — phase ordering, track handling, Contracts distinction + qa-plan criteria (Area C)
**Exit Gate:** `skills/plan/SKILL.md` covers integration-driven phase ordering, `[Integration-Test]` block
on TDD or Implement track, non-TDD double-loop handling, and the Contracts-vs-integration-boundary
distinction; `qa-plan.md` (+twin) has integration-allocation criteria; twins identical. AC-3 greps pass.
**ACs Covered:** AC-3
**In scope:** `plugins/spec-flow/skills/plan/SKILL.md`, `plugins/spec-flow/agents/qa-plan.md`,
`plugins/spec-flow/agents/qa-plan.agent.md`
**NOT in scope:** `templates/plan.md` (Phase 2, done); execute machinery (Phases 5–6); spec authoring
(Phase 3).
**Charter constraints honored in this phase:**
- Cross-cutting: CR-002 (preserve `skills/plan/SKILL.md` frontmatter); NN-P-003 (dog-food).

- [x] **[Implement]** Add integration planning guidance to plan/SKILL.md and integration criteria to
  qa-plan (both twins).
  - Order: plan SKILL ordering + track + non-TDD + Contracts-distinction prose → qa-plan criteria
    (`.md` then identical `.agent.md`).
  - Architecture constraints: reference doctrine definitions (ADR-3); preserve frontmatter (CR-002); the
    `[Integration-Test]` block must be described as valid on BOTH TDD and Implement tracks.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/skills/plan/SKILL.md**
  - Anchor: Phase 2 step 1 "Define phases" (near line 115) + track-selection prose (lines 153–194) +
    non-TDD override (lines 196–201) + Contracts step 10 (lines 426–461)
  - Current (Implement-track intro, line 153):
    ```
    153    **Implement track** (for config, infra, scaffolding, glue/wiring, docs-as-code, fixtures, migrations — where unit-level TDD is ceremony without payoff):
    ```
  - Current (non-TDD override head, lines 196–197):
    ```
    196    **Non-TDD mode override.** If the plan front-matter declares `tdd: false`:
    197    - Generate ALL phases with non-TDD structure: `[Implement]` → `[Write-Tests]` → `[Verify]` → `[Refactor]` (optional) → `[QA]`.
    ```
  - Target: Add four pieces of guidance, each referencing the doctrine (ADR-3):
    1. **Integration-driven phase ordering** (near line 115): when the spec's Integration Coverage block
       declares integrations, order phases so each integration's outer `[integration]` test is declared up
       front and allocated to its **completing phase** (the phase introducing the last in-boundary
       component), with a `completes_in_phase` marker; allocate a contract test per doubled external.
    2. **Track handling** (after line 194): an `[Integration-Test]` block may live in a TDD-track OR an
       Implement-track completing phase — state where the outer test is authored in each.
    3. **Non-TDD double-loop** (after line 201): in `tdd: false` mode the outer `[integration]` test is
       authored and greened within its completing phase's `[Write-Tests]`/`[Integration-Test]` step (no
       cross-phase Red).
    4. **Contracts-vs-integration-boundary distinction** (in/after step 10, line 426+): the `## Contracts`
       section captures **boundary-crossing API interfaces** (exported signatures/schemas); an
       **integration boundary** is the real wired path an `[integration]` test crosses. A phase may have
       either, both, or neither — they are different concepts; do not conflate.
  - Pattern (existing SKILL numbered-guidance idiom, plan SKILL step 10 line 426): `N. **Title (FR-…).**
    <guidance>. Steps: 1. ... 2. ...`
  - Done: all four guidance blocks present; the `[Integration-Test]`-on-both-tracks sentence present; the
    Contracts-vs-boundary distinction present.
  - Verify: `grep -niE "completes_in_phase|integration-driven|Integration-Test.*track|integration boundary.*contract|contract.*integration boundary" plugins/spec-flow/skills/plan/SKILL.md`

  **T-2: MODIFY plugins/spec-flow/agents/qa-plan.md AND plugins/spec-flow/agents/qa-plan.agent.md (identical edit to both)**
  - Anchor: Review Criteria end — append after criterion 25 (currently last; criteria L19–145)
  - Current:
    ```
    143 25. **Per-change verification.** Phases with ≥2 file changes must include per-change verification checkpoints in their `[Verify]` block — not just a single phase-level command. ...
    ```
  - Target: Add **criterion 26** — "**Integration allocation (activate only when the spec declares an
    Integration Coverage block; skip if absent — not an error per NFR-INT-02):** For each declared
    integration: (a) exactly one phase contains an `[Integration-Test]` block with a concrete real-path
    `[Verify]` command and a `completes_in_phase` marker no earlier than the completing component's phase;
    (b) each doubled true external has a contract test named in that block; (c) the block states its
    boundary (nothing inside the boundary is doubled); (d) the `## Integration-Test Registry` table is
    well-formed (one row per `[integration]` test; required columns present). Any missing (a)/(b)/(c)/(d)
    → must-fix. Evidence: quote the integration and the phase block."
  - Pattern (existing qa-plan criterion idiom with activation guard, file lines 49/63): `N. **Title
    (activate only when …):** rule. ... Evidence: ... **Must-fix.**`
  - Done: criterion 26 present in BOTH files, byte-identical.
  - Verify: `grep -n "Integration allocation" plugins/spec-flow/agents/qa-plan.md plugins/spec-flow/agents/qa-plan.agent.md` (2 matches); `cmp` clean.

- [x] **[Verify]** Confirm plan-authoring edits (structural oracle for AC-3)
  **Per-change checks:**
  - T-1: `grep -ciE "completes_in_phase|integration-driven|integration boundary" plugins/spec-flow/skills/plan/SKILL.md` — Expected: ≥ 3
  - T-2: `grep -c "Integration allocation" plugins/spec-flow/agents/qa-plan.md` — Expected: 1; `.agent.md` — Expected: 1
  **Phase-level check:**
  - Run: `cmp plugins/spec-flow/agents/qa-plan.md plugins/spec-flow/agents/qa-plan.agent.md && echo TWIN_OK`
  - Expected: `TWIN_OK`
  - Failure: `cmp` reports a diff → twins drifted

- [x] **[QA]** Phase review
  - Review against: AC-3
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 5: Execute machinery — M1 registry + M2 tag-separation (Area F, part 1)
Why serial: Phases 5 and 6 BOTH edit `skills/execute/SKILL.md` (overlapping scope) — they cannot
parallelize; M3/M4 (Phase 6) build on the M1 registry + M2 suite split defined here.
**Exit Gate:** execute builds/maintains the integration-test registry from plan+Red (never Build) and
carries it across phases; the per-phase oracle and fast-mode direct run scope to the non-integration suite
via an explicit marker exclusion with a documented path-dir fallback. Greps for the registry-build prose
and the `not integration` exclusion succeed.
**ACs Covered:** AC-6 (M1 + M2 portion)
**In scope:** `plugins/spec-flow/skills/execute/SKILL.md` (Step 2 Red-manifest area ~L396; Step 3 oracle
~L484–491; Step 4 fast-mode run L548–555; Phase 1 Load Context for registry build)
**NOT in scope:** M3 edit window + M4 oracle split + sub-cycle + anti-cheat assertion (Phase 6); board
wiring (Phase 10); RBVR/QA agents (Phases 7–8).
**Charter constraints honored in this phase:**
- NN-C-005 (degrade silently when a capability is absent): the M2 tag-marker convention degrades to a
  **path-dir fallback** when the runner lacks markers; exclusions are always stated explicitly, never
  silent.
- Cross-cutting: CR-002 (preserve `execute/SKILL.md` frontmatter); NN-P-003 (dog-food).

- [x] **[Implement]** Add M1 registry build/carry + M2 tag-separated suite scoping to execute.
  - Order: M1 registry (Phase 1 Load Context build + carry) → M2 oracle exclusion (Step 3) → M2 fast-mode
    exclusion (Step 4 L548–555).
  - Architecture constraints: registry rows come from plan + Red, NEVER Build (M1 invariant, sets up
    Phase 6's anti-cheat assertion); reference the doctrine's M1/M2 definitions (ADR-3); exclusions
    explicit (NN-C-005).

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: Phase 1 Load Context (L130–200) — add registry build/carry step
  - Current (Step 2 manifest capture that the registry parallels, L396):
    ```
    396 6. **Capture the stage manifest.** Extract Red's `## Staged test manifest` section verbatim. Hold in orchestrator state as `phase_N_red_stage_manifest` — a dict of `path → sha256`. ...
    ```
  - Target: Add an **M1 registry** step in Phase 1 Load Context: read the `## Integration-Test Registry`
    table from `plan.md` (if present); hold it in orchestrator state as `integration_registry` (rows:
    path, boundary, doubled externals, AC, completes_in_phase, skeleton_sha256, completed_sha256); carry
    it across every phase; **rows are sourced from plan + Red only, never written from Build**. Absent
    table ⇒ `integration_registry = []` ⇒ no integration behavior (NFR-INT-02).
  - Pattern (existing orchestrator-state idiom, L396 above): "Hold in orchestrator state as `name` — …".
  - Done: a registry-load step exists naming `integration_registry`, "built from plan + Red", "carried
    across phases", and the absent-table degradation.
  - Verify: `grep -nE "integration_registry|Integration-Test Registry" plugins/spec-flow/skills/execute/SKILL.md`

  **T-2: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: Step 3 oracle invariants (L484–491)
  - Current:
    ```
    485    - Mode: TDD — three invariants, all required:
    486      - **(a) Full suite green** — `0 failed` across the whole test suite.
    487      - **(b) Every Red ID is in PASSED** — parse the current run's PASSED set and diff against the FAILED IDs captured in `phase_N_oracle_block` from Step 2.5. ...
    ```
  - Target: Scope invariant (a) to the **non-integration suite**: the per-phase oracle runs the suite with
    an explicit `[integration]` exclusion — `-m 'not integration'` (pytest) or the project's marker
    convention, with a **path-dir fallback** (exclude the integration test directory) for runners lacking
    markers; the exclusion is always logged explicitly. State that an up-front `[integration]` test
    registered for a later `completes_in_phase` is NOT part of the per-phase non-integration oracle until
    its completing phase. (The due-integration invariant itself is added in Phase 6's M4 split.)
  - Pattern (existing invariant idiom, L486 above): "**(letter) Name** — rule."
  - Done: invariant (a) references the non-integration suite + the explicit `not integration` exclusion +
    the path-dir fallback.
  - Verify: `grep -nE "not integration|non-integration suite|path-dir fallback" plugins/spec-flow/skills/execute/SKILL.md`

  **T-3: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: Step 4 fast-mode direct test run (L548–555)
  - Current:
    ```
    548 **Fast mode — direct test execution (no agent dispatch):** if `orchestrator_fast_mode: true`, skip the verify agent dispatch entirely. Instead, run the project test command directly:
    549
    550 ```bash
    551 # Use the [Verify] command from the plan's current phase block, or fall back to CLAUDE.md test command
    552 <test command>
    553 ```
    ```
  - Target: The fast-mode direct run also scopes to the **non-integration suite** via the same explicit
    `[integration]` marker exclusion (path-dir fallback when unavailable); log the exclusion. Note that
    due `[integration]` tests are gated by the M4 sub-cycle (Phase 6), not by this raw exit-code run.
  - Pattern (existing fenced-command idiom, L550–553 above).
  - Done: the fast-mode block states it excludes `[integration]` tests (same marker + fallback) and logs
    the exclusion.
  - Verify: `grep -n "not integration" plugins/spec-flow/skills/execute/SKILL.md` returns a hit inside the
    fast-mode block (L548–560 region).

- [x] **[Verify]** Confirm M1+M2 machinery (structural oracle for AC-6 part 1)
  **Per-change checks:**
  - T-1: `grep -c "integration_registry" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 2 (build + carry)
  - T-2: `grep -nE "non-integration suite|not integration|path-dir fallback" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 3 matches
  - T-3: `grep -n "not integration" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 2 occurrences (oracle + fast-mode)
  **Phase-level check:**
  - Run: `grep -nE "integration_registry.*plan \+ Red|built from plan \+ Red|from plan \+ Red, never" plugins/spec-flow/skills/execute/SKILL.md`
  - Expected: ≥ 1 match (the M1 "plan+Red, never Build" invariant is present)
  - Failure: 0 matches → the M1 sourcing invariant is missing (Phase 6's anti-cheat assertion depends on it)

- [x] **[QA]** Phase review
  - Review against: AC-6
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 6: Execute machinery — M3 edit window + M4 oracle split + sub-cycle + anti-cheat assertion (Area F, part 2)
Why serial: edits the same `skills/execute/SKILL.md` as Phase 5 and depends on the M1 registry + M2 split
landed there.
**Exit Gate:** the content-hash gate keeps registered `[integration]` paths immutable at `skeleton_sha256`
until `completes_in_phase`, then permits exactly one plan-authorized/path-confined (incl. fixture-helper
closure)/phase-gated skeleton→completed edit, records `completed_sha256`, immutable thereafter; the M4
oracle split requires every due `[integration]` test green; the completing-phase `[Integration-Test]`
sub-cycle runs between `[Verify]` and `[Refactor]`; an explicit anti-cheat assertion states Build cannot
create a registry row, move a `completes_in_phase`, or edit a registered test outside the window. AC-6 +
AC-7 greps pass.
**ACs Covered:** AC-6 (M3 + M4 portion), AC-7
**In scope:** `plugins/spec-flow/skills/execute/SKILL.md` (Step 3 item 7a content-hash gate L492–502;
Step 4 post-Refactor re-hash L580; Step 5/6 region for the sub-cycle; oracle invariants L484–491)
**NOT in scope:** registry build + M2 suite split (Phase 5, done); RBVR agent behavior (Phase 7); board
wiring (Phase 10).
**Charter constraints honored in this phase:**
- NN-P-002 (two human sign-off gates, no auto-merge): M3/M4 do NOT bypass per-phase QA or end-of-piece
  review-board sign-off; the M3 edit window is a gate **tightening** mechanism (it permits exactly one
  audited edit and re-locks), **never a merge path**.
- Cross-cutting: CR-002 (preserve `execute/SKILL.md` frontmatter); NN-P-003 (dog-food).

- [x] **[Implement]** Add the M3 edit window, M4 oracle split + sub-cycle, and the anti-cheat assertion to
  execute.
  - Order: M3 content-hash edit window (Step 3.7a) → fixture/helper closure hashing → post-Refactor
    re-hash update (L580) → M4 due-integration oracle invariant (L484–491) → M4 completing-phase
    `[Integration-Test]` sub-cycle (between Step 4 Verify and Step 5 Refactor) → anti-cheat assertion.
  - Architecture constraints: the M3 window is single-shot, plan-authorized (from the registry's
    skeleton/completed hashes), path-confined incl. declared dependency-closure, phase-gated to
    `completes_in_phase` (NFR-INT-01); reference doctrine M3/M4 (ADR-3); NN-P-002 (never a merge path).

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: Step 3 item 7(a) content-hash integrity gate (L492–502)
  - Current:
    ```
    494    - **(a) Content-hash integrity (Mode: TDD only).** For every path in `phase_N_red_stage_manifest`, re-hash the file AS COMMITTED in HEAD and compare against the manifest:
    495      ```bash
    496      for path in <manifest paths>; do
    497        commit_hash=$(git show HEAD:"$path" | sha256sum | cut -d' ' -f1)
    498        manifest_hash=<manifest hash for path>
    499        [ "$commit_hash" = "$manifest_hash" ] || echo "integrity fail: $path"
    500      done
    501      ```
    502      Any mismatch means the implementer modified one of Red's tests ...
    ```
  - Target: Extend gate (a) for registered `[integration]` paths: a path in `integration_registry` is
    immutable at its `skeleton_sha256` for every phase where `current_phase < completes_in_phase`; **at**
    `completes_in_phase` exactly one plan-authorized edit is permitted — the file (and its declared
    fixture/helper dependency-closure) may change from `skeleton_sha256` to `completed_sha256`, which the
    orchestrator records; for every phase after, the path is immutable at `completed_sha256`. Hash the
    declared fixture/helper closure too (closes the refactor real→double blind spot). Any out-of-window
    edit, or an edit not matching the recorded completed hash, is rejected.
  - Pattern (existing gate idiom, L494–500 above): bash re-hash loop + "Any mismatch means …" rejection
    prose.
  - Done: gate (a) describes the skeleton→completed single-edit window keyed on
    `completes_in_phase`, records `completed_sha256`, and hashes the fixture/helper closure.
  - Verify: `grep -nE "skeleton_sha256|completed_sha256|completes_in_phase|fixture/helper closure|dependency.closure" plugins/spec-flow/skills/execute/SKILL.md`

  **T-2: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: Step 4 item 5 post-Refactor re-hash (L580)
  - Current:
    ```
    580 5. **Test integrity (Mode: TDD only; non-TDD mode: no-op).** As of v2.7.0, the primary anti-tampering safeguard runs at Step 3.7a ... If the phase produces a Refactor commit in Step 5, re-run the content-hash check against HEAD after Refactor lands ...
    ```
  - Target: Update the post-Refactor re-hash to honor the M3 window: registered `[integration]` paths are
    re-hashed against `skeleton_sha256` (pre-completing) or `completed_sha256` (at/after completing),
    AND their fixture/helper closure is re-hashed — so Refactor cannot swap a real in-boundary dependency
    for a fake in a helper file (the integration-preservation backstop for Phase 7's refactor.md rule).
  - Pattern: existing prose idiom of L580.
  - Done: the post-Refactor re-hash references the registry hashes (skeleton/completed) and the
    fixture/helper closure.
  - Verify: `grep -nE "after Refactor|completed_sha256|fixture/helper" plugins/spec-flow/skills/execute/SKILL.md`

  **T-3: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: Step 3 oracle invariants (L484–491) — add the M4 due-integration invariant
  - Current:
    ```
    486      - **(a) Full suite green** — `0 failed` across the whole test suite.
    487      - **(b) Every Red ID is in PASSED** — ...
    488      - **(c) Zero Red IDs in SKIPPED** — ...
    ```
  - Target: Add a parallel invariant: "**(d) Every due `[integration]` test green** — for every registry
    row with `completes_in_phase ≤ current_phase`, that `[integration]` test (and its contract tests)
    must be in PASSED. Rows with `completes_in_phase > current_phase` are expected absent/red and are NOT
    a violation." (Per-phase invariants (a)–(c) apply to the non-integration suite per Phase 5's M2 split;
    this (d) is the integration half of the M4 oracle split.)
  - Pattern (existing invariant idiom, L486–488 above): "**(letter) Name** — rule."
  - Done: invariant (d) exists, keyed on `completes_in_phase ≤ current`.
  - Verify: `grep -nE "due .integration. test|completes_in_phase . current|completes_in_phase <= current" plugins/spec-flow/skills/execute/SKILL.md`

  **T-4: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: between Step 4 (Verify, ends ~L585) and Step 5 (Refactor, L587) — insert the
    completing-phase sub-cycle
  - Current:
    ```
    585 (end of Step 4: Verify)
    586
    587 ### Step 5: Refactor — Clean Up
    ```
  - Target: Add a **completing-phase `[Integration-Test]` sub-cycle** that runs only when the current
    phase is a `completes_in_phase` for some registry row, **between `[Verify]` and `[Refactor]`**:
    complete + green the outer `[integration]` test (the single M3 edit window), run its contract tests,
    and gate on invariant (d). Note the non-TDD-mode dispatch path handles the same (author + green in the
    completing phase's `[Write-Tests]`/`[Integration-Test]` step). This is additive — non-completing
    phases skip it.
  - Pattern (existing step-heading idiom, L587): `### Step N: Name — Summary` + numbered items.
  - Done: a sub-cycle exists, dispatched at `completes_in_phase`, positioned between Verify and Refactor,
    gating on the due `[integration]` test + contract tests; non-TDD path noted.
  - Verify: `grep -nE "\[Integration-Test\] sub-cycle|completing-phase.*sub-cycle|between .Verify. and .Refactor." plugins/spec-flow/skills/execute/SKILL.md`

  **T-5: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: M3 gate region (near T-1, Step 3 item 7a) — add the explicit anti-cheat assertion
  - Current: (the content-hash gate prose from T-1, L494–502)
  - Target: Add an explicit **anti-cheat assertion**: "Build cannot self-authorize an integration edit.
    The implementer may NOT create a registry row, move a `completes_in_phase` marker, or edit a
    registered `[integration]` test outside its single plan-authorized window — registry rows come only
    from plan + Red (M1), and the edit window is plan-derived, qa-plan-reviewed, single-shot,
    path-confined, and phase-gated (NFR-INT-01). Any such attempt is rejected. The M3 window is a gate
    *tightening* mechanism, never a merge path (NN-P-002)."
  - Pattern: existing anti-cheat prose idiom (L502 "Any mismatch means the implementer modified … the
    anti-cheat safeguard …").
  - Done: an assertion states Build cannot (create a row | move a marker | edit outside the window), with
    the single-shot/plan-derived/path-confined/phase-gated qualifiers.
  - Verify: `grep -nE "cannot self-authorize|cannot create a registry row|outside its single plan-authorized window|single-shot, path-confined" plugins/spec-flow/skills/execute/SKILL.md`

- [x] **[Verify]** Confirm M3+M4 machinery + anti-cheat assertion (structural oracle for AC-6 part 2, AC-7)
  **Per-change checks:**
  - T-1: `grep -nE "skeleton_sha256|completed_sha256|fixture/helper closure" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 3 matches
  - T-2: `grep -n "after Refactor" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 1, now referencing registry hashes
  - T-3: `grep -nE "completes_in_phase . current|due .integration." plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 1
  - T-4: `grep -nE "Integration-Test. sub-cycle|between .Verify. and .Refactor." plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 1
  - T-5: `grep -nE "cannot create a registry row|cannot self-authorize" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 1
  **Phase-level check (AC-7 independent test):**
  - Run: `grep -nE "single-shot.*path-confined.*phase-gated|plan-authorized.*path-confined.*phase-gated" plugins/spec-flow/skills/execute/SKILL.md`
  - Expected: ≥ 1 match (the edit window is described as single-shot/plan-derived/path-confined/phase-gated)
  - Failure: 0 matches → the anti-cheat qualifiers are missing

- [x] **[QA]** Phase review
  - Review against: AC-6, AC-7
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 7: RBVR agents — tdd-red, implementer, verify, refactor (Area D)
Why serial: kept serial from Phase 8 (QA gates) despite disjoint agent-file scopes — both depend on the
execute machinery (Phases 5–6) and must reference the same M2/M3/M4 semantics consistently; per-phase
Opus QA is the consistency check.
**Exit Gate:** tdd-red authors a one-wired-path `[integration]` test (nothing in-boundary doubled) with
its `completes_in_phase` and the expected-red carve-out; implementer treats integration Build as wiring
glue (no spurious BLOCK), writes contract tests, respects the M3 window; verify has boundary-authenticity
/ path-coverage / contract checks and the redefined "tests pass"; refactor has the integration-
preservation rule. All four `.md`/`.agent.md` twin pairs identical. AC-4 greps pass.
**ACs Covered:** AC-4
**In scope:** `plugins/spec-flow/agents/tdd-red.md` (+`.agent.md`), `agents/implementer.md`
(+`.agent.md`), `agents/verify.md` (+`.agent.md`), `agents/refactor.md` (+`.agent.md`)
**NOT in scope:** qa-tdd-red/qa-phase/qa-phase-lite (Phase 8); execute machinery (Phases 5–6, done);
board wiring (Phase 10). Note: verify's board-member **count** renumber to "9th" happens here as part of
AC-4's verify edits AND is re-asserted in the Phase 11 sweep (AC-10).
**Charter constraints honored in this phase:**
- Cross-cutting: NN-P-003 (dog-food). (Agent frontmatter is `name:`/`description:` — CR-001 governs the
  *new* agent in Phase 9; existing agents' frontmatter is merely preserved here.)

- [x] **[Implement]** Add integration semantics to the four RBVR agents (each `.md` + identical
  `.agent.md`).
  - Order: tdd-red → implementer → verify → refactor (each twin pair edited identically).
  - Architecture constraints: reference doctrine definitions (ADR-3); keep twins byte-identical; the
    tdd-red carve-out must not weaken the fail-now contract for ordinary unit tests.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/agents/tdd-red.md AND tdd-red.agent.md (identical)**
  - Anchor: Rule 8 fail-now contract (L42–44)
  - Current:
    ```
    42 8. **Zero passing tests among the ones you authored.** Every test ID listed in `## Tests Written` MUST appear in the `FAILED` (or `SKIPPED` with an explicit reason) list of your `## Oracle block`. The runner summary for the paths you created or modified must report `0 passed`. If any of your new tests passes on first run, STOP and report ...
    ```
  - Target: Add an `[integration]` carve-out to Rule 8: an outer `[integration]` test authored up front
    for a later `completes_in_phase` is **expected-red until its completing phase** — it is listed with
    its `completes_in_phase` and is exempt from the "0 passed / fail-now" rule for the current phase
    (the orchestrator's M4 invariant (d) tracks it). Ordinary unit tests keep the strict fail-now rule.
    Also: an authored `[integration]` test must exercise **one wired path** with **nothing in-boundary
    doubled** (only true externals stubbed/faked).
  - Pattern (existing rule idiom, L42 above): "**N. Bold title.** rule. — with exception bullets."
  - Done: Rule 8 carves out `[integration]` tests with `completes_in_phase`; the one-wired-path /
    nothing-in-boundary-doubled clause present.
  - Verify: `grep -nE "\[integration\]|completes_in_phase|one wired path|nothing in-boundary doubled|expected-red" plugins/spec-flow/agents/tdd-red.md`

  **T-2: MODIFY plugins/spec-flow/agents/implementer.md AND implementer.agent.md (identical)**
  - Anchor: must-pass-every-Red oracle (L86)
  - Current:
    ```
    86 - **Every Red test must pass — zero skipped, zero missing.** The `## Oracle` block you received lists the test IDs the Red agent authored (the `FAILED` lines). Every one of those IDs must appear in the PASSED set of your final oracle run. ... report BLOCKED — do not land a "green suite" that silently drops Red tests.
    ```
  - Target: Add a carve-out: a registered `[integration]` test whose `completes_in_phase` is **after** the
    current phase is expected red and must NOT be greened or BLOCKED on now — do not treat it as a missing
    Red test. At its completing phase, greening the `[Integration-Test]` block is **wiring glue** (the
    in-boundary components already exist), so the minimal-code law applies to the wiring; do NOT raise a
    spurious BLOCK. Also write the **contract tests** for each doubled true external, and respect the M3
    window (only edit the registered test in its completing phase).
  - Pattern (existing mode-rule idiom, L86 above): "**Bold constraint.** prose."
  - Done: implementer text exempts not-yet-due `[integration]` tests, frames completing-phase greening as
    wiring glue with no spurious BLOCK, mandates contract tests, and cites the M3 window.
  - Verify: `grep -nE "wiring glue|\[integration\]|contract test|completes_in_phase|M3" plugins/spec-flow/agents/implementer.md`

  **T-3: MODIFY plugins/spec-flow/agents/verify.md AND verify.agent.md (identical)**
  - Anchor: "Tests pass" task (L49) + mode/board-member references (L3 frontmatter, L36 body)
  - Current:
    ```
    3  description: Internal agent — dispatched by spec-flow:execute. ... In fast mode, dispatched as a 7th Final Review board member in Piece Full mode ...
    ...
    36 Used in fast mode (`fast: true`) as a 7th parallel member of the end-of-piece Final Review board. ...
    ...
    49 1. **Tests pass:** Confirm all tests pass with clean output (no warnings, no errors).
    ```
  - Target: (i) Add boundary-authenticity / path-coverage / contract-faithfulness checks to Full and
    Piece Full modes: confirm each `[integration]` test exercises the real wired path (nothing in-boundary
    doubled), that integration-bearing ACs have path coverage (not unit-only), and that each doubled
    external has a faithful contract test. (ii) Redefine task 1 "Tests pass" per the M2 split: "all
    **non-integration** tests pass AND every due `[integration]` test (`completes_in_phase ≤ current`) is
    green." (iii) Renumber the board-member references from **"7th" → "9th"** at L3 and L36 (post-change
    fast-mode board = 9; verify-piece-full is the 9th — fixes the current stale "7th"; AC-10).
  - Pattern (existing task idiom, L49 above): "N. **Title:** instruction."
  - Done: boundary/path-coverage/contract checks present in Full + Piece Full; "non-integration" clause in
    the tests-pass task; no "7th" remains (both occurrences now "9th").
  - Verify: `grep -nE "boundary authenticity|path coverage|contract faithfulness|non-integration" plugins/spec-flow/agents/verify.md` and `grep -c "7th" plugins/spec-flow/agents/verify.md` — Expected: 0; `grep -c "9th" plugins/spec-flow/agents/verify.md` — Expected: ≥ 2

  **T-4: MODIFY plugins/spec-flow/agents/refactor.md AND refactor.agent.md (identical)**
  - Anchor: Rules block (L29–33) — add a new Rule 5
  - Current:
    ```
    32 3. No new behavior. No changing what code does — only how it's organized.
    33 4. **ONE commit at the end of your Refactor step, when all cleanups are done and tests are green.** ...
    ```
  - Target: Add **Rule 5 — integration-preservation:** "Never replace a real in-boundary dependency with a
    fake/stub/mock in an `[integration]` test or its fixtures/helpers; never reorder the wired-path calls.
    If a cleanup would weaken an `[integration]` test (real→double, or path reordering), report BLOCKED.
    (The M3 fixture/helper closure hashing backs this — a weakening edit also fails the integrity gate.)"
  - Pattern (existing rule idiom, L32–33 above): "N. <rule>." / "N. **Bold.** rule."
  - Done: Rule 5 (integration-preservation) present, with the real→double prohibition + BLOCKED outcome.
  - Verify: `grep -nE "integration-preservation|real in-boundary dependency|never reorder the wired" plugins/spec-flow/agents/refactor.md`

- [x] **[Verify]** Confirm RBVR agent edits + twin integrity (structural oracle for AC-4)
  **Per-change checks:**
  - T-1: `grep -cE "\[integration\]|completes_in_phase" plugins/spec-flow/agents/tdd-red.md` — Expected: ≥ 2
  - T-2: `grep -c "wiring glue" plugins/spec-flow/agents/implementer.md` — Expected: ≥ 1
  - T-3: `grep -c "7th" plugins/spec-flow/agents/verify.md` — Expected: 0; `grep -cE "boundary authenticity|path coverage" plugins/spec-flow/agents/verify.md` — Expected: ≥ 1
  - T-4: `grep -c "integration-preservation" plugins/spec-flow/agents/refactor.md` — Expected: ≥ 1
  **Phase-level check (twin integrity for all four pairs):**
  - Run: `for a in tdd-red implementer verify refactor; do cmp plugins/spec-flow/agents/$a.md plugins/spec-flow/agents/$a.agent.md && echo "$a TWIN_OK" || echo "$a DRIFT"; done`
  - Expected: four `… TWIN_OK` lines, zero `DRIFT`
  - Failure: any `DRIFT` → that twin pair diverged; re-sync

- [x] **[QA]** Phase review
  - Review against: AC-4
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 8: QA gate agents — qa-tdd-red, qa-phase, qa-phase-lite (Area E)
**Exit Gate:** qa-tdd-red checks boundary authenticity (nothing inside doubled) + contract faithfulness +
valid `completes_in_phase`; qa-phase criterion 7 is extended from contract-break to boundary/seam
authenticity; qa-phase-lite has a lightweight boundary-authenticity spot-check. All three twin pairs
identical. AC-5 greps pass.
**ACs Covered:** AC-5
**In scope:** `plugins/spec-flow/agents/qa-tdd-red.md` (+`.agent.md`), `agents/qa-phase.md`
(+`.agent.md`), `agents/qa-phase-lite.md` (+`.agent.md`)
**NOT in scope:** RBVR agents (Phase 7, done); the new reviewer (Phase 9); board wiring (Phase 10).
**Charter constraints honored in this phase:**
- Cross-cutting: NN-P-003 (dog-food).

- [x] **[Implement]** Add boundary-authenticity / contract / `completes_in_phase` checks to the three QA
  gate agents (each `.md` + identical `.agent.md`).
  - Order: qa-tdd-red → qa-phase → qa-phase-lite (each twin pair identical).
  - Architecture constraints: reference doctrine definitions (ADR-3); keep twins identical; qa-phase-lite
    stays scoped to a single sub-phase (do NOT make it cross-phase).

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/agents/qa-tdd-red.md AND qa-tdd-red.agent.md (identical)**
  - Anchor: Theater Pattern Catalog + AC-binding check (L57–61), Rules block (L26–41)
  - Current:
    ```
    59 **AC-binding check (separate from the 11 above):** for each test, answer in one sentence: "If I implemented [the AC this test is supposed to cover] incorrectly ...
    ```
  - Target: Add a **boundary-authenticity + contract check** (alongside the AC-binding check): for an
    `[integration]` test, flag if anything **inside the boundary** is doubled (mock/stub/fake of an
    in-boundary real component); confirm each doubled **true external** has a contract test; confirm the
    test carries a valid `completes_in_phase`. Reference the doctrine for the boundary definition.
  - Pattern (existing named-check idiom, L59 above): "**<Check name> (separate from …):** rule + flag
    examples."
  - Done: a boundary-authenticity/contract/`completes_in_phase` check present.
  - Verify: `grep -nE "boundary authenticity|nothing inside.*doubled|contract test|completes_in_phase" plugins/spec-flow/agents/qa-tdd-red.md`

  **T-2: MODIFY plugins/spec-flow/agents/qa-phase.md AND qa-phase.agent.md (identical)**
  - Anchor: criterion 7 "Integration surface" (L34)
  - Current:
    ```
    34 7. **Integration surface:** Spot-check the listed integration callers — does the change break any caller's contract? `Read` a caller only if the diff's public symbols suggest a breaking change.
    ```
  - Target: Extend criterion 7 from contract-break-only to **boundary/seam authenticity**: in addition to
    the existing caller-contract spot-check, a phase that **first wires a real dependency across a
    boundary** must have an **authentic (un-mocked) `[integration]` test** for that path, or a justified
    rationale; a phase that mocks an in-boundary real dependency without rationale is a finding. (Keep the
    existing caller-contract sentence.)
  - Pattern (existing criterion idiom, L33 above): "N. **Title:** rule."
  - Done: criterion 7 now covers boundary/seam authenticity (un-mocked test or rationale) in addition to
    the caller-contract check; criterion count still ends at 8.
  - Verify: `grep -nE "boundary.*authenticity|un-mocked|authentic.*integration test" plugins/spec-flow/agents/qa-phase.md`

  **T-3: MODIFY plugins/spec-flow/agents/qa-phase-lite.md AND qa-phase-lite.agent.md (identical)**
  - Anchor: "Review focus (ordered)" checks 1–4 (L39–44)
  - Current:
    ```
    44 4. **Scope discipline.** Did the sub-phase touch only the files declared in its scope block? Flag any out-of-scope file edits as must-fix.
    ```
  - Target: Add **check 5 — boundary-authenticity spot-check (sub-phase scope only):** if this sub-phase
    wires a real dependency, spot-check that its `[integration]` test does not double anything inside the
    boundary; stay within the sub-phase (do NOT review cross-phase integrations or mock-avalanche — those
    are the piece-scoped board's job, per the existing "What NOT to do" scoping).
  - Pattern (existing check idiom, L44 above): "N. **Title.** instruction."
  - Done: check 5 present, scoped to the sub-phase, deferring cross-phase to the board.
  - Verify: `grep -nE "boundary-authenticity spot-check|5\. \*\*Boundary" plugins/spec-flow/agents/qa-phase-lite.md`

- [x] **[Verify]** Confirm QA gate edits + twin integrity (structural oracle for AC-5)
  **Per-change checks:**
  - T-1: `grep -cE "boundary authenticity|completes_in_phase" plugins/spec-flow/agents/qa-tdd-red.md` — Expected: ≥ 1
  - T-2: `grep -cE "un-mocked|boundary.*authenticity" plugins/spec-flow/agents/qa-phase.md` — Expected: ≥ 1
  - T-3: `grep -cE "boundary-authenticity spot-check" plugins/spec-flow/agents/qa-phase-lite.md` — Expected: ≥ 1
  **Phase-level check (twin integrity):**
  - Run: `for a in qa-tdd-red qa-phase qa-phase-lite; do cmp plugins/spec-flow/agents/$a.md plugins/spec-flow/agents/$a.agent.md && echo "$a TWIN_OK" || echo "$a DRIFT"; done`
  - Expected: three `… TWIN_OK`, zero `DRIFT`
  - Failure: any `DRIFT` → re-sync

- [x] **[QA]** Phase review
  - Review against: AC-5
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 9: New reviewer agent — review-board-integration (Area G.1, CREATE twins)
**Exit Gate:** `agents/review-board-integration.md` + `.agent.md` exist, are byte-identical, have a bare
`name:`, `model: opus`, are read-only, lead with path enumeration, carry 7 boundary probes + the coverage
probe (mock-avalanche + un-contract-tested external double), the two-axis verdict (boundary correctness
SOUND/DIVERGES/UNTRACED; path coverage COVERED/UNIT-ONLY/UNCOVERED), Full + Focused re-review modes, and
explicit de-confliction vs ground-truth/edge-case/architecture. AC-8 checks pass.
**ACs Covered:** AC-8
**In scope:** `plugins/spec-flow/agents/review-board-integration.md` (CREATE),
`plugins/spec-flow/agents/review-board-integration.agent.md` (CREATE)
**NOT in scope:** wiring the agent into execute/review-board (Phase 10); docs (Phase 11); version
(Phase 12). The agent file exists here; its dispatch is added in Phase 10.
**Charter constraints honored in this phase:**
- NN-C-004 (bare agent names): the new agent's `name:` is `review-board-integration` — bare, no plugin
  prefix.
- CR-001 (agent frontmatter schema): the agent carries `name:` + `description:` + `model: opus` per the
  existing review-board agent pattern.
- Cross-cutting: NN-P-003 (dog-food).

- [x] **[Implement]** Create the review-board-integration agent as byte-identical twins, modeled on
  review-board-ground-truth.md.
  - Order: author `review-board-integration.md` in full → copy verbatim to `.agent.md`.
  - Architecture constraints: model structure on `agents/review-board-ground-truth.md` (114 lines);
    read-only (Read/Grep/Glob); reference doctrine definitions (ADR-3); bare name (NN-C-004); frontmatter
    schema (CR-001).

  **Change Specifications:**

  **T-1: CREATE plugins/spec-flow/agents/review-board-integration.md**
  - Complete structure outline (mirror ground-truth's section order):
    - Frontmatter: `name: review-board-integration` (bare), `description:` (one line: "Internal agent —
      dispatched by spec-flow:execute at end-of-piece Final Review. Do NOT call directly. Integration /
      path-coverage reviewer — audits each wired path across an integration boundary on two axes: boundary
      correctness and path coverage … Read-only — never modifies code."), `model: opus`.
    - `# Integration / Path-Coverage Reviewer`
    - `## Why this role exists` — the prop_firm calibration-2 failure mode (integration-boundary defects
      survive a green unit suite because each component is unit-tested with its collaborator mocked).
    - `## Context Provided` — diff + **codebase access (read beyond the diff)**; read-only.
    - `## Scope` — every wired path across an integration boundary in the piece (piece-scoped).
    - `## What You Check` — **Step 1: enumerate every integration path first** (before reading), then per
      path: **7 boundary probes** (axis 1: boundary correctness) + **1 coverage probe** (axis 2),
      including the **piece-only mock-avalanche** (every phase mocks the same external → real path never
      exercised piece-wide) and the **un-contract-tested external double** cases.
    - `## Method` — isolate path, trace real wiring, confront, verdict.
    - `## Output Format` — **two-axis verdict per path**: boundary correctness =
      `SOUND | DIVERGES | UNTRACED`; path coverage = `COVERED | UNIT-ONLY | UNCOVERED`; plus a per-finding
      block (Location / Probe / Expected / Actual / Severity / Suggested correction) mirroring
      ground-truth.
    - `## Input Modes` — **Full** (iter 1: all paths) + **Focused re-review** (iter 2+: delta + prior
      must-fix).
    - `## De-confliction` — explicit carve vs **ground-truth** (computed-component correctness; skips
      plumbing), **edge-case** (in-diff branch/boundary walking), **architecture** (layering); this
      reviewer owns boundary correctness + path coverage.
    - `## Rules` — read-only; never run the app; judge path coverage by reading tests, never by executing.
  - Pattern (verbatim from `agents/review-board-ground-truth.md` two-axis verdict, L82–85):
    ```
    **Per-component solidity verdict** (one per in-scope component):
    - **Component:** name / file:symbol
    - **Claim:** what it is supposed to compute
    - **Oracle used:** the independent derivation ... (or `NONE AVAILABLE` — itself a finding)
    - **Verdict:** `SOLID` ... | `UNVERIFIED` ... | `DIVERGES` ...
    ```
    (Adapt to per-path two-axis: Path / Boundary / Boundary-correctness verdict / Path-coverage verdict.)
    And frontmatter pattern (verbatim from ground-truth L1–4):
    ```
    ---
    name: review-board-ground-truth
    description: "Internal agent — dispatched by spec-flow:execute at end-of-piece Final Review. ... Read-only — never modifies code."
    ---
    ```
  - Done: file exists with bare `name: review-board-integration`, `model: opus`, read-only rules, Step-1
    path enumeration, 7 boundary probes + coverage probe (mock-avalanche + un-contract-tested external),
    two-axis verdict, Full + Focused modes, de-confliction section.
  - Verify: `grep -nE "^name: review-board-integration$|^model: opus$|SOUND|DIVERGES|UNTRACED|COVERED|UNIT-ONLY|UNCOVERED|mock-avalanche|de-confliction|Focused re-review" plugins/spec-flow/agents/review-board-integration.md`

  **T-2: CREATE plugins/spec-flow/agents/review-board-integration.agent.md**
  - Complete structure outline: **byte-identical copy** of `review-board-integration.md` (twin
    convention).
  - Pattern: identical content to T-1.
  - Done: `.agent.md` exists and is byte-identical to `.md`.
  - Verify: `cmp plugins/spec-flow/agents/review-board-integration.md plugins/spec-flow/agents/review-board-integration.agent.md` (no output)

- [x] **[Verify]** Confirm the new reviewer agent (structural oracle for AC-8)
  **Per-change checks:**
  - T-1: `grep -cE "^name: review-board-integration$" plugins/spec-flow/agents/review-board-integration.md` — Expected: 1; `grep -cE "^model: opus$" …` — Expected: 1; `grep -cE "SOUND|DIVERGES|UNTRACED" …` — Expected: ≥ 1; `grep -cE "COVERED|UNIT-ONLY|UNCOVERED" …` — Expected: ≥ 1; `grep -ci "mock-avalanche" …` — Expected: ≥ 1; `grep -ci "de-confliction" …` — Expected: ≥ 1
  - T-2: twin identity (phase-level check)
  **Phase-level check (AC-8 independent test):**
  - Run: `cmp plugins/spec-flow/agents/review-board-integration.md plugins/spec-flow/agents/review-board-integration.agent.md && echo TWIN_OK; head -3 plugins/spec-flow/agents/review-board-integration.md | grep -E "name: review-board-integration"`
  - Expected: `TWIN_OK` printed AND the bare `name:` line matched
  - Failure: `cmp` reports a diff, or `name:` carries a `spec-flow-` prefix

- [x] **[QA]** Phase review
  - Review against: AC-8
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 10: Board wiring — execute Final Review + review-board skill (Areas G.2 + G.3)
**Exit Gate:** `review-board-integration` runs by default in the piece-track Final Review (standard 7→8,
fast 8→9 with verify-piece-full the 9th) and the change-track board (6→7); every count / member list /
fix-loop re-dispatch / amendment re-entry / Step 8 source-agent enumeration in `execute/SKILL.md` is
updated consistently; `review-board/SKILL.md` includes `integration` in frontmatter, default lens set, and
Step 3 dispatch. AC-9 dispatch-parity greps pass.
**ACs Covered:** AC-9 (execute + review-board wiring), AC-10 (execute/review-board portion)
**In scope:** `plugins/spec-flow/skills/execute/SKILL.md` (Final Review section + every board-count site
per the introspection census), `plugins/spec-flow/skills/review-board/SKILL.md`
**NOT in scope:** docs board counts (Phase 11); version (Phase 12); the agent file itself (Phase 9, done).
**Charter constraints honored in this phase:**
- Cross-cutting: CR-002 (preserve both SKILLs' frontmatter); NN-P-003 (dog-food).

- [x] **[Implement]** Wire review-board-integration into execute's Final Review and the review-board
  skill; update every board-count/member reference consistently.
  - Order: add the integration dispatch line → update piece-track count (7→8) → update change-track set
    (6→7, add integration) → update fast-mode references (8→9, verify-piece-full = 9th) → update fix-loop
    + amend re-entry + Step 8 enumerations → review-board skill (frontmatter, lens set, Step 3).
  - Architecture constraints: integration is **default everywhere** (piece + change tracks); the
    verify-piece-full fast member becomes the **9th**; do NOT drop prd-alignment's change-track exclusion.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/skills/execute/SKILL.md — add the integration dispatch line**
  - Anchor: Final Review Step 1 dispatch block (L1217–1226, "dispatch ALL SEVEN")
  - Current:
    ```
    1217 Read each template from `${CLAUDE_PLUGIN_ROOT}/agents/review-board-<role>.md` and dispatch ALL SEVEN concurrently with `Input Mode: Full`:
    ...
    1226     Agent({ description: "Ground-truth review (iter 1, full)", prompt: <review-board-ground-truth.md + Input Mode: Full + diff + spec (for known/expected results and worked examples)>, model: "opus" })
    ```
  - Target: Change "ALL SEVEN" → "ALL EIGHT"; after the ground-truth dispatch line (L1226) add:
    `Agent({ description: "Integration/path-coverage review (iter 1, full)", prompt: <review-board-integration.md + Input Mode: Full + diff + "read beyond the diff to enumerate every wired path across an integration boundary" note>, model: "opus" })`
  - Pattern (existing dispatch-line idiom, L1226 above): `Agent({ description: "… (iter 1, full)", prompt: <agent.md + Input Mode: Full + diff + context>, model: "opus" })`
  - Done: "ALL EIGHT" present; an integration `Agent({…})` dispatch line exists.
  - Verify: `grep -n "ALL EIGHT" plugins/spec-flow/skills/execute/SKILL.md` and `grep -n "review-board-integration.md" plugins/spec-flow/skills/execute/SKILL.md`

  **T-2: MODIFY plugins/spec-flow/skills/execute/SKILL.md — update every board-count / member-list site**
  - Anchor: the full board census (introspection Cluster F): L5, L11, L39, L348, L1196, L1230,
    L1231–1236, L1240, L1242, L1252, L1256, L1276, L1283, L1290, L1298
  - Current (representative sites):
    ```
    11  ... a final review board (7 agents in standard mode; 8 in fast mode) before merge.
    1230 When `track = "change"`, dispatch exactly **6 agents** (not 7 or 8):
    1256 Collect findings from all board agents (7 in standard mode; 8 in fast mode — the 8th is `verify-piece-full`).
    ```
  - Target: Apply the count map consistently:
    - piece-track standard **7 → 8**; fast **8 → 9**; the verify-piece-full member is the **9th** (L348,
      L1242, L1252, L1256, L1276, L1298, and frontmatter L5 "7-8" → "8-9").
    - change-track **6 → 7**: add `- review-board-integration` to the change-track bullet list
      (L1231–1236); update "exactly 6 agents (not 7 or 8)" → "exactly 7 agents (not 8 or 9)" (L1230);
      keep the prd-alignment exclusion (L1238).
    - add `integration` to the fix-loop re-dispatch sets (L1276), the amend re-entry sets (L1298), and
      the Step 8 source-agent enumerations (L1283, L1290).
    - L1196 heading "(7 Parallel Agents; 8 in fast mode)" → "(8 Parallel Agents; 9 in fast mode)".
    - L39 "up to 8 review-board agents … (7 standard; 8 in fast mode)" → "up to 9 … (8 standard; 9 in
      fast mode)".
  - Pattern: in-place token edits matching each quoted current line.
  - Done: no current-state board description reads "7 standard / 8 fast" / "ALL SEVEN" / "6 agents (not 7
    or 8)"; every reviewer enumeration that lists `ground-truth` also lists `integration`.
  - Verify: `grep -nE "ALL SEVEN|7 standard|7-standard|7 Parallel|8 in fast mode|6 agents \(not 7" plugins/spec-flow/skills/execute/SKILL.md` — Expected: 0 current-state hits (Phase 12 runs the full sweep).

  **T-3: MODIFY plugins/spec-flow/skills/review-board/SKILL.md**
  - Anchor: frontmatter reviewer list (L5–6); default lens set (L44–46); Step 3 dispatch block (L58–71)
  - Current:
    ```
    44 **Default lens set (no spec/PRD needed):** `blind`, `edge-case`, `security`, `ground-truth`, `architecture`.
    ...
    62 Agent({ description: "Blind review",        prompt: <review-board-blind.md ... >, model: "opus" })
    ...
    66 Agent({ description: "Architecture review", prompt: <review-board-architecture.md ... >, model: "opus" })
    ```
  - Target: Add `integration` to: the frontmatter reviewer enumeration (after `ground-truth`); the
    default lens set (with a one-line "why default: path coverage applies to almost any wired change"
    note); and a new Step 3 dispatch line
    `Agent({ description: "Integration review", prompt: <review-board-integration.md + Input Mode: Full + diff + read-beyond-diff note>, model: "opus" })`. Update any change-track board-size reference in the `--fix` paragraph to include integration.
  - Pattern (existing dispatch-line idiom, L62/66 above).
  - Done: `integration` in frontmatter list + default lens set + a Step 3 dispatch line.
  - Verify: `grep -c "integration" plugins/spec-flow/skills/review-board/SKILL.md` — Expected: ≥ 3 (frontmatter, lens set, dispatch)

- [x] **[Verify]** Confirm board wiring + dispatch parity (structural oracle for AC-9)
  **Per-change checks:**
  - T-1: `grep -c "review-board-integration.md" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 1; `grep -c "ALL EIGHT" …` — Expected: ≥ 1
  - T-2: `grep -nE "ALL SEVEN|7 standard|7 Parallel|6 agents \(not 7|8 in fast mode" plugins/spec-flow/skills/execute/SKILL.md` — Expected: 0
  - T-3: `grep -c "integration" plugins/spec-flow/skills/review-board/SKILL.md` — Expected: ≥ 3
  **Phase-level check (AC-9 dispatch parity — every board enumeration names integration):**
  - Run: `grep -n "ground-truth" plugins/spec-flow/skills/execute/SKILL.md | wc -l` then `grep -n "integration" plugins/spec-flow/skills/execute/SKILL.md | wc -l`
  - Expected: every line/section that enumerates `ground-truth` as a board member is matched by an
    adjacent `integration` member (manual confirmation that the 5 board enumerations — Step 1 piece set,
    change-track set, fix-loop, amend re-entry, Step 8 source-agent — each name `integration`)
  - Failure: a board enumeration lists `ground-truth` but not `integration`

- [x] **[QA]** Phase review
  - Review against: AC-9, AC-10
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 11: Docs — README, command + concept guides (Area H)
**Exit Gate:** README agent count 25→26 + tree entry + board counts 8/9; `commands/execute.md` board
counts 8/9 + integration lens row; `commands/review-board.md` CREATED with the integration lens;
`concepts/{qa-loop,pipeline,tdd-loop}.md` board counts 8/9 + integration mentions, and `tdd-loop.md` gains
the integration-test / double-loop / `[Integration-Test]` / contract-test / path-coverage content. AC-9
(docs) + AC-10 (docs) greps pass.
**ACs Covered:** AC-9 (docs portion), AC-10 (docs portion)
**In scope:** `plugins/spec-flow/README.md`, `plugins/spec-flow/docs/userguide/commands/execute.md`,
`plugins/spec-flow/docs/userguide/commands/review-board.md` (CREATE),
`plugins/spec-flow/docs/userguide/concepts/qa-loop.md`,
`plugins/spec-flow/docs/userguide/concepts/pipeline.md`,
`plugins/spec-flow/docs/userguide/concepts/tdd-loop.md`
**NOT in scope:** other untracked command docs (intake/defer/small-change — not in this piece's scope);
version files (Phase 12); the final anti-drift sweep (Phase 12).
**Charter constraints honored in this phase:**
- Cross-cutting: NN-P-003 (dog-food). (No SKILL.md edited here, so CR-002 does not apply.)

- [x] **[Implement]** Update all six docs for the new board member, counts, and integration concepts;
  create review-board.md.
  - Order: README (count + tree + board counts) → execute.md (counts + lens row) → review-board.md
    (CREATE) → qa-loop.md → pipeline.md → tdd-loop.md (counts + new integration section).
  - Architecture constraints: reference the doctrine for concepts (ADR-3); board counts must match
    Phase 10's wiring (8 standard / 9 fast / 7 change-track).

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/README.md**
  - Anchor: agent count (L23, L39), agent tree (L56–64), board counts (L203, L223, L239, L453),
    review-board row reviewer enum (L225)
  - Current:
    ```
    23  The plugin ships ten skills, a pool of 25 specialized agents, ...
    62  │   ├── review-board-ground-truth.md     # Final Review — ground-truth / oracle correctness
    203 final review:   7 parallel reviewers (Opus); 8 in fast mode
    ```
  - Target: "25 specialized agents" → "26" (L23) and "# 25 subagent templates" → "26" (L39); insert
    `│   ├── review-board-integration.md      # Final Review — integration / path-coverage` after L62
    (before reflection-process-retro); "7 parallel reviewers (Opus); 8 in fast mode" → "8 … (Opus); 9 in
    fast mode" (L203); "(7 agents; 8 in fast mode)" → "(8 agents; 9 in fast mode)" (L223); "7 agents
    standard; 8 in fast mode" → "8 … standard; 9 in fast mode" (L239); "seven parallel reviewers … an 8th
    reviewer" → "eight … a 9th reviewer" (L453); add `integration` to the L225 reviewer enumeration.
  - Pattern (existing agent-tree line idiom, L62 above): `│   ├── <file>.md     # <description>`.
  - Done: agent count = 26; tree has the integration entry; all board counts read 8/9.
  - Verify: `grep -c "26 " plugins/spec-flow/README.md` ≥ 1 (count line); `grep -c "review-board-integration.md" plugins/spec-flow/README.md` ≥ 1; `grep -nE "7 parallel reviewers|8 in fast mode" plugins/spec-flow/README.md` — Expected: 0

  **T-2: MODIFY plugins/spec-flow/docs/userguide/commands/execute.md**
  - Anchor: board counts (L3, L14, L36, L143, L145), board lens table (after ground-truth row ~L155)
  - Current:
    ```
    143 ### Final Review — board (7 agents; 8 in fast mode)
    145 Seven reviewers dispatched **in parallel**, each with a specialized lens. In fast mode, an 8th reviewer (`verify Mode: Piece Full`) ...
    ```
  - Target: All "(7 agents … 8 in fast mode)" → "(8 agents … 9 in fast mode)" (L3, L14, L36, L143);
    "Seven reviewers … an 8th reviewer" → "Eight reviewers … a 9th reviewer" (L145); add an `integration`
    row to the board lens table after the ground-truth row.
  - Pattern (existing lens-table row idiom, execute.md L155): `| **ground-truth** | <description> |`.
  - Done: all board counts 8/9; an `integration` lens row present.
  - Verify: `grep -nE "7 agents|8 in fast mode|Seven reviewers" plugins/spec-flow/docs/userguide/commands/execute.md` — Expected: 0; `grep -c "integration" plugins/spec-flow/docs/userguide/commands/execute.md` ≥ 1

  **T-3: CREATE plugins/spec-flow/docs/userguide/commands/review-board.md**
  - Complete structure outline: a userguide page for `/spec-flow:review-board` mirroring the style of
    `commands/execute.md` — purpose (out-of-band board on any PR/branch/diff), usage/args, the lens set
    (blind, edge-case, security, ground-truth, architecture, **integration**; +spec-compliance/
    prd-alignment when context supplied), `--fix` / `--comment` behavior, and a lens table including the
    `integration` row. (File is ABSENT in the worktree — CREATE, do not MODIFY.)
  - Pattern (verbatim lens-table idiom from execute.md, model the structure on it):
    ```
    ### Final Review — board (8 agents; 9 in fast mode)
    | Lens | What it checks |
    | **ground-truth** | ... |
    | **integration** | Real wired path across each boundary; path coverage; mock-avalanche |
    ```
  - Done: `review-board.md` exists, documents the board including the `integration` lens.
  - Verify: `test -f plugins/spec-flow/docs/userguide/commands/review-board.md && grep -c "integration" plugins/spec-flow/docs/userguide/commands/review-board.md` ≥ 1

  **T-4: MODIFY plugins/spec-flow/docs/userguide/concepts/qa-loop.md**
  - Anchor: L16 (review-board row), L82, L92 (after ground-truth row), L94, L96
  - Current:
    ```
    96  ... the end-of-piece board gains an **8th member — `verify` Mode: Piece Full** ... standard mode = 7 board members; fast mode = 8.
    ```
  - Target: L16 "(7 agents in parallel)" → "(8 agents in parallel)" + add `integration` to the lens enum;
    L82 "seven reviewers" → "eight reviewers"; add an `integration` table row after the ground-truth row
    (L92); L94 "all seven return" → "all eight return"; L96 "8th member" → "9th member" and "standard mode
    = 7 … fast mode = 8" → "standard mode = 8 … fast mode = 9".
  - Pattern (existing lens-table row idiom).
  - Done: all counts 8/9; integration lens present.
  - Verify: `grep -nE "seven reviewers|standard mode = 7|fast mode = 8|all seven" plugins/spec-flow/docs/userguide/concepts/qa-loop.md` — Expected: 0; `grep -c "integration" …` ≥ 2

  **T-5: MODIFY plugins/spec-flow/docs/userguide/concepts/pipeline.md**
  - Anchor: L39, L50
  - Current:
    ```
    50 - **review-board** (7 reviewers in parallel: blind, edge-case, spec-compliance, prd-alignment, architecture, security, ground-truth) ... Fast mode adds an 8th member ...
    ```
  - Target: L39 "7-agent final review board (8 in fast mode)" → "8-agent … (9 in fast mode)"; L50 add
    `integration` to the parallel reviewer list and "an 8th member" → "a 9th member".
  - Pattern: in-place token edits.
  - Done: counts 8/9; integration in the reviewer list.
  - Verify: `grep -nE "7-agent final review|an 8th member|7 reviewers in parallel" plugins/spec-flow/docs/userguide/concepts/pipeline.md` — Expected: 0; `grep -c "integration" …` ≥ 1

  **T-6: MODIFY plugins/spec-flow/docs/userguide/concepts/tdd-loop.md**
  - Anchor: board counts (L143, L149) + new content section
  - Current:
    ```
    143 - Final Review (7-agent board; 8 in fast mode) runs after all phases.
    149 ... the final piece still gets a 7-agent review board (8 in fast mode).
    ```
  - Target: Both "7-agent … 8 in fast mode" → "8-agent … 9 in fast mode"; ADD a new section
    "## Integration tests & the double-loop" covering: the `[integration]` tag + `[Integration-Test]`
    block; the R3 double-loop (outer test authored up front, greened in the completing phase); contract
    tests for doubled true externals; path coverage as a peer of AC coverage; and how
    `review-board-integration` backstops cross-phase integrations. Reference the doctrine for definitions.
  - Pattern (existing section idiom in tdd-loop.md): `## Heading` + prose + bullet list.
  - Done: counts 8/9; a new integration/double-loop section exists naming `[Integration-Test]`, contract
    tests, and path coverage.
  - Verify: `grep -nE "7-agent board|7-agent review board" plugins/spec-flow/docs/userguide/concepts/tdd-loop.md` — Expected: 0; `grep -cE "\[Integration-Test\]|double-loop|path coverage|contract test" …` ≥ 3

- [x] **[Verify]** Confirm docs (structural oracle for AC-9 docs + AC-10 docs)
  **Per-change checks:**
  - T-1: `grep -c "review-board-integration.md" plugins/spec-flow/README.md` ≥ 1; `grep -nE "7 parallel reviewers" plugins/spec-flow/README.md` — Expected: 0
  - T-2: `grep -nE "7 agents|Seven reviewers" plugins/spec-flow/docs/userguide/commands/execute.md` — Expected: 0
  - T-3: `test -f plugins/spec-flow/docs/userguide/commands/review-board.md && echo EXISTS` — Expected: `EXISTS`
  - T-4: `grep -nE "seven reviewers|standard mode = 7" plugins/spec-flow/docs/userguide/concepts/qa-loop.md` — Expected: 0
  - T-5: `grep -nE "7-agent final review|an 8th member" plugins/spec-flow/docs/userguide/concepts/pipeline.md` — Expected: 0
  - T-6: `grep -cE "\[Integration-Test\]|double-loop" plugins/spec-flow/docs/userguide/concepts/tdd-loop.md` ≥ 2
  **Phase-level check:**
  - Run: `grep -rnE "7 (agents|parallel reviewers)|Seven reviewers|7-agent" plugins/spec-flow/README.md plugins/spec-flow/docs/userguide/`
  - Expected: 0 current-state hits describing the standard board as 7
  - Failure: any hit → a doc still says 7-standard

- [x] **[QA]** Phase review
  - Review against: AC-9, AC-10
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 12: Version bump + CHANGELOG + final anti-drift / twin / version-sync sweep (Area I + AC-9/AC-10/AC-12 verification)
**Exit Gate:** version is 4.12.0 in the three JSON files; CHANGELOG has a `## [4.12.0]` entry with a
backward-compat migration note; the repo-wide anti-drift sweep returns no offending current-state hits
(historical CHANGELOG excepted); every board enumeration that names `ground-truth` also names
`integration`; all touched + new agent twins are byte-identical; version-sync across the four files agrees.
**ACs Covered:** AC-9 (final dispatch-parity sweep), AC-10 (anti-drift sweep), AC-12 (version sync)
**In scope:** `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`,
`.claude-plugin/marketplace.json` (spec-flow entry), `plugins/spec-flow/CHANGELOG.md`; plus the read-only
verification sweep across the whole `plugins/spec-flow` tree.
**NOT in scope:** any new behavior — this phase bumps versions, writes the CHANGELOG, and runs the
verification sweep. (If the sweep finds a stale count missed in Phases 7/10/11, fix it here as a sweep
correction.)
**Charter constraints honored in this phase:**
- NN-C-003 (semver / backward-compat): additive, opt-in stricter behavior → **minor** bump 4.11.0 →
  4.12.0; no breaking change to existing specs/plans (NFR-INT-02).
- NN-C-007 (CHANGELOG): a `## [4.12.0]` Keep-a-Changelog entry is added.
- NN-C-009 (version sync): 4.12.0 in all four version-bearing files per `releasing.md` (three JSON
  strings + CHANGELOG).
- Cross-cutting: NN-P-003 (dog-food).

- [x] **[Implement]** Bump versions, add the CHANGELOG entry, and run the verification sweep (fixing any
  residual drift).
  - Order: three JSON version strings → CHANGELOG `## [4.12.0]` entry → verification sweep → fix any
    sweep findings.
  - Architecture constraints: minor bump (NN-C-003); all four files agree (NN-C-009); CHANGELOG includes
    a backward-compat migration note (NFR-INT-02).

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/plugin.json**
  - Anchor: `"version"` (L4)
  - Current: `  "version": "4.11.0",`
  - Target: `  "version": "4.12.0",`
  - Done: version is 4.12.0.
  - Verify: `grep -n '"version": "4.12.0"' plugins/spec-flow/plugin.json`

  **T-2: MODIFY plugins/spec-flow/.claude-plugin/plugin.json**
  - Anchor: `"version"` (L4)
  - Current: `  "version": "4.11.0",`
  - Target: `  "version": "4.12.0",`
  - Done: version is 4.12.0.
  - Verify: `grep -n '"version": "4.12.0"' plugins/spec-flow/.claude-plugin/plugin.json`

  **T-3: MODIFY .claude-plugin/marketplace.json**
  - Anchor: the spec-flow entry `"version"` (L15 — NOT the qa entry at L26 = `1.1.1`)
  - Current: `      "version": "4.11.0",`
  - Target: `      "version": "4.12.0",`
  - Done: the spec-flow marketplace entry is 4.12.0; the qa entry is untouched (1.1.1).
  - Verify: `grep -n '"version": "4.12.0"' .claude-plugin/marketplace.json` (1 hit) and `grep -n '"version": "1.1.1"' .claude-plugin/marketplace.json` (qa entry still present)

  **T-4: MODIFY plugins/spec-flow/CHANGELOG.md**
  - Anchor: between `## [Unreleased]` (L5) and `## [4.11.0]` (L7)
  - Current:
    ```
    5 ## [Unreleased]
    6
    7 ## [4.11.0] — 2026-06-01
    ```
  - Target: Insert a `## [4.12.0] — 2026-06-03` entry (Keep-a-Changelog) with `### Added` (integration-
    test primitive + `[integration]` tag; `[Integration-Test]` block + registry; double-loop M1–M4;
    contract tests; `review-board-integration`; path-coverage doctrine) and `### Changed` (board 7→8 /
    fast 8→9, change-track 6→7; oracle + fast-mode tag-separation; immutability-gate edit window;
    verify/refactor/qa-* checks; templates; docs; verify board-member renumber 7th→9th) plus an explicit
    **backward-compat migration note** (pre-4.12.0 specs/plans with no Integration Coverage /
    `[Integration-Test]` / registry are not rejected; absence = "no integrations declared"; pre-4.12.0
    in-flight pieces are not retrofitted — D10). Model on the v4.11.0 entry (file L10–16).
  - Pattern (existing CHANGELOG bullet idiom, file L10–11):
    ```
    ### Added
    - **`agents/review-board-ground-truth.md` — new Final Review board member:** A generic ground-truth ...
    ```
  - Done: `## [4.12.0]` entry exists with Added + Changed + a backward-compat migration note.
  - Verify: `grep -n "## \[4.12.0\]" plugins/spec-flow/CHANGELOG.md` and `grep -niE "backward-compat|no integrations declared|not rejected" plugins/spec-flow/CHANGELOG.md`

- [x] **[Verify]** Final verification sweep (structural oracle for AC-9, AC-10, AC-12)
  **Per-change checks:**
  - T-1/T-2/T-3 (version sync, AC-12): `grep -h '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json | grep -c "4.12.0"` — Expected: 2; `grep -c '"version": "4.12.0"' .claude-plugin/marketplace.json` — Expected: 1
  - T-4 (AC-12): `grep -c "## \[4.12.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: 1; `grep -ciE "backward-compat|no integrations declared" plugins/spec-flow/CHANGELOG.md` — Expected: ≥ 1
  **Anti-drift sweep (AC-10):**
  - Run: `grep -rnE "ALL SEVEN|7 standard|7-standard|7 in standard|8 in fast|7 parallel|Seven reviewers|7 reviewers|7-8 agents|7-agent board|6 agents \(not 7" plugins/spec-flow --include=*.md --include=*.json | grep -v CHANGELOG`
  - Expected: **0** offending current-state hits (historical CHANGELOG entries excepted by the `grep -v`)
  - Failure: any hit → a current-state self-description still reads "7 standard / 8 fast"; fix it
  **Member-list parity (AC-9 / AC-10):**
  - Run: `for f in $(grep -rln "ground-truth" plugins/spec-flow --include=*.md); do grep -q "integration" "$f" || echo "MISSING integration: $f"; done`
  - Expected: no `MISSING integration:` lines (every file that lists `ground-truth` as a board member also
    lists `integration`)
  - Failure: any `MISSING integration:` line → that enumeration omits the new member
  **Twin integrity (all touched + new agents):**
  - Run: `for a in review-board-integration tdd-red implementer verify refactor qa-tdd-red qa-phase qa-phase-lite qa-spec qa-plan; do cmp plugins/spec-flow/agents/$a.md plugins/spec-flow/agents/$a.agent.md && echo "$a OK" || echo "$a DRIFT"; done`
  - Expected: ten `… OK` lines, zero `DRIFT`
  - Failure: any `DRIFT` → re-sync that twin
  **Bare-name check (NN-C-004):**
  - Run: `grep -rE "^name:\s*spec-flow-" plugins/spec-flow/agents/*.md`
  - Expected: empty (no plugin-prefixed agent names)
  **Definition single-source (ADR-3):**
  - Run: `grep -rln "never mock inside the boundary" plugins/spec-flow`
  - Expected: the definition appears in `reference/spec-flow-doctrine.md` (consumers reference, not
    redefine the term)

- [x] **[QA]** Phase review
  - Review against: AC-9, AC-10, AC-12
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### phase_final_amend_1: Plan-authoring process-enforcement — cross-phase schema-consistency oracle + superseded-ordinal sweep (Area K, K1 + K3-plan)
Why serial: must run before phase_final_amend_2 (execute guidance may reference the plan-side sweep pattern). Extends original Phase 4's edits to `skills/plan/SKILL.md` (in-scope).
**Exit Gate:** `skills/plan/SKILL.md` contains (a) cross-phase schema-consistency `[Verify]`-step guidance, (b) superseded-ordinal anti-drift sweep guidance. AC-13 and AC-15 greps pass.
**ACs Covered:** AC-13, AC-15
**In scope:** `plugins/spec-flow/skills/plan/SKILL.md`
**NOT in scope:** `skills/execute/SKILL.md` (phase_final_amend_2); any other file.
**Charter constraints honored in this phase:**
- CR-002 (preserve `skills/plan/SKILL.md` `name:`/`description:` frontmatter on edit).
- FR-PROC-01 + FR-PROC-03 (plan-side). Cross-cutting: NN-P-003 (dog-food).

- [x] **[Implement]** Add cross-phase schema-consistency oracle guidance (K1/AC-13) and superseded-ordinal anti-drift sweep guidance (K3/AC-15) to `skills/plan/SKILL.md`.
  - Order: K1 cross-phase block → K3 superseded-ordinal block, in the plan-authoring verification/anti-drift guidance region. Re-locate the anchor by content (large file). Preserve frontmatter (CR-002); reference doctrine (ADR-3).
  - **K1 (AC-13):** guidance that when ≥2 phases reference/mutate the same schema-bearing file, the plan author inserts a dedicated **cross-phase** consistency `[Verify]` step after the last schema-touching phase, naming the overlapping files + invariants. Must contain "cross-phase" + ("schema" or "consistency") + "Verify".
  - **K3 (AC-15):** guidance that when a phase mutates a list-length/count invariant, the author enumerates the **superseded** ordinal/count strings (prior values) in the anti-drift sweep alongside the new pattern. Must contain "superseded" + ("ordinal" or "count" or "prior").

- [x] **[Verify]** Confirm plan-authoring guidance (structural oracle for AC-13, AC-15)
  - AC-13: `grep -nE "cross-phase" plugins/spec-flow/skills/plan/SKILL.md | grep -iE "schema|consistency"` — Expected: ≥ 1; confirm "Verify" in adjacent context
  - AC-15: `grep -ni "superseded" plugins/spec-flow/skills/plan/SKILL.md | grep -iE "ordinal|count|prior"` — Expected: ≥ 1
  - CR-002: `head -6 plugins/spec-flow/skills/plan/SKILL.md | grep -E "^name:|^description:"` — both present

- [x] **[QA]** Phase review
  - Review against: AC-13, AC-15
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### phase_final_amend_2: Execute-orchestration process-enforcement — Verify-scope union + post-CHANGELOG re-verification (Area K, K2 + K4)
Why serial: runs after phase_final_amend_1; extends original Phases 5/6/10 edits to `skills/execute/SKILL.md` (in-scope).
**Exit Gate:** `skills/execute/SKILL.md` contains (a) actual-modified ∪ declared-scope Verify-before-QA guidance, (b) post-CHANGELOG fix re-verification guidance. AC-14 and AC-16 greps pass.
**ACs Covered:** AC-14, AC-16
**In scope:** `plugins/spec-flow/skills/execute/SKILL.md`
**NOT in scope:** `skills/plan/SKILL.md` (phase_final_amend_1); any other file. (execute/SKILL.md is a skill — no `.agent.md` twin.)
**Charter constraints honored in this phase:**
- CR-002 (preserve `skills/execute/SKILL.md` frontmatter on edit).
- FR-PROC-02 + FR-PROC-04. Cross-cutting: NN-P-003 (dog-food).

- [x] **[Implement]** Add Verify-scope union guidance (K2/AC-14) and post-CHANGELOG fix re-verification guidance (K4/AC-16) to `skills/execute/SKILL.md`.
  - Order: K2 union-scope block placed immediately BEFORE the per-phase QA-dispatch step → K4 re-check block placed in the Final Review fix-iteration / amendment region. Re-locate anchors by content. Preserve frontmatter (CR-002).
  - **K2 (AC-14):** guidance that the implementer reports its actual-modified-file list and the orchestrator runs the `[Verify]` oracle + phase-level sweep against the **union** of actual-modified ∪ **declared scope** BEFORE dispatching QA. Must contain "actual" + ("modified" or "touched") + ("union" or "declared scope"), before QA dispatch.
  - **K4 (AC-16):** guidance that the orchestrator **re-ver**ifies the CHANGELOG entry whenever a **fix** iteration lands **after** the CHANGELOG/version phase has run; a fix that alters a shipped artifact without updating the CHANGELOG is a must-fix. Must contain "CHANGELOG" + ("re-ver" or "re-check") + ("fix" or "after").

- [x] **[Verify]** Confirm execute guidance (structural oracle for AC-14, AC-16)
  - AC-14: `grep -ni "actual" plugins/spec-flow/skills/execute/SKILL.md | grep -iE "modified|touched"` — Expected: ≥ 1; `grep -ni "union" plugins/spec-flow/skills/execute/SKILL.md | grep -iE "declared scope|actual"` — Expected: ≥ 1
  - AC-16: `grep -ni "CHANGELOG" plugins/spec-flow/skills/execute/SKILL.md | grep -iE "re-ver|re-check"` — Expected: ≥ 1; same with `grep -iE "fix|after"` — Expected: ≥ 1
  - CR-002: `head -6 plugins/spec-flow/skills/execute/SKILL.md | grep -E "^name:|^description:"` — both present

- [x] **[QA]** Phase review
  - Review against: AC-14, AC-16
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1  | Doctrine defines all 5 terms + mocking policy + R1 + R3 + M1–M4 + Implementer's-Dilemma + path-coverage/contract checklist line; forbids mocking inside boundary | COVERED | Phase 1 |
| AC-2  | `templates/spec.md` Integration Coverage block; `qa-spec` allocation criterion | COVERED | Phase 2, Phase 3 |
| AC-3  | `templates/plan.md` `[Integration-Test]` block + registry table; `qa-plan` integration criteria | COVERED | Phase 2, Phase 4 |
| AC-4  | RBVR agents: tdd-red up-front `[integration]` test; implementer wiring-glue + contract tests; verify boundary/path/contract checks; refactor integration-preservation | COVERED | Phase 7 |
| AC-5  | qa-tdd-red / qa-phase (crit 7) / qa-phase-lite boundary authenticity + contract + valid completes_in_phase | COVERED | Phase 8 |
| AC-6  | execute builds registry from plan+Red, carries it; non-integration suite scoping; M3 edit window; M4 sub-cycle | COVERED | Phase 5, Phase 6 |
| AC-7  | Immutability gate rejects Build creating a row / moving a marker / editing outside the window | COVERED | Phase 6 |
| AC-8  | `review-board-integration.md` (+twin): byte-identical, bare name, model opus, read-only, path-enum-first, 7 boundary probes + coverage probe, two-axis verdict, Full+Focused, de-confliction | COVERED | Phase 9 |
| AC-9  | review-board-integration default in piece-track (7→8, fast 8→9) + change-track (6→7); all counts / member lists / fix-loop / amend re-entry / Step 8 enum consistent | COVERED | Phase 10, Phase 11, Phase 12 |
| AC-10 | Anti-drift grep sweep returns no offending current-state hits; every `ground-truth` enumeration also lists `integration` | COVERED | Phase 10, Phase 11, Phase 12 |
| AC-11 | `ac-matrix-contract.md` accepts `tests/x.py:N [integration]` pointer; bare category ref still invalid | COVERED | Phase 1 |
| AC-12 | Version 4.12.0 in three JSON files + `## [4.12.0]` CHANGELOG header w/ migration note; four files agree | COVERED | Phase 12 |
| AC-13 | `skills/plan/SKILL.md` instructs author to insert a cross-phase consistency `[Verify]` step when ≥2 phases touch the same schema-bearing file | COVERED | phase_final_amend_1 |
| AC-14 | `skills/execute/SKILL.md` runs `[Verify]` + sweep against union of actual-modified ∪ declared-scope before QA dispatch | COVERED | phase_final_amend_2 |
| AC-15 | `skills/plan/SKILL.md` instructs author to enumerate superseded ordinal/count strings in the anti-drift sweep | COVERED | phase_final_amend_1 |
| AC-16 | `skills/execute/SKILL.md` re-verifies CHANGELOG when a fix iteration lands after the CHANGELOG/version phase | COVERED | phase_final_amend_2 |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1  | shell | `grep -cE "never mock inside the boundary\|one wired path per integration test\|double-loop\|wiring glue\|Path coverage:" plugins/spec-flow/reference/spec-flow-doctrine.md` | ≥ 5 (each anchor present at least once) |
| AC-1  | shell | `grep -cE "M1\|M2\|M3\|M4" plugins/spec-flow/reference/spec-flow-doctrine.md` | ≥ 4 |
| AC-2  | shell | `grep -c "## Integration Coverage" plugins/spec-flow/templates/spec.md` | 1 |
| AC-2  | shell | `grep -c "Integration allocation" plugins/spec-flow/agents/qa-spec.md` | 1 |
| AC-3  | shell | `grep -c "\[Integration-Test\]" plugins/spec-flow/templates/plan.md` | 3 |
| AC-3  | shell | `grep -c "## Integration-Test Registry" plugins/spec-flow/templates/plan.md` | 1 |
| AC-3  | shell | `grep -c "Integration allocation" plugins/spec-flow/agents/qa-plan.md` | 1 |
| AC-4  | shell | `grep -cE "\[integration\]\|completes_in_phase" plugins/spec-flow/agents/tdd-red.md` | ≥ 2 |
| AC-4  | shell | `grep -c "wiring glue" plugins/spec-flow/agents/implementer.md` | ≥ 1 |
| AC-4  | shell | `grep -c "7th" plugins/spec-flow/agents/verify.md` | 0 |
| AC-4  | shell | `grep -c "integration-preservation" plugins/spec-flow/agents/refactor.md` | ≥ 1 |
| AC-5  | shell | `grep -cE "boundary authenticity\|completes_in_phase" plugins/spec-flow/agents/qa-tdd-red.md` | ≥ 1 |
| AC-5  | shell | `grep -cE "un-mocked\|boundary.*authenticity" plugins/spec-flow/agents/qa-phase.md` | ≥ 1 |
| AC-5  | shell | `grep -c "boundary-authenticity spot-check" plugins/spec-flow/agents/qa-phase-lite.md` | ≥ 1 |
| AC-6  | shell | `grep -c "integration_registry" plugins/spec-flow/skills/execute/SKILL.md` | ≥ 2 |
| AC-6  | shell | `grep -c "not integration" plugins/spec-flow/skills/execute/SKILL.md` | ≥ 2 |
| AC-6  | shell | `grep -cE "skeleton_sha256\|completed_sha256\|Integration-Test. sub-cycle" plugins/spec-flow/skills/execute/SKILL.md` | ≥ 3 |
| AC-7  | shell | `grep -cE "cannot create a registry row\|cannot self-authorize\|single-shot, path-confined" plugins/spec-flow/skills/execute/SKILL.md` | ≥ 1 |
| AC-8  | shell | `cmp plugins/spec-flow/agents/review-board-integration.md plugins/spec-flow/agents/review-board-integration.agent.md; echo $?` | `0` (identical) |
| AC-8  | shell | `grep -cE "^name: review-board-integration$\|^model: opus$\|UNTRACED\|UNIT-ONLY\|mock-avalanche\|de-confliction" plugins/spec-flow/agents/review-board-integration.md` | ≥ 6 |
| AC-9  | shell | `grep -c "review-board-integration.md" plugins/spec-flow/skills/execute/SKILL.md` | ≥ 1 |
| AC-9  | shell | `grep -c "integration" plugins/spec-flow/skills/review-board/SKILL.md` | ≥ 3 |
| AC-10 | shell | `grep -rnE "ALL SEVEN\|7 standard\|8 in fast\|Seven reviewers\|6 agents \(not 7" plugins/spec-flow --include=*.md --include=*.json \| grep -v CHANGELOG \| wc -l` | `0` |
| AC-10 | shell | `for f in $(grep -rln "ground-truth" plugins/spec-flow --include=*.md); do grep -q "integration" "$f" \|\| echo MISS; done \| grep -c MISS` | `0` |
| AC-11 | shell | `grep -c "\[integration\]" plugins/spec-flow/reference/ac-matrix-contract.md` | ≥ 2 |
| AC-12 | shell | `grep -h '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json \| grep -c 4.12.0` | `2` |
| AC-12 | shell | `grep -c "## \[4.12.0\]" plugins/spec-flow/CHANGELOG.md` | 1 |
| AC-13 | shell | `grep -nE "cross-phase" plugins/spec-flow/skills/plan/SKILL.md \| grep -iE "schema\|consistency" \| wc -l` | ≥ 1 |
| AC-14 | shell | `grep -ni "actual" plugins/spec-flow/skills/execute/SKILL.md \| grep -iE "modified\|touched" \| wc -l` | ≥ 1 |
| AC-15 | shell | `grep -ni "superseded" plugins/spec-flow/skills/plan/SKILL.md \| grep -iE "ordinal\|count\|prior" \| wc -l` | ≥ 1 |
| AC-16 | shell | `grep -ni "CHANGELOG" plugins/spec-flow/skills/execute/SKILL.md \| grep -iE "re-ver\|re-check" \| wc -l` | ≥ 1 |

## Contracts

No TDD-track phases in this plan — contracts section present for forward compatibility. tdd-red agents
will not be dispatched; no contract injection occurs. (This piece is Implement-track only: pure
markdown / agent-prose with structural verification per the spec's Testing Strategy. The
boundary-crossing artifacts it introduces — the M1 registry table schema and the `review-board-integration`
agent — are plan/prose artifacts, not runtime interfaces, and carry no executable contract.)

## Parallel Execution Notes

All 12 phases run **serial** by deliberate choice (`Why serial:` lines on Phases 3, 5, 7; whole-plan
rationale in the Overview). The dominant risk is cross-file consistency — single-source-of-truth
terminology (ADR-3) and board-count / dispatch-parity drift (AC-9/AC-10/FR-INT-11) — which standard-mode
(`fast: false`) per-phase Opus QA catches phase-by-phase. Disjoint-scope pairs that were considered for
Phase Groups but kept serial: Phase 3 (spec authoring) vs Phase 4 (plan authoring); Phase 7 (RBVR agents)
vs Phase 8 (QA gate agents). Phases 5 and 6 share `execute/SKILL.md` (genuinely non-parallelizable). No
Phase 0 Scaffold is needed: although `execute/SKILL.md` is touched by Phases 5, 6, and 10, those phases
are serial (no concurrent-write race), and each agent twin is edited within a single phase.

## Agent Context Summary
| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, plan `[Implement]` tasks (Change Specs with verbatim CURRENT blocks), spec ACs, plan's `[Verify]` structural commands, arch constraints (ADRs), pattern blocks, codebase context from `introspection.md` | Spec rationale, brainstorming history |
| Verify | Verification output (the phase's structural grep/`cmp`/version commands), spec ACs | Implementation reasoning |
| Refactor | Current files (phase files only), the phase's `[Verify]` commands, quality principles | Prior agent conversations |
| QA (qa-phase, Opus) | Phase diff, spec, plan, PRD sections | Any agent conversation history |
| Final Review board (8 agents; 9 in fast mode) | Cumulative piece diff + per-lens context | Each other's conversations |
