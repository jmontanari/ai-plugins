# metrics.yaml — per-piece pipeline instrumentation

Single source of truth for the per-piece metrics artifact (FR-010) — the `metrics.yaml` schema, write procedure, field semantics, markers, helper output contract, and SC computation. Cited by `skills/spec`, `skills/plan`, `skills/execute`, `skills/status`, and `scripts/metrics-aggregate`. Definitions live here and nowhere else.

## Location

`docs/prds/<prd-slug>/specs/<piece-slug>/metrics.yaml`; created lazily on first write by whichever stage runs first (spec). All paths are repo-root-relative (CR-005).

## Schema

The canonical block-style illustrative form:

```yaml
schema_version: 1
generated: 2026-06-10
last_updated: 2026-06-10
piece: exec-ready/metrics
spec:
  qa_rounds: 3            # Phase-2 question→answer exchanges
  qa_iterations: 1        # spec QA gate (Phase 4) loops to clean
  research_artifact: true # research.md present for this piece — gates SC-001's population
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

**Block-style / no-inline-flow-maps invariant:** Every leaf must be on its own indented line; no inline flow maps (`{a: 1}`). This makes the file parseable by both `python3 -c 'yaml.safe_load'` (fast path) and pure grep/awk (fallback). Inline `#` comments are permitted and are stripped by the parsers before value extraction; comments must not carry semantic data (they are advisory only).

## Field semantics

One entry per field; DEFINED fields (per ADR-5) include their full derivation.

- `schema_version` — integer; currently always `1`. Incremented only on a breaking schema change.
- `generated` — ISO date on which the file was first created.
- `last_updated` — ISO date refreshed on every upsert; writers set this to today's date.
- `piece` — the `<prd-slug>/<piece-slug>` identifier, matching `manifest.yaml`.
- `spec.qa_rounds` — **DEFINED:** count of operator-answer turns in spec Phase 2 (one AskUserQuestion card answered in one turn counts as one round, regardless of sub-question count within that card).
- `spec.qa_iterations` — the Phase-4 QA-loop iteration count to clean.
- `spec.research_artifact` — `true` when a `research.md` exists for the piece at the canonical path; `false` otherwise. Gates SC-001's population.
- `plan.qa_iterations` — the qa-plan loop iteration count to clean.
- `plan.concreteness_floor` — **DEFINED:** `passed` when the qa-plan gate reached clean with no circuit-breaker escalation; `overridden` when the piece advanced via the 3-iter circuit-breaker human override. Gates SC-002's denominator.
- `execute.sonnet_default` — `true` when the coordinator + implementer ran Sonnet-default with no global Opus override; SC-004's second conjunct.
- `execute.phases.total` — total phase count dispatched.
- `execute.phases.clean_sonnet` — phases that completed on Sonnet with no escalation and no unmarked discovery.
- `execute.discoveries.spike_attributed` — count of `.discovery-log.md` amend rows whose Resolution-commit cell carries `(spike: spikes/<id>.md)`.
- `execute.discoveries.unmarked` — total amend/discovery rows minus `spike_attributed`.
- `execute.spikes.planned` — count of `[SPIKE:]`-phases resolved at Step 1c.
- `execute.spikes.scope` — count of scope-mode spikes (Step 6c scoping spikes).
- `execute.escalations` — operator-halt events; triggers are: `[STATE-INCOMPLETE]` resume failure, spike returning `BLOCKED`, amendment hard-cap reached, non-`[SPIKE]` phase the implementer cannot complete on Sonnet (halt → plan-amend), and a mid-piece Opus QA pass that escalated.
- `execute.amendments.total` — same as the existing `piece_amendment_count`.
- `execute.amendments.repeat_scope` — **DEFINED:** count of `.discovery-log.md` amend rows whose finding text re-targets a scope already amended in this piece.
- `execute.dispatches.opus` — count of dispatches assigned to Opus (tier from the sonnet-coord model policy, not per-call-site bookkeeping).
- `execute.dispatches.sonnet` — count of dispatches assigned to Sonnet.
- `execute.qa_iterations` — sum of per-phase qa-phase gate loops across the piece.
- `execute.resume[].at` — phase ID where a journal-resume occurred.
- `execute.resume[].outcome` — `clean` (reached the correct next action without re-running a passing phase) or `state-incomplete` (hit the `[STATE-INCOMPLETE]` escalation).
- `final_review.iterations` — board cycle count (1 = clean first pass).
- `final_review.must_fix` — deduped must-fix count from the Final Review triage.

## Write procedure

The upsert mechanic cited by all writers.

