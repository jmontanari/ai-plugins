---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
legacy_deferred_rows: false
tdd: false
fast: false
---

# Plan: metrics

**Spec:** docs/prds/exec-ready/specs/metrics/spec.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** draft

## Overview

Non-TDD mode (all phases Implement + Write-Tests; the AC Coverage Matrix is still generated for traceability). Nine phases, inside-out / cite-before-use ordering. The load-bearing design choice: **the schema, the write procedure, the field semantics, the markers, and the SC computation rules are all defined once in a new `reference/metrics-artifact.md` (Phase 1)**; every writer (Phases 5–7) and the reader (Phases 3, 8) cite it rather than restate it (CR-008 / NN-C-008). This keeps the four writer edits to one-line citations and confines all logic drift to a single greppable file.

Phase order: (1) reference doc = schema SoT → (2) config key → (3) the one behavior-bearing component, the `metrics-aggregate` bash helper + its test → (4) flywheel `metric` wire → (5) spec writer → (6) plan writer → (7) execute writer + `## Measurement` re-point → (8) status renderer + the cross-phase schema-consistency check → (9) version bump + CHANGELOG.

Three fields have **no existing producer** and are defined for the first time by this plan (see ADR-5): `spec.qa_rounds` (Phase 2 spec brainstorm is an explicitly uncounted loop), `plan.concreteness_floor` (no `passed|overridden` signal exists), and `execute.amendments.repeat_scope` (derived from the `.discovery-log.md` spike-attribution cell). Two linter invariants that might appear relevant are confirmed non-issues (see ADR-4 consequences): config-branch parity (`metrics` is a 2-value key, not in the hardcoded `MANAGED_KEYS`) and state-field producer→consumer (the specced field names don't end in the tracked `_sha|_hashes|_manifest|_state` suffixes).

**Cross-cutting charter constraints (qa-plan criterion 8 flag).** Three honored entries are genuinely cross-cutting across the SKILL-editing phases rather than owned by one, and are flagged here as honored-by-all-via-mechanism (cited once in a primary phase below with "cross-cutting — see Overview"): **NN-P-001** (no phase removes or alters a spec / plan / Final-Review sign-off gate — every metrics write is appended *after* the existing approval; honored by Phases 5, 6, 7); **CR-009** (every `SKILL.md` edit preserves the load-bearing `### Step` / `#### ` heading anchors and the `## Measurement` heading level; honored by Phases 5, 6, 7, 8); **CR-001 / CR-002** (no new agent is added and each edited `SKILL.md`'s frontmatter is preserved; honored by Phases 5, 6, 7, 8). The remaining entries have single owners and are cited once: NN-C-002 → Phase 3; NN-C-003 → Phase 8; NN-C-005 → Phase 8; NN-C-007 → Phase 9; NN-C-008 → Phase 3; NN-C-009 + NN-C-001 → Phase 9; NN-P-004 → Phase 4; CR-006 → Phase 9; CR-007 → Phase 2; CR-008 → Phase 1.

## Architectural Decisions

### ADR-1: Block-style YAML, no inline flow maps
**Context:** The schema is nested (per-stage blocks) but the chosen reader is a bash helper that must parse without a runtime YAML dependency (NN-C-002 forbids `yq`).
**Decision:** `metrics.yaml` is strictly block-style — every leaf on its own indented line, no inline flow maps (`{a: 1}`). This makes the same file parseable by both `python3 -c 'yaml.safe_load'` (fast path) and pure `grep`/`awk` (fallback).
**Alternatives considered:** (a) inline flow maps — compact but the bash fallback can't reliably parse them; (b) flat dotted keys (`execute.amendments.total: 1`) — greppable but loses the clean per-writer block ownership and is non-idiomatic vs `patterns.yaml`.
**Consequences:** Writers must emit block style; an AC (AC-1) asserts `grep -E '^\s+\{'` returns nothing. Slightly more verbose file.
**Charter alignment:** NN-C-002 (no runtime dep), NN-C-008 (helper self-contained).

### ADR-2: The SC aggregator is a deterministic bash helper, not LLM-inline
**Context:** SC-001..SC-006 must be reproducible — the whole point of the piece is trustworthy measurement.
**Decision:** A `scripts/metrics-aggregate` tool computes the SCs deterministically and `/spec-flow:status` shells out to it; status does not compute SCs itself. **It follows the `scripts/manifest-query` precedent merged in 5.9.0 (`c318f82`)** — the established house pattern for a status-invoked, zero-install dual-path tool: a two-file split (`scripts/metrics-aggregate` bash wrapper that `exec`s into `scripts/metrics-aggregate.py` when `python3` is present, else runs a complete awk/bash fallback in the wrapper), an `*_NO_PY=1` env var to force the fallback for testing, and a `scripts/tests/` harness. Both tools live in `scripts/` and are called by `status`.
**Alternatives considered:** (a) the status orchestrator (an LLM) reads metrics.yaml and computes inline — non-reproducible, and a measurement piece cannot have a stochastic measurer; (b) precompute SCs at each piece's write time — a single piece can't compute cross-PRD trend SCs (SC-003/005); (c) a single-file bash helper with an inline python3 heredoc (the pre-merge draft) — rejected post-merge for consistency with the sibling `manifest-query` two-file pattern that `status` already invokes.
**Consequences:** Adds two scripts (`metrics-aggregate` + `metrics-aggregate.py`) + one `scripts/tests/` harness (the only executable test in the piece). The python and awk paths must be output-identical (the manifest-query test enforces this with `MANIFEST_QUERY_NO_PY`; metrics mirrors it with `METRICS_AGG_NO_PY`). status stays thin (CR-008).
**Charter alignment:** NN-C-002 (python3 fast path with mandatory bash fallback — the same owner-accepted exception `manifest-query` carries), CR-008, G-6 (measured pipeline).

### ADR-3: Define the write procedure + field semantics once in the reference doc
**Context:** Four stages write `metrics.yaml`; restating the upsert mechanic and field definitions in each would be four drift sites.
**Decision:** `reference/metrics-artifact.md` owns the schema, the `## Write procedure` (create-if-absent, idempotent per-field upsert, serial-checkpoint-only, `metrics: off` skip, `[METRICS-DEGRADED]` on failure), the field semantics, the marker definitions, the helper output contract, the SC computation rules, and a no-secrets clause. Writers cite it by section.
**Alternatives considered:** inline the procedure in each writer — violates CR-008 and creates the exact multi-site drift this PRD's flywheel exists to detect.
**Consequences:** Phase 1 must land first (cite-before-use). Each writer edit becomes a one-line citation.
**Charter alignment:** CR-008 (thin orchestrator, single SoT), NN-C-008 (no restatement).

### ADR-4: metrics.yaml is written only at serial coordinator checkpoints
**Context:** execute's deferred-commit model has a concurrent git-free section (Step G4) where sub-phases stage nothing and run in parallel. A metrics write there would race and/or be lost.
**Decision:** All `metrics.yaml` writes land at serial checkpoints only — Step 7 per-phase progress commit, the Step 6c `.discovery-log.md` commit, the group barrier commit (Step G8), Final Review pending-marker commit, and the Step 5 learnings commit (the latest point by which the execute + final_review blocks must be complete). `resume[]` rows append at the next serial checkpoint after the resume event.
**Alternatives considered:** write at every event including inside G4 — maximal fidelity but races on a file no sub-phase owns; write once at Step 5 — loses resume "as they occur" fidelity and any mid-piece crash data.
**Consequences:** The execute phase prose must explicitly state the serial-checkpoint constraint and name G4 as off-limits. Confirmed non-issues: the two `lint-skill-coherence` invariants (config-branch parity for a 2-value key not in `MANAGED_KEYS`; state-field producer→consumer for names not ending in the tracked suffixes) do not fire on this piece's additions.
**Charter alignment:** NN-C-003 (additive), preserves the deferred-commit invariant.

### ADR-5: Three previously-unproduced fields are defined here
**Context:** `spec.qa_rounds`, `plan.concreteness_floor`, and `execute.amendments.repeat_scope` have no producer in the current pipeline.
**Decision:** Define each in `reference/metrics-artifact.md` `## Field semantics`: `qa_rounds` = count of operator-answer turns in spec Phase 2 (one AskUserQuestion card answered in one turn = one round); `concreteness_floor` = `passed` when the qa-plan gate reached clean without circuit-breaker escalation, else `overridden`; `repeat_scope` = count of `.discovery-log.md` amend rows whose finding re-targets a scope already amended in this piece.
**Alternatives considered:** leave them implicit — makes SC-001/002/006 uncomputable (the exact gap qa-spec caught at spec stage).
**Consequences:** Phases 5/6/7 each implement one new counter per ADR-5's definitions.
**Charter alignment:** NN-C-003, G-6.

### ADR-6: Forward-only instrumentation; pre-instrumentation pieces render [METRICS-ABSENT]
**Context:** Six merged exec-ready pieces have no metrics.yaml; this spec session predates the spec-writer change.
**Decision:** No backfill. The helper + status treat a piece with no (or `off`) metrics.yaml as `[METRICS-ABSENT]` and compute SCs over the instrumented subset only.
**Alternatives considered:** reconstruct metrics from transcripts — the manual archaeology SC-007 exists to eliminate, and lower fidelity.
**Consequences:** Trend SCs may be `insufficient-data` until ≥2 instrumented pieces exist.
**Charter alignment:** NN-C-003, NN-C-005 (passive surface).

## Integration-Test Registry (M1)

| ID | Path | Boundary (inside) | Doubled externals (contract test) | AC | registered_in_phase | completes_in_phase | skeleton_sha256 | completed_sha256 |
|----|------|-------------------|-----------------------------------|----|--------------------|---------------------|-----------------|------------------|
| INT-1 | plugins/spec-flow/scripts/tests/test-metrics-aggregate.sh | metrics.yaml schema ↔ metrics-aggregate helper (the cross-component contract) | none (no true external; all components are in-repo markdown/bash) | AC-9, AC-10, AC-11, AC-13, AC-19, AC-20 | 3 | 3 | — | — |

> **Seam-coverage honesty (read by the integration reviewer):** there is no true external to double. The writer→helper→status path is verified in two halves, not one live end-to-end run: (1) the **schema↔helper** half by INT-1's fixture-driven test (Phase 3, real wired path: real helper over real fixture `metrics.yaml` files); (2) the **writer→schema** half by inspection ACs (writers emit per the reference doc) plus the cross-phase schema-consistency grep in Phase 8. A genuine end-to-end run (a real piece producing metrics.yaml that the live helper then reads) is owned by FR-013's pipeline e2e harness (a separate piece, explicitly out of scope here per the spec).

## Phases

### Phase 1: Reference doc — the metrics.yaml schema SoT
**Exit Gate:** `reference/metrics-artifact.md` exists and defines (a) the block-style schema with all blocks/fields, (b) `## Write procedure`, (c) `## Field semantics` for the three defined fields, (d) `## Markers` ([METRICS-DEGRADED]/[METRICS-ABSENT]), (e) `## Helper output contract`, (f) `## SC computation` incl. the trend split rule, (g) a `## No secrets` clause.
**ACs Covered:** AC-2, AC-18, AC-15, AC-16
**In scope:** CREATE `plugins/spec-flow/reference/metrics-artifact.md` only.
**NOT in scope:** the config key (Phase 2); the helper (Phase 3); any skill wiring (Phases 5–8); the flywheel edit (Phase 4). This phase writes only the contract those phases cite.
**Charter constraints honored in this phase:**
- CR-008 (single source of truth): this doc is the only file that defines the schema/procedure/SC rules; all other phases cite it.

- [x] **[Implement]** Author the reference doc
  - Architecture constraints this phase must honor: model the doc's structure (degraded-path framing, "definitions live here and nowhere else", no-secrets clause) on `reference/flywheel.md`. All paths repo-root-relative (CR-005). Heading hierarchy: one H1, H2 sections, H3 sub-blocks (CR-009).

  **Change Specifications:**

  **T-1: CREATE plugins/spec-flow/reference/metrics-artifact.md**
  - Structure outline (H2 sections, in order):
    1. Intro line: "Single source of truth for the per-piece metrics artifact (FR-010) — the `metrics.yaml` schema, write procedure, field semantics, markers, helper output contract, and SC computation. Cited by `skills/spec`, `skills/plan`, `skills/execute`, `skills/status`, and `scripts/metrics-aggregate`. Definitions live here and nowhere else."
    2. `## Location` — `docs/prds/<prd-slug>/specs/<piece-slug>/metrics.yaml`; created lazily on first write by whichever stage runs first (spec).
    3. `## Schema` — the canonical block-style illustrative form (copy from spec.md SF-1 verbatim, including the three gating fields `spec.research_artifact`, `plan.concreteness_floor`, `execute.sonnet_default`). State the **block-style / no-inline-flow-maps** invariant (ADR-1) explicitly.
    4. `## Field semantics` — one bullet per field. The three DEFINED fields carry their full derivation (ADR-5): `spec.qa_rounds` = count of operator-answer turns in spec Phase 2 (one AskUserQuestion card answered in one turn = one round, regardless of sub-question count); `plan.concreteness_floor` = `passed` when the qa-plan gate reached clean with no circuit-breaker escalation, else `overridden`; `execute.amendments.repeat_scope` = count of `.discovery-log.md` amend rows whose finding text re-targets a scope already amended in this piece. Also define `escalations` triggers (the five from spec SF-1), `discoveries.{spike_attributed,unmarked}` (derived by grepping the `.discovery-log.md` Resolution-commit cell for `(spike: spikes/<id>.md)`; unmarked = total amend/discovery rows − spike_attributed), `spikes.{planned,scope}`, `dispatches.{opus,sonnet}` (tier from the sonnet-coord model policy), `resume[].outcome` (`clean|state-incomplete`).
    5. `## Write procedure` — the upsert mechanic cited by all writers: (i) read `.spec-flow.yaml` `metrics:` (default `auto`); if `off`, skip all writes (the piece renders [METRICS-ABSENT]); (ii) create the file with the `schema_version: 1` / `generated` / `last_updated` / `piece` envelope on first write; (iii) upsert only the calling stage's own block/fields, preserving other blocks, refreshing `last_updated`; (iv) **serial-checkpoint-only** (ADR-4) — name the safe execute checkpoints and explicitly forbid writes inside the Step G4 concurrent git-free section; (v) on an unwritable/unparseable path, emit `[METRICS-DEGRADED: <reason>]` and continue (never block).
    6. `## Markers` — `[METRICS-DEGRADED: <reason>]` (emitted by a writer stage on write failure; non-blocking) and `[METRICS-ABSENT]` (emitted by status/helper rendering for a piece with no/`off` artifact). Single-line bracketed informational markers, matching `[FLYWHEEL-DEGRADED]` convention.
    7. `## Helper output contract` — the stable stdout line grammar emitted by `scripts/metrics-aggregate <prd-slug>`: one `SC-NNN key=val …` line per SC-001..SC-006 and one `ABSENT <prd-slug>/<piece-slug>` line per uninstrumented piece; exit 0 always. Specify the exact keys per SC line (the grammar in C-2 of `## Contracts`).
    8. `## SC computation` — the per-SC rules from spec.md Technical Approach verbatim: SC-001 over `research_artifact==true` only; SC-002 over `concreteness_floor==passed` only; SC-003/005 first-half/second-half by manifest order with the trend split rule (`first_half = pieces[0:floor(N/2)]`, `second_half = pieces[N−floor(N/2):N]`, middle excluded when N odd, `N<2` ⇒ `trend=insufficient-data`); SC-004 dual conjunct (resume 100% AND every piece `sonnet_default==true`); SC-006 `Σ repeat_scope == 0`; SC-007 = the helper+status capability itself.
    9. `## No secrets` — never transcribe credentials/tokens/secrets into metrics.yaml; the schema records only counts, slugs, dates, and enum outcomes (mirror the flywheel.md clause).
  - Pattern (degraded-path idiom, from reference/flywheel.md `## Degraded path` L122-126):
    ```
    When `docs/patterns.yaml` is **unwritable** OR **unparseable**:
    1. The flywheel emits a single bracketed orchestrator line: `[FLYWHEEL-DEGRADED: repo registry unavailable]`
    2. **No** registry write occurs.
    3. Execute is **not** blocked or failed — the piece continues normally.
    ```
  - Done: all nine H2 sections present; the schema block is block-style (no inline flow maps); the three defined fields carry their derivations; the no-secrets clause present.
  - Verify: `grep -E '^## (Location|Schema|Field semantics|Write procedure|Markers|Helper output contract|SC computation|No secrets)' plugins/spec-flow/reference/metrics-artifact.md` returns 8 section headers; `grep -c 'METRICS-DEGRADED\|METRICS-ABSENT' …` ≥ 2.

- [x] **[Write-Tests]** N/A — pure documentation phase, no executable behavior.
  - This phase creates a reference doc; there is no code to test. Verification is the grep inspection in [Verify]. (Non-TDD mode permits a phase whose verification is inspection-only when the deliverable is documentation.)

- [x] **[Verify]** Confirm the reference doc is complete and well-formed
  - Run: `grep -E '^## (Location|Schema|Field semantics|Write procedure|Markers|Helper output contract|SC computation|No secrets)' plugins/spec-flow/reference/metrics-artifact.md | wc -l` — Expected: `8`
  - Run: LLM-agent-step: read `plugins/spec-flow/reference/metrics-artifact.md` and confirm (a) the schema block contains `research_artifact`, `concreteness_floor`, and `sonnet_default`; (b) `## Write procedure` forbids writes in the Step G4 concurrent section; (c) `## SC computation` states the `N<2 ⇒ insufficient-data` rule. — Expected: all three confirmed.
  - Run: `grep -nE '^\s+\{' plugins/spec-flow/reference/metrics-artifact.md` — Expected: no inline flow maps in the schema block (matches the ADR-1 invariant the file documents); a hit inside an illustrative "bad example" is acceptable if labelled.
  - Failure: any missing section header, missing gating field, or a write-procedure that permits concurrent-section writes.

- [x] **[QA]** Phase review
  - Review against: AC-2, AC-18, AC-15, AC-16
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 2: Config key — `metrics: auto|off`
**Exit Gate:** `templates/pipeline-config.yaml` carries a `metrics: auto` key with a CR-007 comment block; the default preserves current behavior.
**ACs Covered:** AC-15, AC-17
**In scope:** MODIFY `plugins/spec-flow/templates/pipeline-config.yaml` (insert the `metrics:` key + comment block).
**NOT in scope:** reading the key (each writer's Step 0 — Phases 5/6/7); the version bump (Phase 9).
**Charter constraints honored in this phase:**
- CR-007 (config keys documented inline): the `metrics:` key ships with a leading comment block (values / default / version / rationale / reference pointer).

- [x] **[Implement]** Insert the config key
  - Architecture constraints: mirror the two-value comment idiom of `model_policy: auto|off` (L55-60) and `reflection: auto|off` (L77-80); place after the `flywheel_threshold:` block.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/templates/pipeline-config.yaml**
  - Anchor: the `flywheel_threshold:` comment block (grep `^flywheel_threshold:`; insert the new key + its `#`-comment block immediately after this key's line)
  - Current:
    ```
    82  # flywheel_threshold: repo-level self-hardening flywheel — occurrence count at which a pattern's
    83  #   batched hardening proposal is surfaced at end-of-piece reflection (new in v5.8.0; FR-006).
    84  #   <int> — distinct-piece occurrence count threshold (default 2). Absent ⇒ 2 (non-blocking; NN-C-003).
    85  #   See plugins/spec-flow/reference/flywheel.md `## Threshold + batched proposal`.
    86  flywheel_threshold: 2
    ```
  - Target: append immediately after line 86 a new comment block + key:
    ```
    # metrics: per-piece pipeline instrumentation (new in v5.11.0; FR-010).
    #   auto — stages write docs/prds/<prd>/specs/<piece>/metrics.yaml; /spec-flow:status renders SC-001..SC-006 (default).
    #   off  — stages skip the metrics write entirely; the piece renders [METRICS-ABSENT] (identical to a pre-instrumentation piece).
    #   Absent ⇒ auto (non-blocking; degrades to [METRICS-DEGRADED] on an unwritable artifact; NN-C-003).
    #   See plugins/spec-flow/reference/metrics-artifact.md.
    metrics: auto
    ```
  - Pattern (two-value comment idiom, from the same file `model_policy` L55-60):
    ```
    # model_policy: per-stage model assignment reporting
    #   auto — report assignments, flag only exceptions (default)
    #   off  — no model-policy report
    model_policy: auto
    ```
  - Done: the `metrics: auto` key exists with a ≥4-line comment block naming values, default, version, and the reference pointer.
  - Verify: `grep -B5 '^metrics: auto$' plugins/spec-flow/templates/pipeline-config.yaml | grep -c '^#'` ≥ 4.

- [x] **[Write-Tests]** N/A — config template change; verification is grep inspection in [Verify].

- [x] **[Verify]** Confirm the key and comment
  - Run: `grep -n '^metrics: auto$' plugins/spec-flow/templates/pipeline-config.yaml` — Expected: one match.
  - Run: `grep -B5 '^metrics: auto$' plugins/spec-flow/templates/pipeline-config.yaml | grep -E 'auto|off|v5.11.0|metrics-artifact.md'` — Expected: comment lines naming both values, the version, and the reference doc.
  - Failure: missing key, missing comment block, or comment lacking values/default/reference.

- [x] **[QA]** Phase review
  - Review against: AC-15, AC-17
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 3: The `metrics-aggregate` bash helper + its test
**Exit Gate:** `scripts/metrics-aggregate <prd-slug>` emits the SC line grammar + ABSENT lines and exits 0 across all fixtures; `scripts/tests/test-metrics-aggregate.sh` passes (summary `N passed, 0 failed`).
**ACs Covered:** AC-9, AC-10, AC-11, AC-13, AC-19, AC-20
<!-- Branch enumeration (doc-as-code §3 N/A — this is executable bash, branches covered by Test Data cases below): python3-present vs absent (AC-10); metrics present vs absent vs malformed (AC-9/AC-11); N even / N odd / N<2 (AC-13); research_artifact true/false (AC-19); concreteness_floor passed/overridden (AC-19); SC-004 both conjunct-failure paths (AC-20). Each branch has a Test Data case. -->
**In scope:** CREATE `plugins/spec-flow/scripts/metrics-aggregate` (bash wrapper + awk fallback); CREATE `plugins/spec-flow/scripts/metrics-aggregate.py` (python fast path, output-identical to the awk fallback); CREATE `plugins/spec-flow/scripts/tests/test-metrics-aggregate.sh` (+ any committed fixture metrics.yaml/manifest files the test references). This mirrors the two-file `scripts/manifest-query` + `scripts/manifest-query.py` + `scripts/tests/test-manifest-query.sh` layout merged in 5.9.0 (ADR-2).
**NOT in scope:** the writers that produce real metrics.yaml (Phases 5–7); the status rendering that consumes the helper output (Phase 8). The test drives the helper over FIXTURE metrics.yaml, not live writer output.
**Charter constraints honored in this phase:**
- NN-C-002 (no runtime deps): the wrapper `exec`s into `metrics-aggregate.py` when `python3` is present and runs a complete awk/bash fallback otherwise — the same owner-accepted python3-fast-path-with-mandatory-fallback exception `scripts/manifest-query` carries; exits 0 when python3 is absent.
- NN-C-008 (self-contained): the tool takes its input as argv (`<prd-slug>`) + on-disk files; no conversation history.

- [x] **[Implement]** Write the helper (two files, mirroring `scripts/manifest-query`)
  - Order: wrapper argv/usage + python3-detect/exec → (py) parse+aggregate+emit / (awk) parse+aggregate+emit → exit 0. Author the wrapper's awk fallback and the `.py` fast path against the SAME output grammar (C-2) so they are byte-identical.
  - Architecture constraints: `set -uo pipefail` (NOT `-e` — must reach `exit 0` even on a malformed piece); the `.py` uses only stdlib `yaml`/`json`; the awk fallback parses the block-style schema (ADR-1: no inline flow maps). Output grammar is the C-2 contract. Never exit non-zero. Malformed/unparseable piece ⇒ treat as absent (stderr one-liner) + continue. `METRICS_AGG_NO_PY=1` forces the awk path (testing), exactly as `manifest-query` uses `MANIFEST_QUERY_NO_PY`.

  **Change Specifications:**

  **T-1: CREATE plugins/spec-flow/scripts/metrics-aggregate** (bash wrapper)
  - Pattern (the python-fast-path dispatch — verbatim from `scripts/manifest-query` L1-40, the established precedent; adapt names):
    ```
    #!/usr/bin/env bash
    set -euo pipefail
    # Python fast-path dispatch. If python3 is available (and not suppressed via
    # METRICS_AGG_NO_PY=1) exec into the .py implementation; else run the awk path below.
    _resolve_real_dir() { ... BASH_SOURCE symlink-follow loop ... ; }   # copy from manifest-query
    _REAL_SCRIPT_DIR="$(_resolve_real_dir)"; _PY="${_REAL_SCRIPT_DIR}/metrics-aggregate.py"
    if [ "${METRICS_AGG_NO_PY:-0}" != "1" ] && command -v python3 >/dev/null 2>&1 && [ -f "$_PY" ]; then
      exec python3 "$_PY" "$@"
    fi
    # ---- awk/bash fallback (mandatory; NN-C-002) ----
    set -uo pipefail   # drop -e for the fallback so a malformed piece can't abort the run
    PRD_SLUG="${1:?usage: metrics-aggregate <prd-slug>}"
    DOCS_ROOT="${DOCS_ROOT:-docs}"
    # 1. piece order from ${DOCS_ROOT}/prds/${PRD_SLUG}/manifest.yaml (slug: lines, file order)
    # 2. per piece: read ${DOCS_ROOT}/prds/${PRD_SLUG}/specs/<piece>/metrics.yaml
    #      absent OR awk-parse fails -> echo "ABSENT ${PRD_SLUG}/<piece>"; continue
    # 3. aggregate per C-2 (SC-001 over research_artifact==true; SC-002 over concreteness_floor==passed;
    #      SC-003/005 split rule; SC-004 dual conjunct; SC-006 Σ repeat_scope)
    # 4. emit SC-001..SC-006 lines + ABSENT lines; exit 0
    ```
  - Target: a complete wrapper: the manifest-query dispatch header (NO_PY gate + symlink-resolved `.py` exec) followed by a section-aware awk fallback that parses each block-style `metrics.yaml` and emits the C-2 grammar. Reuse the `_resolve_real_dir` helper from manifest-query verbatim.
  - Done: `scripts/metrics-aggregate exec-ready` emits the SC lines + ABSENT lines and exits 0 both with python3 (exec path) and with `METRICS_AGG_NO_PY=1` (awk path).
  - Verify: `METRICS_AGG_NO_PY=1 bash plugins/spec-flow/scripts/metrics-aggregate exec-ready >/dev/null; echo $?` — Expected: `0`.

  **T-2: CREATE plugins/spec-flow/scripts/metrics-aggregate.py** (python fast path)
  - Structure outline:
    ```
    #!/usr/bin/env python3
    # metrics-aggregate.py — python fast path (awk-output-identical). See reference/metrics-artifact.md.
    import sys, yaml, math, os
    prd = sys.argv[1]; docs = os.environ.get("DOCS_ROOT","docs")
    # read manifest piece order; for each piece load specs/<piece>/metrics.yaml (yaml.safe_load);
    # on missing/parse-error -> print(f"ABSENT {prd}/{piece}") and skip;
    # aggregate per C-2 (research/concreteness gating, split rule with middle-exclusion + N<2 insufficient-data,
    #   SC-004 dual conjunct, SC-006 Σ repeat_scope); print SC-001..SC-006 lines; sys.exit(0)
    ```
  - Target: a complete python implementation emitting the identical C-2 grammar as the awk fallback. Must `sys.exit(0)` always; a malformed piece becomes an `ABSENT` line (+ stderr note), never a traceback to stdout.
  - Done: `python3 scripts/metrics-aggregate.py exec-ready` and the awk path (`METRICS_AGG_NO_PY=1`) produce byte-identical stdout on every fixture.
  - Verify: `diff <(METRICS_AGG_NO_PY=1 bash plugins/spec-flow/scripts/metrics-aggregate exec-ready) <(python3 plugins/spec-flow/scripts/metrics-aggregate.py exec-ready)` — Expected: no output (identical).

  **T-3: CREATE plugins/spec-flow/scripts/tests/test-metrics-aggregate.sh**
  - Structure outline: clone `scripts/tests/test-manifest-query.sh` (the sibling dual-path tool's harness, 144 tests) — `#!/usr/bin/env bash`, `set -uo pipefail`, `SCRIPT_DIR`, `TOOL="${SCRIPT_DIR}/../metrics-aggregate"`, `pass`/`fail` counters, `assert_grep`/`assert_no_grep`/`assert_exit` with the `-- <command...>` convention, `mktemp -d` fixtures, summary + `exit 1 iff FAILS`. Each fixture builds a temp `docs/prds/<slug>/{manifest.yaml, specs/<piece>/metrics.yaml}` tree and runs `DOCS_ROOT=$TMP/docs TOOL <slug>`. **Every case runs BOTH paths** — once normally (python exec) and once with `METRICS_AGG_NO_PY=1` (awk) — asserting identical output (the manifest-query test does exactly this).
  - Pattern (assert helper + summary, from test-manifest-query.sh):
    ```
    assert_grep() {
      local pat="$1" label="$2"; shift 3
      local out; out="$("$@" 2>/dev/null)"
      if printf '%s\n' "$out" | grep -qE "$pat"; then pass "$label"; else fail "${label} (pattern not found: ${pat})"; fi
    }
    echo "== summary: ${PASSES} passed, ${FAILS} failed =="
    [ "$FAILS" -ne 0 ] && exit 1; exit 0
    ```
  - Done: the test encodes every Test Data case below, each asserted on both the py and awk paths; running it prints `N passed, 0 failed` and exits 0.
  - Verify: `bash plugins/spec-flow/scripts/tests/test-metrics-aggregate.sh` — Expected: `== summary: <N> passed, 0 failed ==`, exit 0.

- [x] **[Write-Tests]** Author `test-metrics-aggregate.sh` per the Test Data block (this is T-3 above; staged via `git add`, not committed). Each case asserts both the python path and the `METRICS_AGG_NO_PY=1` awk path.

  **Test Data:**
  - M1 (instrumented + absent): manifest `[p1, p2]`; `p1/metrics.yaml` complete (research_artifact:true, qa_rounds:2, concreteness_floor:passed, phases total:4 clean_sonnet:4, discoveries.unmarked:0, spikes.planned:1 scope:0, amendments.repeat_scope:0, sonnet_default:true, resume:[{outcome:clean}]); `p2` has no metrics.yaml → expect stdout contains `SC-001 ` line with `total=1`, `ABSENT exec-ready/p2`, and `exit 0`.
  - M2 (awk fallback path): same tree as M1, run the awk path via `METRICS_AGG_NO_PY=1` (the manifest-query NO_PY convention; covers the python3-absent case deterministically without PATH surgery) → expect byte-identical SC lines as the python path and `exit 0` (AC-10). Every other case (M1, M3–M10) is likewise asserted on BOTH paths.
  - M3 (malformed): manifest `[p1, p2]`; `p1` valid, `p2/metrics.yaml` is malformed YAML (`spec:\n  qa_rounds: : :`) → expect `ABSENT exec-ready/p2`, SC lines computed over p1 only, a one-line stderr note, `exit 0` (AC-11).
  - M4 (trend even N=4): manifest `[p1,p2,p3,p4]`, all instrumented, `execute.discoveries.unmarked` = 3,2,1,0 and `spikes.planned+scope` = 4,2,1,0 in order → expect `SC-003 first=5 second=1 trend=down` and `SC-005 first=6 second=1 trend=down` (AC-13).
  - M5 (trend odd N=5): unmarked = 4,3,2,1,0 → first_half {4,3}=7, second_half {1,0}=1, middle p3(=2) excluded → expect `SC-003 first=7 second=1 trend=down` (AC-13).
  - M6 (N=1): one instrumented piece → expect `SC-003 trend=insufficient-data` and `SC-005 trend=insufficient-data`, `exit 0` (AC-13).
  - M7 (SC-001 population): p1 research_artifact:true qa_rounds:2, p2 research_artifact:false qa_rounds:9 → expect `SC-001 … total=1` (p2 excluded from population, NOT a failure) (AC-19).
  - M8 (SC-002 population): p1 concreteness_floor:passed phases 4/4, p2 concreteness_floor:overridden phases 1/9 → expect SC-002 ratio computed over p1 only (denominator excludes p2) (AC-19).
  - M9a (SC-004 conjunct b): all pieces resume clean (rate 1.0) but one piece `sonnet_default:false` → expect `SC-004 … pass=false` (AC-20).
  - M9b (SC-004 conjunct a): all pieces `sonnet_default:true` but one `resume` row `outcome:state-incomplete` → expect `SC-004 … pass=false` (AC-20).
  - M10 (all-absent PRD): manifest `[p1,p2]`, neither has metrics.yaml → expect two `ABSENT` lines, SC lines render `insufficient-data`/empty population, `exit 0` (AC-9 degenerate).

- [x] **[Verify]** Run the test
  - Run: `bash plugins/spec-flow/scripts/tests/test-metrics-aggregate.sh` — Expected: `== summary: <N> passed, 0 failed ==`, exit 0 (N = number of assertions, ≥ the 11 cases above).
  - Run: `chmod +x plugins/spec-flow/scripts/metrics-aggregate plugins/spec-flow/scripts/metrics-aggregate.py plugins/spec-flow/scripts/tests/test-metrics-aggregate.sh && bash plugins/spec-flow/scripts/metrics-aggregate exec-ready >/dev/null; echo $?` — Expected: `0` (exits 0 even over the live, mostly-absent exec-ready PRD).
  - Run (path parity): `diff <(METRICS_AGG_NO_PY=1 bash plugins/spec-flow/scripts/metrics-aggregate exec-ready) <(python3 plugins/spec-flow/scripts/metrics-aggregate.py exec-ready)` — Expected: no output (the awk and python paths agree on the live PRD).
  - Failure: any `FAIL —` line, a non-zero exit from the tool, a `diff` mismatch between the two paths, or a crash on the malformed fixture.

- [x] **[Refactor]** (optional) Reconcile the python (`.py`) and awk (wrapper) field-extraction lists if they drifted; keep the test + path-parity diff green.

- [x] **[QA]** Phase review
  - Review against: AC-9, AC-10, AC-11, AC-13, AC-19, AC-20
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 4: Flywheel `metric` source wire (RESERVED → WIRED)
**Exit Gate:** `reference/flywheel.md` documents `source_type: metric` as WIRED with the `metrics.yaml#<field>` pointer form, routed through the existing operator-confirm flow.
**ACs Covered:** AC-14
**In scope:** MODIFY `plugins/spec-flow/reference/flywheel.md` (three edits: the `## Source taxonomy` `metric` row, the schema-open/wire-narrow paragraph, the field-rules restatement at L32).
**NOT in scope:** any execute code path change — the wire reuses the existing Step 6c match/confirm flow; execute prose is unchanged (the metric occurrence is an operator choice at triage, not a new auto-emitter).
**Charter constraints honored in this phase:**
- NN-P-004 (flywheel writes operator-gated): the `metric` occurrence is written only via the existing match/confirm flow — LLM-proposed, human-confirmed, no silent write; the edited text states this.

- [x] **[Implement]** Flip the taxonomy and update the enum prose
  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/reference/flywheel.md**
  - Anchor: `## Source taxonomy` `metric` row (lines 61-71)
  - Current:
    ```
    69  | `metric` | **RESERVED** | No emitter in this piece; reserved for FO-2 (admission-n event recording) and FO-3 (cross-piece spike index) |
    ```
  - Target: replace the row with:
    ```
    | `metric` | **WIRED** | An occurrence may cite a measured trend from a piece's `metrics.yaml`; the `source:` field carries a pointer `<prd-slug>/<piece-slug>/metrics.yaml#<field>`. Written only via the existing match/confirm flow (operator-confirmed, NN-P-004). See `plugins/spec-flow/reference/metrics-artifact.md`. |
    ```
  - Done: the `metric` row reads WIRED with the pointer form + operator-confirm note.
  - Verify: `grep -E '`metric`.*WIRED' plugins/spec-flow/reference/flywheel.md` returns a match.

  **T-2: MODIFY plugins/spec-flow/reference/flywheel.md**
  - Anchor: the "schema-open, wire-narrow" paragraph just below the taxonomy table (~line 71)
  - Current:
    ```
    71  The `metric` value and the `originating_repo` occurrence field are schema-open (representable) but wire-narrow (no path emits them here). This ensures the deferred FO-2/FO-3 emitters and the `flywheel-global` piece add one field/emitter each — not a schema restructure.
    ```
  - Target: narrow the claim to `originating_repo` only:
    ```
    The `originating_repo` occurrence field remains schema-open (representable) but wire-narrow (no path emits it here) — the `flywheel-global` piece (FR-007) adds that emitter. The `metric` source_type is wired by the `metrics` piece (FR-010); see `## Source taxonomy`.
    ```
  - Done: the paragraph no longer lists `metric` as wire-narrow.
  - Verify: `grep -n 'metric.*wire-narrow\|wire-narrow.*metric' plugins/spec-flow/reference/flywheel.md` returns nothing.

  **T-3: MODIFY plugins/spec-flow/reference/flywheel.md**
  - Anchor: the `source_type` field-rules restatement (line 32)
  - Current:
    ```
    32    - `source_type` — one of `reflection-finding | execute-discovery | metric`. The `metric` value is a RESERVED enum member; no path in the repo flywheel emits it (FO-2/FO-3 deferred). See `## Source taxonomy`.
    ```
  - Target:
    ```
      - `source_type` — one of `reflection-finding | execute-discovery | metric`. All three are wired: `metric` occurrences cite a measured `metrics.yaml` trend, written via the operator-confirm flow (FR-010). See `## Source taxonomy`.
    ```
  - Done: the field rule no longer calls `metric` RESERVED.
  - Verify: `grep -n 'metric.*RESERVED\|RESERVED.*metric' plugins/spec-flow/reference/flywheel.md` returns nothing (the `originating_repo` RESERVED note may remain, but not for `metric`).

- [x] **[Write-Tests]** N/A — reference-doc edit; verification is grep inspection in [Verify].

- [x] **[Verify]** Confirm the wire
  - Run: ``grep -E '`metric`.*WIRED' plugins/spec-flow/reference/flywheel.md`` — Expected: one match.
  - Run: `grep -niE 'metric[^s].{0,40}reserved|reserved.{0,40}metric' plugins/spec-flow/reference/flywheel.md` — Expected: no match referring `metric` to RESERVED.
  - Run: `grep -rn 'source_type: *metric' plugins/spec-flow/` — Expected: now resolves to the wire prose (flips the flywheel-repo AC-4 baseline that required zero hits).
  - Failure: any surviving "metric … RESERVED" wording or a missing pointer form.

- [x] **[QA]** Phase review
  - Review against: AC-14
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 5: spec writer — `spec` block + qa_rounds counter
**Exit Gate:** `skills/spec/SKILL.md` reads the `metrics:` key at Step 0, defines the qa_rounds counting rule, and writes the `spec` block to metrics.yaml at Phase 5 Finalize per the reference doc's write procedure.
**ACs Covered:** AC-3, AC-1 (spec block), AC-15 (off-branch in spec)
<!-- Branch enumeration (doc-as-code §3): the writer's conditional branches each have a covering AC — metrics:auto→write (AC-3/AC-1), metrics:off→skip (AC-15), unwritable→[METRICS-DEGRADED] (AC-16, owned by the reference write procedure cited here). -->
**In scope:** MODIFY `plugins/spec-flow/skills/spec/SKILL.md` — Step 0 config read; a qa_rounds counting-rule note in Phase 2; the `spec` block write at Phase 5 step 3.
**NOT in scope:** the plan/execute/status writers (Phases 6/7/8); the write-procedure mechanics themselves (defined in Phase 1, cited here).
**Steps traversed (P2):** Phase 2 (brainstorm — qa_rounds increment point), Phase 4 (QA loop — qa_iterations source), Phase 5 steps 2-3 (manifest+spec commit — the spec-block write/commit checkpoint). The new write adds no new conditional path through the loop; it appends one artifact at an existing serial commit.
**Dispatch sites (P3):** none — no agent-dispatch contract changes.
**Charter constraints honored in this phase:**
- NN-P-001 (human gate never removed) (cross-cutting — see Overview): the spec sign-off gate at Phase 5 step 1 is untouched; the metrics write is appended after approval, removing no gate.
- CR-001 / CR-002 (frontmatter schemas) (cross-cutting — see Overview): no new agent; the SKILL.md frontmatter is preserved.

- [x] **[Implement]** Wire the spec writer
  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/skills/spec/SKILL.md**
  - Anchor: the spec-skill Step 0 config read (grep `^## Step 0: Load Config`, then the `Read \`.spec-flow.yaml\`` line under it)
  - Current:
    ```
    19  ## Step 0: Load Config
    20
    21  Read `.spec-flow.yaml` from the project root. Use `docs_root` ... default to `docs` and `worktrees`.
    ```
  - Target: append one sentence: "Also read `metrics:` (default `auto`; `off` ⇒ skip the Phase-5 metrics write per `plugins/spec-flow/reference/metrics-artifact.md` `## Write procedure`)."
  - Done: Step 0 reads the `metrics:` key.
  - Verify: `grep -n 'metrics:' plugins/spec-flow/skills/spec/SKILL.md` shows a Step-0 read.

  **T-2: MODIFY plugins/spec-flow/skills/spec/SKILL.md**
  - Anchor: the Phase 2 brainstorm loop (grep `There is no question count` — the un-counted Socratic loop that is the qa_rounds source)
  - Target: add a single bracketed note (not a new step): "**Metrics — Q&A rounds:** increment a `qa_rounds` counter once per operator-answer turn during this brainstorm (one AskUserQuestion card answered in one turn counts as one round, regardless of sub-question count); persisted in Phase 5 per `reference/metrics-artifact.md` `## Field semantics`."
  - Done: the counting rule is stated at the source.
  - Verify: `grep -n 'qa_rounds' plugins/spec-flow/skills/spec/SKILL.md` returns a match in Phase 2.

  **T-3: MODIFY plugins/spec-flow/skills/spec/SKILL.md**
  - Anchor: the Phase 5 Finalize spec commit (grep `git commit -m "spec: add <prd-slug>`)
  - Current:
    ```
    3. Commit spec on worktree branch:
       ```bash
       git add docs/prds/<prd-slug>/specs/<piece-slug>/spec.md
       git commit -m "spec: add <prd-slug>/<piece-slug> specification"
       ```
    ```
  - Target: insert a sub-step (3a) before/with the commit: "**Write metrics (`metrics: auto`):** per `reference/metrics-artifact.md` `## Write procedure`, create/upsert `metrics.yaml` with the envelope + the `spec: {qa_rounds, qa_iterations, research_artifact}` block — `qa_rounds` from the Phase-2 counter, `qa_iterations` = the Phase-4 QA-loop iteration count to clean, `research_artifact` = `true` iff `research.md` exists at the canonical path. Stage it with the spec commit (`git add … metrics.yaml`). If `metrics: off`, skip. On write failure, emit `[METRICS-DEGRADED: <reason>]` and continue." Add `metrics.yaml` to the `git add` line.
  - Done: Phase 5 writes the spec block at the spec commit; off/degraded branches stated.
  - Verify: `grep -n 'spec: {qa_rounds\|spec block\|metrics.yaml' plugins/spec-flow/skills/spec/SKILL.md` shows the Phase-5 write.

- [x] **[Write-Tests]** N/A — orchestration-prose edit; verified by grep inspection (the behavior is exercised live, and end-to-end by FR-013's harness, out of scope here).

- [x] **[Verify]** Confirm the spec wiring
  - Run: `grep -n 'metrics:' plugins/spec-flow/skills/spec/SKILL.md` — Expected: a Step-0 read.
  - Run: LLM-agent-step: read `plugins/spec-flow/skills/spec/SKILL.md` Phase 5 and confirm it (a) writes the `spec` block citing `reference/metrics-artifact.md`, (b) names `qa_rounds`/`qa_iterations`/`research_artifact`, (c) has the `metrics: off` skip and `[METRICS-DEGRADED]` branches. — Expected: all confirmed.
  - Failure: missing Step-0 read, missing write sub-step, or a restated write procedure (must cite, not restate — CR-008).

- [x] **[QA]** Phase review
  - Review against: AC-3, AC-1, AC-15
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 6: plan writer — `plan` block + concreteness_floor signal
**Exit Gate:** `skills/plan/SKILL.md` reads `metrics:` at Step 0 and writes the `plan` block (`qa_iterations`, `concreteness_floor`) at Phase 4 Finalize per the write procedure.
**ACs Covered:** AC-4, AC-1 (plan block)
<!-- Branch enumeration: concreteness_floor=passed (clean qa-plan) vs overridden (circuit-breaker escalation) — both covered by AC-4; metrics:off skip (AC-15, cited from Phase 1). -->
**In scope:** MODIFY `plugins/spec-flow/skills/plan/SKILL.md` — Step 0 config read; the `plan` block write at Phase 4 step 5; the `concreteness_floor` derivation note at the qa-plan loop.
**NOT in scope:** spec/execute/status writers; the write-procedure mechanics (Phase 1).
**Steps traversed (P2):** Phase 3 QA loop (qa_iterations + concreteness_floor source), Phase 4 steps 4-5 (manifest+plan commit — the plan-block write checkpoint). No new conditional path; appends one artifact at the existing plan commit.
**Dispatch sites (P3):** none.
**Charter constraints honored in this phase:**
- NN-P-001 (human gate never removed) (cross-cutting — see Overview): the plan sign-off gate (Phase 4 step 1) is untouched; the metrics write follows approval.
- CR-009 (heading hierarchy) (cross-cutting — see Overview): the plan/SKILL.md edit preserves its `### Phase`/`#### Step` anchors.

- [x] **[Implement]** Wire the plan writer
  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/skills/plan/SKILL.md**
  - Anchor: the plan-skill Step 0 config read (grep `^## Step 0: Load Config`, then the `Read \`.spec-flow.yaml\`` line under it)
  - Target: append: "Also read `metrics:` (default `auto`; `off` ⇒ skip the Phase-4 metrics write per `reference/metrics-artifact.md` `## Write procedure`)."
  - Done: Step 0 reads `metrics:`.
  - Verify: `grep -n 'metrics:' plugins/spec-flow/skills/plan/SKILL.md` shows a Step-0 read.

  **T-2: MODIFY plugins/spec-flow/skills/plan/SKILL.md**
  - Anchor: the Phase 3 QA-loop circuit breaker (grep `**Circuit breaker:** 3 iterations max` — the concreteness_floor passed/overridden source)
  - Target: add a bracketed note: "**Metrics — concreteness_floor:** record `plan.concreteness_floor = passed` when this QA loop reaches clean with no circuit-breaker escalation; `overridden` when the piece advances via the 3-iter circuit-breaker human override. `plan.qa_iterations` = the iteration count to clean. Persisted in Phase 4 per `reference/metrics-artifact.md` `## Field semantics`."
  - Done: the passed|overridden derivation is stated at its source.
  - Verify: `grep -n 'concreteness_floor' plugins/spec-flow/skills/plan/SKILL.md` returns a match.

  **T-3: MODIFY plugins/spec-flow/skills/plan/SKILL.md**
  - Anchor: the Phase 4 Finalize plan commit (grep `git commit -m "plan: add <prd-slug>`)
  - Current:
    ```
    5. Commit plan on worktree branch:
       ```bash
       git add docs/prds/<prd-slug>/specs/<piece-slug>/plan.md
       git commit -m "plan: add <prd-slug>/<piece-slug> implementation plan"
       ```
    ```
  - Target: insert a sub-step: "**Write metrics (`metrics: auto`):** per `reference/metrics-artifact.md` `## Write procedure`, upsert the `plan: {qa_iterations, concreteness_floor}` block into the existing `metrics.yaml` (created at spec stage; create it if absent), refresh `last_updated`, and stage it with the plan commit. `off` ⇒ skip; write failure ⇒ `[METRICS-DEGRADED]` + continue." Add `metrics.yaml` to the `git add`.
  - Done: Phase 4 writes the plan block at the plan commit.
  - Verify: `grep -n 'plan: {qa_iterations\|plan block\|metrics.yaml' plugins/spec-flow/skills/plan/SKILL.md` shows the Phase-4 write.

- [x] **[Write-Tests]** N/A — orchestration-prose edit; grep-verified.

- [x] **[Verify]** Confirm the plan wiring
  - Run: `grep -n 'metrics:\|concreteness_floor' plugins/spec-flow/skills/plan/SKILL.md` — Expected: Step-0 read + the concreteness_floor derivation.
  - Run: LLM-agent-step: read `plugins/spec-flow/skills/plan/SKILL.md` Phase 4 and confirm it upserts the `plan` block citing the reference doc, with off/degraded branches. — Expected: confirmed.
  - Failure: missing read, missing write, or restated procedure.

- [x] **[QA]** Phase review
  - Review against: AC-4, AC-1
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 7: execute writer — `execute`/`final_review` blocks + `## Measurement` re-point
phase_size_override: single-file cohesive instrumentation wiring across execute/SKILL.md's serial checkpoints; the sites are same-file (not parallelizable) and each is a one-line citation to the Phase-1 write procedure, so the change is wide but shallow.
**Exit Gate:** `skills/execute/SKILL.md` reads `metrics:` at Step 0, writes the `execute` + `final_review` blocks at serial checkpoints only (never in the Step G4 concurrent section), appends `resume[]` rows at serial checkpoints, and re-points `## Measurement` to render from `metrics.yaml`.
**ACs Covered:** AC-5, AC-6, AC-7, AC-8, AC-16, AC-1 (execute/final_review blocks)
<!-- Branch enumeration: resume outcome clean vs state-incomplete (AC-7); discovery spike-attributed vs unmarked (AC-6); metrics:auto write vs off skip (AC-5/AC-15); write success vs unwritable→[METRICS-DEGRADED] (AC-16). Each has a covering AC. -->
**In scope:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md` — Step 0 config read; write-site citations at the serial checkpoints (Step 6 per-phase close, Step 6c `.discovery-log.md` commit, group barrier Step G8, Final Review pending-marker, Step 5 learnings commit); resume[] append at the post-resume serial checkpoint; `## Measurement` re-point.
**NOT in scope:** the flywheel `metric` occurrence write (Phase 4 — reuses existing Step 6c flow, no execute change); the write-procedure mechanics (Phase 1).
**Steps traversed (P2):** Step 0 (config read), Step 0a (escalations source), Step 1c (spikes.planned), Step 6 (qa_iterations/phases/dispatches), Step 6c Aggregation + `.discovery-log.md` commit (discoveries/amendments — the discovery-write checkpoint), Step 7 progress commit (resume[] append checkpoint), Step G4 (the concurrent git-free section — explicitly OFF-LIMITS for writes), Step G8 (group barrier commit checkpoint), Final Review Steps 1-3 (final_review.iterations/must_fix) + the final-review-pending marker commit, Step 5 (learnings commit — the latest checkpoint by which both blocks must be complete). The metrics writes add **no new conditional path** through the loop; they append fields at existing serial commits.
**Dispatch sites (P3):** none — no agent-dispatch contract changes (the `dispatches.{opus,sonnet}` tally reads the existing sonnet-coord model-policy assignment; it does not alter any dispatch).
**Charter constraints honored in this phase:**
- CR-009 (heading hierarchy load-bearing) (cross-cutting — see Overview): all `### Step N` / `#### ` anchors are preserved; the `## Measurement` heading level is unchanged.
- NN-P-001 (human gate never removed) (cross-cutting — see Overview): the Final Review human sign-off (Step 4) is untouched; metrics writes are appended at existing commits.

- [x] **[Implement]** Wire the execute writer at serial checkpoints
  - Order: Step 0 read → field-by-field write citations at each serial checkpoint → resume[] append → `## Measurement` re-point. Each T-N is a one-line citation to `reference/metrics-artifact.md` `## Write procedure` / `## Field semantics`, NOT a restated mechanic (CR-008).

  **Change Specifications:**

  **T-1: MODIFY skills/execute/SKILL.md** — Anchor: the Step 0 config-load region (the `.spec-flow.yaml` read; grep `Read \`.spec-flow.yaml\` from the project root` — sibling reads `deferred_commit`/integration config live in the same block).
  - Current (grep anchor, verbatim):
    ```
    Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.
    ```
  - Target: append after that line: "Also read `metrics:` (default `auto`); store `metrics_enabled`. `off` ⇒ skip all metrics writes below (the piece renders [METRICS-ABSENT]). **All metrics writes below honor `metrics_enabled`; on an unwritable/unparseable path emit `[METRICS-DEGRADED: <reason>]` and continue — never block, and never write inside the Step G4 concurrent git-free section.**"
  - Done: Step 0 reads the key and states the shared off/degraded/G4 constraint once.
  - Verify: `grep -n 'metrics_enabled\|METRICS-DEGRADED' plugins/spec-flow/skills/execute/SKILL.md` shows the Step-0 read + shared constraint.

  **T-2: MODIFY skills/execute/SKILL.md** — Anchor: Step 6 per-phase QA close, the `opus_dispatched` record (grep `Record the decision (\`opus_dispatched`).
  - Current (grep anchor, verbatim):
    ```
    Record the decision (`opus_dispatched: true|false (reason)`) for the session summary and for Step 0a's mid-piece trigger evaluation.
    ```
  - Target: add a bracketed note immediately after that line: "**Metrics (serial per-phase checkpoint):** upsert `execute.qa_iterations` (running sum), `execute.phases.{total,clean_sonnet}` (clean_sonnet increments when the phase completed on Sonnet with no escalation and no unmarked discovery), and `execute.dispatches.{opus,sonnet}` (tier from the model policy) per `reference/metrics-artifact.md`. Set `execute.sonnet_default` from the Pre-flight Model Check (true unless an operator override forced a non-Sonnet coordinator/implementer)."
  - Done: per-phase fields cited at the opus_dispatched record. Verify: `grep -n 'execute.phases\|clean_sonnet\|sonnet_default' plugins/spec-flow/skills/execute/SKILL.md` returns matches.

  **T-3: MODIFY skills/execute/SKILL.md** — Anchor: Step 1c [SPIKE]-phase resolution (grep `### Step 1c: [SPIKE]-phase resolution`) for `spikes.planned`; the Step 6c scope-spike pre-step (grep `Scope-spike`) and the Step 4.5 flywheel hardening spike for `spikes.scope`.
  - Current (grep anchor, verbatim):
    ```
    ### Step 1c: [SPIKE]-phase resolution (FR-005)
    ```
  - Target: at Step 1c add "increment `execute.spikes.planned` for each `[SPIKE:]`-phase resolved here"; at each scope-mode spike site add "increment `execute.spikes.scope`". Both persisted at the next serial checkpoint per `reference/metrics-artifact.md`.
  - Done: both spike counters cited at their distinct sites. Verify: `grep -n 'spikes.planned\|spikes.scope' plugins/spec-flow/skills/execute/SKILL.md` returns matches.

  **T-4: MODIFY skills/execute/SKILL.md** — Anchor: Step 0a mid-piece Opus QA circuit-breaker outcome (grep `mid_piece_opus_pass: escalated`), plus the budget/fork escalation sites.
  - Current (grep anchor, verbatim):
    ```
    5. On circuit-breaker escalation: log `mid_piece_opus_pass: escalated`; surface to human; halt.
    ```
  - Target: add "increment `execute.escalations` on each operator-halt event — `mid_piece_opus_pass: escalated`, `[STATE-INCOMPLETE]`, spike `BLOCKED`, amendment hard-cap reached, and a non-`[SPIKE]` phase that can't complete on Sonnet (halt → plan-amend) — per `reference/metrics-artifact.md` `## Field semantics`."
  - Done: escalations cited at its triggers. Verify: `grep -n 'execute.escalations' plugins/spec-flow/skills/execute/SKILL.md` returns a match near Step 0a.

  **T-5: MODIFY skills/execute/SKILL.md** — Anchor: the Step 6c `.discovery-log.md` Resolution-commit cell convention (grep `Resolution-commit cell convention`).
  - Current (grep anchor, verbatim):
    ```
    **Resolution-commit cell convention.** ... When the amend path ran a scope spike before `plan-amend`, the orchestrator appends the spike artifact path to the commit subject inside the cell: `abc1234 chore(plan): amend — auth helper missing X (spike: spikes/<id>.md)`.
    ```
  - Target: add after that convention, at the `.discovery-log.md` commit (a serial checkpoint): "**Metrics:** upsert `execute.discoveries.{spike_attributed,unmarked}` (spike_attributed = count of `.discovery-log.md` rows whose Resolution-commit cell carries `(spike: spikes/<id>.md)`; unmarked = total amend/discovery rows − spike_attributed) and `execute.amendments.{total,repeat_scope}` (total = the existing `piece_amendment_count`; repeat_scope = count of amend rows re-targeting a scope already amended) per `reference/metrics-artifact.md` `## Field semantics`."
  - Done: discovery/amendment fields cited at the discovery-log commit. Verify: `grep -n 'discoveries.spike_attributed\|amendments.repeat_scope' plugins/spec-flow/skills/execute/SKILL.md` returns matches.

  **T-6: MODIFY skills/execute/SKILL.md** — Anchor: the mid-group resume `[STATE-INCOMPLETE: journal]` branch (grep `[STATE-INCOMPLETE: journal]`).
  - Current (grep anchor, verbatim):
    ```
    - **No/corrupt journal WHILE a group is in flight → `[STATE-INCOMPLETE: journal]`, escalate.**
    ```
  - Target: add "**Metrics:** on each journal-resume append one `execute.resume[]` row `{at: <phase>, outcome: clean|state-incomplete}` — clean = reached the correct next action without re-running a passing phase; state-incomplete = a `[STATE-INCOMPLETE: journal]` emission. **Write the row at the next serial checkpoint (Step 7 progress commit) — never inside the Step G4 concurrent git-free section** (`reference/metrics-artifact.md` `## Write procedure`)."
  - Done: resume[] append cited with the serial-checkpoint constraint. Verify: `grep -n 'execute.resume' plugins/spec-flow/skills/execute/SKILL.md` returns a match naming the serial-checkpoint constraint.

  **T-7: MODIFY skills/execute/SKILL.md** — Anchor: the Final Review board findings-triage classification (grep `Collect findings from all board agents`).
  - Current (grep anchor, verbatim):
    ```
    Collect findings from all board agents (8 in standard mode; 9 in fast mode — the 9th is `verify-piece-full`). Deduplicate (same issue reported by multiple reviewers). Classify:
    - `must-fix` — blocks merge; amendment-eligible in Step 8 triage
    ```
  - Target: add "**Metrics:** upsert `final_review.{iterations,must_fix}` (iterations = board cycle count, 1 = clean first pass; must_fix = deduped must-fix count from this triage) at the final-review serial checkpoint (the `final-review-pending` marker commit) per `reference/metrics-artifact.md`."
  - Done: final_review block cited at the triage. Verify: `grep -n 'final_review.iterations\|final_review.must_fix' plugins/spec-flow/skills/execute/SKILL.md` returns matches.

  **T-8: MODIFY skills/execute/SKILL.md** — Anchor: the Step 5 Capture Learnings commit (grep `git commit -m "learnings:`).
  - Current (grep anchor, verbatim):
    ```
    git add docs/prds/<prd-slug>/specs/<piece-slug>/learnings.md
    git commit -m "learnings: <prd-slug>/<piece-slug>"
    ```
  - Target: add a line `git add docs/prds/<prd-slug>/specs/<piece-slug>/metrics.yaml` to that staging step, and a note: "**Metrics — completion checkpoint:** by this Step-5 learnings commit the `execute` and `final_review` blocks of `metrics.yaml` MUST be complete; co-stage `metrics.yaml` with `learnings.md`. This is the latest serial checkpoint per the PRD AC and `reference/metrics-artifact.md` `## Write procedure`."
  - Done: the completion checkpoint co-stages metrics.yaml. Verify: `grep -n 'metrics.yaml' plugins/spec-flow/skills/execute/SKILL.md` shows the Step-5 co-stage.

  **T-9: MODIFY skills/execute/SKILL.md** — Anchor: `## Measurement` block (lines 1996-2006). Target: re-point the opening sentence — replace "At session end, emit a summary with per-phase …" with "At session end, render the summary **from the persisted `docs/prds/<prd-slug>/specs/<piece-slug>/metrics.yaml`** (written incrementally at the serial checkpoints above per `reference/metrics-artifact.md`), not from session memory — the file is the single source of truth. The summary surfaces: per-phase Build duration/token count (ephemeral, not persisted), and from metrics.yaml the QA iteration count, mid_piece_opus_pass outcome (→ `execute.escalations`), deferred_findings_recorded, and the group commit model." Keep the existing observable-properties list. Done: `## Measurement` reads from the file. Verify: `grep -n 'from the persisted\|from .*metrics.yaml' skills/execute/SKILL.md` returns a match in the `## Measurement` block.

  **T-10: MODIFY skills/execute/SKILL.md** — Anchor: the write sites collectively. Target: ensure each T-2..T-8 note carries the `metrics: off` skip + `[METRICS-DEGRADED]` failure branch by a single shared sentence at T-1 ("All metrics writes below honor `metrics_enabled`; on an unwritable/unparseable path emit `[METRICS-DEGRADED: <reason>]` and continue — never block, never write inside Step G4."). Done: the off/degraded/G4 constraints are stated once and apply to all sites. Verify: `grep -n 'METRICS-DEGRADED\|Step G4\|concurrent git-free' skills/execute/SKILL.md` returns the shared constraint.

- [x] **[Write-Tests]** N/A — orchestration-prose edit; the write-site discipline is grep-verified below and the live behavior is exercised by FR-013's e2e harness (out of scope).

- [x] **[Verify]** Confirm the execute wiring + serial-checkpoint discipline
  - Run: `grep -n 'metrics.yaml\|execute\.\|final_review\.' plugins/spec-flow/skills/execute/SKILL.md` — Expected: write citations at Step 6, Step 6c, resume, Final Review, Step 5; no write inside the Step G4 section.
  - Run: LLM-agent-step: read the Step G4 concurrent git-free section of `skills/execute/SKILL.md` and confirm it contains NO metrics.yaml write and that the metrics notes explicitly name G4 as off-limits. — Expected: confirmed (AC-5).
  - Run: LLM-agent-step: read the `## Measurement` block and confirm it renders from `metrics.yaml`, not session memory. — Expected: confirmed (AC-8).
  - Run: `grep -n 'METRICS-DEGRADED' plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1 (the degraded branch, AC-16).
  - Failure: any metrics write inside G4, a `## Measurement` that still recomputes in-context, or a restated write procedure.

- [x] **[Refactor]** (optional) Consolidate the per-site notes if they drifted in wording; preserve all `### Step` anchors.

- [x] **[QA]** Phase review
  - Review against: AC-5, AC-6, AC-7, AC-8, AC-16, AC-1
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 8: status renderer + cross-phase schema-consistency check
**Exit Gate:** `/spec-flow:status` renders a per-PRD "Success Metrics" block in the default view by shelling out to `scripts/metrics-aggregate`, showing SC-001..SC-006 over the instrumented subset with `[METRICS-ABSENT]` for uninstrumented pieces; the cross-phase schema-consistency [Verify] passes.
**ACs Covered:** AC-12, AC-1 (rendering)
<!-- Branch enumeration: piece instrumented (render SC contribution) vs absent (render [METRICS-ABSENT], exclude from aggregate) — AC-12; helper available vs unavailable/all-absent (block renders [METRICS-ABSENT], rest unaffected) — AC-12. -->
**In scope:** MODIFY `plugins/spec-flow/skills/status/SKILL.md` — Step 0 config read; invoke `scripts/metrics-aggregate <prd-slug>` in the per-PRD loop; render the Success Metrics block in the default view; `[METRICS-ABSENT]` passive surface.
**NOT in scope:** the helper itself (Phase 3); the writers (Phases 5-7).
**Steps traversed (P2):** Step 0 (config read), Step 4 per-PRD parse (the helper-invocation + aggregation hook), Step 6 all-PRDs default view (where the Success Metrics block prints), Step 7 drill-in (optional per-piece SC detail). New conditional path: per PRD, invoke helper → render block; absent/unavailable → `[METRICS-ABSENT]`. Both branches enumerated in the ACs.
**Dispatch sites (P3):** none — the helper is a shell invocation, not an agent dispatch.
**Charter constraints honored in this phase:**
- NN-C-003 (backward compat): SCs computed over the instrumented subset; pre-instrumentation pieces render `[METRICS-ABSENT]` and never break status.
- NN-C-005 (passive surface): a missing helper or all-absent PRD informs via `[METRICS-ABSENT]`; never blocks or errors other pieces' display.
- CR-009 / CR-001 / CR-002 (cross-cutting — see Overview): the status/SKILL.md edit preserves its numbered-step structure and frontmatter; no new agent.
- (Thin-orchestrator discipline for status — shelling to the helper rather than computing SCs — is the CR-008 instance owned by Phase 1's single-SoT allocation; applied here in practice.)

- [x] **[Implement]** Wire the status renderer
  **Change Specifications:**

  **T-1: MODIFY skills/status/SKILL.md** — Anchor: the status Step 0 Load config (grep `0. **Load config:**`). Target: append "Also read `metrics:` (informational; status renders SCs regardless, marking `off`/absent pieces `[METRICS-ABSENT]`)." Done: Step 0 notes the key. Verify: `grep -n 'metrics' skills/status/SKILL.md` shows a Step-0 mention.

  **T-2: MODIFY skills/status/SKILL.md** — Anchor: the Step 4 per-PRD parse (grep `4. **Per-PRD parse (default all-PRDs view`). Target: add a sub-step: "**Success Metrics (per PRD):** run `bash plugins/spec-flow/scripts/metrics-aggregate <prd-slug>` (honoring `docs_root` via `DOCS_ROOT`); parse its `SC-NNN key=val` lines and `ABSENT` lines per `reference/metrics-artifact.md` `## Helper output contract`. If the helper is absent or every piece is `ABSENT`, mark the block `[METRICS-ABSENT]`." Done: the helper invocation + parse is wired into the per-PRD loop. Verify: `grep -n 'metrics-aggregate' skills/status/SKILL.md` returns a match in Step 4.

  **T-3: MODIFY skills/status/SKILL.md** — Anchor: the Step 6 all-PRDs default-view render (grep the `Pieces:` example line in the default-view section). Target: add a worked-example render directly under the Pieces line showing the Success Metrics block in the **default** view (counts illustrative):
    ```
    PRD: exec-ready (active, v4)
      Pieces: 16 total — 6 merged, 1 in-progress, 9 open
      Success Metrics (over 1 instrumented piece):
        SC-001 Q&A≤3: 1/1 pass   SC-002 Sonnet-clean: 86%   SC-003 unmarked-discovery: insufficient-data
        SC-004 resume+Sonnet: pass   SC-005 spike-trend: insufficient-data   SC-006 no-repeat-amend: pass
        [METRICS-ABSENT]: 6 merged pieces predate instrumentation (excluded from aggregate)
    ```
    Render this block in the default view (no flag); model the passive-surface discipline on the `stale-in-progress` block (grep `stale-in-progress` in the default-all-PRDs-view section). Done: a default-view worked example with the SC block + `[METRICS-ABSENT]`. Verify: `grep -n 'Success Metrics' skills/status/SKILL.md` returns a match in the default-view section.

  **T-4: MODIFY skills/status/SKILL.md** — Anchor: the new Success Metrics rendering prose. Target: state the passive-surface rule verbatim-in-spirit: "This is a passive surface (NN-C-005). Pieces with no/`off` metrics.yaml render `[METRICS-ABSENT]` and are excluded from the aggregate; never block, error, or prevent other pieces from displaying." Done: the NN-C-005 rule is attached to the metrics block. Verify: `grep -n 'METRICS-ABSENT' skills/status/SKILL.md` returns a match with the passive-surface note.

- [x] **[Write-Tests]** N/A — status output has no automated test; the contract is the worked-example render, grep-verified, and the helper it calls is already tested in Phase 3.

- [x] **[Verify]** Confirm rendering + cross-phase schema consistency
  - Run: `grep -n 'metrics-aggregate\|Success Metrics\|METRICS-ABSENT' plugins/spec-flow/skills/status/SKILL.md` — Expected: helper invocation in Step 4, Success Metrics block in the default view, `[METRICS-ABSENT]` passive note.
  - Run: LLM-agent-step: read `skills/status/SKILL.md` and confirm the Success Metrics block renders in the DEFAULT view (not behind a flag like `--include-drift`). — Expected: confirmed (AC-12).
  - **Cross-phase schema-consistency check (plan SKILL §2d — metrics.yaml is the schema-bearing file touched by Phases 1,3,5,6,7,8):** confirm the field names agree across the SoT, the reader, and the writers.
    - Run: `for f in research_artifact concreteness_floor sonnet_default clean_sonnet spike_attributed repeat_scope; do echo "== $f =="; grep -rl "$f" plugins/spec-flow/reference/metrics-artifact.md plugins/spec-flow/scripts/metrics-aggregate plugins/spec-flow/scripts/metrics-aggregate.py plugins/spec-flow/skills/{spec,plan,execute,status}/SKILL.md; done` — Expected: each field name appears in the reference doc (Phase 1) AND in at least its producing writer AND (for SC-gating fields) in BOTH helper files (the awk wrapper and the `.py`, Phase 3). No field name is spelled differently in any consumer or between the two helper paths.
    - Run: LLM-agent-step: confirm the block/field names in `reference/metrics-artifact.md` `## Schema` exactly match the keys the helper's `parse_metrics` extracts and the keys the writers (spec/plan/execute SKILLs) emit — no drift (e.g. `clean_sonnet` is never `sonnet_clean`). — Expected: consistent.
  - Failure: a flag-gated metrics block, a field-name mismatch across phases, or a missing helper invocation.

- [x] **[QA]** Phase review
  - Review against: AC-12, AC-1
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 9: Version bump + CHANGELOG (5.10.0 → 5.11.0)
**Exit Gate:** all four version-bearing files read 5.11.0; CHANGELOG has a `## [5.11.0] — <date>` section with an Added grouping.
**ACs Covered:** AC-17
<!-- Branch enumeration: N/A — no conditionals in a version bump. -->
**In scope:** MODIFY `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (spec-flow entry only), `plugins/spec-flow/CHANGELOG.md`.
**NOT in scope:** the qa plugin's marketplace entry (L24, stays 1.1.1).
**Charter constraints honored in this phase:**
- NN-C-009 + NN-C-001 (version bump all files + marketplace sync): all four version-bearing files bumped in lockstep to 5.11.0.
- NN-C-007 (CHANGELOG present, Keep a Changelog): the 5.11.0 entry uses `## [5.11.0] — YYYY-MM-DD` + an `### Added` grouping.
- CR-006 (CHANGELOG format): Added/Changed groupings + heading convention.

- [x] **[Implement]** Bump versions and write the CHANGELOG entry
  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/plugin.json** — Anchor: line 4 `"version": "5.10.0",`. Target: `"version": "5.11.0",`. Verify: `grep '"version": "5.11.0"' plugins/spec-flow/plugin.json`.

  **T-2: MODIFY plugins/spec-flow/.claude-plugin/plugin.json** — Anchor: line 4 `"version": "5.10.0",`. Target: `"version": "5.11.0",`. Verify: `grep '"version": "5.11.0"' plugins/spec-flow/.claude-plugin/plugin.json`.

  **T-3: MODIFY .claude-plugin/marketplace.json** — Anchor: the spec-flow entry version (line 15; the `name: spec-flow` block L11-19). Current: `      "version": "5.10.0",`. Target: `      "version": "5.11.0",`. **Do NOT touch L24 (qa plugin, 1.1.1).** Verify: `grep -A6 '"name": "spec-flow"' .claude-plugin/marketplace.json | grep '"version": "5.11.0"'`.

  **T-4: MODIFY plugins/spec-flow/CHANGELOG.md** — Anchor: between `## [Unreleased]` and `## [5.10.0]`. Target: insert
    ```
    ## [5.11.0] — <today's date>

    ### Added
    - **`reference/metrics-artifact.md` (per-piece metrics SSOT, FR-010):** schema, write procedure, field semantics, `[METRICS-DEGRADED]`/`[METRICS-ABSENT]` markers, helper output contract, SC computation, no-secrets clause.
    - **`metrics.yaml` instrumentation:** spec/plan/execute write per-piece metrics at serial checkpoints; the execute `## Measurement` summary now renders from the persisted file.
    - **`scripts/metrics-aggregate` (+ test):** deterministic SC-001..SC-006 aggregator (python3 fast path + pure-bash fallback); `/spec-flow:status` renders a per-PRD Success Metrics block in the default view.
    - **`metrics: auto|off` config key** in `templates/pipeline-config.yaml` (default `auto`).

    ### Changed
    - **`reference/flywheel.md`:** the `metric` occurrence `source_type` flips RESERVED → WIRED (an occurrence may cite a measured `metrics.yaml` trend via the existing operator-confirm flow, NN-P-004).
    ```
  - Done: a 5.11.0 section with Added + Changed groupings.
  - Verify: `grep -n '## \[5.11.0\]' plugins/spec-flow/CHANGELOG.md` returns a match above `## [5.10.0]`.

- [x] **[Write-Tests]** N/A — version metadata; verified by the grep checks in [Verify].

- [x] **[Verify]** Confirm all four files + CHANGELOG
  - Run: `for f in plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json; do grep '"version": "5.11.0"' "$f" || echo "MISS $f"; done` — Expected: two matches, no MISS.
  - Run: `grep -A6 '"name": "spec-flow"' .claude-plugin/marketplace.json | grep '"version": "5.11.0"'` — Expected: one match.
  - Run: `grep -A2 '"name": "qa"' .claude-plugin/marketplace.json | grep '"version"'` — Expected: still `1.1.1` (untouched).
  - Run: `grep -n '## \[5.11.0\]' plugins/spec-flow/CHANGELOG.md` — Expected: one match, positioned above `## [5.10.0]`.
  - Failure: any file still at 5.10.0, the qa entry changed, or a missing/empty CHANGELOG section.

- [x] **[QA]** Phase review
  - Review against: AC-17
  - Diff baseline: git diff <phase_start_tag>..HEAD

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | metrics.yaml exists, block-style, has the four blocks + three gating fields | COVERED | Phase 5, Phase 6, Phase 7 (+ Phase 8 render) |
| AC-2 | reference doc is the single source of truth for schema/ownership/timing/markers/contract/no-secrets | COVERED | Phase 1 |
| AC-3 | spec writes qa_rounds (counting rule) + qa_iterations + research_artifact | COVERED | Phase 5 |
| AC-4 | plan writes qa_iterations + concreteness_floor | COVERED | Phase 6 |
| AC-5 | execute writes at serial checkpoints only, never in the parallel section | COVERED | Phase 7 |
| AC-6 | spike_attributed/unmarked split from .discovery-log; spikes.{planned,scope} counted | COVERED | Phase 7 |
| AC-7 | journal-resume appends resume[] row clean|state-incomplete | COVERED | Phase 7 |
| AC-8 | ## Measurement renders from metrics.yaml | COVERED | Phase 7 |
| AC-9 | helper emits SC lines + ABSENT lines, exit 0 | COVERED | Phase 3 |
| AC-10 | python3 absent → pure-bash fallback, same output, exit 0 | COVERED | Phase 3 |
| AC-11 | malformed metrics.yaml → that piece absent, others aggregate, exit 0 | COVERED | Phase 3 |
| AC-12 | status default view renders Success Metrics over instrumented subset | COVERED | Phase 8 |
| AC-13 | trend split rule (even/odd N, N<2 insufficient-data) | COVERED | Phase 3 (computed), Phase 1 (defined) |
| AC-14 | flywheel metric WIRED, pointer form, operator-confirm | COVERED | Phase 4 |
| AC-15 | metrics: off → no write, renders [METRICS-ABSENT] | COVERED | Phase 1 (procedure), Phase 2 (key) |
| AC-16 | unwritable → [METRICS-DEGRADED] + continue | COVERED | Phase 1 (procedure), Phase 7 (execute exercises) |
| AC-17 | all four version files 5.11.0 + CHANGELOG + config comment | COVERED | Phase 2 (config comment), Phase 9 (version+CHANGELOG) |
| AC-18 | no secrets transcribed; only counts/slugs/dates/outcomes | COVERED | Phase 1 |
| AC-19 | SC-001/SC-002 populations gated (research_artifact / concreteness_floor) | COVERED | Phase 3 |
| AC-20 | SC-004 dual conjunct fails if either conjunct fails | COVERED | Phase 3 |

All 20 ACs COVERED — no NOT COVERED rows, no forward-pointer prompts required.

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `python3 -c "import yaml,sys; d=yaml.safe_load(open(sys.argv[1])); assert all(k in d for k in ('schema_version','spec','plan','execute','final_review')) and 'research_artifact' in d['spec'] and 'concreteness_floor' in d['plan'] and 'sonnet_default' in d['execute']" <fixture metrics.yaml>` | exit 0 |
| AC-2 | shell | `grep -E '^## (Location\|Schema\|Field semantics\|Write procedure\|Markers\|Helper output contract\|SC computation\|No secrets)' plugins/spec-flow/reference/metrics-artifact.md \| wc -l` | `8` |
| AC-3 | agent-step | Read spec/SKILL.md Phase 5; confirm it writes spec block (qa_rounds/qa_iterations/research_artifact) citing the reference doc | Confirmed |
| AC-4 | shell | `grep -n 'concreteness_floor\|plan: {qa_iterations' plugins/spec-flow/skills/plan/SKILL.md` | ≥1 match |
| AC-5 | agent-step | Read execute/SKILL.md Step G4; confirm no metrics.yaml write there + writes named at serial checkpoints | Confirmed |
| AC-6 | shell | `grep -n 'discoveries.spike_attributed\|spikes.planned\|spikes.scope' plugins/spec-flow/skills/execute/SKILL.md` | ≥1 match each |
| AC-7 | agent-step | Read execute/SKILL.md resume section; confirm resume[] append with clean\|state-incomplete at a serial checkpoint | Confirmed |
| AC-8 | shell | `grep -n 'from the persisted\|from .*metrics.yaml' plugins/spec-flow/skills/execute/SKILL.md` (within `## Measurement`) | ≥1 match |
| AC-9 | shell | `bash plugins/spec-flow/scripts/tests/test-metrics-aggregate.sh` | `N passed, 0 failed`, exit 0 |
| AC-10 | shell | test case M2 (`METRICS_AGG_NO_PY=1` awk path) inside test-metrics-aggregate.sh; + `diff` of the two paths on the live PRD | PASS, identical output |
| AC-11 | shell | test case M3 (malformed) inside test-metrics-aggregate.sh | PASS, exit 0 |
| AC-12 | agent-step | Read status/SKILL.md; confirm Success Metrics renders in the default view (no flag) | Confirmed |
| AC-13 | shell | test cases M4/M5/M6 (even/odd/N<2) inside test-metrics-aggregate.sh | PASS |
| AC-14 | shell | ``grep -E '`metric`.*WIRED' plugins/spec-flow/reference/flywheel.md`` | one match |
| AC-15 | agent-step | Read reference/metrics-artifact.md `## Write procedure` + pipeline-config.yaml; confirm `off` ⇒ skip + key default `auto` | Confirmed |
| AC-16 | shell | `grep -n 'METRICS-DEGRADED' plugins/spec-flow/reference/metrics-artifact.md plugins/spec-flow/skills/execute/SKILL.md` | ≥1 each |
| AC-17 | shell | `grep '"version": "5.11.0"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json; grep -A6 '"name": "spec-flow"' .claude-plugin/marketplace.json \| grep 5.11.0; grep '## \[5.11.0\]' plugins/spec-flow/CHANGELOG.md` | all match |
| AC-18 | agent-step | Read reference/metrics-artifact.md `## No secrets`; confirm clause present + schema fields are numeric/enum/slug | Confirmed |
| AC-19 | shell | test cases M7/M8 (research/concreteness population gating) | PASS |
| AC-20 | shell | test cases M9a/M9b (SC-004 dual-conjunct failure) | PASS |

## Contracts

### C-1: metrics.yaml schema (data schema)
- **ID:** C-1
- **Type:** Data Schema
- **Phase:** Phase 1 (defined); produced by Phases 5/6/7; consumed by Phases 3/8.
- **Signature:** block-style YAML, `schema_version: 1` envelope + `spec` / `plan` / `execute` / `final_review` blocks (fields per spec.md SF-1).
- **Inputs:** written incrementally by the four writer stages, one block per stage.
- **Outputs:** read by `metrics-aggregate` and (transitively) `/spec-flow:status`.
- **Error cases:** unwritable/unparseable → `[METRICS-DEGRADED]` (writer) / treated as absent (reader); absent → `[METRICS-ABSENT]`.
- **Constraints:** block-style only (no inline flow maps); each stage upserts only its own block; serial-checkpoint writes only.

### C-2: metrics-aggregate CLI output (function/CLI contract)
- **ID:** C-2
- **Type:** Function (CLI)
- **Phase:** Phase 3; consumed by Phase 8 (status).
- **Signature:** `metrics-aggregate <prd-slug>` (honors `DOCS_ROOT` and `METRICS_AGG_NO_PY` env) → stdout lines, exit 0 always. Two files: the `scripts/metrics-aggregate` wrapper `exec`s `scripts/metrics-aggregate.py` when python3 is present and `METRICS_AGG_NO_PY!=1`, else runs the awk fallback in-wrapper.
- **Inputs:** `<prd-slug>` (positional); reads `<DOCS_ROOT>/prds/<prd-slug>/manifest.yaml` + each piece's `metrics.yaml`.
- **Outputs:** one `SC-NNN key=val …` line per SC-001..SC-006 (e.g. `SC-001 pass=1 total=1 population=research-artifact`; `SC-003 first=5 second=1 trend=down|insufficient-data`; `SC-004 resume_rate=1.00 sonnet_default_all=true pass=true`), plus one `ABSENT <prd-slug>/<piece-slug>` line per uninstrumented piece.
- **Error cases:** malformed/unparseable piece → `ABSENT` + stderr note (never crash); missing manifest → empty SC output + exit 0.
- **Constraints:** exit 0 in every case (NN-C-002 / non-blocking); the python (`.py`) and awk (wrapper) paths must produce **byte-identical** stdout — enforced by the test running every case on both paths and a `diff` parity check (mirrors `scripts/manifest-query`).

### Phases 2, 4, 9 — no boundary-crossing interfaces
Omission rationale: Phase 2 (config key), Phase 4 (flywheel reference-doc edit), and Phase 9 (version bump) expose no functions, schemas, or endpoints consumed by code outside their own phase.

## Parallel Execution Notes

All nine phases are **serial** by dependency (cite-before-use): Phase 1 (reference doc) is the contract every other phase cites and must land first; Phase 2 (config key) precedes the writers that read it; Phase 3 (helper) precedes Phase 8 (status, which calls it); Phases 5–7 (writers) cite Phase 1; Phase 8 cites Phase 1 + calls Phase 3; Phase 9 (version bump) lands last (NN-C-009 — bumps for the cumulative change). No Phase Group is used: Phases 5/6/7 edit *different* skill files (disjoint scopes) and could in principle parallelize, but each is small and all share the Phase-1 contract dependency, and Phase 8's cross-phase schema-consistency check reads all of them — serial keeps the schema-drift check meaningful and the wall-clock cost is negligible (single-file prose edits). **Why serial (Phases 5–7):** they are small disjoint-file edits whose value in parallelizing is negligible, and the Phase-8 cross-phase consistency grep depends on all three being complete and consistent; serial ordering makes that check authoritative.

**Seam coverage:** see the Integration-Test Registry note — the writer→helper→status path is verified in two halves (fixture-driven helper test in Phase 3; inspection + cross-phase grep for the writer→schema half in Phase 8). A live end-to-end run belongs to FR-013's pipeline e2e harness (separate piece).

## Agent Context Summary
| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, plan [Implement] tasks (T-N Change Specs), spec ACs, plan's [Verify] commands, arch constraints, pattern blocks inlined from introspection.md | Spec rationale, brainstorming history |
| Write-Tests | The phase's Test Data block (Phase 3 only), the implemented helper, the test-harness pattern from introspection.md Anchor 9 | Prior agent conversations |
| Verify | The [Verify] commands + expected outputs, spec ACs | Implementation reasoning |
| Refactor | Current code (phase files only), the [Verify] command, quality principles | Prior agent conversations |
| QA | Phase diff, spec, plan, PRD sections | Any agent conversation history |
