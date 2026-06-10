---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: metrics

**PRD Sections:** FR-010, SC-007, G-5, G-6
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** flywheel-repo (merged, spec-flow 5.8.0)

## Goal

Make every spec-flow piece leave behind a small, machine-readable metrics artifact so the exec-ready success criteria (SC-001..SC-006) become computable from disk instead of "measurement pending," and so the flywheel can cite measured trends. Four stages write the numbers they own (spec → Q&A rounds + its QA-gate iterations; plan → its QA-gate iterations; execute → discoveries/escalations/amendments/dispatches/per-phase QA iterations/resume outcomes + the Final Review iterations + must-fix counts), a tested bash helper aggregates them into SC values, and `/spec-flow:status` renders those values per PRD in its default view. The flywheel's already-reserved `metric` occurrence source flips from RESERVED to WIRED. Everything is additive, non-blocking, and degrades gracefully on absent or unwritable artifacts.

## In Scope

- A per-piece metrics artifact at `docs/prds/<prd-slug>/specs/<piece-slug>/metrics.yaml` — block-style YAML, `schema_version` envelope, created lazily on first write, written **incrementally at serial coordinator checkpoints only**.
- A single source-of-truth reference doc `plugins/spec-flow/reference/metrics-artifact.md` defining the schema, per-field stage ownership, write timing, the `[METRICS-DEGRADED]` / `[METRICS-ABSENT]` markers, the helper output contract, and a no-secrets clause. Cited (not restated) by spec/plan/execute/status.
- Writer wiring in **four** stages: `spec/SKILL.md` (its block), `plan/SKILL.md` (its QA-gate iterations), `execute/SKILL.md` (its block + the `final_review` block), and the execute `## Measurement` session-end summary re-pointed to render from the persisted file.
- A tested bash helper `plugins/spec-flow/scripts/metrics-aggregate` (+ `scripts/tests/test-metrics-aggregate.sh`): python3 fast-path / pure-POSIX-bash fallback, reads a PRD's manifest piece order + each piece's `metrics.yaml`, emits stable `SC-NNN key=val` lines + `ABSENT <piece>` lines, exit 0 always.
- `/spec-flow:status` integration: a per-PRD "Success Metrics" block in the **default** view rendering SC-001..SC-006 from the helper, `[METRICS-ABSENT]` for uninstrumented pieces, SCs computed over the instrumented subset only.
- Flywheel wire: flip `source_type: metric` from RESERVED to WIRED in `reference/flywheel.md` — an occurrence may carry `source_type: metric` + a `source:` pointer to `<piece>/metrics.yaml#<field>`, through the **existing** operator-confirm Step 6c path (NN-P-004). No new flywheel mechanism.
- A `metrics: auto|off` config key in `templates/pipeline-config.yaml` (default `auto`).
- Plugin version bump 5.10.0 → 5.11.0 across all four version-bearing files + CHANGELOG entry.

## Out of Scope / Non-Goals

- **No backfill.** The six already-merged exec-ready pieces (and any pre-instrumentation piece) get no retroactive `metrics.yaml`; they render `[METRICS-ABSENT]` and are excluded from SC aggregates (NN-C-003). Reconstructing metrics from transcripts is the manual archaeology SC-007 exists to eliminate. This piece's own `metrics.yaml` is best-effort — its `spec` block cannot be fully captured because the spec-writer ships *in* this piece.
- **No automatic trend-detector.** Wiring the flywheel `metric` source means *enabling* `source_type: metric` + the operator-confirm path. It does **not** add a robot that scans metrics and auto-proposes pattern occurrences. The PRD AC says an occurrence "*may* carry `source: metric`" — a wire, not an agent.
- **No new SC definitions or threshold changes.** SC-001..SC-008 are fixed by the PRD; this piece only makes SC-001..SC-006 computable and renders them. SC-008 (operator-interaction baseline) is gate-scaling's concern.
- **No status output beyond SC rendering.** No new dashboards, no historical charting, no cross-PRD rollup view — one per-PRD Success Metrics block.
- **No instrumentation of the helper's own runtime** (timing, token cost). Counts and outcomes only.
- **No write of the flywheel `originating_repo` field** — that stays RESERVED for flywheel-global (FR-007).

