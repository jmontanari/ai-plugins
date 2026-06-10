# Research — exec-ready/metrics

## Brainstorm Inference Digest

**Piece purpose.** Add a per-piece, machine-readable metrics artifact (proposed `docs/prds/<prd-slug>/specs/<piece-slug>/metrics.yaml`) written incrementally by the stages that own each number — `spec` (Q&A rounds), `execute` (Step 6c discoveries split spike-attributed vs unmarked, escalations, amendments, QA iterations per gate, dispatches by model tier, resume outcomes), and `Final Review` (board iterations + must-fix counts). `/spec-flow:status` then renders SC-001..SC-006 per PRD from the on-disk artifacts (SC-007), degrading to `[METRICS-ABSENT]` for pre-instrumentation pieces and computing SCs over instrumented pieces only. Stages emit `[METRICS-DEGRADED: <reason>]` on an unwritable/unparseable artifact and never block the pipeline. The piece also wires the flywheel's already-reserved `metric` occurrence `source_type` (flywheel.md / flywheel-repo ADR-3 SF-4) so a recorded occurrence may cite a measured trend, still operator-confirmed (NN-P-004). Covers FR-010; depends on flywheel-repo (merged, 5.8.0).

**Design constraints (charter + PRD).**
- NN-C-002 / tools charter: markdown + YAML + JSON + POSIX bash only; no runtime code dep. Any status-side aggregation math must be bash (python3 optional fast path with bash fallback per NN-C-002), or prose the orchestrator executes.
- NN-C-003 backward-compat: artifact is additive; absent artifact must render `[METRICS-ABSENT]` and not break `status` (PRD AC explicitly requires this). New config key (if any) defaults to current behavior.
- NN-C-005 silent no-op on absent optional input; NN-C-009/NN-C-001 every plugin change bumps all four version-bearing files (see Versioning cluster).
- CR-008 thin-orchestrator / narrow-executor; CR-009 heading hierarchy load-bearing. Failure mode (FR-010): unwritable → `[METRICS-DEGRADED]` + continue, instrumentation NEVER blocks.
- Marker convention precedent is strict and consistent across the repo (see Markers below): bracketed single-line `[X-DEGRADED: <reason>]` / `[X-ABSENT]`, informational, non-blocking. `[METRICS-DEGRADED]`/`[METRICS-ABSENT]` are NEW — no existing emitter.

**Open ambiguities for the brainstorm to resolve:**
1. **Q&A round counter does not exist yet.** `spec/SKILL.md` Phase 2 is an explicit "no question count" Socratic loop ("There is no question count — ask as many as it takes"). Nothing today increments or records a round count. The spec author must define what a "round" is (one question? one sub-area in step 3? one user message?) and where spec writes it.
2. **Schema/location confirmation.** PRD proposes `metrics.yaml` "confirmed at spec time." Schema shape (flat keys vs nested per-stage blocks), envelope (`schema_version`?), and field names are open. Sibling artifacts give two precedents: YAML-with-`schema_version` envelope (`docs/patterns.yaml`, flywheel.md) and markdown-table append-log (`.discovery-log.md`). Which idiom?
3. **Incremental multi-writer concurrency.** Three stages append to one file across the piece lifecycle; spec writes before worktree work, execute mid-piece, Final Review at end, resume events "as they occur." Must define create-if-absent + append/merge semantics that survive a fresh-context resume (sonnet-coord disk-derivable-state discipline).
4. **Existing ephemeral `## Measurement` summary** (execute/SKILL.md L1996) already names most execute numbers (QA iteration count, mid_piece_opus_pass, Build token/duration, deferred_findings_recorded, group commit model) but emits them only as a session-end log — NOT persisted. The brainstorm must decide whether metrics.yaml replaces, persists, or is fed by this summary.
5. **Spike-attributed vs unmarked discovery split.** `.discovery-log.md` rows carry a `Resolution commit` cell that embeds `(spike: spikes/<id>.md)` when a scope spike ran (execute L1274); the split is derivable from that, but no field counts it today.
6. **Status SC computation** is currently absent — status renders piece/PRD state but computes no SC values. New rendering hooks needed in the per-PRD parse / drill-in loop.
7. **Resume-outcome semantics (SC-004).** "resumes correctly on 100% of attempts" needs a recordable resume event; sonnet-coord's `[STATE-INCOMPLETE]` / journal resume is the mechanism but emits no metric today.

