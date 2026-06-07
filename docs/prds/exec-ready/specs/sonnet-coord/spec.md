---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: sonnet-coord — Lean Sonnet coordinator on file-based state

**PRD Sections:** FR-004, NFR-002, NFR-003, NFR-004, G-3, G-4
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** plan-concrete (merged)

## Goal

Make the execute coordinator run **lean on Sonnet over long pieces**. Leanness has two mechanisms: (1) the coordinator re-derives its resume position from **on-disk state**, holding minimal state in-context, so its context does not grow unbounded across a long-running piece; and (2) every agent returns a **bounded, structured summary** to the coordinator rather than a raw dump, so the coordinator's context is fed optimized input. Around that core, this piece formalizes the already-correct per-stage model assignment into a **declared, reported model policy** that flags only sanctioned exceptions, and makes the QA fix-loop circuit-breaker **configurable** (fixing the pi-011 hard-3 defect for doc-as-code pieces). All additions are additive and opt-out (NFR-003).

This piece does **not** rewire model dispatch — verification against the dispatch sites confirmed the split is already correct: the **deep-reasoning stages** already dispatch `model: "opus"` (spec/plan authoring, the per-phase full `qa-phase` review, the mid-piece Opus QA pass, and the 8–9 Final Review board agents) and the **mechanics + transcription + narrow-review stages** already dispatch `model: "sonnet"` (implementer, `tdd-red`, `qa-tdd-red`, `verify`, `refactor`, `fix-code`, `qa-phase-lite`, and both reflection agents). So G-3 / NN-P-005 are already satisfied at the dispatch sites. The new surface is *declaration, reporting, configurability, and disk-derivable-state discipline*, not new wiring.

## In Scope

- **Model-policy framework** in execute: a declared per-stage model table (documenting the existing sonnet-mechanics / opus-thinking assignment), a start-of-run report of the per-stage assignment, and an exception-reporting structure that names exactly two sanctioned exceptions abstractly — *spike phase → Opus* and *operator override → Opus*. The policy reports the assignment and flags only these exceptions (FR-004 AC-1).
- **Opt-out model-policy config key** `model_policy: auto|off` (NFR-003). `auto` (default; absent → `auto`) = the new report-and-flag-exceptions behavior. `off` = preserve today's single bbcf58c pre-flight "Model Check" prompt only, with no per-stage report.
- **Lean coordinator return discipline** (operationalizes the "optimized input from agents" goal under G-3/G-4): an explicit contract that every agent return to the coordinator is a bounded, structured summary, with raw artifacts (diffs, full test output, file bodies) living on disk/git and referenced by path — never pasted into the coordinator's context. Plus an **audit table** classifying each existing execute dispatch's current return shape and flagging any non-compliant dispatch for correction.
- **Configurable QA circuit-breaker** key `qa_max_iterations: auto|<int>` (NFR-003). Default `auto` resolves per piece track: **5** for doc-as-code/Implement pieces, **3** for TDD/behavior pieces. An explicit integer overrides for all governed loops. The key governs the **five QA-agent fix-loop breakers** that defer to `reference/qa-iteration-loop.md` (Final Review fix loop, per-phase `qa-phase`, mid-piece Opus pass, Group Deep QA, `qa-phase-lite`). `reference/qa-iteration-loop.md`'s "3-iter" prose is parameterized to reference the key (default 3 preserves current behavior).
- **File-based resume state + `[STATE-INCOMPLETE: <field>]` escalation** (NFR-002): a canonical resume-critical field table with a three-tier classification, plus the escalation rule and its computable predicate.
- **Plugin version bump** 5.5.0 → 5.6.0 across all four version-bearing files + CHANGELOG (NFR-004), and a sync-verification on touch.
- **Canonical reference doc** `plugins/spec-flow/reference/coordinator-contract.md` holding the model-policy table, the return discipline, the exception categories, and the resume-critical field-tier table; execute *cites* it (keeps the 1863-line execute SKILL lean, matching the `deferred-commit-journal.md` / `qa-iteration-loop.md` / `research-artifact.md` reference-doc convention).