## Requirements

### Functional Requirements

- **SF-1 (schema + reference doc):** `reference/metrics-artifact.md` is the single source of truth for the `metrics.yaml` schema, per-field stage ownership, write timing, markers, helper output contract, and a no-secrets clause. The schema is block-style YAML (one leaf per line; **no inline flow maps**) so it is parseable by both `python3 -c 'yaml.safe_load'` and pure grep/awk. Canonical illustrative form:

  ```yaml
  schema_version: 1
  generated: 2026-06-10
  last_updated: 2026-06-10
  piece: exec-ready/metrics
  spec:
    qa_rounds: 3            # Phase-2 question→answer exchanges
    qa_iterations: 1        # spec QA gate (Phase 4) loops to clean
    research_artifact: true # research.md present for this piece — gates SC-001's "on pieces with a research artifact"
  plan:
    qa_iterations: 2        # plan QA gate (qa-plan) loops to clean
    concreteness_floor: passed   # passed | overridden — qa-plan concreteness floor; gates SC-002's denominator
  execute:
    sonnet_default: true    # coordinator + implementer ran Sonnet-default with no global Opus override — SC-004's second conjunct
    phases:
      total: 6
      clean_sonnet: 5       # completed on Sonnet, no escalation, no unmarked discovery
    discoveries:
      spike_attributed: 1
      unmarked: 0
    spikes:
      planned: 2            # Step 1c [SPIKE] phases
      scope: 1              # Step 6c scoping spikes
    escalations: 0          # operator-halt events
    amendments:
      total: 1
      repeat_scope: 0       # amendments re-targeting an already-amended change
    dispatches:
      opus: 3
      sonnet: 14
    qa_iterations: 4        # sum of per-phase qa-phase gate loops
    resume:
      - at: phase_3
        outcome: clean       # clean | state-incomplete
  final_review:
    iterations: 1
    must_fix: 0
  ```

  `escalations` counts operator-halt events; the reference doc enumerates the triggers: a `[STATE-INCOMPLETE]` resume failure, a spike returning `BLOCKED`, the amendment hard-cap being reached, a non-`[SPIKE]` phase the implementer cannot complete on Sonnet (halt → plan-amend), and a mid-piece Opus QA pass that escalated. `resume[].outcome` is `clean` (reached the correct next action without re-running a passing phase) or `state-incomplete` (hit the `[STATE-INCOMPLETE]` escalation).

- **SF-2 (spec writes its block):** `spec/SKILL.md` records `spec.qa_rounds` (count of Phase-2 question→answer exchanges — one increment per operator reply to a spec question or question-batch), `spec.qa_iterations` (the Phase-4 QA loop iteration count to clean), and `spec.research_artifact` (`true` when a `research.md` exists for the piece at the canonical path, else `false` — this is the field SC-001 gates on, since the PRD scopes SC-001 to "pieces with a research artifact"), writing/updating `metrics.yaml` at Phase 5 Finalize on the piece branch.

