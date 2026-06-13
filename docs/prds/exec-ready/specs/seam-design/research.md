# Research — seam-design (exec-ready)

## Brainstorm Inference Digest

**Piece purpose.** Shift-left the integration-surface design that today lands only POST-execution.
The manifest frames it as four edits (SPEC seam inventory + production-call-site AC, PLAN `[integration]`
B-lite phases + contract tests, DOCTRINE single-source-of-truth definitions, ENFORCEMENT in qa-spec/qa-plan).
It is the integration analog of the shipped `outcome-acs` piece.

**CRITICAL FRAMING CORRECTION — most of the manifest's "four edits" already shipped.** A prior wave
(the stalled 4.12.0 "review-board-integration" proposal, resurrected and largely landed) already put in place:
- **Doctrine** (`spec-flow-doctrine.md` §"Integration Tests & Path Coverage", L113–136): full definitions of
  *integration boundary, integration test (narrow/sociable), path coverage, `[integration]` tag, contract test,
  boundary mocking policy ("never mock inside the boundary"), R1, R3 double-loop, M1–M4 mechanics*. The
  Verification Checklist already carries a path-coverage line.
- **Spec skill** Phase-2 step "Integration surfacing" (L230) + `## Integration Coverage` block in `templates/spec.md` (L71–73).
- **Plan skill** "Integration-driven phase ordering" (L180–184, the **B-lite** ordering: declare outer test up front,
  author+green in completing phase), `[Integration-Test]` block (L262–274), `## Integration-Test Registry` (M1) table.
- **QA**: `qa-spec` #13 (integration allocation: boundary/externals/AC), `qa-plan` #26 (integration allocation:
  registry well-formedness, `registered_in_phase ≤ completes_in_phase`), `qa-tdd-red` boundary-authenticity +
  contract + `completes_in_phase` check, `qa-phase` #7 (seam authenticity), `qa-phase-lite` #5 (sub-phase spot-check),
  and the shipped **`review-board-integration` agent** (8 probes, two-axis verdict, post-hoc Final-Review lens).
- **AC-matrix contract** already accepts `tests/x.py:N [integration]` as a valid concrete pointer (the prior
  "covered by integration tests = invalid vague pointer" tension is resolved).