## Out of Scope / Non-Goals

- **The operator-override mechanism itself** (the flag/config that forces Opus for a named piece/phase) and the **`[SPIKE]` Opus dispatch wiring** — owned by `spike-agent` (FR-005 AC-3), which `depends_on: sonnet-coord`. This piece defines only the *reporting framework* that names these two exceptions abstractly; `spike-agent` wires the mechanisms into it. (Avoids a forward dependency and duplicate ownership.)
- **Rewiring model dispatch** — dispatch-site `model:` fields are already correct; this piece declares and reports the policy, it does not change which model any stage runs on (beyond the sanctioned exceptions, which are wired by `spike-agent`).
- **A data-driven per-stage model map** in config — model assignment stays deterministic in the SKILL text (which is itself on-disk, hence re-derivable); only the opt-out `model_policy` scalar is added, not a per-stage override map.
- **Making the oracle 2-attempt build budget or the mechanical SKILL self-lint breaker configurable** — these are not QA-agent review-cycle loops (one is a build-retry budget, one is a deterministic linter) and are left unchanged.
- **Per-stage numeric return-token caps** — the return discipline is a qualitative, inspectable contract, not brittle token math (the repo has no automated test harness to enforce numeric caps).

## Requirements

### Functional Requirements

- **FR-004.1 (Model policy + report):** Execute declares a per-stage model policy table. The table is **derived from and must agree with the actual `Agent({… model:})` dispatch sites** (AC-1's Independent Test enforces this agreement) — it documents, it does not redefine. The split it documents: **Opus** for the deep-reasoning stages (spec/plan authoring — upstream of execute; the per-phase full `qa-phase` review; the mid-piece Opus QA pass; the Final Review board agents) and **Sonnet** for the coordinator and the mechanics + transcription + narrow-review stages (implementer, `tdd-red`, `qa-tdd-red`, `verify`, `refactor`, `fix-code`, `qa-phase-lite`, reflection). At execute start, when `model_policy: auto`, the coordinator reports the per-stage assignment and flags only the two sanctioned exceptions (spike → Opus; operator override → Opus). It never silently upgrades a non-`[SPIKE]` stage to Opus.
- **FR-004.2 (Opt-out):** `model_policy: off` preserves today's single bbcf58c pre-flight Model Check prompt and emits no per-stage report. Absent key → `auto`.
- **FR-004.3 (Lean return discipline):** Execute carries a coordinator return-discipline contract: every agent return to the coordinator is a bounded structured summary; raw diffs / full test output / file bodies live on disk or git and are referenced by path, never pasted into the coordinator's context. An audit table classifies each existing dispatch's return shape; any dispatch that pastes a raw dump is corrected to return a bounded summary + reference.
- **FR-004.4 (Configurable breaker):** The QA fix-loop circuit-breaker limit is read from `.spec-flow.yaml` key `qa_max_iterations` (default `auto` = 5 doc-as-code / 3 TDD; explicit int overrides) and threads into all five governed QA-agent fix loops. `reference/qa-iteration-loop.md` is parameterized to reference the key with default 3.
- **FR-004.5 (Resume from disk):** All resume-critical coordinator state is re-derivable from disk per the canonical field-tier table. A coordinator started in a fresh context resumes from the last clean checkpoint using only on-disk state, re-running no passing phase.
- **FR-004.6 (STATE-INCOMPLETE escalation):** When a resume-critical field is *expected-present given the current resume position* but missing or corrupt, the coordinator emits `[STATE-INCOMPLETE: <field>]` and escalates to the operator rather than guessing. Valid absences and cosmetic fields do not escalate.
- **FR-004.7 (Version bump + sync):** The plugin version is bumped 5.5.0 → 5.6.0 across `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, the `.claude-plugin/marketplace.json` spec-flow entry, and a new `CHANGELOG.md` section; all four version strings are verified identical on touch (NFR-004's "5.2.1 skew" is already resolved — this is a sync-verify, not a fix).

### Non-Functional Requirements

- **NFR-002 (Disk-derivable state):** No resume-critical coordinator state exists only in the in-context transcript. The canonical field-tier table names, for every resume-critical field, its on-disk home (or its recompute source). A coordinator re-started in a fresh context reaches the same next action from on-disk state alone.
- **NFR-003 (Additive / opt-out):** All changes are additive and backward-compatible within the current major. `model_policy` and `qa_max_iterations` default to current behavior when absent (`auto`/`auto`); `model_policy: off` and an explicit `qa_max_iterations: 3` restore exact pre-change behavior. The parameterized `qa-iteration-loop.md` default (3) preserves TDD-piece behavior unchanged.
- **NFR-004 (Version + self-containment):** Minor version bump in all version-bearing files; any new reference doc and edited skill prose remain self-contained. No new agents are created; no agent frontmatter is changed.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-003 (Backward compat within a major): every new config key defaults to current behavior when absent; `model_policy: off` and `qa_max_iterations: 3` exactly restore pre-change behavior; no config key, skill name, template header, or hook contract is removed or renamed.
- NN-C-009 (Always bump version, all files): minor bump 5.5.0 → 5.6.0 in all four version-bearing files per `plugins/spec-flow/docs/releasing.md`, with a CHANGELOG `## [5.6.0]` section carrying at least one non-empty grouping.
- NN-C-001 (version ⇄ marketplace sync): the marketplace entry is bumped in lockstep with `plugin.json`; the spec's sync-verify step re-runs the `releasing.md` grep recipe.
- NN-C-005 (silent no-op on absent optional input) — *applied by analogy to execute's config reads*: an absent `model_policy`/`qa_max_iterations` key uses the default with no error; a malformed value emits a one-line warning and falls back to the default rather than blocking.

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-005 (Thinking on Opus, mechanics on Sonnet — no silent upgrade): the model policy asserts the stage→model assignment and flags the only two sanctioned upgrades (spike, override); it adds no execute path that upgrades a non-`[SPIKE]` stage to Opus.
- NN-P-003 (Execute loop is operator-invoked only): nothing in the model-policy report, the configurable breaker, or the resume logic adds a self-invocation path; resume remains operator-initiated.

### Coding Rules Honored

- CR-007 (Config keys documented inline): `model_policy` and `qa_max_iterations` are added to `plugins/spec-flow/templates/pipeline-config.yaml` with a leading comment block listing valid values, the default, and the rationale, matching the `refactor` / `deferred_commit` idiom.
- CR-008 (Thin-orchestrator skills): all logic stays in the execute orchestrator skill + the cited reference doc; no agent is made to dispatch sub-agents and no implementation logic moves into an agent.
- CR-009 (Heading hierarchy): the new reference doc and edited execute sections preserve the H2/H3/H4 hierarchy; no `### Phase N` / `#### Sub-Phase N.m` detection anchors are altered.
- CR-005 (Repo-root-relative paths in docs): the new reference doc and all cross-references use repo-root-relative paths.

## Acceptance Criteria

**AC-1 (Model policy declared + reported).** Given `model_policy: auto` (or absent), When execute starts, Then the coordinator emits a per-stage model-assignment report and the report flags exactly the two sanctioned exception categories (spike → Opus; operator override → Opus) and no others.
  Independent Test: read the execute SKILL + `reference/coordinator-contract.md`; confirm a per-stage model table exists, a start-of-run report step references it, and the exception list contains exactly {spike, operator-override}. Diff each table row that maps to an in-execute dispatch site against that `Agent({… model:})` call — they must agree. (Rows for spec/plan authoring are upstream-context only — they are not execute dispatches and are excluded from this diff.)

**AC-2 (Opt-out preserves legacy).** Given `model_policy: off`, When execute starts, Then today's single bbcf58c "Model Check" Override/Change-now/Cancel prompt runs and no per-stage report is emitted.
  Independent Test: inspect the `model_policy: off` branch in execute; confirm it routes to the existing Pre-flight Model Check unchanged and emits no report.

**AC-3 (No silent Opus upgrade).** Given any non-`[SPIKE]` stage, When the coordinator assigns a model, Then it assigns the policy-declared model and never upgrades to Opus outside the two sanctioned exceptions.
  Independent Test: grep execute for any path that raises a non-`[SPIKE]` stage to Opus without the operator-override flag; there must be none. (Spec-compliance reviewer verifies NN-P-005.)

**AC-4 (Lean return discipline + audit).** Given the execute SKILL, When reviewed, Then it states the coordinator return-discipline contract (bounded structured summaries; raw artifacts by reference) and carries an audit table classifying each dispatch's return shape, with every dispatch either compliant or corrected.
  Independent Test: read the return-discipline section + audit table; confirm each execute dispatch appears as a row marked compliant; confirm no remaining dispatch instructs an agent to paste a raw diff / full test output / file body into its return.

**AC-5 (Configurable breaker — auto default).** Given `qa_max_iterations: auto` (or absent), When a doc-as-code piece runs a QA fix loop, Then the limit is 5; for a TDD piece it is 3. Given an explicit integer, Then all five governed QA fix loops use that integer.
  Independent Test: read the Step 0 config-load + each of the five fix-loop sites; confirm each reads the resolved value (not a hard-coded 3); confirm `reference/qa-iteration-loop.md` references the key with default 3; confirm the per-track resolution (5 doc-as-code / 3 TDD) is stated.

**AC-6 (Breaker backward-compat).** Given the key is absent and the piece is a TDD piece, When any governed QA fix loop runs, Then it behaves byte-for-byte as before (limit 3, escalate on iter-3 must-fix).
  Independent Test: confirm absent-key + TDD-track resolves to 3 and the escalation semantics in `qa-iteration-loop.md` are unchanged for that value.

**AC-7 (Resume from disk, no re-run).** Given a piece interrupted mid-flight (e.g. `/clear`), When the coordinator restarts in a fresh context, Then it resumes from the last clean checkpoint using only on-disk state and re-runs no already-passing phase.
  Independent Test: a manual forced-`/clear`-then-resume smoke run on a partially-executed piece reaches the same next action; cross-check the field-tier table — every field needed to compute "next action" has a named on-disk home or recompute source.

**AC-8 (STATE-INCOMPLETE predicate).** Given a resume-critical field that is expected-present at the current resume position but missing/corrupt, When the coordinator resumes, Then it emits `[STATE-INCOMPLETE: <field>]` and escalates rather than guessing; Given a valid absence (no group in flight → no journal; mid-piece pass not yet fired → no `.orchestra-state.json`) or a cosmetic field, Then it continues without escalation.
  Independent Test: walk the field-tier table; for each tier-1 field confirm an "expected-present given current position" predicate is stated and is computable from disk (plan.md checkboxes + HEAD); confirm tier-3 (valid-absence/defensive-default) preserves the line-932 behavior; confirm the journal-absent case is tier-1 only when position shows a group in flight, else tier-3.

**AC-9 (Version bump + sync).** Given this piece's changes, When committed, Then all four version-bearing files read 5.6.0 identically and CHANGELOG carries a `## [5.6.0] — <date>` section with a non-empty grouping.
  Independent Test: run the `plugins/spec-flow/docs/releasing.md` grep recipe — all four version strings print 5.6.0; CHANGELOG top section is `## [5.6.0]`.

## Technical Approach

**Edit targets.** `plugins/spec-flow/skills/execute/SKILL.md` (model-policy report step at Step 0/Pre-flight; config reads at Step 0; the five fix-loop breaker sites; the Session Resumability + Escalation Rules sections; return-discipline + audit table); `plugins/spec-flow/reference/qa-iteration-loop.md` (parameterize the 3-iter prose); new `plugins/spec-flow/reference/coordinator-contract.md` (canonical definitions); `plugins/spec-flow/templates/pipeline-config.yaml` (two new keys); the four version-bearing files + `plugins/spec-flow/CHANGELOG.md`.

**Model policy.** Deterministic per-stage table lives in `coordinator-contract.md`; execute cites it and, under `model_policy: auto`, emits a report at start. Model assignment is *not* moved to config — it stays at the `Agent({… model:})` dispatch sites (already correct and on-disk in the SKILL, hence re-derivable). The two sanctioned exceptions are named abstractly; `spike-agent` later wires their mechanisms.

**Configurable breaker.** `qa_max_iterations` is read once at Step 0. `auto` resolves to 5 (doc-as-code/Implement track) or 3 (TDD/behavior track) from the piece/plan track already known to execute. The resolved integer threads into the five governed fix loops. `qa-iteration-loop.md` states the limit as "`qa_max_iterations` (default 3)" so its semantics (escalate on the final must-fix iteration; never run limit+1) are value-parameterized.

**Resume-state three tiers** (canonical table in `coordinator-contract.md`):
- *Tier 1 — escalate `[STATE-INCOMPLETE]`*: plan.md (and its `[x]` checkboxes); the Phase Group journal's `sub_phases[].status` and `red_manifest_hashes` **when position shows a group in flight**. Predicate "group in flight" = computable from plan.md checkboxes (a Phase Group's first sub-phase checked but the group not fully checked) + HEAD, defined explicitly.
- *Tier 2 — recompute, no escalation*: phase-start SHA (`git rev-parse HEAD` minus this phase's already-committed steps), amendment counters (count from branch history).
- *Tier 3 — valid absence / defensive default, no escalation*: journal absent **with no group in flight** (= fresh start / flat phases); `.orchestra-state.json` absent (= mid-piece Opus pass not yet dispatched); cosmetic discovery-row fields (substitute `unknown`, per current line 932 — preserved).

**Return discipline.** A contract section + an audit table (`stage | current return shape | compliant?`) over every execute dispatch (research, tdd-red, qa-tdd-red, implementer, verify, refactor, qa-phase, qa-phase-lite, the fix-code loops, the 8–9 board agents, reflection). Non-compliant rows get a one-line correction directive in the dispatch prose.

**Data flow.** `.spec-flow.yaml` → Step 0 reads `model_policy` + `qa_max_iterations` (absent/invalid → default + optional warning) → values thread into the start-of-run report and the five fix loops. Resume path: disk (plan.md + HEAD + journal + `.orchestra-state.json`) → field-tier classifier → next action, or `[STATE-INCOMPLETE]` escalation.

## Testing Strategy

- **No automated harness** (markdown/YAML plugin; charter-tools). Verification is by qa-plan / review-board reading the SKILL + reference docs for internal consistency, and by manual smoke runs.
- **Inspectable-invariant ACs:** most ACs are phrased so a reviewer can diff the declared policy/table against the dispatch sites and config reads (AC-1, AC-3, AC-4, AC-5, AC-6, AC-8, AC-9).
- **Manual smoke (AC-7):** a forced `/clear`-then-resume on a partially-executed piece, confirming the same next action with no passing-phase re-run.
- **Edge cases to cover:** absent config keys (→ defaults); malformed config value (→ warn + default); journal absent with a group in flight (→ tier-1 escalate) vs. without (→ tier-3 continue); `model_policy: off` (→ legacy prompt only); doc-as-code vs TDD track resolution of `auto`.

## Integration Coverage

None in scope. This is a doc-as-code piece: the new config-key reads follow the existing Step 0 config-read pattern (no new external boundary), and the model-policy exception contract is an internal forward-reference that `spike-agent` consumes later (verified by that piece's own coverage, not here).

## Open Questions

None. The PRD/backlog open questions for this piece (`model_policy` + `circuit_breaker.docs` `.spec-flow.yaml` key shapes) are resolved above: `model_policy: auto|off` and `qa_max_iterations: auto|<int>` (default `auto` = 5 doc-as-code / 3 TDD). The plugin-registry path / pattern-granularity open questions belong to the flywheel pieces, not this one.
