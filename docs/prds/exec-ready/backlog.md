# exec-ready PRD Backlog

Deferred work items scoped to this PRD. Cross-PRD learnings live at `docs/improvement-backlog.md`.
Items here are surfaced during spec brainstorm for each piece and either incorporated, deferred with rationale, or marked obsolete.

---

## Open Questions deferred to piece spec brainstorm (2026-06-06)

These are the PRD's Open Questions; resolve each during the relevant piece's spec:

- **Plugin-registry path** — `~/.claude/spec-flow/patterns.yaml` is the proposal; confirm path and update-stability (must survive plugin reinstall, must not collide) during `flywheel` spec.
- **Pattern occurrence granularity** — one occurrence per piece where the pattern appeared, or one per reflection finding? Resolve during `flywheel` spec.
- **`.spec-flow.yaml` keys** — finalize `flywheel_threshold` shape during `flywheel` spec. (`model_policy` and the doc-as-code circuit-breaker were resolved in the `sonnet-coord` spec, 2026-06-07: `model_policy: auto|off`; `qa_max_iterations: auto` = 5 doc-as-code / 3 TDD.)

---

## Deferred from the 2026-06-06 re-evaluation (cut/deferred from the prior exec-loop PRD)

The original `exec-loop` PRD was re-scoped after a capability audit + fresh Boris research. These items were dropped from scope and parked here:

- **Sonnet context-budget / oversized-file routing / summarizer (old FR-006)** — DEFERRED. The original justification ("Sonnet's small window") was superseded by the Opus-1M driver, and the real goal became file-based statelessness (now FR-004/NFR-002). Revisit only if dense plans strain context at the *plan* stage, or if a token ceiling proves necessary in practice. Not a piece today.
- **Execute self-resolve + `decisions.md` (old FR-004)** — CUT. Conflicts with the synchronous-discovery doctrine; an execute-time ambiguity is a plan-incompleteness signal routed to Step 6c or a `[SPIKE]`, not a silent in-execute decision log. Captured as NN-P-002.
- **`loop-driver.md` multi-piece driver + DONE/BLOCKED vocabulary (old FR-005 scraps)** — DROPPED. The execute loop, manifest→merged, and journal resume already ship; only the configurable circuit-breaker survived (folded into `sonnet-coord`). Autonomous multi-piece queue is an explicit non-goal.
- **Cross-machine plugin-pattern correlation** — NON-GOAL. The `~/` plugin registry is per-machine; cross-machine correlation needs a shared remote backend (auth/privacy/weight). Revisit only if multi-machine plugin learning becomes a real need.

---

## Recent findings

### [Deferred via /spec-flow:defer] qa-spec + spec/SKILL.md + templates/spec.md lack branch-enumeration AC coverage — 2026-06-07