1. **Check the `metrics:` key.** Read `.spec-flow.yaml` `metrics:` key (default `auto`). If the value is `off`, skip all writes — the piece renders `[METRICS-ABSENT]`.
2. **Create the envelope on first write.** If `metrics.yaml` does not yet exist, create it with the `schema_version: 1` / `generated` / `last_updated` / `piece` envelope before writing the calling stage's block.
3. **Upsert only the calling stage's own block/fields.** Preserve all other blocks unchanged. Refresh `last_updated` on every upsert.
4. **Serial-checkpoint-only constraint (ADR-4).** Writes land only at these execute checkpoints:
   - Step 7 per-phase progress commit
   - Step 6c `.discovery-log.md` commit
   - Phase-Group barrier commit (Step G9b/G10)
   - Step 5 learnings commit (the latest point by which `execute` and `final_review` blocks must be complete; `final_review` fields are accumulated in orchestrator state after board triage completes and written here)
   - `resume[]` rows append at the next serial checkpoint after the resume event

   **Explicitly forbidden: writes inside the Step G4 concurrent git-free section.** The deferred-commit model has a concurrent git-free section (Step G4) where sub-phases run in parallel and stage nothing — a metrics write there would race and/or be lost.

5. **Degraded path.** On an unwritable or unparseable path:
   1. Emit a single bracketed orchestrator line: `[METRICS-DEGRADED: <reason>]`
   2. No metrics write occurs.
   3. Execute is **not** blocked or failed — the stage continues normally.

   This mirrors the `[FLYWHEEL-DEGRADED]` pattern in `reference/flywheel.md` `## Degraded path`.

## Markers

Two markers, both single-line bracketed informational markers matching the repo convention.

- `[METRICS-DEGRADED: <reason>]` — emitted by a writer stage when `metrics.yaml` is unwritable or unparseable. Non-blocking: the stage continues.
- `[METRICS-ABSENT]` — emitted by status/helper rendering for a piece with no (or `off`) metrics artifact. Passive surface: informs, never blocks.

## Helper output contract

The stable stdout grammar emitted by `scripts/metrics-aggregate <prd-slug>`:

- One `SC-NNN key=val …` line per SC-001..SC-006. Exact key=val forms:
  - `SC-001 pass=1 total=1 population=research-artifact`
  - `SC-002 rate=0.86 threshold=0.80 pass=true population=concreteness-floor`
  - `SC-003 first=5 second=1 trend=down` (second < first) or `SC-003 first=1 second=5 trend=up` (second > first) or `SC-003 first=3 second=3 trend=flat` (equal) or `SC-003 trend=insufficient-data`
  - `SC-004 resume_rate=1.00 sonnet_default_all=true pass=true`
  - `SC-005 first=6 second=1 trend=down` (second < first) or `SC-005 first=1 second=6 trend=up` (second > first) or `SC-005 first=3 second=3 trend=flat` (equal) or `SC-005 trend=insufficient-data`
  - `SC-006 repeat_scope_sum=0 pass=true`
- One `ABSENT <prd-slug>/<piece-slug>` line per uninstrumented piece (no/`off` metrics.yaml or malformed).
- Exit 0 always (NN-C-002 / non-blocking).
- The python (`.py`) and awk (wrapper) paths must produce **byte-identical** stdout.

## SC computation

Per-SC computation rules:

- **SC-001** — over instrumented pieces where `spec.research_artifact == true` only (SC-001 population is "pieces with a research artifact"): each such piece passes when `spec.qa_rounds ≤ 3`. Pieces without a research artifact are excluded from the SC-001 population, not counted as failures.
- **SC-002** — over instrumented pieces where `plan.concreteness_floor == passed` only (SC-002 population is "pieces whose plan passed the concreteness floor"): `Σ phases.clean_sonnet / Σ phases.total ≥ 0.80`. `overridden`-floor pieces are excluded from the population.
- **SC-003** — `Σ execute.discoveries.unmarked`, first-half vs second-half by manifest order (split rule below); passes when second-half sum < first-half sum.
- **SC-004** — both conjuncts must hold: (a) `Σ clean resume / Σ resume == 1.0` (100%), AND (b) every instrumented piece has `execute.sonnet_default == true`. The SC fails if either conjunct fails.
- **SC-005** — `Σ execute.spikes.(planned + scope)`, first-half vs second-half by manifest order; passes when second-half sum < first-half sum.
- **SC-006** — `Σ execute.amendments.repeat_scope == 0` across instrumented pieces.
- **SC-007** — the meta-capability; satisfied by the helper + status rendering existing (this file + `scripts/metrics-aggregate` + the status integration).

**Trend split rule (SC-003, SC-005).** Let `N` = count of instrumented pieces (those with a parseable `metrics.yaml`), ordered by `manifest.yaml` `pieces[]` order:
- `first_half = pieces[0 : floor(N/2)]`
- `second_half = pieces[N − floor(N/2) : N]`
- When `N` is odd the single middle piece is excluded from both halves (no boundary ambiguity).
- When `floor(N/2) < 1` (i.e. `N < 2`), the trend is not computed — emit `trend=insufficient-data` (no false pass/fail, no divide-by-zero).

## No secrets

Never transcribe credentials, tokens, private keys, or connection strings into `metrics.yaml`. The schema records only counts, slugs, dates, and enum outcomes. When writing a finding reference into `execute.resume[].at` or similar fields, summarize the finding type rather than pasting sensitive values. (Mirror the `reference/flywheel.md` `## No secrets` clause.)