- **behavior-classification.md** already defines the `[outcome:integration]` facet ("seams plumbed and wired;
  e2e produces a real result, not a fixture; nothing stubbed; no glue missing").

**The genuine GAP this piece must fill (the residue the prior wave did NOT ship):**
1. **MANDATORY production-call-site AC per seam.** Nothing today forces a seam AC to reference a **real
   production call path in `src/`** (not test-side wiring). `[outcome:integration]` asks "what could be left
   unwired" but does not mandate a per-seam AC naming the production call site. `qa-spec` #13 checks the
   *Integration Coverage block* shape, not a production-call-site AC.
2. **Enforcement raising must-fix when a behavior-bearing boundary-touching piece lacks a seam inventory /
   production-call-site AC / `[integration]` coverage** — and **non-boundary pieces exempt with a recorded
   one-line rationale**. Today `qa-spec` #13 / `qa-plan` #26 only *activate when an Integration Coverage block
   is present* (NFR-INT-02: absence == "no integrations") — so a piece that SHOULD have seams but omits the
   block sails through. This piece must close that "silent omission" hole with an exemption-rationale gate,
   mirroring `outcome-acs`'s `behavior_rationale` precedent.
3. Possibly a **`[seam]`/seam-inventory artifact** distinct from the existing `## Integration Coverage` block
   (or an extension of it) — see open questions.

**Design constraints (binding).** NN-C-002: markdown/YAML/JSON/POSIX-bash only, no runtime deps; spec-flow also
installs on GitHub Copilot CLI → all orchestration hand-rolled in markdown. NN-C-003: additive/backward-compatible,
legacy specs (no `piece_class`) never retro-failed. NN-C-008: agents self-contained (read discriminator/tags from
the artifact, no brainstorm-history dependency). NN-C-009: version triad bump (plugin.json + marketplace.json +
CHANGELOG). Paired agent files use a **relative symlink** (`qa-spec.agent.md -> qa-spec.md`); a `qa-spec` edit
must bump its `rubric_version`.

**Genuine open questions a spec author must resolve:**
- **Q1 — artifact location & schema.** Does the seam inventory extend the existing `## Integration Coverage`
  block (lowest-friction, reuses qa-spec #13 / qa-plan #26 plumbing) or get a new artifact/section? The
  `outcome-acs` precedent deliberately added NO new `###` under `## Acceptance Criteria` (CR-009 extraction-anchor
  collision) — a new heading must avoid that collision.
- **Q2 — production-call-site AC expression & machine-check.** How is "an AC must reference a real production
  call path in `src/`, not test-side wiring" expressed and *machine-checked* deterministically (NFR-OA-2 style)?
  Candidate: an `[outcome:integration]` AC whose `Independent Test [machine:]` greps a `src/` path (not a
  `tests/` path). How does the gate distinguish a production-call-site pointer from a test-side one with a
  fixed, greppable rule (not free-text judgment)?
- **Q3 — tag composition.** How does a seam/production-call-site AC compose with the existing exactly-one-of
  `[mechanism]`/`[outcome:result]`/`[outcome:integration]` AC-line tags and the orthogonal
  `[machine:]`/`[judgment:]` Independent-Test tags? Is the production-call-site AC simply an `[outcome:integration]`
  AC with an added constraint, or a new tag? (Adding a 4th AC-line tag would touch behavior-classification.md's
  "exactly one" glossary — heavier blast radius.)
- **Q4 — B-lite `[integration]` phase interaction** with phase-groups, deferred-commit, and fast-mode. The
  alignment-findings doc records that *true* Option-B cross-phase-red collides with the SHA-256 gate, the
  "every Red test must pass" oracle, fast-mode, and Red's "fail now" contract — which is WHY B-lite (author+green
  in the completing phase) was adopted. The spec must NOT re-open true-Option-B; it stays within B-lite.
- **Q5 — exemption mechanism.** What is the "recorded one-line rationale" for non-boundary pieces? Mirror
  `behavior_rationale`? A `## Integration Coverage` body of "None in scope — <reason>"? The gate must treat
  *rationale presence* as the clean state (criterion-15 sentinel precedent).
- **Q6 — ≤7-AC split.** `outcome-acs` shipped ~17 ACs in one piece (it touched template+skill+brainstorm+lens+
  convergence+2 qa agents+version). This piece's surface is comparable (doctrine + spec + template + plan +
  template + qa-spec + qa-plan + version) → likely brushes/exceeds the ≤7-AC granularity guideline (qa-prd #10).
  The author must decide whether to split (e.g. authoring-affordances vs enforcement) or justify one piece.

## Codebase Conventions

- **File layout.** `plugins/spec-flow/{skills/<name>/SKILL.md, agents/<name>.md, templates/{spec,plan}.md,
  reference/<topic>.md}`. Specs/plans live at `docs/prds/<prd-slug>/specs/<piece-slug>/{spec,plan,research}.md`.
- **AC-tag idioms (exact-literal, case-sensitive).** Every `AC-N:` line ends with exactly one of `[mechanism]`,
  `[outcome:result]`, `[outcome:integration]`. The next line is `Independent Test [machine: <greppable check>]: …`
  or `Independent Test [judgment: <named arbiter>]: …`. Per-facet N/A sentinel: `Outcome N/A [outcome:<facet>]: <reason>`.
  A mis-cased tag fails safe (treated as absent). Tokens are owned by `reference/behavior-classification.md`.
- **`[integration]` test pointer** in the AC matrix: `tests/x.py:N [integration]` (path + line + tag) is a valid
  concrete pointer; path coverage tracked orthogonally to AC coverage.
- **Reference-doc citation by path/anchor.** Skills/agents cite reference docs by repo-root-relative path
  (CR-005), e.g. "see `reference/spec-flow-doctrine.md` for the boundary and seam definitions" — definitions
  are NOT restated in the citing file (single-source-of-truth discipline).
- **QA criteria are appended, never renumbered** (NN-C-003); each carries an activation guard
  ("activate only when …; skip if absent — not an error") and ends with `**Must-fix.**` + an `Evidence:` line.
- **Agent symlink pair.** `<agent>.agent.md` is a relative symlink to `<agent>.md`; editing the `.md` bumps
  `rubric_version` in its front-matter.
- **Three-state enforcement predicate** (the `outcome-acs` pattern qa-spec #17 / qa-plan #33 follow): legacy-skip
  (discriminator absent) → exempt-with-rationale (non-applicable + rationale present) → enforce (applicable).
- **Gate determinism (NFR-OA-2).** Matching is exact-literal/greppable; any quality judgment is a fixed enumerated
  blocklist with quoted evidence — no free-text semantic adjudication in a gate.
- **Version triad** bumped together (plugin.json `.version`, root `marketplace.json` spec-flow entry, CHANGELOG
  Keep-a-Changelog entry); MINOR for additive.

## Doctrine & Reference

### File Inventory
**File Inventory:** `plugins/spec-flow/reference/spec-flow-doctrine.md` (184 lines; §"Testing Strategy" L96–111,
§"Integration Tests & Path Coverage" L113–136 with definitions + R1/R3 + M1–M4, §"Verification Checklist" L138–152);
`plugins/spec-flow/reference/behavior-classification.md` (defines `piece_class`, `result`/`integration` facets,
canonical tag glossary, fail-safe matching); `plugins/spec-flow/reference/ac-matrix-contract.md` (accepts
`tests/x.py:N [integration]` pointer at rule 4; declares "covered by integration tests" bare-category still invalid).

### Dependency Map
**Dependency Map:** Doctrine is loaded at session start and cited by every QA agent + the spec/plan skills.
behavior-classification.md is the spec-time piece-level classifier (cited by qa-spec #17, qa-plan #33,
spec-skill Phase 2/3, brainstorm-procedure, templates/spec.md). ac-matrix-contract.md governs the Build→verify
handoff (execute Step 4). All three are pure markdown, no runtime consumers. The new doctrine definitions for
"seam inventory" / "production-call-site" would land in the existing §"Integration Tests & Path Coverage".

### Test Landscape
**Test Landscape:** No code tests; verification is grep/`[ -L ]` static checks (see `tests/e2e/lib/static.sh`
referenced by outcome-acs AC-12) plus judgment review of fixture specs run through qa-spec/qa-plan. Doctrine
correctness is asserted by `git diff` (e.g. "L179 unchanged") and grep-for-definition machine tests.

### Pattern Catalog
**Pattern Catalog:**
```
## Integration Tests & Path Coverage
**Integration boundary** — the set of real components a wired path crosses. "Inside the boundary" = those
components; "outside the boundary" = true externals (network services, filesystems, third-party APIs, etc.).
**Integration test** — a test that exercises the real wired path across an integration boundary: real components
inside; stub/fake for true externals outside. This is the *sociable / narrow integration test* …
**`[integration]` tag** — the marker placed on an integration test (e.g. `@pytest.mark.integration`, `// [integration]`).
**Contract test** — a test that verifies a stub or fake of a true external stays faithful to the real external's contract.
```
```
- **`integration`** — the seams are plumbed and wired; the e2e path produces a real result,
  not a fixture; nothing is stubbed; no glue is missing. The `integration` facet asks: what
  could be left unwired, stubbed, or not actually plumbed so the e2e path silently short-circuits …
```

## Prior-Art Drafts (review-board-integration proposal — stalled 4.12.0, partially shipped)

### File Inventory
**File Inventory:** `plugins/spec-flow/proposals/review-board-integration/` (gitignored — present only in the MAIN
repo checkout `/Volumes/joeData/ai-plugins/plugins/...`, NOT in this worktree): `spec.md` (29.2K — "Integration Tests
as a First-Class Pipeline Primitive"), `plan.md` (13K), `alignment-findings.md` (8.2K — the four architectural
collisions + B-lite recommendation), `concerns-and-integration-map.md` (10.6K — the full file-touch census,
Concerns 1–4, the `[seam]`-tag proposal), `testing-foundations.md` (7.8K — Fowler/Cohn/Meszaros/GOOS grounding).

### Dependency Map
**Dependency Map:** These are design drafts, not wired into the pipeline. **What SHIPPED from them:** the doctrine
definitions, the `[integration]` tag, the `[Integration-Test]` block + M1 registry, B-lite ordering, contract tests,
the `review-board-integration` agent, and the qa-spec #13 / qa-plan #26 / qa-tdd-red / qa-phase #7 / qa-phase-lite #5
integration checks. **What did NOT ship — the residue this piece owns:** (a) the MANDATORY production-call-site AC,
(b) the must-fix enforcement when a behavior-bearing boundary-touching piece *omits* the seam inventory entirely
(today omission == "no integrations" per NFR-INT-02 — the silent-omission hole), (c) the non-boundary exemption
rationale gate. The drafts also proposed a `[seam]` tag primitive (Concern 4) — the shipped work used `[integration]`
instead; a spec author should NOT reintroduce `[seam]` without reconciling.

### Test Landscape
**Test Landscape:** N/A (design docs). The drafts' decisions of record: **B-lite** over true-Option-B (alignment-findings
"the fix"); **R1 + R3** doctrine resolution (concerns-and-integration-map Concern 1); "seam" was the WRONG word →
use "integration boundary/test" (testing-foundations); contract tests **mandated** for doubled externals.

### Pattern Catalog
**Pattern Catalog:**
```
**Hybrid (B-lite) — declared-up-front scenario, authored-and-greened in the completing phase.**
  The integration scenario is declared in the plan up front (drives phase ordering — the double-loop planning
  benefit). The actual [integration] test is authored AND greened within its completing phase as a normal
  in-phase Red→Build→Verify at integration scope.
  - Kills all four collisions: no cross-phase manifest, no immutability conflict, no expected-red, no fast-mode change.
```
```
Distinct failure mode owned by the new work: "a seam (cross-component / real-dependency call) is mocked in tests,
so the wired path is never asserted; the suite stays green; the integrated system is broken."
```

## Authoring Skills (spec & plan)

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/spec/SKILL.md` (349 lines — Phase 2 brainstorm L222–249 incl.
"Integration surfacing" L230 + "Outcome-AC per-facet coverage check" L241–245; Phase 3 write L251–261 incl.
always-write `piece_class` L261; Phase 4 QA loop L263–292). `plugins/spec-flow/skills/plan/SKILL.md` (722 lines —
"Integration-driven phase ordering" L180–184, track selection + `[Integration-Test]` block L202–274, phase-sizing
L276–288, Contracts step ~L426–450).

### Dependency Map
**Dependency Map:** spec-skill Phase 2 → `reference/brainstorm-procedure.md` (mandatory blocks incl. C-NS
negative-space) + `templates/spec.md`; Phase 4 → `agents/qa-spec.md` + `agents/fix-doc.md`. plan-skill →
`templates/plan.md` + `agents/qa-plan.md`; reads spec's `## Integration Coverage` block to drive phase ordering;
writes the `## Integration-Test Registry` (M1) and `## Contracts`. A seam-inventory authoring step slots into
spec Phase 2 "Integration surfacing" (extend) + a production-call-site self-check into Phase 2 step-1a / the
H-5 active-validation preview (mirroring the outcome-AC per-facet check at L241–245).

### Test Landscape
**Test Landscape:** Verified by judgment review of the SKILL prose (outcome-acs AC-3/AC-4 pattern: "reviewer confirms
the N authoring instructions are present and unambiguous") and by grep machine-checks for the new block/clause.

### Pattern Catalog
**Pattern Catalog:**
```
   - **Integration surfacing:** Identify each cross-component integration in scope: name the boundary (which
     components are inside), the true externals that must be doubled (each needing a contract test), and the AC
     each integration is allocated to. Record them in the spec's Integration Coverage block (per templates/spec.md);
     if there is no cross-component wiring, write 'None in scope.' Reference reference/spec-flow-doctrine.md …
```
```
   1a. **Outcome-AC per-facet coverage check (behavior-bearing only):** When `piece_class` is behavior-bearing,
       list: "For each facet {result, integration}, do I have ≥1 `[outcome:<facet>]` AC or a facet N/A sentinel?"
       Flag any uncovered facet before writing the spec. Skip when `piece_class: non-behavioral` …
```
```
   **Integration-driven phase ordering.** When the spec's `## Integration Coverage` block declares one or more
   integrations … - Declare the outer `[integration]` test up front … - Mark that phase with a
   `completes_in_phase: <phase-number>` annotation on the `[Integration-Test]` block …
```

## QA Agents

### File Inventory
**File Inventory:** `agents/qa-spec.md` (126 lines, `rubric_version: 2`; #13 integration allocation L37, #17
outcome/negative-space L56–78); `agents/qa-plan.md` (233 lines, `rubric_version: 2`; #26 integration allocation
L148, #33 anti-mislabel L200+); `agents/qa-tdd-red.md` (boundary-authenticity + contract + `completes_in_phase`
check L64–67); `agents/qa-phase.md` (#7 integration surface / seam authenticity L35); `agents/qa-phase-lite.md`
(#5 boundary-authenticity spot-check L46); `agents/review-board-integration.md` (159 lines, `rubric_version: 1`,
`model: opus`; 8 probes, two-axis verdict, mock-avalanche + un-contract-tested-double; explicit de-confliction vs
ground-truth/edge-case/architecture). Each has a relative `.agent.md` symlink.

### Dependency Map
**Dependency Map:** qa-spec ← spec skill Phase 4 (Full + Focused re-review + Focused-charter modes); qa-plan ←
plan skill QA loop; qa-tdd-red ← execute Step 2.5; qa-phase / qa-phase-lite ← execute phase/sub-phase boundaries;
review-board-integration ← execute end-of-piece Final Review. All read the doctrine for definitions. The new
production-call-site / silent-omission must-fix would be **appended** as new criteria to qa-spec (and possibly
qa-plan) with a `rubric_version` bump; review-board-integration is the *post-hoc* lens the new *shift-left*
primitive must COMPOSE WITH (catch at spec/plan time what the board catches post-merge) — not duplicate.

### Test Landscape
**Test Landscape:** Enforcement ACs follow the outcome-acs precedent: `[machine:]` for symlink/`rubric_version`/grep
checks (`[ -L agents/qa-spec.agent.md ]`, `readlink …`, grep for criterion text), `[judgment:]` for "reviewer runs
qa-spec Full mode on a provided fixture spec lacking a seam inventory and confirms must-fix" + a legacy-fixture
clean-pass AC. The existing activation guards (NFR-INT-02 "absence == no integrations") are the precise hole the
new criterion must change to "behavior-bearing + boundary-touching + no inventory + no exemption rationale → must-fix".

### Pattern Catalog
**Pattern Catalog:**
```
13. **Integration allocation:** If the spec declares any integration in its Integration Coverage block, each must
    (a) state its boundary …, (b) name the true externals to be doubled (each requiring a contract test), and
    (c) be allocated to a specific AC. A declared integration missing any of (a)/(b)/(c), or any integration
    silently deferred, is must-fix. Absence of an Integration Coverage block when the piece has no cross-component
    wiring is NOT a finding (NFR-INT-02 — absence = 'no integrations declared').
```
```
**Boundary-authenticity + contract + `completes_in_phase` check (separate from the 11 above):** for each
[integration] test …
- **Nothing inside the boundary is doubled.** Flag any mock, stub, or fake of a real in-boundary component …
- **Each doubled external has a contract test.** …
- **`completes_in_phase` is present and valid.** …
```
```
17. **Outcome / negative-space coverage (behavior-bearing pieces).** … Three-state predicate, decided by the
    spec's piece_class front-matter: - **Legacy skip:** NO piece_class field → skip … - **Non-behavioral
    exemption:** non-behavioral → exempt. Must-fix ONLY if behavior_rationale is absent … - **Behavior-bearing
    enforcement:** for EACH facet in {result, integration}, require at least one AC … OR a per-facet N/A sentinel.
```

## Sibling Precedent (outcome-acs) & Templates

### File Inventory
**File Inventory:** `docs/prds/exec-ready/specs/outcome-acs/{spec.md (26.5K, ~17 ACs), plan.md (66.3K),
research.md, deliberation.md, metrics.yaml}`. Sibling `gate-scaling` introduced `[machine:]`/`[judgment:]`
Independent-Test tags. Templates: `plugins/spec-flow/templates/spec.md` (77 lines — AC form L56–61, `## Integration
Coverage` L71–73) and `plugins/spec-flow/templates/plan.md` (378 lines — `## Integration-Test Registry` L54–62,
`[Integration-Test]` block L124–127 & L193–195 & L264–266, `## Contracts` L348–365).

### Dependency Map
**Dependency Map:** outcome-acs is the structural template to copy: it added `piece_class`/`behavior_rationale`
front-matter + `[outcome:*]` AC tags to `templates/spec.md`, an always-write rule + per-facet self-check to
`skills/spec/SKILL.md`, a mandatory negative-space block to `reference/brainstorm-procedure.md`, criterion #17 to
qa-spec (+ rubric bump + symlink), criterion #33 to qa-plan, a new `reference/behavior-classification.md`, and the
version triad. This piece mirrors that shape on the integration axis (doctrine definitions + production-call-site AC
+ qa criteria + exemption). The `## Integration Coverage` block + M1 registry are the existing slots to extend
rather than re-invent.

### Test Landscape
**Test Landscape:** outcome-acs ACs use the exact pattern this piece should follow — `[machine:]` grep/symlink/version
checks for static artifacts; `[judgment:]` fixture-run checks for qa-agent enforcement behavior (e.g. AC-9 "reviewer
runs qa-spec Full mode on a provided behavior-bearing fixture missing a facet and confirms must-fix"; AC-10 legacy
fixture clean-pass; AC-14 liveness-only must-fix). A seam-design AC-11-analog ("every site the design requires to
cite the reference doc actually does") greps each named site.

### Pattern Catalog
**Pattern Catalog:**
```
AC-1: Given the piece is implemented, When `reference/behavior-classification.md` is read, Then it defines …,
the two facets (result, integration — integration explicitly naming seams/e2e/stub/glue), and the canonical
token glossary; and it does not modify `spec-flow-doctrine.md` L179. `[mechanism]`
  Independent Test [machine: grep for the piece-class criteria, both facet definitions, and the glossary tokens …]
```
```
## Integration Coverage
- Integration: {{A}}→{{B}} — inside:{{components}}; doubled externals:{{ext}}(contract-tested); AC-{{id}}; completes phase {{N}}
- (A piece with no cross-component wiring writes "None in scope.")
```
```
- [ ] **[Integration-Test]** (completing-phase only) Complete + green the outer `[integration]` test
  - Boundary: {{which components are inside; which true externals are doubled}}
  - completes_in_phase: {{N}}
  - Contract tests: {{one per doubled true external}}
  - Run: {{real-wired-path test command}} — Expected: {{specific pass output}}
```
