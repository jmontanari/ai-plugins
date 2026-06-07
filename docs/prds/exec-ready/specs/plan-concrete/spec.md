---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: plan-concrete

**PRD Sections:** FR-002, G-1, G-2
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** research-unify (merged)

## Goal

Make the plan-authoring stage produce **execution-ready** plans by adding a **plan concreteness contract** to `plan/SKILL.md` and a **concreteness floor** to the `qa-plan` gate. Every phase must name the exact target file, the exact location/anchor within it, and the exact content/signatures to add — never "implement X." Genuine unknowns that cannot be resolved from the spec + `research.md`/codebase become explicit `[SPIKE: <unknown>]` markers rather than vague prose. For doc-as-code phases, every conditional branch in the deliverable carries its own enumerated acceptance criterion (codifying the pi-011 finding). The outcome bar (downstream, observational): a plan that passes the concreteness floor yields zero *unmarked* execute-time discoveries.

This piece **defines and enforces** the `[SPIKE: <unknown>]` marker as a plan-authoring artifact and a `qa-plan`/finalize concern. It does **not** build the spike *resolver* — the Opus spike agent and execute-time spike wiring are the later `spike-agent` piece (FR-005).

## In Scope

- A new authoritative reference doc `plugins/spec-flow/reference/plan-concreteness.md` defining: (a) the per-phase concreteness floor (target file + location/anchor + concrete content/signature); (b) the `[SPIKE: <unknown>]` marker syntax, semantics, and scan-scoping rules; (c) the doc-as-code branch-enumeration-AC rule; (d) the interim plan-finalize spike-block and its forward-handoff to FR-005.
- A new Phase-2 authoring rule in `plugins/spec-flow/skills/plan/SKILL.md` instructing the plan author to make each phase concrete, mark unresolvable unknowns as `[SPIKE: <unknown>]`, and enumerate each doc-as-code conditional branch as a numbered AC — citing the reference doc (define-once, cite-everywhere).
- A plan-finalize / sign-off scan in `plan/SKILL.md` that refuses to advance a plan to execute while any `[SPIKE: <unknown>]` survives in plan prose (skipping fenced code blocks and HTML comments), listing each offending phase.
- New `qa-plan` must-fix criteria (appended as #28+) in `plugins/spec-flow/agents/qa-plan.md`: (1) per-phase concreteness floor; (2) unmarked-unknown detection (marked `[SPIKE]` accepted, hidden/hedged unknown must-fix); (3) doc-as-code branch-enumeration-AC presence — each carrying a backward-compat activation guard and the existing **Evidence:** + severity convention.
- `[SPIKE: <unknown>]` marker convention + a branch-enumeration-AC slot documented in `plugins/spec-flow/templates/plan.md` (conditional-comment style on the Implement-track / Non-TDD phase exemplar), citing the reference doc.
- Plugin version bump (minor: 5.3.0 → 5.4.0) synced across `plugin.json`, `.claude-plugin/marketplace.json`, and `CHANGELOG.md`.

## Out of Scope / Non-Goals

- **The spike resolver** — the Opus spike agent (`agents/spike.md`), its isolated dispatch, and execute-time `[SPIKE]` handling are FR-005 / the `spike-agent` piece. This piece only defines + enforces the marker at plan authoring and the plan-finalize gate.
- **Execute / Step 6c changes** — no edit to `skills/execute/SKILL.md`. The execute-time "zero unmarked discovery" metric is *observed* at Step 6c; this piece does not instrument or change Step 6c.
- **Test-data-upfront for TDD phases** — the `Test Data` block and `tdd-red` transcription are FR-003 / `test-data-up`. This piece keeps the `[SPIKE: <unknown>]` syntax reusable by that sibling but does not add test-data mechanics.
- **The Final Review circuit-breaker configurability** — the pi-011 "hard-3" recommendation is FR-004 / `sonnet-coord`, not this piece.
- **Enforcing the zero-discovery outcome inside `qa-plan`** — that outcome (PRD FR-002 AC-4 / SC-003) is observational and downstream; `qa-plan` enforces the *floor*, not the outcome.

## Requirements

### Functional Requirements

- **FR-002a (per-phase concreteness floor):** `qa-plan` must-fixes any plan phase whose deliverable does not name a target file, a location/anchor within it, and concrete content/signatures. The primary gate is presence of that concrete triple; vague verbs ("implement", "handle", "add support for", "wire up", "support") are an *illustrative signal* of a missing triple, scoped to deliverable/TARGET prose — not a standalone grep that fails on any occurrence of the word.
- **FR-002b (explicit unknowns):** Any decision the plan cannot resolve from spec + `research.md`/codebase is written as an explicit `[SPIKE: <unknown>]` marker. `qa-plan` accepts a correctly-marked `[SPIKE]` and must-fixes a hedged/deferred unknown that lacks one.
- **FR-002c (doc-as-code branch ACs):** For Implement-track / Non-TDD (doc-as-code) phases, every conditional branch in the deliverable (a clause introduced by if/when/unless/otherwise/either, or an enumerated case) has a matching numbered AC. `qa-plan` must-fixes a conditional branch in the deliverable prose with no corresponding AC.
- **FR-002d (authoritative definition + authoring instruction):** `plan-concreteness.md` is the single authoritative home for the floor, the `[SPIKE]` marker, and the branch-AC rule; `plan/SKILL.md` carries a Phase-2 authoring rule that instructs the author and cites the reference; `templates/plan.md` carries the marker + branch-AC slots and cites the reference.
- **FR-002e (interim finalize-block + handoff):** The plan-skill finalize/sign-off step refuses to advance a plan to execute while any `[SPIKE: <unknown>]` survives in plan prose (skip fenced code + HTML comments), naming each offending phase. The reference doc documents this as the **interim** behavior and forward-references FR-005: the spike agent will resolve a `[SPIKE]` by emitting a **plan amendment** (Step 6c), after which the amended phases execute normally and this finalize-block is relaxed.

### Non-Functional Requirements

- **NFR-003 (backward-compatible, additive):** All changes are additive within the current major (NN-C-003). New `qa-plan` criteria are guarded so a concrete, `[SPIKE]`-free pre-existing plan receives no new must-fix. The finalize-block triggers only on a `[SPIKE]` marker — which did not exist before this piece — so a spike-free plan is unaffected.
- **NFR (agent self-containment):** The new `qa-plan` criteria are evaluable from the plan document text alone (qa-plan has no codebase access). Branch detection reads the plan's own enumerated branches/ACs; concreteness reads the phase's own deliverable triple — never the real target file.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-003 (backward compat within major): all additions are additive; guarded `qa-plan` criteria + spike-only finalize-block keep pre-existing concrete plans passing unchanged.
- NN-C-008 (agents self-contained): the new `qa-plan` criteria carry their own detection rules and operate only on injected plan text — no conversation history, no codebase access.
- NN-C-009 (version bump on any `plugins/*` change) + NN-C-001 (plugin/marketplace version sync): minor bump 5.3.0 → 5.4.0 applied to `plugin.json`, `marketplace.json`, and `CHANGELOG.md` in one coherent series.

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-001 (human gate on spec/plan never removed): the concreteness contract reduces execute-time surprises and review rounds; it does not remove or auto-pass the plan sign-off. The finalize-block adds a gate; it never removes one.
- NN-P-002 (no silent execute-time discovery/self-resolution): every unknown is forced to a visible `[SPIKE: <unknown>]` marker (must-fix if hidden) and, interim, may not survive to execute; the eventual resolution path is a recorded plan amendment, never a silent in-execute decision.

### Coding Rules Honored

- CR-008 (thin-orchestrator skills / narrow-executor agents): the finalize spike-scan is an orchestrator-side validator in `plan/SKILL.md` (alongside §2a/§2b); the concreteness/branch/unknown checks are agent-side review prose in `qa-plan.md`. Neither side crosses the boundary.
- CR-009 (markdown heading hierarchy): the new template slots are added as phase-header fields / conditional comments on existing `### Phase N:` exemplars; the Phase-Scheduler detection anchors (`### Phase N:` H3, `#### Sub-Phase N.m:` H4) are not altered.
- CR-005 (repo-root-relative paths): the new reference doc and all cross-file citations use repo-root-relative paths.
- CR-001 / CR-002 (frontmatter schemas): `qa-plan.md` and `plan/SKILL.md` frontmatter are unchanged; only body content is appended.

## Acceptance Criteria

AC-1: Given a plan phase whose deliverable lacks a target file, a location/anchor, or concrete content/signatures, When `qa-plan` reviews it, Then `qa-plan` returns a must-fix citing the per-phase concreteness criterion; given a phase that names file + anchor + concrete content, the same criterion is acceptable.
  Independent Test: dispatch `qa-plan` against a fixture plan containing one vague phase ("implement the new validator") and one concrete phase (`MODIFY plan/SKILL.md`, anchor `§2e`, with the exact rule text); assert the vague phase is must-fix and the concrete phase is not. (Maps FR-002 PRD AC-1.)

AC-2: Given a phase that defers/hedges a decision it cannot resolve, When the decision is left as ordinary prose (no marker), Then `qa-plan` must-fixes it as an unmarked unknown; When the same decision carries a `[SPIKE: <unknown>]` marker, Then `qa-plan` accepts it (not a must-fix on that basis).
  Independent Test: dispatch `qa-plan` against a fixture phase whose deliverable says "the exact threshold depends on profiling" with and without a `[SPIKE: real throughput ceiling]` marker; assert must-fix in the first case, acceptable in the second. (Maps FR-002 PRD AC-2.)

AC-3: Given an Implement-track / Non-TDD (doc-as-code) phase whose deliverable prose contains a conditional branch (if/when/unless/otherwise/either, or an enumerated case), When any such branch has no matching numbered AC, Then `qa-plan` must-fixes the phase naming the un-AC'd branch; When every branch has a matching AC, Then the criterion is acceptable.
  Independent Test: dispatch `qa-plan` against a fixture doc-as-code phase whose prose says "if merge strategy is `pr` … otherwise …" with (a) one AC and (b) one AC per branch; assert must-fix in (a) naming the missing branch, acceptable in (b). (Maps FR-002 PRD AC-3; codifies pi-011.)

AC-4: Given the repository after this piece, When `plugins/spec-flow/reference/plan-concreteness.md` is read, Then it authoritatively defines the concreteness floor, the `[SPIKE: <unknown>]` marker syntax + scan scoping, and the branch-enumeration-AC rule; and `plan/SKILL.md` (a Phase-2 authoring rule), `agents/qa-plan.md` (the new criteria), and `templates/plan.md` (the marker + branch-AC slots) each cite that reference rather than restating its definitions.
  Independent Test: assert `reference/plan-concreteness.md` exists and contains the three definitions; grep `plan/SKILL.md`, `qa-plan.md`, and `templates/plan.md` for the citation to `reference/plan-concreteness.md`.

AC-5: Given a plan that still contains a `[SPIKE: <unknown>]` marker in prose, When the plan-skill finalize/sign-off step runs, Then it refuses to advance the plan to execute and lists each offending phase; Given the marker appears only inside a fenced code block or an HTML comment, Then it is not counted and finalize proceeds; And the reference doc documents this finalize-block as interim with an explicit forward-reference to FR-005 (spike → plan amendment → normal downstream execution).
  Independent Test: run the finalize scan against a fixture plan with a surviving `[SPIKE]` in prose (expect refusal naming the phase), against a fixture with the marker only inside ``` fences / `<!-- -->` (expect proceed); grep the reference doc for the "interim" + "FR-005"/"spike-agent" + "plan amendment" forward-reference.

AC-6: Given a concrete, `[SPIKE]`-free plan authored before this piece, When `qa-plan` re-reviews it, Then the new criteria produce no new must-fix (backward-compatible, additive); And the plugin version is bumped to 5.4.0 consistently across `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and a new `CHANGELOG.md` entry.
  Independent Test: dispatch `qa-plan` against a known-good pre-existing plan fixture and assert zero new must-fix from criteria #28+; `diff` the three version strings for equality and assert a `## [5.4.0]` CHANGELOG section with at least one populated grouping.

## Technical Approach

**Define-once, cite-everywhere.** `reference/plan-concreteness.md` is the authoritative home (matching `research-artifact.md`'s opening-line convention). Three consuming files cite it:
- **`plan/SKILL.md`** — a new Phase-2 authoring rule (append after §2e as §2f, and/or a §9d AC-discipline note) tells the author to (1) make each phase concrete (file + anchor + content), (2) mark genuine unknowns `[SPIKE: <unknown>]`, (3) enumerate doc-as-code conditional branches as numbered ACs. The finalize spike-scan is an orchestrator-side validator in the finalize/sign-off path (Phase 4), reusing the `[PENDING-DECISION]` scan idiom already in plan Prerequisites (skip fenced code + HTML comments; only raw prose markers count).
- **`agents/qa-plan.md`** — criteria #28+ in `## Review Criteria`, each a sibling to crit 16/19/23 with an activation guard, a **Flag:** list, an **Evidence:** requirement, and **Must-fix.**. The branch-AC criterion is evaluable from plan text alone: it reads the phase's own enumerated branches and ACs, never the real deliverable file.
- **`templates/plan.md`** — the `[SPIKE: <unknown>]` marker convention and a branch-enumeration-AC slot on the Implement-track / Non-TDD exemplar, documented in the existing conditional-comment style.

**`[SPIKE: <unknown>]` marker.** Bracket + uppercase token + colon + free-text param, exactly parallel to `[PENDING-DECISION: <area>]` (the closest existing analog). It is a distinct marker family from the RESEARCH markers (`[RESEARCH-CONSUMED/ABSENT/UNAVAILABLE]`) added by `research-unify`. Interim semantics: a `[SPIKE]` is the sanctioned way to surface a genuine unknown at authoring time, must be cleared (resolved) before plan finalize, and is reusable by `test-data-up` (FR-003) for unpredictable TDD outcomes.

**Concreteness floor robustness.** The floor's primary test is presence of the concrete triple (file + anchor + content). The vague-verb list is illustrative, scoped to deliverable/TARGET prose, so legitimate occurrences ("the `[Implement]` block", "implementer agent") do not false-positive — directly resolving the backlog's brittleness concern.

**Dogfood.** This piece's own plan is an Implement-track doc-as-code plan; it is subject to its own concreteness floor and branch-enumeration-AC rule (e.g., the qa-plan criterion's marked-vs-unmarked and fenced-vs-prose branches must each be a numbered AC).

## Testing Strategy

- **Unit focus:** N/A — SKILL/agent/template/reference are prose instructions, not executable code (per pi-011 testing doctrine). "Tests" are structural reads + adversarial review.
- **Verification (Implement-track `[Verify]` steps):** crit-presence reads — e.g., confirm `qa-plan.md` criterion #28 contains the concreteness-floor language and the vague-verb list; confirm `plan/SKILL.md` Phase 2 contains the authoring rule + the `reference/plan-concreteness.md` citation; confirm the finalize scan text + fenced/HTML-comment scoping; confirm template slots; confirm version strings match.
- **Adversarial gate:** `qa-plan` against fixture plans (vague vs concrete phase; marked vs unmarked unknown; doc-as-code branch with/without per-branch AC; known-good pre-existing plan for backward-compat) — these are the AC Independent Tests.
- **Edge cases:** `[SPIKE]` inside fenced code / HTML comment (not counted); a vague verb appearing in legitimate non-deliverable prose (not flagged); a TDD phase (branch-AC rule does not apply — doc-as-code only); a pre-existing spike-free concrete plan (no new must-fix).

## Integration Coverage

None in scope. This piece is coordinated doc-as-code edits across four files (`reference/plan-concreteness.md`, `plan/SKILL.md`, `qa-plan.md`, `templates/plan.md`) with no cross-component runtime wiring and no true externals to double. The cross-file *consistency* concern (authoritative definition vs three citers staying aligned) is the codebase's standard cross-phase schema-consistency discipline, verified by the per-file `[Verify]` crit-presence reads above, not an integration boundary.

## Open Questions

All brainstorm open questions resolved:
- **Doc-as-code "exact prose" concreteness bar (PRD open question)** → resolved: mechanically checkable concrete triple (file + anchor + content) as the primary gate; vague-verb list as scoped illustrative signal (FR-002a).
- **Contract home** → resolved: new authoritative `reference/plan-concreteness.md` + cited from SKILL + qa-plan + template (FR-002d).
- **Branch-AC enforcement under no-codebase-access qa-plan** → resolved: AC-per-branch authored by the plan author; qa-plan scans the deliverable prose for conditional clauses lacking a matching AC (FR-002c).
- **`[SPIKE]` interim behavior** → resolved: finalize-block now; reference doc forward-references FR-005's spike→plan-amendment relaxation (FR-002e).

## Explicitly Out of Scope / Deferred

- **Spike resolver (Opus spike agent + execute-time `[SPIKE]` dispatch + plan-amendment-from-spike)** → owned by `spike-agent` (FR-005). This piece's finalize-block is the interim guard until that lands.
- **Zero-unmarked-discovery measurement at execute Step 6c (PRD FR-002 AC-4 / SC-003)** → observational, cross-piece outcome; not enforced or instrumented here.
- **`[SPIKE]`-as-test-data fallback for non-deterministic TDD outcomes** → owned by `test-data-up` (FR-003); this piece keeps the marker syntax reusable for it.