## Codebase Conventions

- **Single-source-of-truth reference docs.** Each cross-cutting contract lives in exactly one `plugins/spec-flow/reference/*.md` and is *cited, not restated* by skills/agents (research-artifact.md, flywheel.md, deferred-commit-journal.md, spike-agent.md, coordinator-contract.md, ac-matrix-contract.md all open with "Definitions live here and nowhere else"). A new metrics contract should almost certainly be a `reference/metrics-artifact.md` cited by spec/execute/status — matching the sonnet-coord rationale ("keeps the execute SKILL lean").
- **Artifact path idiom.** All per-piece artifacts live under `docs/prds/<prd-slug>/specs/<piece-slug>/`: `research.md`, `spec.md`, `plan.md`, `learnings.md`, `.discovery-log.md`, `spikes/<id>.md`. `metrics.yaml` fits this directory verbatim.
- **Config-key idiom (CR-007).** New keys go in `plugins/spec-flow/templates/pipeline-config.yaml` with a leading comment block (valid values / default / "new in vX.Y.Z" / rationale), matching `deferred_commit`, `model_policy`, `qa_max_iterations`, `reflection`, `flywheel_threshold`. Defaults preserve current behavior (NN-C-003). Read from `.spec-flow.yaml` at each skill's Step 0; absent ⇒ default, malformed ⇒ one-line warning + default fallback.
- **Marker idiom.** Bracketed single-line orchestrator output `[NAME-STATE: <reason>]`; informational, never blocking; mirrors `[FLYWHEEL-DEGRADED]` / `[RESEARCH-UNAVAILABLE]` / `[TEST-DATA-ABSENT]` / `[STATE-INCOMPLETE]`. Degraded/absent paths skip the work, do not error.
- **Two persistence idioms to choose between:** (a) YAML registry with `schema_version`/`generated`/`last_updated` envelope, lazily created on first write (`docs/patterns.yaml`); (b) markdown-table append-log with H1 + fixed header, created on first row, chronological append (`.discovery-log.md`). Worked illustrative instances accompany every schema in this repo.
- **No-secrets clause.** Every artifact/reference doc carries an explicit "## No secrets" / no-secrets note (flywheel.md, spike-agent.md, research-artifact.md). A metrics contract should too.
- **Versioning (NN-C-009).** Four files bump in lockstep: `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (spec-flow entry), `plugins/spec-flow/CHANGELOG.md` (prepend `## [X.Y.Z] — YYYY-MM-DD`). Current version **5.8.0**; CHANGELOG top is `## [Unreleased]` then `## [5.8.0] — 2026-06-09`. Per `plugins/spec-flow/docs/releasing.md`.

## Metrics-Writer Stages (spec, execute, Final Review)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/skills/spec/SKILL.md` (231 lines) — Phase 2 Brainstorm is the Q&A source. **No round counter exists.** Phase 5 Finalize commits manifest+spec; the metrics write for Q&A rounds would hook here or in Phase 2.
- `plugins/spec-flow/skills/execute/SKILL.md` (2016 lines) — owns most fields. Key loci: Step 1c `[SPIKE]` resolution (L393, FR-005, model:opus dispatch — spike-attribution source); Step 6 Phase QA iter-until-clean (L841, QA iterations); Step 6a deferred-finding tracking (L917); Step 6c Discovery Triage (L975) incl. Aggregation (L981), Operator-initiated change admission FR-008 (L1004), Flywheel pattern recording FR-006 (L1048), Amend dispatch (L1103), Amendment budget tracking 5/1 (L1205), `.discovery-log.md` authoring (L1259, spike-attribution cell); Step 0a mid-piece Opus QA pass (L302, escalations); Final Review Step 1–3 board iterations + must-fix triage (L1589–1736); Step 4 Human Sign-Off (L1761); Step 4.5 Reflection + flywheel batched proposal (L1799/L1866); Step 5 Capture Learnings — writes `learnings.md` (L1880, "Step 5 capture-learnings at the latest" per PRD AC); Session Resumability (L1978) + Mid-group resume (L1987, resume outcomes); `## Measurement` ephemeral session-end summary (L1996, names QA iteration count, mid_piece_opus_pass dispatched/not-triggered/escalated, deferred_findings_recorded, group commit model — currently NOT persisted).
- `plugins/spec-flow/reference/coordinator-contract.md` — model-policy table + resume-critical field tiers; source for "dispatches by model tier" and resume-outcome semantics.
- `plugins/spec-flow/reference/ac-matrix-contract.md` — `NOT COVERED`/`requires-amendment` rows feed execute-discovery counts; `Reason` enum `does-not-block-goal | requires-amendment | requires-fork`.