**Source:** `exec-ready/plan-concrete` phase `step-4.5-reflection` (agent: `reflection-future-opportunities`)
**Finding (verbatim):** plan-concrete shipped branch-enumeration AC enforcement at the plan layer (qa-plan criterion #30, plan/SKILL.md §2f sub-rule 3, §9d, templates/plan.md slot). The upstream spec layer is untouched — a spec can ship with implicit conditional branches that no AC covers, and the plan author must retrofit ACs later (or qa-plan must-fixes the resulting plan). The pi-011 retro in improvement-backlog.md also called for qa-spec branch-enumeration. Candidate piece: add qa-spec criterion (#19) for doc-as-code phases, extend spec/SKILL.md with a parallel authoring note, add branch-AC slot to templates/spec.md — all citing reference/plan-concreteness.md §3. Deps: plan-concrete (merged ✓).
**Why this does not block plan-concrete's goals:** plan-concrete's scope is the plan layer only; the spec-layer gap is a follow-on improvement. qa-plan's criterion #30 provides a backstop even when the spec layer is silent.
**Captured:** 2026-06-07

### spike-agent future opportunities (2026-06-07)

**Source:** `exec-ready/spike-agent` step-4.5-reflection (agent: `reflection-future-opportunities`)

**FO-1: Configurable `spike_threshold` key (fold into flywheel-repo spec)**
The 0.5 diff-ratio threshold is hardcoded in `reference/spike-agent.md` `## Threshold reuse`. Once the flywheel accumulates per-piece amendment data (FR-006), operators will have a basis for tuning. The spec's Open Questions (spec.md line 172) already flagged `spike_threshold` as a future `.spec-flow.yaml` key. Candidate: during `flywheel-repo` spec brainstorm, propose adding `spike_threshold` as an optional config scalar (default 0.5) read at the threshold computation site in `execute/SKILL.md`. When present it overrides the hardcoded value; when absent behavior is identical (NN-C-003). `reference/spike-agent.md` `## Threshold reuse` is updated to cite `.spec-flow.yaml` as the source of truth.
**Deps:** spike-agent merged (this piece); flywheel-repo spec brainstorm.

**FO-2: Confirm-then-n recording for admission-heuristic calibration (fold into flywheel-repo spec)**
The detect-and-confirm gate (Step 6c `#### Operator-initiated change admission`) treats a `n` response as a silent no-op (comment). Once flywheel-repo has a recording surface, `n` events could be recorded as `admission-false-positive` pattern-type in `docs/patterns.yaml`. At threshold, the flywheel proposes a heuristic-tuning amendment to the admission trigger list. This keeps the detection heuristic improvable without NLU infrastructure.
**Deps:** spike-agent merged; flywheel-repo spec brainstorm.

**FO-3: Cross-piece resolved-spike index (fold into flywheel-repo spec or follow-on piece)**
The no-re-spike guard (Step 1c) is piece-scoped: `spikes/<phase-id>.md` lookup is local. A later piece in the same PRD resolving the same unknown would re-spike from scratch. The flywheel already walks `docs/prds/<prd-slug>/` during pattern recording; it could index spike `Trigger:` fields into `docs/patterns.yaml` as a queryable resolution cache. The spike agent's resolve mode could receive "prior resolutions for similar trigger" pre-context. This bounds Opus spend as PRD unknowns accumulate.
**Deps:** spike-agent merged (canonical artifact schema/location); flywheel-repo (the indexing surface).

**Non-blocking on spike-agent goals:** all three items are flywheel-downstream. This piece's goals are complete without them.

---

### Reflection findings (flywheel-repo, 2026-06-09) — flywheel-global brainstorm inputs

**Source:** `exec-ready/flywheel-repo` phase `step-4.5-reflection` (agent: `reflection-future-opportunities`). Deferred via operator triage 2026-06-09.

**FW-1: `hardenings` schema growth changes flywheel-global's reuse scope (SF-N4 undercount).** The final-review amendment (`phase_final_amend_1`) added `hardenings: [{date, outcome: resolved|blocked, spike_artifact, amend_commit, at_count}]` to `reference/flywheel.md` `## Registry schema` — a field not present when the spec's SF-N4 wrote "flywheel-global reuses the schema by varying only location, routing target, one added `originating_repo` field, and a `plugin` scope value." `spike_artifact` is a repo-relative path and `amend_commit` is a repo-local SHA — neither has a global analogue (global "hardening" = creating a self-improvement piece, not appending amendment phases). During `flywheel-global` spec brainstorm, resolve as an explicit open question: inherit `hardenings` verbatim, define a narrower variant (e.g. substitute `improvement_piece_slug` for `amend_commit`), or omit it. Update SF-N4's reuse claim to reference three varied elements, not one. **Deps:** flywheel-repo (merged); resolution point = flywheel-global spec brainstorm.

**FW-2: registry-integrity lint for schema-valid-but-structurally-wrong `docs/patterns.yaml`.** The degraded path covers unwritable/unparseable, but a registry that parses as valid YAML yet is schema-invalid (missing `id`/`scope`/`occurrences`, unknown `scope`, `hardenings.outcome` outside `resolved|blocked`, `source_type` outside the 3-value enum, non-integer `at_count`) has no validation path — the only structural check is inline LLM read/write. As the registry accumulates across PRDs, silent schema drift corrupts counts undetected. Candidate: add a `## Registry invariants` grep/inspection recipe to `reference/flywheel.md` + a `flywheel-lint` step. **Deps:** flywheel-repo (merged); candidate owner `flywheel-enhancements` (TBD) or folded into flywheel-global.

**FW-3: resolved/blocked exclusion branches lack their own ACs.** The AC Coverage Matrix was finalized before `phase_final_amend_1` added the resolved-exclusion + blocked-exclusion rules; only AC-7 (rejection) has a covering AC. flywheel-global must inherit these exclusion rules (infinite re-proposal is at least as problematic globally) — add explicit ACs + smoke scenarios for the resolved/blocked branches in the flywheel-global spec (the agent notes these belong there, not retrofitted here). **Deps:** flywheel-repo (merged); resolution point = flywheel-global spec brainstorm.

**Captured:** 2026-06-09

---

## Deferred from exec-ready/artifact-budgets step-4.5-reflection (2026-06-10)

**Source:** `exec-ready/artifact-budgets` step-4.5 reflection (`reflection-future-opportunities`). Deferred via operator triage 2026-06-10 — all are future-scope, none are current defects.

**AB-1: Aggregate reporting for documented-only artifact classes (research.md, learnings.md).** These classes are "documented-only" — authors self-enforce. Budget compliance is recorded passively in `metrics.yaml` per piece (Phase 3, ADR-3). Once the corpus has 5+ pieces with `budget_compliance` entries, `scripts/metrics-aggregate` could emit a `budget_compliance` summary (count measured, p75 actual, max actual) to give a measured basis for deciding whether a QA gate is warranted. Candidate: extend `scripts/metrics-aggregate.py` (+ parity test) to emit per-class compliance statistics. **Deps:** artifact-budgets (merged); gate-scaling (open).

**AB-2: Budget threshold re-derivation mechanism.** The `artifact-budgets.md` thresholds are static, derived from 9 merged exec-ready pieces (2026-06-10). As more pieces merge, the p75/max distribution will drift. No mechanism triggers a corpus re-derivation. Candidate: add a note to `reference/artifact-budgets.md §2` that thresholds re-derive when corpus grows by 5+ pieces; have the flywheel record a `budget-threshold-drift` pattern when the p75 in an aggregate report diverges from the documented soft ceiling by >15%. **Deps:** AB-1; flywheel-refresh (open).

**AB-3: Shared budget-resolution recipe to prevent per-skill drift.** The `wc -l` + config-resolve + interpolation sub-step is duplicated in `skills/spec/SKILL.md` and `skills/plan/SKILL.md`. A third skill requiring budget interpolation (e.g. if a `spike.md` artifact class is added) would introduce a third copy. Candidate: extract the shared resolution recipe into a `## Shared: budget resolution` anchor in the orchestrator reference or a `budget-resolution-recipe.md` so all skills cite-by-reference. **Deps:** artifact-budgets (merged); triggered by any third budget-interpolation site. **Context update (2026-06-12):** `drop-plan-len-cap` (5.15.0) removed the `plan/SKILL.md` budget-interpolation site entirely — `skills/spec/SKILL.md` is now the sole remaining live site. The "third copy" trigger condition is less likely to materialize. Reassess priority when the next budget-interpolation site is added; if only one site ever remains, close this item.

**AB-4: Override sanity validation (soft ≤ hard invariant).** A `.spec-flow.yaml` with `soft > hard` (e.g. `{soft: 700, hard: 600}`) silently produces incoherent gate behavior. The reference doc says "unresolvable or malformed → skip" but doesn't define soft > hard as malformed. Candidate: add a budget-resolution validation rule in `skills/spec/SKILL.md` and `skills/plan/SKILL.md`; emit `[BUDGET-CONFIG-INVALID: spec_md soft=X > hard=Y]` and fall back to reference-doc defaults; document the `soft ≤ hard` invariant in `reference/artifact-budgets.md §5`. Small amendment, low blast radius. **Deps:** artifact-budgets (merged); self-contained.
---

## Deferred from exec-guardrails spec (2026-06-10)

**EG-1: full transitive / by-name fixture-closure hashing.** `exec-guardrails` (FR-EG-3, VOQ-1) ships *directly-imported* fixture + same-tree `conftest.py` hashing in `tdd-red`'s manifest — a best-effort, shallow rule chosen to avoid the false-positive risk of fragile closure-derivation in POSIX bash (NN-C-002). Residual immutability gap: a Build phase can still tamper via a deep transitive fixture chain or a fixture injected *by name with no import*, changing what a Red test asserts while the listed test bytes stay identical. The only NN-C-002-clean shape for closing this is *plan-declared* closures (modeled on the existing M3 integration closure-hashing), which pushes work onto the plan author and was judged not worth building speculatively. **Resolution point:** evaluate at a future exec-ready piece's brainstorm *with real evidence the residual is exploited in practice* — inherit M3-style plan-declared closure hashing, or accept-and-document. **Deps:** exec-guardrails (this piece); candidate owner TBD.

## Follow-on candidates from exec-guardrails reflection (2026-06-10)

**EG-2: G9b per-sub-phase authored-test exemption scoping.** The deferred-path barrier (Step G9b) evaluates `exempt_authored` "for the sub-phase" (plan Phase 3 T-4) but the barrier re-hash runs once over the working tree of a multi-sub-phase Phase Group. `execute/SKILL.md` does not specify the per-sub-phase parsing step at barrier time: if the orchestrator collapses to a union of all sub-phases' `**Authored-tests:**` fields, a path authored by sub-phase A could exempt tampering by sub-phase B. **Resolution point:** add explicit G9b per-sub-phase attribution rule to `execute/SKILL.md` (prose amendment, not a new piece) before `gate-evals` is specced; `gate-evals` should include a multi-sub-phase fixture that surface-tests this.

**EG-3: amendment-counter-recovery degradation path.** `piece_amendment_count` is recovered via `git log --grep '^chore(plan): amend'` (execute/SKILL.md `#### Amendment budget tracking`). On pieces with squashed commits or pre-5.12.0 histories where the commit-message convention was not used, the count can under- or over-report — causing the hard cap to miss a halt or trigger prematurely. NFR-EG-3 covers format-incompatible journal resume but not counter-recovery degradation. **Resolution point:** a follow-on piece could add a `[COUNTER-DEGRADED: <reason>]` escalation path and a cross-check against `.discovery-log.md` amend rows as a reconciliation signal, making recovery auditable rather than silent best-effort.

**EG-4: gate-evals cheater scenarios should cover the flat-path transient-commit window.** ADR-1 (plan §Architectural Decisions) accepts that on the flat/`deferred_commit: off` path a tampered commit transiently exists on HEAD before the orchestrator's revert. The `gate-evals` piece (manifest open, prd_sections FR-017) describes ≥10 cheater scenarios but its description does not include this flat-path window as a distinct scenario class. **Resolution point:** when `gate-evals` is specced, include a scenario where a cheat reads tampered content from HEAD in the window between implementation and the gate (a) revert — else the ADR-1-accepted asymmetry goes untested.

**Captured:** 2026-06-10

---

## Deferred from exec-ready/flywheel-refresh step-4.5-reflection (2026-06-11)

**Source:** `exec-ready/flywheel-refresh` step-4.5 reflection. Deferred via operator triage 2026-06-11.

**FO-1: On-demand flywheel refresh skill.** ADR-4 deferred this (no `commands/` host, YAGNI at spec time). As the registry accumulates entries across multiple PRDs, operators will want to inspect and prune patterns outside the end-of-piece cadence — e.g. mid-PRD when a batch of pieces ships rapidly and several stale patterns accumulate before any Step 4.5 fires. Candidate: `/spec-flow:flywheel` (or `/spec-flow:status --flywheel`) — reads `docs/patterns.yaml`, derives lifecycle state per `reference/flywheel.md ## Pattern lifecycle`, presents the operator-gated archival prompt. Read-only view arm is minimum; full refresh arm (operator-confirmed archival) is stretch goal. **Deps:** flywheel-refresh (merged); real registry data (at least one threshold-triggered hardening).

**FO-2: `/spec-flow:status` lifecycle rendering.** `status/SKILL.md` renders SC-001–SC-006 from `metrics.yaml` but has no flywheel-aware section. Now that lifecycle fields + schema are stable, the natural home for a `Flywheel:` summary row is the status output: active/hardened/archived counts, pending stale-active or clean-hardened proposals, ineffective-hardening regressions. Without this, flywheel health is invisible between end-of-piece passes. Candidate: extend `status/SKILL.md` to derive state from `docs/patterns.yaml` (when present) and emit a compact summary. **Deps:** flywheel-refresh (merged); metrics (merged).

**FO-3: FW-2 scope expansion for flywheel-global spec brainstorm.** FW-2 (registry-integrity lint) was deferred in ADR-5 to flywheel-global. The lifecycle fields added by flywheel-refresh expand the structural-validity surface: `archived` non-boolean, `hardenings.at_count` non-integer, `hardenings.outcome` outside `resolved|blocked`, duplicate `piece` values in `occurrences` (inflates `pieces_since_last_seen`). During flywheel-global spec brainstorm, expand FW-2 scope to cover lifecycle fields and add a `## Registry invariants` grep recipe to `reference/flywheel.md` covering both base schema and lifecycle fields. **Deps:** flywheel-global spec (open); extends existing FW-2 backlog entry (2026-06-09) — not a duplicate.

**FO-4: flywheel-global dependency gate is now cleared.** flywheel-global (manifest `status: open`) required flywheel-refresh to be merged (lifecycle mechanics precondition). This piece satisfies that gate. Start of flywheel-global is further gated on: (1) at least one real threshold-triggered hardening on live pieces (per manifest ordering note), and (2) resolution of open questions FW-1 (`hardenings` schema variant for cross-repo context) and FW-3 (resolved/blocked exclusion ACs) — both already in this backlog (2026-06-09). No new piece needed; this is a tracking note.

**Captured:** 2026-06-11

---

## Deferred from exec-ready/gate-scaling step-4.5-reflection (2026-06-11)

**Source:** `exec-ready/gate-scaling` phase `step-4.5-reflection` (agent: `reflection-future-opportunities`). Deferred via operator triage 2026-06-11 — all are future-scope enhancements, none are current defects.

**GS-1: Coherence linter — enforce `<<<...>>>` delimiters at triage dispatch sites.** Add a linter invariant that verifies triage dispatch sites in `execute/SKILL.md` use all three required structural delimiters (`<<<JUST_FIXED_FINDINGS>>>`, `<<<FIX_DIFF>>>`, `<<<PRIOR_MUSTFIX_SET>>>` with matching `<<<END>>>` markers). A missing delimiter silently corrupts triage input without any parse error. Candidate: BLOCK-level invariant (same tier as invariant-1). **Deps:** gate-scaling (merged); self-contained linter extension.

**GS-2: Coherence linter — `known-violations` suppression for cross-file step refs.** Provide a `.linter-known-violations` file or inline annotation (`# lint: cross-file-step-ref`) so pre-existing and intentional invariant-1 cross-file step references can be suppressed without masking real new violations. Unblocks clean linter exits for all future execute runs. **Deps:** gate-scaling (merged); see also improvement-backlog MF-GS-3 for the repair of pre-existing violations.

**GS-3: Pre-5.14 metrics backfill convention.** When a piece's spec/plan gates ran before gate-scaling shipped, `metrics.yaml` should carry an explicit comment at the omitted `spec_gate`/`plan_gate` block site (e.g. `# gate ran before gate-scaling shipped`). The gate-scaling piece itself demonstrates this pattern — its own spec/plan gate blocks are absent with a prose comment. Candidate: add a note to `reference/metrics-artifact.md §gate_scaling` formalizing the pre-5.14 omission convention so all future backfill-authors use consistent form. **Deps:** gate-scaling (merged); self-contained reference amendment.

**GS-4: `#advisory-fields` anchor in `reference/gate-scaling.md`.** The `machine_checkable_ratio` at spec-gate is the first advisory-only field in the gate-scaling contract — present but non-blocking, silently omitted if unavailable, never raises a must-fix. Future gates adding advisory fields will need to define the same contract. Candidate: add an `## advisory-fields` section to `reference/gate-scaling.md` with a concise definition of the advisory-field contract so all gates can cite-by-reference rather than restating it inline. **Deps:** gate-scaling (merged); self-contained reference amendment.

**GS-5: Additional spec-gate digest advisory signals.** The current spec-gate digest carries three fields (QA-iteration count, zero-marker scan result, `machine_checkable_ratio` if available). Candidates for additional advisory fields already computable at spec Phase 5: `spec_line_count` vs soft/hard budget, `qa_round_count` (operator Q→A exchanges during brainstorm), `research_artifact_present`. All are in `metrics.yaml` after Phase 5 — adding them broadens operator context at sign-off with no predicate impact. **Deps:** gate-scaling (merged); gate-scaling GS-4 (advisory-fields anchor is a natural prerequisite).

**Captured:** 2026-06-11
