# Learnings — exec-ready/pipeline-e2e

Pipeline end-to-end smoke test (FR-013, G-1). 7 phases, all Implement-track (non-TDD), serial. 30 commits, 54 files, +3827/−6. Built a three-layer bash e2e harness for the spec-flow pipeline's observable contract. Ran on Opus 4.8 (operator override of the Sonnet-class coordinator check).

## Patterns that worked well

- **ADR-1 "runner pre-wires all modes, modules register by presence."** Phase 1 wrote the complete CLI + `run_mode` guard once; every later phase added only a `lib/*.sh` file with zero runner edits. No coordination-file contention across 6 module-adding phases, and a missing module surfaced as a counted `ERROR` (never a silent PASS) during partial builds — which doubled as the never-false-green property during the build itself.
- **The orchestrator pre-flight caught two cross-phase contract gaps before they cost a QA cycle.** Phase-2 pre-flight verified all 13 L1 tokens existed at line-start in the live `execute/SKILL.md` (confirming AC-1's "13 PASS on unmodified tree"); Phase-4 pre-flight discovered the `[SPIKE]` audit-target collision and resolved it into a binding pre-decision (`[SPIKE:` live-marker detection) before dispatching the implementer.
- **Audit/Full verify split mapped cleanly onto phase shape.** Audit on Phases 1/2/6 (sourced-library output, clean first-attempt builds); Full on Phases 3/4/5 (real-git subprocess + multi-file assertion chains where Audit would miss integration behavior). No mis-classifications. Refactor auto-skip ran twice (P3, P5) → both NO_CHANGES_NEEDED; for small single-responsibility bash modules the per-phase scope already enforces the equivalent of "one concern per file."
- **FR-8 Opus-skip on the docs-only Phase 7 was correct.** README + charter markdown + JSON version literals carry no control-flow; per-phase Opus QA was skipped and the 8-agent board covered the release content with no finding.
- **Byte-exact fixture discipline held.** The builder reproduces the pipeline's conventional-commit grammar verbatim (verified to the em-dash by the QA board's hexdump); refactor passes were scope-guarded to never touch frozen assertion substrate.

## Issues QA caught (and the layered defense that caught them)

The harness exists to be never-false-green; fittingly, three of its own false-green / contract-gap defects were caught by the layered gates — a useful demonstration that the layers are complementary, not redundant:

1. **Phase-3 fixture heading mismatch (`## Phase` H2 vs the `### Phase` H3 that `check_test_data` and real plans use).** Caught at Phase-4 pre-flight (would have made the no-test-data break silently not fire). Root cause: the Phase-3 fixture T-spec described content shape ("two phases") without naming the heading anchor that Phase-4's parser keys on. Fixed via fix-code (Build-correctness).
2. **Phase-4 self-test asserted substrings that appeared in PASS lines too** (pass/fail-indistinguishable — a check regression would not be caught). Caught by Phase-4 Opus QA; fixed by `^FAIL`-anchoring.
3. **Default-mode break loop accepted ANY `^FAIL` + didn't check the builder's exit** (false-green if the builder ever broke for the wrong reason), and **`check_spike` omitted the `**Test Data:**` enforcement its own SF-3(d)/AC-7 require** (a Test-Data-less spike passed). Both caught by the Final Review board (edge-case + ground-truth), missed by per-phase QA because neither was named in a phase AC. Fixed in one fix-code iteration: builder-exit guard + per-case `^FAIL.*<pattern>` matching, and the four-field spike conformance check with a new `spike-no-td` self-test case.

The board also confirmed the load-bearing AC-7 round-trip is the REAL wired path (spike oracle grepped, bound to both plan + test — not isolation) and the Registry-#2 transcript double is faithful to the live Claude Code token shape.

## Recommendations for future specs/plans (process)

- **When a fixture file is the input contract for a later phase's parser, the fixture T-spec must state the exact anchor the parser keys on** — not just content shape. (Would have prevented issue #1 at authoring time.)
- **For a phase whose deliverable is a check function with an enumerated required-field list, add a field-completeness assertion to the phase's own Verify step** (e.g. count the field-checks against the spec's named count). (Would have caught the `check_spike` `**Test Data:**` omission before QA — issue #3.)
- **When a Test Data case uses an expected-fail wrapper (a PASS verdict whose label describes a FAIL), the Test Data block should name the label pattern and the anti-pattern** ("assert `^PASS — break:` / `^FAIL.*<token>`, not a bare substring"). (Issue #2.)
- **For an expected-fail loop, the phase Exit Gate should include a counter assertion** ("emits exactly N `^PASS — break:` lines, zero `^FAIL — break:`") rather than only a prose description of passing behavior. (Issue #3, break-loop targeting.)
- **A loosely-quoted token in a plan spec (`grep '[SPIKE'`) cost an orchestrator pre-decision to refine to the live-marker grammar (`[SPIKE:`).** Plans that name a grep token should name the precise, collision-free form.

## Forward opportunities (surfaced at reflection — for operator triage, not auto-deferred)

These are out of this piece's scope and feed existing open pieces or are small harness-polish items. Recorded here with provenance; triage to backlog at your discretion (`/spec-flow:defer`).

- **`verify_live` hardcodes `tdd-red count == 3`** coupled to the live fixture's 3 TDD phases, with no re-record policy covering the coupling (unlike golden). Candidate: derive the count by grepping the plan at verify time, or document the coupling in the README re-record policy. → small `pipeline-e2e` spec amendment.
- **`golden_validate`'s commit-subject ordering anchor is `feat(demo): phase 1`** (exact); a future fixture phase-naming change would silently mis-match. Candidate: generalize to the `feat(demo): phase ` prefix + document the grammar coupling. → small fix, gates on `pi-022-vsync-ci` re-recording goldens in CI.
- **`metrics_check` SKIPPED reason references "FR-010"** rather than the `metrics` piece slug — whoever flips the gate when `metrics` ships will search the wrong term. → one-line, land with the `metrics` piece.
- **`scripts/` is still absent from `charter-architecture`'s plugin-internal layer list** (the manifest-ops change shipped it 2026-06-09; this piece sanctioned `tests/` and the charter-tools line but explicitly left the `scripts/` charter-architecture entry out of scope). → one-line charter amendment.
- **`gate-evals` reuses this harness's fixture infra** (per manifest). Its spec brainstorm should open with an explicit decision: extend `build-fixture.sh` with corpus/`--break` cases vs a parallel builder — reusing the `demo/hello` slug, C-4 commit grammar, and `lib/assert.sh` vocabulary verbatim so eval fixtures audit against the same core. → open question for the `gate-evals` spec.