### Dependency Map
**Dependency Map:** spec → research-artifact.md (research dispatch), brainstorm-procedure.md, depends-on-precondition.md, charter-*. execute cites: deferred-commit-journal.md, qa-iteration-loop.md, coordinator-contract.md, spike-agent.md, plan-amend.md, flywheel.md (Step 6c/4.5 hooks), ac-matrix-contract.md, plan-concreteness.md. Flywheel `metric` source_type is reserved in flywheel.md `## Source taxonomy` and flywheel-repo SF-4 — wiring it means execute's Step 6c flywheel hook (L1048) gains a `source_type: metric` occurrence path pointing at metrics.yaml. The metrics writes are additive to existing commit points (spec Phase 5; execute Step 6c `.discovery-log.md` commits; Step 5 learnings commit; Final Review commits).

### Test Landscape
**Test Landscape:** Plugins are markdown/config — the only executable test is `plugins/spec-flow/hooks/tests/test-lint-skill-coherence.sh` driving `hooks/lint-skill-coherence` (four invariants: step-reference integrity BLOCK, cross-ref BLOCK, config-branch parity BLOCK, state-field producer→consumer WARNING). Any new `Step` references or `state-field` tokens added to execute/spec/status SKILLs are linted by this hook at Final Review Step 1a (execute L1636 pre-board self-check). FR-013 (sibling PRD, separate piece) plans an e2e harness asserting "metrics artifact at end" as part of the observable contract — this piece must make that artifact exist for FR-013 to assert on. No unit-test framework; verification is grep/inspection Independent Tests in ACs (flywheel-repo precedent: `grep -E 'schema_version|occurrences|...'`).

### Pattern Catalog
**Pattern Catalog:**

Ephemeral execute measurement summary (the numbers to persist) — execute/SKILL.md L1996+:
```
## Measurement

At session end, emit a summary with per-phase **Build duration**, **Build token count**, ... **QA iteration count** (iter-1 / iter-2 / iter-3 mix per phase), **Step 6b outcome** ..., **mid_piece_opus_pass** (`dispatched` with iteration count / `not-triggered` / `escalated`), and **deferred_findings_recorded** (count ...).
```

`.discovery-log.md` row format incl. spike-attribution cell — execute/SKILL.md L1266:
```markdown
| Phase | Discovery type | Source agent | Finding (1-line) | Triage choice | Resolution commit |
|---|---|---|---|---|---|
| phase_3 | requires-amendment | qa-phase | Auth helper missing X | amend | abc1234 chore(plan): amend — ... (spike: spikes/<id>.md) |
```

Amendment budget (amendment count source) — execute/SKILL.md L1207:
```
Per FR-14, each piece has a hard amendment budget: 5 amendments total per piece, of which at most 1 may be a spec amendment. The budget is piece-scoped — the counters survive across all phases of the piece.
```

Final Review must-fix triage (board iterations + must-fix counts) — execute/SKILL.md L1693:
```
Collect findings from all board agents (8 in standard mode; 9 in fast mode). Deduplicate. Classify:
- must-fix — blocks merge; amendment-eligible in Step 8 triage
- should-fix — non-blocking ...
```

Spec brainstorm — the un-counted Q&A loop (no round counter exists) — spec/SKILL.md L82:
```
Socratic dialogue ... one question at a time. ... There is no question count — ask as many as it takes. Do not ask theater questions ...
```

## Flywheel `metric` Wire