- **SF-3 (plan writes its block):** `plan/SKILL.md` records `plan.qa_iterations` (the qa-plan loop iteration count to clean) and `plan.concreteness_floor` (`passed` when qa-plan's concreteness floor passed without circuit-breaker escalation, `overridden` when it reached execute via the 3-iter circuit-breaker human override — this is the field SC-002 restricts its denominator to, since the PRD scopes SC-002 to "pieces whose plan passed the concreteness floor"), writing/updating `metrics.yaml` at plan sign-off on the piece branch.

- **SF-4 (execute writes its block, incrementally at serial checkpoints):** `execute/SKILL.md` writes/updates the `execute` and `final_review` blocks of `metrics.yaml` **only at serial coordinator checkpoints** — per-phase close, Phase-Group barrier, Final Review, Step 5 — and **never from inside a parallel sub-phase / from an implementer agent** (preserves the deferred-commit git-free-section invariant and avoids write races). `resume[]` rows are appended as each journal-resume occurs. The fields and their production sites are: `sonnet_default` (`true` when the model policy ran coordinator + implementer on Sonnet with no global Opus override — SC-004's second conjunct), `phases.{total,clean_sonnet}`, `discoveries.{spike_attributed,unmarked}` (split via the `.discovery-log.md` `(spike: …)` resolution cell), `spikes.{planned,scope}`, `escalations`, `amendments.{total,repeat_scope}` (`repeat_scope` increments when an amendment re-targets an already-amended change), `dispatches.{opus,sonnet}` (tier taken from the sonnet-coord model-policy assignment, not per-call-site bookkeeping), `qa_iterations`, `resume[]`, and `final_review.{iterations,must_fix}`.

- **SF-5 (Measurement summary renders from file):** the execute `## Measurement` session-end summary reads its numbers from the persisted `metrics.yaml` rather than recomputing them in-context, so the file is the single source of truth and the two cannot drift.

- **SF-6 (aggregation helper):** `plugins/spec-flow/scripts/metrics-aggregate <prd-slug>` parses `docs/prds/<prd-slug>/manifest.yaml` (for piece order, needed by the first-half/second-half trend SCs) and each piece's `metrics.yaml`, and emits to stdout stable, greppable lines: one `SC-NNN key=val …` line per computed criterion (each computed to its PRD definition including the SC-001 research-artifact gate, the SC-002 concreteness-floor gate, the SC-004 dual-conjunct, and the SC-003/SC-005 trend split rule — see Technical Approach) and one `ABSENT <prd-slug>/<piece-slug>` line per uninstrumented piece. It tries `python3` (stdlib `yaml`) first and falls back to pure POSIX grep/awk when `python3` is absent; it exits 0 in every case (NN-C-002 fast-path-with-fallback). A `metrics.yaml` that is malformed/unparseable is treated as `[METRICS-DEGRADED]` for that piece (counted as absent for aggregation) with a one-line stderr note — never a crash, never a non-zero exit.

- **SF-7 (status renders SCs):** `/spec-flow:status` invokes the helper in its **default** per-PRD view and renders a "Success Metrics" block showing SC-001..SC-006 computed over the instrumented subset, with `[METRICS-ABSENT]` shown passively for uninstrumented pieces. No flag is required (SC-007: "a single `/spec-flow:status` invocation renders them per PRD"). If the helper is unavailable or every piece is absent, the block renders `[METRICS-ABSENT]` and the rest of status is unaffected (NN-C-005 passive-surface discipline).

- **SF-8 (flywheel `metric` wire):** `reference/flywheel.md` flips `source_type: metric` from RESERVED to WIRED — its `## Source taxonomy` row and the occurrence-schema comment are updated. An occurrence may carry `source_type: metric` with a `source:` pointer of the form `<prd-slug>/<piece-slug>/metrics.yaml#<field-path>`. The occurrence is written only through the **existing** Step 6c match/confirm flow (operator-confirmed, no silent write — NN-P-004); no new flywheel code path, no auto-emitter.

- **SF-9 (config key):** `templates/pipeline-config.yaml` gains a `metrics: auto|off` key (default `auto`) with a CR-007 comment block (valid values / default / "new in v5.10.0" / rationale). `auto` ⇒ stages write `metrics.yaml`; `off` ⇒ stages skip the metrics write entirely (behaviorally identical to a pre-instrumentation piece — renders `[METRICS-ABSENT]`). Absent key ⇒ `auto` (NN-C-003). Each writer stage reads it at its Step 0 config load.

- **SF-10 (markers, non-blocking):** `[METRICS-DEGRADED: <reason>]` is emitted by a writer stage when `metrics.yaml` is unwritable/unparseable; the stage continues — instrumentation never blocks pipeline progress. `[METRICS-ABSENT]` is emitted by status/helper rendering for a piece with no (or `off`) metrics artifact. Both are single-line bracketed informational markers matching the repo convention (`[FLYWHEEL-DEGRADED]`, `[RESEARCH-UNAVAILABLE]`, `[TEST-DATA-ABSENT]`, `[STATE-INCOMPLETE]`).

- **SF-11 (versioning + hygiene):** the change bumps the plugin 5.10.0 → 5.11.0 in all four version-bearing files (`plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` spec-flow entry, `plugins/spec-flow/CHANGELOG.md`) per `plugins/spec-flow/docs/releasing.md`; the reference doc carries a no-secrets clause; the helper ships with its bash test.

### Non-Functional Requirements

- **NFR-M1 (additive / backward-compatible — NN-C-003):** every change is additive. Pieces without `metrics.yaml` run unchanged and render `[METRICS-ABSENT]`. The new config key defaults to current behavior. The flywheel `metric` value was already a representable enum member; flipping it to WIRED restructures nothing.
- **NFR-M2 (non-blocking):** no metrics path can fail a stage or block merge. Unwritable/unparseable artifact ⇒ `[METRICS-DEGRADED]` + continue. Helper exits 0 always.
- **NFR-M3 (no runtime dependency — NN-C-002):** the helper is POSIX bash with an optional `python3` fast path and a pure-bash fallback; it requires nothing beyond Claude Code, git, and a POSIX shell.
- **NFR-M4 (single source of truth — CR-008):** the schema/contract lives only in `reference/metrics-artifact.md`; skills and the helper cite it, never restate it.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-002 (markdown + config only, no runtime deps): the aggregation helper is POSIX bash with a `python3` *optional fast path* and a pure-bash fallback that exits 0 when `python3` is absent — the explicitly-allowed exception.
- NN-C-003 (backward compat within a major): all additions are additive; absent/`off` metrics render `[METRICS-ABSENT]` and never break status; the new config key defaults to current behavior.
- NN-C-005 (hooks/optional inputs no-op silently): status treats a missing helper or absent metrics as a passive surface — informs, never blocks or errors.
- NN-C-008 (agents self-contained): no new agent is added; the helper takes its inputs as argv + on-disk files, not conversation history.
- NN-C-009 + NN-C-001 (version bump + marketplace sync): the change bumps all four version-bearing files in lockstep to 5.11.0 with a CHANGELOG entry.
- NN-C-007 (CHANGELOG present, Keep a Changelog format): the 5.11.0 CHANGELOG entry uses a `## [5.11.0] — YYYY-MM-DD` heading with an `Added` grouping (new metrics artifact + helper + config key).

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-001 (human gate never removed): metrics only *measure*; no gate is removed or auto-advanced.
- NN-P-004 (flywheel writes operator-gated): the `metric` source flows through the existing Step 6c match/confirm flow — LLM-proposed, human-confirmed, no silent write.

### Coding Rules Honored

- CR-006 (CHANGELOG format — Keep a Changelog): the 5.11.0 entry follows the Added/Changed groupings and `## [X.Y.Z] — YYYY-MM-DD` heading convention.
- CR-007 (config keys documented inline): the `metrics:` key ships with a leading comment block (values / default / version / rationale).
- CR-008 (thin orchestrator / narrow executor): status stays thin — it shells out to the helper and renders; the schema contract lives in one reference doc; no skill restates it.
- CR-009 (heading hierarchy load-bearing): edits to execute/status/spec/plan SKILLs preserve existing `### Phase N:` / `#### ` anchors; new sections respect the H2/H3/H4 hierarchy.
- CR-001 / CR-002 (frontmatter schemas): no new agent; any SKILL edits preserve valid frontmatter.

## Acceptance Criteria

AC-1: Given a piece executed after this ships with `metrics: auto`, When the piece reaches Step 5, Then `docs/prds/<prd>/specs/<piece>/metrics.yaml` exists, parses as block-style YAML with a `schema_version` envelope, contains the `spec`, `plan`, `execute`, and `final_review` blocks, and carries the three SC-gating fields `spec.research_artifact`, `plan.concreteness_floor`, and `execute.sonnet_default`.
  Independent Test: `python3 -c "import yaml,sys; d=yaml.safe_load(open(sys.argv[1])); assert all(k in d for k in ('schema_version','spec','plan','execute','final_review')); assert 'research_artifact' in d['spec'] and 'concreteness_floor' in d['plan'] and 'sonnet_default' in d['execute']" <path>` exits 0; and `grep -E '^\s+\{' <path>` returns nothing (no inline flow maps — fallback-parseable).

AC-2: Given the `metrics-artifact.md` reference doc, When inspected, Then it defines the schema, per-field stage ownership, write-timing rule (serial checkpoints only), both markers, the helper output contract, and a no-secrets clause, and is the only file that does so.
  Independent Test: `grep -lRE 'schema_version|qa_rounds|clean_sonnet' plugins/spec-flow/ | grep -v 'reference/metrics-artifact.md' | grep -vE 'specs/.*/metrics.yaml|CHANGELOG'` returns no skill/agent file restating the schema (skills cite the reference doc by path).

AC-3: Given the spec skill completes a piece, When Phase 5 runs, Then `metrics.yaml` `spec.qa_rounds` equals the count of distinct operator-answer turns in Phase 2 under the SF-2 counting rule (one round per operator reply to a spec question or question-batch — an AskUserQuestion card answered in one turn is one round, regardless of how many sub-questions it carried), `spec.qa_iterations` equals the number of qa-spec dispatches in Phase 4 until clean, and `spec.research_artifact` is `true` iff `research.md` exists at the canonical path.
  Independent Test: machine-checkable part — `spec.qa_rounds` and `spec.qa_iterations` are non-negative integers and `spec.research_artifact` matches `test -f docs/prds/<prd>/specs/<piece>/research.md`. Judgment-required part — the `qa_rounds` integer equals the Phase-2 answer-turn count per the SF-2 rule when checked against the session record.

AC-4: Given the plan skill signs off a piece, When complete, Then `metrics.yaml` `plan.qa_iterations` equals the qa-plan loop count to clean.
  Independent Test: `grep -A1 '^plan:' <path> | grep -E 'qa_iterations: [0-9]+'`.

AC-5: Given execute runs, When it crosses each serial checkpoint, Then the `execute` block is written/updated only at per-phase close / group barrier / Final Review / Step 5 — and no metrics write occurs from inside a parallel sub-phase or an implementer agent.
  Independent Test: `grep -n 'metrics.yaml' plugins/spec-flow/skills/execute/SKILL.md` shows writes only under serial-checkpoint sections; the parallel-section prose contains no metrics write and explicitly states the deferral.

AC-6: Given a piece that ran a `[SPIKE]` phase and a scope spike, When metrics are aggregated, Then `execute.discoveries.spike_attributed` / `unmarked` split matches the `.discovery-log.md` `(spike: …)` cells and `execute.spikes.{planned,scope}` are counted.
  Independent Test: cross-check `metrics.yaml` spike/discovery counts against the piece's `.discovery-log.md` rows.

AC-7: Given execute resumes from the journal in a fresh context, When the resume completes, Then exactly one `resume:` row is appended with `outcome: clean` (reached the correct next action, no passing-phase re-run) or `outcome: state-incomplete` (hit `[STATE-INCOMPLETE]`).
  Independent Test: two deterministic forcing fixtures establish ground truth. (a) Clean fixture — resume from a complete, valid journal at a known phase boundary; the resume must append one row with `outcome: clean`. (b) State-incomplete fixture — remove one resume-critical journal field (per the sonnet-coord resume-critical field list) before resuming; the resume must emit `[STATE-INCOMPLETE]` and append one row with `outcome: state-incomplete`. Each fixture's expected outcome is fixed by construction, so the assertion is decidable; the row count increments by exactly one per resume.

AC-8: Given the execute `## Measurement` summary, When it renders at session end, Then its numbers are read from `metrics.yaml` (not recomputed in-context).
  Independent Test: the execute `## Measurement` prose references reading `metrics.yaml`; no second independent computation of the same numbers remains.

AC-9: Given a PRD with a mix of instrumented and uninstrumented pieces, When `scripts/metrics-aggregate <prd-slug>` runs, Then it emits one `SC-NNN key=val` line per SC-001..SC-006 and one `ABSENT <prd>/<piece>` line per uninstrumented piece, and exits 0.
  Independent Test: `scripts/tests/test-metrics-aggregate.sh` runs the helper over fixture PRDs and asserts the emitted lines; CI/manual invocation exits 0.

AC-10: Given `python3` is absent, When the helper runs, Then it falls back to pure POSIX grep/awk, still emits the SC lines, and exits 0.
  Independent Test: `scripts/tests/test-metrics-aggregate.sh` includes a `PATH`-stubbed-no-python3 case asserting identical SC output and exit 0.

AC-11: Given a malformed `metrics.yaml` for one piece, When the helper runs, Then that piece is treated as absent (one-line stderr note), the other pieces still aggregate, and the helper exits 0.
  Independent Test: fixture with one malformed file; helper exits 0, emits `ABSENT` for it, computes SCs over the rest.

AC-12: Given `/spec-flow:status` is invoked with no flags, When a PRD has instrumented pieces, Then a "Success Metrics" block renders SC-001..SC-006 over the instrumented subset with `[METRICS-ABSENT]` shown for uninstrumented pieces.
  Independent Test (judgment-required): run status on a PRD with ≥1 instrumented + ≥1 absent piece; the block appears in the default view with correct subset computation.

AC-13: Given the helper computes first-half/second-half trend SCs (SC-003, SC-005), When `N` instrumented pieces are ordered by `manifest.yaml` `pieces[]` order, Then `first_half = pieces[0 : floor(N/2)]`, `second_half = pieces[N − floor(N/2) : N]`, the middle piece is excluded from both halves when `N` is odd, and the helper emits `trend=insufficient-data` (not a comparison) when `N < 2`.
  Independent Test: three fixture manifests — (a) even `N` (e.g. 4) → halves of 2 each; (b) odd `N` (e.g. 5) → halves of 2 each, middle piece in neither sum; (c) `N = 1` → `SC-003 trend=insufficient-data` and `SC-005 trend=insufficient-data`. Assert the emitted half-sums and the insufficient-data line match the fixture.

AC-19: Given a PRD containing pieces both with and without a research artifact (SC-001) and both `passed`- and `overridden`-floor (SC-002), When the helper runs, Then SC-001 is computed only over `spec.research_artifact == true` pieces and SC-002 only over `plan.concreteness_floor == passed` pieces; excluded pieces are not counted as failures.
  Independent Test: fixture PRD mixing the gating-field values; assert the SC-001/SC-002 populations (denominators) in the emitted lines exclude the non-qualifying pieces.

AC-20: Given SC-004's two conjuncts, When the helper runs, Then SC-004 passes only when the resume-clean rate is 100% AND every instrumented piece has `execute.sonnet_default == true`, and fails if either conjunct fails.
  Independent Test: two fixtures — one with a non-Sonnet-default piece (SC-004 fails on conjunct b despite 100% resume), one with a `state-incomplete` resume row (SC-004 fails on conjunct a despite all-Sonnet-default); assert SC-004 fails in both.

AC-14: Given `reference/flywheel.md`, When inspected, Then `source_type: metric` is documented as WIRED (not RESERVED) with the `metrics.yaml#<field>` pointer form, and the occurrence is written only via the existing operator-confirm Step 6c flow.
  Independent Test: `grep -n 'metric' plugins/spec-flow/reference/flywheel.md` shows the taxonomy row marked WIRED; `grep -n 'RESERVED' …` no longer applies to `metric`; the wire prose names the operator-confirm gate.

AC-15: Given `metrics: off` in `.spec-flow.yaml`, When any writer stage runs, Then no `metrics.yaml` is written and the piece renders `[METRICS-ABSENT]` — behaviorally identical to a pre-instrumentation piece.
  Independent Test: set `metrics: off`; run a stage; assert no `metrics.yaml` created and status shows `[METRICS-ABSENT]`.

AC-16: Given an unwritable metrics path, When a writer stage attempts to write, Then it emits `[METRICS-DEGRADED: <reason>]` and continues to completion without failing the stage or blocking merge.
  Independent Test (judgment-required): simulate an unwritable path; the stage emits the marker and completes.

AC-17: Given the change ships, When the diff is inspected, Then all four version-bearing files read 5.11.0, the CHANGELOG has a `## [5.11.0] — <date>` section with at least one Added bullet, and the `metrics:` config key has its CR-007 comment block.
  Independent Test: `for f in plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json; do grep '"version": "5.11.0"' $f; done`; `grep '"version": "5.11.0"' .claude-plugin/marketplace.json`; `grep '## \[5.11.0\]' plugins/spec-flow/CHANGELOG.md`; `grep -B3 '^metrics:' plugins/spec-flow/templates/pipeline-config.yaml | grep '#'`.

AC-18: Given any `metrics.yaml` write path or the helper, When inspected, Then no credential/token/secret is transcribed — only counts, slugs, dates, and outcomes are recorded.
  Independent Test: the reference doc carries the no-secrets clause; the schema fields are all numeric/enum/slug; no field captures verbatim finding prose.

## Technical Approach

**Persistence model.** One block-style `metrics.yaml` per piece, created lazily on first write by whichever stage runs first (spec). Each stage owns a top-level block (`spec`, `plan`, `execute`, `final_review`) and updates only its own keys, so the four writers never contend for the same key. Block-style (no inline flow maps) is the load-bearing constraint that lets the same file be read by `yaml.safe_load` *and* by a pure-bash grep/awk fallback — it is the reconciliation of the "nested blocks" schema choice with the "bash helper" reader choice.

**Write timing & concurrency.** Execute writes only at serial coordinator checkpoints, never inside the deferred-commit git-free parallel section — this both preserves that invariant and removes any write race (only the serial coordinator touches the file). `resume[]` is append-only, written by the resume path itself. Because every resume-critical number is derivable from disk artifacts the coordinator already maintains (`.discovery-log.md`, journal, ac-matrix, amendment counters), a fresh context reconstructs the `execute` block from those sources if `metrics.yaml` is partial — consistent with the sonnet-coord disk-derivable-state discipline.

**Aggregation.** The helper is the deterministic evaluator (the point of choosing bash over LLM-inline: SC numbers must be reproducible). It reads the manifest for piece order, then each piece's `metrics.yaml`. Each SC is computed to its **PRD definition**, including the PRD's scoping qualifiers:

- **SC-001** — over instrumented pieces where `spec.research_artifact == true` only (the PRD scopes SC-001 to "pieces with a research artifact"): each such piece passes when `spec.qa_rounds ≤ 3`. Pieces without a research artifact are excluded from the SC-001 population, not counted as failures.
- **SC-002** — over instrumented pieces where `plan.concreteness_floor == passed` only (the PRD scopes SC-002 to "pieces whose plan passed the concreteness floor"): `Σ phases.clean_sonnet / Σ phases.total ≥ 0.80`. `overridden`-floor pieces are excluded from the population.
- **SC-003** — `Σ execute.discoveries.unmarked`, first-half vs second-half by manifest order (split rule below); passes when second-half sum < first-half sum.
- **SC-004** — both conjuncts: (a) `Σ clean resume / Σ resume == 1.0` (100%), AND (b) every instrumented piece has `execute.sonnet_default == true`. The SC fails if either conjunct fails.
- **SC-005** — `Σ execute.spikes.(planned + scope)`, first-half vs second-half by manifest order; passes when second-half sum < first-half sum.
- **SC-006** — `Σ execute.amendments.repeat_scope == 0` across instrumented pieces.
- **SC-007** — the meta-capability; satisfied by the helper + status rendering existing.

**Trend split rule (SC-003, SC-005).** Let `N` = the count of instrumented pieces (those with a parseable `metrics.yaml`), ordered by `manifest.yaml` `pieces[]` order. `first_half = pieces[0 : floor(N/2)]`; `second_half = pieces[N − floor(N/2) : N]`. When `N` is odd the single middle piece is excluded from **both** halves (deterministic, no boundary ambiguity). When `floor(N/2) < 1` (i.e. `N < 2`), the trend is not computed — the helper emits `trend=insufficient-data` for that SC rather than a comparison (no divide-by-zero, no false pass/fail).

**Flywheel wire.** Minimal: flip the taxonomy row, update the occurrence-schema comment, and let the existing Step 6c match/confirm prose carry `source_type: metric` + a pointer. No code, no auto-detection — an operator who sees a measured trend during triage may cite it; the gate is unchanged.

**Marker + degraded discipline.** Mirrors `flywheel.md`'s degraded path exactly: unwritable/unparseable ⇒ single bracketed line, no write, no block.

## Testing Strategy

- **Executable test (the only one possible in a markdown/config plugin):** `scripts/tests/test-metrics-aggregate.sh`, following the `scripts/tests/test-manifest-query.sh` precedent (the sibling bash+python3 dual-path tool merged in 5.9.0). Fixtures: (a) a PRD with instrumented + absent pieces → assert all six SC lines + `ABSENT` lines; (b) awk-fallback path (`METRICS_AGG_NO_PY=1`, the manifest-query NO_PY convention) → byte-identical SC output to the python path, exit 0; (c) one malformed `metrics.yaml` → that piece absent, others aggregate, exit 0; (d) known manifest order → SC-003/SC-005 first-half/second-half correctness; (e) empty/all-absent PRD → `[METRICS-ABSENT]`, exit 0.
- **Inspection/grep ACs** for the prose-level wiring (writer sites, marker definitions, flywheel taxonomy flip, version bump, config comment) — the AC Independent Tests above are the verification.
- **Judgment-required ACs** (AC-3, AC-7, AC-12, AC-16) for behaviors that need a live run to confirm (round counting against a transcript, resume-outcome recording, default-view rendering, degraded-path continuation).
- Edge cases: malformed YAML; `python3` absent; `metrics: off`; unwritable path; all-absent PRD; a PRD with a single instrumented piece (trend SCs degrade to "insufficient data," not a divide-by-zero).

## Integration Coverage

- Integration: writer-stages (spec/plan/execute) → `metrics.yaml` → `metrics-aggregate` helper → status. Inside: the four writer stages and the helper (all internal pipeline components, markdown/bash). Doubled externals: none — there is no external service; the cross-component contract is the `metrics.yaml` *schema*, contract-tested by `scripts/tests/test-metrics-aggregate.sh` driving the helper against fixture artifacts (AC-9..AC-13, AC-11). The writer→file seam is verified by inspection ACs (AC-1, AC-3..AC-8). Completes across the execute phases that wire the helper + status (the e2e seam is the helper test).
- Integration: execute Step 6c → `reference/flywheel.md` `metric` source. Inside: execute's existing Step 6c hook. Doubled externals: none; the wire is documentation + the existing operator-confirm flow. AC-14; no new code path.

## Open Questions

- (none — all brainstorm decisions resolved: schema=nested block-style YAML; round=question→answer exchange; ephemeral summary persists/renders-from-file; SC compute=bash helper with python3 fast path; writers=spec/plan/execute/Final Review; status=default view; backfill=forward-only; config key=`metrics: auto|off`; flywheel wire=enable source_type only, no auto-detector.)