### File Inventory
**File Inventory:**
- `plugins/spec-flow/reference/flywheel.md` (146 lines) — registry schema, `## Source taxonomy` (`metric` = RESERVED, "no emitter in this piece"), occurrence `{piece, date, source, source_type}`, Match+confirm flow (NN-P-004 operator-gated), `[FLYWHEEL-DEGRADED: repo registry unavailable]` degraded path. The `metric` enum is already representable; this piece adds the emitter.
- `docs/prds/exec-ready/specs/flywheel-repo/spec.md` (467 lines) — SF-4 reserves `metric` schema-open/wire-narrow; AC-4 Independent Test: `grep -rn 'source_type: *metric' plugins/spec-flow/` must currently return nothing (this piece flips that). Out-of-scope note names the deferred emitter as a "follow-on flywheel-enhancements piece" — metrics is effectively that wire.
- `plugins/spec-flow/skills/execute/SKILL.md` Step 6c "Flywheel pattern recording (FR-006)" (L1048) — the existing record/match hook where a `source: metric` occurrence with a pointer to metrics.yaml + field would be written, operator-confirmed.

### Dependency Map
**Dependency Map:** Wiring `metric` is a one-field-level addition (per flywheel-repo SF-4 "additive, not a restructure"): an occurrence gains `source_type: metric` + a pointer (`source:` text pointing at `<piece>/metrics.yaml#<field>`). It reuses flywheel.md's existing match/confirm/no-silent-write flow (NN-P-004), the count/dedup rule, and the `[FLYWHEEL-DEGRADED]` degraded path verbatim. No new flywheel mechanism. `docs/patterns.yaml` is created lazily on first confirmed occurrence (unchanged).

### Test Landscape
**Test Landscape:** Verification is grep-based (flywheel-repo AC-4 precedent). A metric-wire AC would assert `grep -rn 'source_type: *metric'` now resolves to the metrics wire prose, and that the occurrence carries an operator-confirmation gate (no silent write). Coherence linter does not check YAML registry content; only SKILL prose step/cross-ref integrity.

### Pattern Catalog
**Pattern Catalog:**

Reserved `metric` source_type — flywheel.md `## Source taxonomy`:
```
| `metric` | RESERVED | No emitter in this piece; reserved for FO-2 (admission-n event recording) and FO-3 (cross-piece spike index) |
```

Occurrence schema + the field this piece fills — flywheel.md `## Registry schema`:
```yaml
occurrences:
  - piece: exec-ready/plan-concrete
    date: 2026-06-07
    source: "reflection-future-opportunities: qa-spec lacks branch-enumeration AC"
    source_type: reflection-finding # reflection-finding | execute-discovery | metric
```

Operator-gated write (NN-P-004) — flywheel.md `## Match + confirm flow`:
```
The flywheel writes nothing to docs/patterns.yaml until the operator confirms both the classification (which pattern) and the scope. ... Matches are LLM-proposed, human-confirmed (NN-P-004).
```

## Status Consumer + SC Rendering

### File Inventory
**File Inventory:**
- `plugins/spec-flow/skills/status/SKILL.md` (328 lines) — the SC-001..SC-006 renderer (SC-007). Scan flow: Step 0 load `.spec-flow.yaml` (`docs_root`/`worktrees_root`); Step 1 worktree scan; Step 2 PRD discovery (per-PRD `prd.md` front-matter); Step 4 per-PRD parse reads `manifest.yaml`, aggregates piece status counts (the natural hook to also read each piece's `metrics.yaml` and aggregate SCs); Step 6 all-PRDs default view; Step 7 drill-in per-piece. `--include-drift` deep scan (L289) is a precedent for an optional metrics-rendering flag if SC rendering is gated. No SC computation exists today.

### Dependency Map
**Dependency Map:** status reads on-disk artifacts only (manifest.yaml, prd.md, spec.md/plan.md front-matter, charter dates via `git log`). Adding SC rendering means: per piece in the per-PRD loop, read `docs/prds/<prd>/specs/<piece>/metrics.yaml` if present; aggregate per PRD; render `[METRICS-ABSENT]` for pieces with no artifact and compute SCs over the instrumented subset (PRD AC + NN-C-003). Aggregation arithmetic must be bash/markdown-expressible (tools charter). Mirror the passive-surface discipline (NN-C-005) status already uses for stale-in-progress and drift.

### Test Landscape
**Test Landscape:** No automated test for status output; the contract is prose + worked example blocks inside SKILL.md. SC rendering would be validated by inspection/worked-example ACs. The `[METRICS-ABSENT]` path must be exercised against pre-instrumentation sibling pieces (research-unify, plan-concrete, sonnet-coord, flywheel-repo, spike-agent, test-data-up — none have metrics.yaml today).

### Pattern Catalog
**Pattern Catalog:**

Per-PRD piece-status aggregation (the line where SC rendering hooks in) — status/SKILL.md Step 4/6:
```
PRD: auth (active, v1)
  Pieces: 5 total — 2 merged, 1 in-progress, 1 planned, 1 open
  ⚠ Drift flagged on 1 piece (token-refresh: non-negotiables)
```

Passive-surface degraded-rendering precedent (model for `[METRICS-ABSENT]`) — status/SKILL.md stale-in-progress:
```
Pieces: 5 total — 2 merged, 1 in-progress, 1 ⚠ stale-in-progress, 1 open
```
```
This is a passive surface (NN-C-005). The user is informed; the fix is a manual manifest edit. Do not block, error, or prevent other pieces from displaying.
```

Optional-flag deep-scan precedent (model for a metrics/SC flag) — status/SKILL.md `--include-drift`:
```
Skip this section unless the skill was invoked with `--include-drift`. The default /spec-flow:status invocation (without this flag) never executes the steps below.
```

## Markers, Config & Versioning

### File Inventory
**File Inventory:**
- `plugins/spec-flow/templates/pipeline-config.yaml` — config-key home (`deferred_commit` L48, `model_policy` L55, `qa_max_iterations` L62, `reflection` L77, `flywheel_threshold` L82). A `metrics:` opt-out key (if specced) lands here.
- `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `plugins/spec-flow/CHANGELOG.md` — four version-bearing files, all at **5.8.0**.
- `plugins/spec-flow/docs/releasing.md` — authoritative version-bump checklist.
- Marker precedents repo-wide: `[FLYWHEEL-DEGRADED]`, `[RESEARCH-UNAVAILABLE]`/`[RESEARCH-ABSENT]`, `[TEST-DATA-ABSENT]`, `[STATE-INCOMPLETE]`. `[METRICS-DEGRADED]`/`[METRICS-ABSENT]` are NEW (grep confirms no existing occurrence).

### Dependency Map
**Dependency Map:** A new config key requires the CR-007 inline comment block. A version bump touches all four files in lockstep (NN-C-009) + a CHANGELOG entry under `## [Unreleased]` then a new `## [X.Y.Z]` section. The new markers must be defined once in the metrics reference doc and emitted by the owning stage (execute for `[METRICS-DEGRADED]` on write failure; status for `[METRICS-ABSENT]` on render).

### Test Landscape
**Test Landscape:** `lint-skill-coherence` enforces config-branch parity (invariant-3) — a config key read in a SKILL must have matching branches; and state-field producer→consumer (invariant-4, WARNING) — if metrics fields are written by one stage and read by status, token producer/consumer tracking may warn. Version-string sync is verified by the `grep '"version"'` recipe in releasing.md (all four must print identical values).

### Pattern Catalog
**Pattern Catalog:**

Config-key comment-block idiom (CR-007) — pipeline-config.yaml L82:
```yaml
# flywheel_threshold: repo-level self-hardening flywheel — occurrence count at which a pattern's
#   batched hardening proposal is surfaced at end-of-piece reflection (new in v5.8.0; FR-006).
flywheel_threshold: 2
```

Degraded-marker definition idiom (model for `[METRICS-DEGRADED]`) — flywheel.md `## Degraded path`:
```
When docs/patterns.yaml is unwritable OR unparseable:
1. The flywheel emits a single bracketed orchestrator line: [FLYWHEEL-DEGRADED: repo registry unavailable]
2. No registry write occurs.
3. Execute is not blocked or failed — the piece continues normally.
```

Version-bearing file list (NN-C-009) — releasing.md:
```
| 1 | plugins/spec-flow/plugin.json | "version" field → new version |
| 2 | plugins/spec-flow/.claude-plugin/plugin.json | "version" field → new version |
| 3 | .claude-plugin/marketplace.json | spec-flow entry "version" → new version |
| 4 | plugins/spec-flow/CHANGELOG.md | Prepend ## [X.Y.Z] — YYYY-MM-DD section |
```
