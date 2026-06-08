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

# Plan: spike-agent — Opus spike agent + mid-execution scope-change workflow

**Spec:** docs/prds/exec-ready/specs/spike-agent/spec.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** draft

## Overview

Non-TDD mode: all phases use the Implement track (`[Implement]` → `[Verify]` → `[QA]`); there are no `[TDD-Red]`/`[Build]` phases and no `[Write-Tests]` steps because this is a markdown/YAML/bash plugin with no test runner (charter-tools). Verification is by-inspection (grep/read assertions on the SKILL/agent/reference prose) plus the `releasing.md` version recipe. AC Coverage Matrix IS included (11 ACs); QA and Final Review remain fully intact.

Build order is inside-out: the canonical contract doc (`reference/spike-agent.md`, Phase 1) is authored first because every other edit cites it; then the spike agent (Phase 2); then the `plan-amend` placement-directive extension (Phase 3); then the plan-finalize gate relaxation (Phase 4); then the three execute-wiring phases (Phases 5–7, all editing `execute/SKILL.md` — serial because they share that file); then the version bump (Phase 8, last). Everything is additive (NN-C-003): a piece with no `[SPIKE]` markers and no mid-execution change runs exactly as today.

**Cross-cutting charter constraints (declared, not incidental duplicates).** Six entries are honored in more than one phase because each phase honors a *distinct facet* — the per-phase slot names which: **NN-C-003** (backward-compat) — the directive default in Phase 3, the gate relaxation in Phase 4, placement/budget resume-from-disk in Phase 7; **NN-C-008** (self-contained dispatch) — the agent in Phase 2 and each new dispatch site in Phases 3/5/6; **NN-C-002** (no runtime deps) — the new doc (Phase 1) and the new agent (Phase 2); **CR-009** (heading hierarchy + `phase_<N>_amend_<K>` anchors) — every file-editing phase (1/3/4/5/7); **NN-P-002** (no silent/mid-stream change) — Step 6c admission/gate in Phase 6 and placement/budget in Phase 7; **NN-P-005** (Opus-thinking/Sonnet-mechanics) — resolve in Phase 5 and scope in Phase 6. These are cross-cutting by nature, not allocation drift.

## Architectural Decisions

### ADR-1: One agent, two modes (resolve | scope)
**Context:** FR-005 (resolve a planned `[SPIKE]`) and FR-008 (scope a mid-execution change) both need isolated Opus thinking that emits a structured artifact. Either one agent with a `mode:` switch or two separate agents.
**Decision:** One agent `agents/spike.md` with an injected `mode:` (`resolve` | `scope`). Shared: Opus, isolated context, ≤2K digest, `STATUS: OK|BLOCKED`, no-partial-on-BLOCKED, no sub-agents. Mode-specific inputs/outputs.
**Alternatives considered:** (a) Two agents (`spike-resolve.md` + `spike-scope.md`) — rejected: fragments the shared primitive, duplicates the isolation/return contract, two files to keep in sync. (b) Fold scoping into `plan-amend` — rejected: `plan-amend` is `model: sonnet`; Opus thinking inside it violates NN-P-005.
**Consequences:** One contract to maintain; the two call sites branch on `mode:`. Slightly more dispatch-site logic in execute. Reversible (could split later).
**Charter alignment:** NN-P-005 (Opus thinking isolated from Sonnet mechanics); CR-008 (single-task agent, no sub-agents); NN-C-004/008 (self-contained, bare name).

### ADR-2: Placement owned by plan-amend via an optional directive
**Context:** Block-aware placement (FR-008.3) must position amendment phases differently per classification, but `plan-amend` today hardcodes "insert before the next original phase" (`plan-amend.md` L34). Either execute re-anchors the emitted diff, or `plan-amend` takes a directive.
**Decision:** `plan-amend` gains an OPTIONAL `Placement directive:` input; execute computes the classification (from the scope spike) and passes it; `plan-amend` encodes the chosen insertion position in its diff. Absent directive → today's before-next-phase default (backward-compat).
**Alternatives considered:** (a) Execute re-anchors the diff post-emission — rejected: re-positioning a unified diff is fragile (drifted hunks, context mismatch) and duplicates `plan-amend`'s phase-insertion logic. (b) New dedicated placement agent — rejected: overkill.
**Consequences:** `plan-amend`'s diff *format* is unchanged; its positioning becomes directive-driven. Legacy callers (no directive) behave identically. One merged-agent contract is extended (additive).
**Charter alignment:** NN-C-003 (additive, default preserves behavior); CR-009 (heading hierarchy + `phase_<N>_amend_<K>` convention preserved).

### ADR-3: Operator-change admission via detect-and-confirm
**Context:** Execute has no classifier distinguishing an operator scope-change ("add X") from a normal answer. Options: explicit gesture, auto-classify, or detect+confirm.
**Decision:** The Sonnet coordinator flags a free-form operator turn that reads as a behavior/scope change and asks ONE `y/n` confirmation before admitting it to Step 6c. Detection is suppressed while execute awaits a structured answer to its own prompt.
**Alternatives considered:** (a) Explicit gesture/sentinel — rejected: a forgotten gesture reintroduces the "fix mid-stream" failure. (b) Auto-classify, no confirm — rejected: false-positives trigger spurious spike+amend cycles.
**Consequences:** Broad trigger + cheap confirm biases to avoid false-negatives (the failure being fixed); accepts occasional false-positive (one `y/n`). Respects NN-P-002 operator triage.
**Charter alignment:** NN-P-002 (synchronous operator triage); NN-P-003 (reacts to operator input — no self-invocation).

### ADR-4: Soft-checkpoint amendment budget (keep count, drop the wall)
**Context:** FR-008 raises amendment frequency (scope→amend). Today's budget hard-refuses at 5 and locks out further amendments. Options: keep wall, remove budget, soft checkpoint.
**Decision:** Keep both counters and the threshold; replace the hard refusal + amend-lockout with a guidance prompt (`continue / fork / defer / block`) that re-surfaces on each amendment past threshold; `continue` dispatches the amendment.
**Alternatives considered:** (a) Remove the budget — rejected: loses the "this piece was under-scoped" flywheel signal (FR-006). (b) Configurable behavior key — rejected: adds config surface for marginal benefit (YAGNI).
**Consequences:** The under-scoped signal survives as the count; the operator is never hard-stopped. `block` still reproduces today's halt outcome (operator-chosen).
**Charter alignment:** NN-P-002/NN-P-004 (operator-gated, no forced/silent outcome); NN-C-006 (operator confirmation, not forced halt).

### ADR-5: Plan-finalize gate relaxation lands in this piece
**Context:** Discovered at plan time — resolve mode (AC-2) needs a `[SPIKE]` to survive plan-finalize into execute, but the finalize gate hard-refuses. `plan-concreteness.md` §4 (L128) explicitly defers this relaxation to FR-005.
**Decision:** Relax `plan/SKILL.md` Phase-4 finalize spike-scan from hard-refuse to routed-resolution annotation; update `plan-concreteness.md` §4 to mark FR-005 shipped. Spec amended (FR-005.4 / AC-11) before this plan.
**Alternatives considered:** (a) Separate follow-up piece — rejected: ships FR-005 non-functional (resolve mode dead) until a second piece lands; contradicts "don't ship half-done." (b) Leave gate intact — rejected: makes resolve mode unreachable.
**Consequences:** A *marked* `[SPIKE]` now advances through finalize (strictly more permissive, the intended direction); unmarked unknowns still fail qa-plan #29.
**Charter alignment:** NN-C-003 (more permissive, nothing removed); NN-P-002 (the marked spike is the sanctioned, recorded resolution path).

## Phases

## Integration-Test Registry (M1)

None in scope. The spec's `## Integration Coverage` entries (execute↔spike, spike→plan-amend, spike→tdd-red, --opus→model-policy) are **in-plugin documentary contracts** with no true external to double and no outer wired-path test (markdown/YAML/bash plugin; charter-tools — no test runner). Each is verified by reading producer + consumer for schema/branch agreement (the by-inspection `[Verify]` blocks below + the cross-phase consistency check in Phase 7). Absent registry ⇒ no integrations declared (NFR-INT-02).

### Phase 1: Canonical contract doc — `reference/spike-agent.md`
**Exit Gate:** `reference/spike-agent.md` exists and defines all six contracts (agent two-mode I/O; spike-artifact schema + location; change-classification rule with three classes; block-aware placement rule; threshold-reuse rule; soft-checkpoint budget rule) + the no-bypass gate invariant; `grep` confirms each section header present.
**ACs Covered:** AC-1 (contract surface), AC-5 (threshold rule def), AC-6 (classification + placement def), AC-7 (budget rule def), AC-10 (gate invariant def)
**In scope:** CREATE `plugins/spec-flow/reference/spike-agent.md` only.
**NOT in scope:** the agent file (Phase 2); any execute/plan-amend/plan wiring (Phases 3–7). This phase writes definitions; consumers cite them later.
**Charter constraints honored in this phase:**
- CR-005 (repo-root-relative paths): all cross-references in the doc use repo-root-relative paths.
- CR-009 (heading hierarchy): H2/H3 section structure matching `coordinator-contract.md` / `research-artifact.md`.
- NN-C-002 (no runtime deps): pure markdown, no tooling introduced.

- [x] **[Implement]** Author the canonical contract doc
  - Architecture constraints: define-once/cite-everywhere — every definition this piece needs lives here; execute/plan-amend/plan/plan-concreteness cite it and do not restate. Mirror the section style of `reference/coordinator-contract.md`.

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/reference/spike-agent.md`**
  - Structure outline (H2 sections, in order):
    1. Intro paragraph — "single source of truth for the spike agent (`agents/spike.md`), its two modes, the spike-artifact schema, the change-classification + placement rules, the threshold-reuse rule, and the soft-checkpoint budget. Cited by `agents/spike.md`, `skills/execute/SKILL.md` (Step 6c + `[SPIKE]` dispatch + budget), `agents/plan-amend.md` (placement directive), and `skills/plan/SKILL.md` (Phase-4 finalize). Definitions live here and nowhere else."
    2. `## Agent modes` — table: `mode` | trigger | inputs | output. `resolve`: trigger = a `[SPIKE]` plan phase; inputs = the `[SPIKE]` marker text + phase plan context + (if a test oracle) the `Test Data` skeleton to fill; output = the resolution recorded to the artifact (+ a `Test Data` block when the unknown is a test oracle). `scope`: trigger = an admitted mid-execution change above threshold; inputs = the change text (operator request or discovery `row_text`) + current plan + diff/neighborhood scope; output = the scoping artifact (classification + enumerated task list) consumed by `plan-amend`. Both: Opus, isolated, ≤2K digest, `STATUS: OK|BLOCKED`, BLOCKED writes no partial artifact, dispatches no sub-agents.
    3. `## Spike artifact` — `## Location`: `docs/prds/<prd-slug>/specs/<piece-slug>/spikes/<id>.md` (`<id>` = phase id for resolve, discovery/change id for scope). `### Schema`: bold-labelled fields in order — `**Mode:**` (resolve|scope) · `**Trigger:**` (unknown or change text) · `**Classification:**` (scope mode only: `blocking-on-current` | `blocking-on-later` | `additive`) · `**Scope / Task list:**` (enumerated) · `**Resolution:**` (resolve mode: the answer) · optional `**Test Data:**` block (plan-concreteness §5 schema — cite, do not restate). `### No secrets` — never transcribe credentials.
    4. `## Change classification` — the three classes with the exact rule: `blocking-on-current` = the change targets the in-progress phase's own deliverable → that phase is re-planned and re-run; `blocking-on-later` = a not-yet-started phase depends on the change → inserted before that dependent phase, current WIP finishes first; `additive` = no existing phase depends on it → appended at a dependency-correct position after current WIP.
    5. `## Placement rule` — placement is realized via `plan-amend`'s optional placement directive (execute computes the class, passes it; `plan-amend` encodes position; absent → before-next-phase default). No amendment phase preempts the in-progress phase except `blocking-on-current` or an explicit operator force-stop. Resume re-derives placement from plan.md checkboxes + amendment IDs on disk.
    6. `## Threshold reuse` — the existing 50% diff-ratio gate (absorption-size ÷ cumulative-diff) is evaluated for every admitted change in BOTH `--auto` and operator modes; `ratio ≥ 0.5` (and the undefined-ratio / zero-cumulative-diff case) → scope spike before `plan-amend`; `ratio < 0.5` → direct amend. No new config key; reuses the value at `execute/SKILL.md` threshold computation.
    7. `## Soft-checkpoint budget` — keep both counters (`piece_amendment_count`, `piece_spec_amendment_count`) and the resume-recovery grep; at threshold (default 5 total; 1 spec sub-cap) prompt `continue / fork / defer / block` and re-surface on each subsequent amendment; `continue` dispatches; count never resets, never hard-blocks; `block` = operator-chosen halt.
    8. `## No-bypass gate` — invariant: no execute path applies an above-threshold mid-execution change without a scope spike then a plan amendment; verified by qa-plan + review-board spec-compliance per NN-P-002.
    9. `## See also` — `agents/spike.md`, `skills/execute/SKILL.md`, `agents/plan-amend.md`, `skills/plan/SKILL.md`, `reference/plan-concreteness.md`, `reference/coordinator-contract.md`.
  - Pattern (section/intro style from `reference/coordinator-contract.md`):
    ```
    ## Model Policy

    The table below documents the model assigned to each in-execute dispatch stage. It is
    **derived from and must agree with** the actual `Agent({… model:})` dispatch sites ...
    ```
  - Done: all nine sections present with the contracts above; no secrets; repo-root-relative paths.
  - Verify: `grep -nE "^## (Agent modes|Spike artifact|Change classification|Placement rule|Threshold reuse|Soft-checkpoint budget|No-bypass gate|See also)" plugins/spec-flow/reference/spike-agent.md` returns 8 matches (+ the `## Location` H2 under Spike artifact may be H3).

- [x] **[Verify]** Confirm the contract doc is complete
  **Per-change checks:**
  - T-1: `grep -c "blocking-on-current\|blocking-on-later\|additive" plugins/spec-flow/reference/spike-agent.md` — Expected: ≥3 (all three classes named).
  **Phase-level check:**
  - Run: LLM-agent-step — read `plugins/spec-flow/reference/spike-agent.md` and confirm each of the six contracts + the no-bypass gate is defined with concrete content (not a placeholder).
  - Expected: all six contracts + gate present, each with substantive prose.
  - Failure: any section missing or stubbed.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-5, AC-6, AC-7, AC-10 (definition coverage)
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 2: Spike agent — `agents/spike.md`
Why serial: Phases 2–4 touch disjoint files (agents/spike.md, agents/plan-amend.md, plan/SKILL.md+plan-concreteness.md) and could parallelize after Phase 1, but are kept serial to preserve per-phase Opus QA review on each shipped-contract edit (audit value for changes to merged agent/skill contracts); wall-clock savings for three small markdown edits are negligible.
**Exit Gate:** `agents/spike.md` exists with bare `name: spike`, `model: opus`, both modes documented, the isolated/≤2K/STATUS/no-partial/no-sub-agents contract stated; cites `reference/spike-agent.md`.
**ACs Covered:** AC-1, AC-8
**In scope:** CREATE `plugins/spec-flow/agents/spike.md` only.
**NOT in scope:** execute dispatch of the agent (Phases 5–6); the artifact schema definition (Phase 1 — cited, not restated here).
**Charter constraints honored in this phase:**
- NN-C-004 (bare agent name): frontmatter `name: spike` (no plugin prefix).
- NN-C-008 (self-contained, no history): the agent assumes no conversation history; all inputs injected.
- CR-008 (single-task, no sub-agents): the agent thinks and writes one artifact; dispatches nothing.
- NN-C-002 (no runtime deps): LLM-native markdown; uses only Read/Bash/Grep.

- [x] **[Implement]** Author the spike agent
  - Architecture constraints: mirror `agents/research.md` structure (Role / Injected Inputs / Procedure / Output Contract / No Secrets / Return Contract); cite `reference/spike-agent.md` for the artifact schema + mode contracts rather than restating them.

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/agents/spike.md`**
  - Frontmatter:
    ```
    ---
    name: spike
    description: "Internal agent — dispatched by spec-flow:execute for a [SPIKE] phase (resolve mode) or an above-threshold mid-execution change (scope mode). Do NOT call directly. Isolated Opus thinking pass: resolves a genuine unknown or scopes a change, writes a spike artifact, returns a ≤2K digest. Dispatches no sub-agents."
    model: opus
    ---
    ```
  - Body sections (cite `reference/spike-agent.md` for all schema/contract detail):
    1. `## Role / Single Task` — "You perform one isolated thinking pass in the mode given (`resolve` | `scope`). You dispatch NO sub-agents." 
    2. `## Injected Inputs (No History)` — the orchestrator injects: `mode:`; for `resolve` the `[SPIKE]` marker text + phase plan context + optional `Test Data` skeleton; for `scope` the change text + current plan + diff/neighborhood scope. No prior conversation.
    3. `## Procedure` — resolve: investigate the unknown (Read/Bash/Grep), determine the concrete answer; if a test oracle, fill the `Test Data` block. scope: determine the change's full blast-radius, enumerate the task list, classify (`blocking-on-current`|`blocking-on-later`|`additive`) per `reference/spike-agent.md` `## Change classification`.
    4. `## Output Contract — Write the spike artifact` — write to `docs/prds/<prd-slug>/specs/<piece-slug>/spikes/<id>.md` per `reference/spike-agent.md` `## Spike artifact` schema (cite, do not restate). On `BLOCKED`, write no artifact.
    5. `## No Secrets` — never transcribe credentials into artifact or digest.
    6. `## Return Contract` — ≤2K-token digest; FINAL line exactly `STATUS: OK` (artifact written) or `STATUS: BLOCKED` (reason above the line, no partial artifact). No other STATUS values.
  - Pattern (from `agents/research.md` Return Contract):
    ```
    The **FINAL line** of your return must be exactly one of:
    STATUS: OK
    STATUS: BLOCKED
    `STATUS: BLOCKED` means you could not complete ... do NOT write a partial ...
    ```
  - Done: file exists; `name: spike` bare; `model: opus`; both modes + the cited schema present; STATUS contract + no-partial rule stated; no sub-agent dispatch.
  - Verify: `grep -E "^name: spike$" plugins/spec-flow/agents/spike.md` matches AND `grep -E "^model: opus$" plugins/spec-flow/agents/spike.md` matches.

- [x] **[Verify]** Confirm agent contract
  **Per-change checks:**
  - T-1: `grep -c "resolve\|scope" plugins/spec-flow/agents/spike.md` — Expected: ≥2 (both modes named).
  - T-1: `grep -n "STATUS: OK\|STATUS: BLOCKED" plugins/spec-flow/agents/spike.md` — Expected: both present.
  **Phase-level check:**
  - Run: LLM-agent-step — read `plugins/spec-flow/agents/spike.md`; confirm bare `name:`, `model: opus`, both modes, no-partial-on-BLOCKED, and that it cites `reference/spike-agent.md` rather than restating the schema; confirm no instruction to dispatch sub-agents.
  - Expected: all true.
  - Failure: prefixed name, missing mode, restated schema, or any sub-agent dispatch.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-8
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 3: `plan-amend` placement-directive extension
**Exit Gate:** `agents/plan-amend.md` accepts an optional `Placement directive:` input and its positioning is directive-driven with the before-next-phase default preserved; diff format unchanged.
**ACs Covered:** AC-6 (producer side)
**In scope:** MODIFY `plugins/spec-flow/agents/plan-amend.md` (Context Provided + Output Contract).
**NOT in scope:** the classification logic (execute Phase 7 computes it); the placement rule definition (Phase 1).
**Charter constraints honored in this phase:**
- NN-C-003 (backward compat): absent directive → today's before-next-phase behavior, byte-for-byte.
- CR-009 (heading hierarchy + `phase_<N>_amend_<K>` convention): preserved.
- NN-C-008 (self-contained agent): the directive is injected by the orchestrator; no history assumed.

- [x] **[Implement]** Add the optional placement directive
  - Architecture constraints: additive only; the diff `## Diff of changes` format is unchanged — only the insertion position becomes directive-driven.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/agents/plan-amend.md`**
  - Anchor: `## Context Provided` (lines ~19-28), after the `Diff+neighborhood scope:` bullet.
  - Current:
    ```
    28  - **Diff+neighborhood scope:** a list of phases (with their `[Implement]` / `[Build]` blocks) whose file scopes overlap with the proposed amendment. The orchestrator computes neighborhood by exact file path per FR-11.
    ```
  - Target: add a new bullet after L28: "**Placement directive (optional):** one of `blocking-on-current`, `blocking-on-later: <phase-id>`, or `additive: <after-phase-id>`, supplied by the orchestrator from the scope spike's classification (see `reference/spike-agent.md` `## Placement rule`). When absent, default to inserting before the next original phase (the legacy behavior)."
  - Done: the optional directive bullet exists and cites `reference/spike-agent.md`.
  - Verify: `grep -n "Placement directive" plugins/spec-flow/agents/plan-amend.md` returns a match.

  **T-2: MODIFY `plugins/spec-flow/agents/plan-amend.md`**
  - Anchor: `## Output Contract`, line 34.
  - Current:
    ```
    34  - The diff inserts amendment phases BEFORE the next original phase numerically — amending phase_3 inserts `phase_3_amend_1` before `phase_4`.
    ```
  - Target: replace L34 with directive-driven positioning: "The diff inserts amendment phases at the position selected by the **Placement directive** (see Context Provided): `blocking-on-current` → re-open the in-progress phase as `phase_<N>_amend_<K>` superseding its remainder; `blocking-on-later: <phase-id>` → insert before `<phase-id>`; `additive: <after-phase-id>` → insert after `<after-phase-id>` at the dependency-correct slot. **When no directive is supplied, insert BEFORE the next original phase numerically** — amending phase_3 inserts `phase_3_amend_1` before `phase_4` (legacy default). The `phase_<N>_amend_<K>` suffix-ID convention (FR-13) and the diff format are unchanged regardless of directive."
  - Done: L34 enumerates all three directive branches + the absent-directive default; suffix-ID convention + format preserved.
  - Verify: `grep -n "blocking-on-current\|no directive is supplied\|BEFORE the next original phase" plugins/spec-flow/agents/plan-amend.md` returns the directive branches + the default.

  **T-3: MODIFY `plugins/spec-flow/agents/plan-amend.md`** — frontmatter description (anti-drift)
  - Anchor: frontmatter `description:` (line 3).
  - Current: `"...emits a unified diff that inserts suffix-named amendment phases (phase_<N>_amend_<K>) before the next original phase. Does NOT commit..."`
  - Target: change "before the next original phase" → "at the position selected by an optional placement directive (default: before the next original phase)". The rest of the description is unchanged.
  - Done: the description no longer unconditionally claims before-next-phase placement.
  - Verify: `grep -c "before the next original phase. Does NOT commit" plugins/spec-flow/agents/plan-amend.md` returns 0 (the unconditional description string is gone).

  **T-4: MODIFY `plugins/spec-flow/agents/plan-amend.md`** — body resume sentence (anti-drift)
  - Anchor: body line 9: `"Emit a unified diff against plan.md that inserts new phases to address the discovery. The orchestrator commits and resumes execute from the first amendment phase."`
  - Target: change "resumes execute from the first amendment phase" → "resumes execute at the placement directive's position (default: the first amendment phase)".
  - Done: the body resume sentence reflects directive-driven placement.
  - Verify: `grep -c "resumes execute from the first amendment phase" plugins/spec-flow/agents/plan-amend.md` returns 0.

- [x] **[Verify]** Confirm directive integration
  **Per-change checks:**
  - T-1: `grep -c "Placement directive" plugins/spec-flow/agents/plan-amend.md` — Expected: ≥2 (Context + Output).
  - T-2: `grep -c "blocking-on-current\|blocking-on-later\|additive" plugins/spec-flow/agents/plan-amend.md` — Expected: ≥3.
  - T-3: `grep -c "before the next original phase. Does NOT commit" plugins/spec-flow/agents/plan-amend.md` — Expected: 0 (stale description string gone).
  - T-4: `grep -c "resumes execute from the first amendment phase" plugins/spec-flow/agents/plan-amend.md` — Expected: 0 (stale resume string gone).
  **Phase-level check:**
  - Run: LLM-agent-step — read `plugins/spec-flow/agents/plan-amend.md`; confirm the directive is OPTIONAL, the three branches map to distinct positions, the absent-directive legacy default is explicit, and `model: sonnet` + the `## Diff of changes` format are unchanged.
  - Expected: all true.
  - Failure: directive made mandatory, missing default, or diff-format change.

- [x] **[QA]** Phase review
  - Review against: AC-6 (producer side)
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 4: Plan-finalize gate relaxation (`plan/SKILL.md` + `plan-concreteness.md` §4)
**Exit Gate:** `plan/SKILL.md` Phase-4 finalize spike-scan annotates-and-advances a *marked* `[SPIKE]` (no hard refuse); `plan-concreteness.md` §4 marks FR-005 shipped + the gate relaxed; scan-scoping preserved; qa-plan #29 unchanged.
**ACs Covered:** AC-11
**In scope:** MODIFY `plugins/spec-flow/skills/plan/SKILL.md` (Phase-4 finalize spike-scan, L611-621); MODIFY `plugins/spec-flow/reference/plan-concreteness.md` §4 (L112-130).
**NOT in scope:** the `[SPIKE]` marker syntax (§2 — unchanged); the Test Data §5 schema (unchanged); execute-side resolve dispatch (Phase 5).
**Charter constraints honored in this phase:**
- NN-C-003 (backward compat): relaxation is strictly more permissive; scan-scoping rules preserved verbatim; unmarked unknowns still fail qa-plan #29.
- CR-005 (repo-root-relative paths): cross-references unchanged.
- CR-009 (heading hierarchy): §4 H2/the Phase-4 block structure preserved.

- [x] **[Implement]** Relax the finalize gate and mark FR-005 shipped
  - Architecture constraints: `plan-concreteness.md` §4 is the canonical definition; `plan/SKILL.md` Phase-4 cites it — both must agree (cross-phase schema consistency). Preserve the fenced-code/HTML-comment scan-scoping exactly.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/plan/SKILL.md`**
  - Anchor: Phase-4 **Finalize spike-scan (FR-002e)**, lines ~611-619.
  - Current (L611-619): refuses to finalize on any surviving spike marker in prose, lists offending phases, tagged "interim ... once FR-005 ... lands ... relaxed."
  - Target: replace the hard-refuse behavior with **routed-resolution annotation**: a surviving *marked* `[SPIKE]` marker in prose no longer refuses finalize — the scan annotates each such marker as "routed-resolution: resolved at execute by `spike-agent` (FR-005)" and finalize PROCEEDS. Preserve the scan-scoping rules verbatim (skip fenced code + HTML comments; multi-line HTML-comment precedence). State that this realizes the `plan-concreteness.md` §4 FR-005 handoff (now shipped). Keep the silent-no-op path when no markers survive. Note: unmarked unknowns are still caught upstream by qa-plan #29 (concreteness) — the finalize scan only governs *marked* spikes.
  - Done: the REFUSE language is replaced by annotate-and-advance; scan-scoping preserved; FR-005 referenced as shipped.
  - Verify: `grep -n "routed-resolution\|annotate" plugins/spec-flow/skills/plan/SKILL.md` returns a match AND the prior `Plan finalize refused — N surviving` hard-refuse wording is gone from the Phase-4 block (allowed only inside the worked-example comment if retained as contrast).

  **T-2: MODIFY `plugins/spec-flow/reference/plan-concreteness.md`**
  - Anchor: `## 4. Interim plan-finalize spike-block + FR-005 handoff`, lines ~112-130 (esp. L126 "interim ... until FR-005 ships" and L128 "after the plan amendment is applied").
  - Current (L128): "FR-005 (`spike-agent`) adds an Opus spike resolver that clears a `[SPIKE]` via a Step 6c **plan amendment** ... After the plan amendment is applied, the finalize gate is relaxed to a routed-resolution annotation rather than a hard refusal. Until FR-005 ships, the operator must resolve each spike marker manually."
  - Target: rewrite §4 to mark FR-005 **shipped**: the finalize gate IS now a routed-resolution annotation (no longer a hard refusal); a marked `[SPIKE]` advances through finalize and is resolved at execute by the spike agent (which records the resolution and, where applicable, emits a Step 6c plan amendment). Tighten the ambiguous "after the plan amendment is applied" wording to the operative model: **annotate-and-advance at finalize → resolve at execute** (the `[SPIKE]` phase must reach execute for the spike agent to fire). Rename the heading from "Interim ... + FR-005 handoff" to "Plan-finalize spike-gate (FR-005: routed-resolution)". Keep §2 (marker syntax) and §5 (Test Data) references intact.
  - Done: §4 states FR-005 shipped; the gate is routed-resolution; the "after the plan amendment is applied" ambiguity is resolved to annotate-then-execute-resolve.
  - Verify: `grep -n "shipped\|routed-resolution" plugins/spec-flow/reference/plan-concreteness.md` returns matches in §4 AND `grep -c "Until FR-005 ships, the operator must resolve" plugins/spec-flow/reference/plan-concreteness.md` returns 0.

- [x] **[Verify]** Confirm gate relaxed + cross-doc consistency
  **Per-change checks:**
  - T-1: `grep -c "Plan finalize refused" plugins/spec-flow/skills/plan/SKILL.md` — Expected: 0 outside the worked-example HTML comment (the hard-refuse is gone).
  - T-2: `grep -c "interim" plugins/spec-flow/reference/plan-concreteness.md` — Expected: §4 no longer frames the block as interim (0 in §4; other-section hits acceptable).
  **Phase-level check:**
  - Run: LLM-agent-step — read `plan/SKILL.md` Phase-4 block and `plan-concreteness.md` §4; confirm both agree that a marked `[SPIKE]` is annotated-and-advanced (not refused), FR-005 is marked shipped, scan-scoping is preserved, and the §4 "after the plan amendment is applied" ambiguity is resolved to annotate-then-resolve-at-execute.
  - Expected: both docs consistent; gate relaxed.
  - Failure: residual hard-refuse, doc disagreement, or dropped scan-scoping.

- [x] **[QA]** Phase review
  - Review against: AC-11
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 5: Execute ROLE 1 — `[SPIKE]`-resolve dispatch + `--opus` override
**Exit Gate:** execute dispatches the spike agent in `resolve` mode (Opus, isolated) on a `[SPIKE]` phase, records the resolution artifact, writes back a `Test Data` block when the unknown is a test oracle, and never silently upgrades a non-`[SPIKE]` phase; `--opus=<phase-id|all>` is parsed at pre-flight and surfaced as the model-policy override exception.
**ACs Covered:** AC-2, AC-3
**In scope:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md` (add `[SPIKE]`-resolve dispatch; `--opus` pre-flight parse); MODIFY `plugins/spec-flow/reference/coordinator-contract.md` (concretize the override exception to name `--opus`).
**NOT in scope:** Step 6c scope-mode wiring (Phase 6); placement/budget (Phase 7); the agent file (Phase 2); the model table itself (sonnet-coord — only the exception text is concretized).
**Steps traversed (P2):** the new `[SPIKE]`-resolve path traverses the Pre-flight Model Check + per-stage model report (L15-53), the per-phase loop entry (Step 0a/Step 1), and the Step 2.7 `[Write-Tests]` / `tdd-red` Test-Data transcription (L670, which consumes the written-back block); it does not invalidate any existing step (a non-`[SPIKE]` phase path is unchanged).
**Dispatch sites (P3):** adds one new dispatch site — the `resolve`-mode spike agent (`model: opus`) at the `[SPIKE]`-phase handler. Existing dispatch contracts (implementer, tdd-red, verify, qa-*) are unchanged. `--opus` affects only the model-policy report surfacing, not other dispatch sites.
**Charter constraints honored in this phase:**
- NN-P-005 (Opus thinking / Sonnet mechanics, no silent upgrade): resolve spike is Opus + isolated; a non-`[SPIKE]` Sonnet failure routes to Step 6c, never an Opus re-run; `--opus` is the explicit operator exception.
- NN-C-005 (graceful on absent optional input): absent `--opus` is a silent no-op.
- NN-C-008 (self-contained dispatch): the resolve dispatch injects all inputs; no history.
- CR-009 (heading hierarchy): no `### Step N`/`### Phase N` anchor renamed.

- [x] **[Implement]** Wire resolve-mode dispatch + override flag
  - Architecture constraints: thin orchestrator (CR-008) — execute drives; the agent thinks. Cite `reference/spike-agent.md` for the artifact schema and `agents/spike.md` for the dispatch. Place the `[SPIKE]`-resolve handler where the per-phase loop detects a `[SPIKE]` phase.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`** — add `[SPIKE]`-resolve dispatch
  - Anchor: the per-phase loop, at phase-track detection (near the Implement/TDD branch; introspection notes execute has NO `[SPIKE]` dispatch today — the only `[SPIKE]` mentions are the model-report L49 and Step 2.7 L670).
  - Target: add a `### [SPIKE]-phase resolution (FR-005)` subsection: when a phase carries a `[SPIKE]` marker, BEFORE the implementer runs, dispatch the spike agent in `resolve` mode — `Agent({description, prompt: <inject mode:resolve + the [SPIKE] text + phase plan context + (if the phase authors tests) the Test Data skeleton>, model: "opus"})`. On `STATUS: OK`: read the spike artifact at `docs/prds/<prd>/specs/<piece>/spikes/<phase-id>.md`; if it carries a `Test Data` block, write it into the phase's `Test Data` block in plan.md (so Step 2.7 / `tdd-red` transcribe it — both already shipped per `plan-concreteness.md` §5); record the artifact; proceed with the phase on Sonnet. Guard: if the artifact already exists for this phase id (already resolved), skip re-dispatch (no re-spike). On `STATUS: BLOCKED`: escalate per T-3 (Phase 5 BLOCKED handling — shared with Phase 6; defined here).
  - Pattern (dispatch shape from an existing Opus dispatch, execute Step 6 qa-phase):
    ```
    Agent({
      description: "...",
      prompt: <composed>,
      model: "opus"
    })
    ```
  - Done: the `[SPIKE]`-resolve subsection exists; dispatch is `model: "opus"`; OK records artifact + test-data write-back + no-re-spike guard; BLOCKED escalates.
  - Verify: `grep -n "SPIKE.*resol\|resolve mode\|mode:resolve\|resolve\b" plugins/spec-flow/skills/execute/SKILL.md` shows the new subsection AND `grep -c "spikes/" plugins/spec-flow/skills/execute/SKILL.md` ≥1.

  **T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`** — `--opus` pre-flight parse + surfacing
  - Anchor: `### Per-stage model policy report` (L47-51).
  - Current (L49): the report "flags only the two sanctioned exceptions (spike phase → Opus; operator override → Opus)."
  - Target: add an invocation-flag parse at pre-flight: `--opus=<phase-id|all>` forces Opus for the named phase(s); when present, the per-stage model-policy report lists those phases under the **operator override → Opus** exception (concrete flag named). Absent flag → no override exception (silent no-op, NN-C-005). State that a non-`[SPIKE]`, non-`--opus` stage never upgrades to Opus (NN-P-005).
  - Done: `--opus=<phase-id|all>` parsed; report surfaces it under the override exception; absent → no-op.
  - Verify: `grep -n -- "--opus" plugins/spec-flow/skills/execute/SKILL.md` returns the parse + the report surfacing.

  **T-3: MODIFY `plugins/spec-flow/reference/coordinator-contract.md`** — concretize override exception
  - Anchor: `## Model Policy`, the exceptions paragraph ("(2) **operator override → Opus** — the operator forces Opus for a named piece/phase (mechanism wired by `spike-agent`, FR-005 AC-3)").
  - Target: concretize "(2) operator override → Opus" to name the mechanism: "the operator forces Opus for a named phase via the `--opus=<phase-id|all>` execute invocation flag (wired by `spike-agent`, FR-005 AC-3)." Model table unchanged.
  - Done: the override exception names `--opus=<phase-id|all>`.
  - Verify: `grep -n -- "--opus" plugins/spec-flow/reference/coordinator-contract.md` returns a match.

- [x] **[Verify]** Confirm resolve wiring + override
  **Per-change checks:**
  - T-1: `grep -c "model: \"opus\"\|model: opus" plugins/spec-flow/skills/execute/SKILL.md` — Expected: increased by 1 vs baseline (the new resolve dispatch).
  - T-2: `grep -c -- "--opus" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥2 (parse + report).
  - T-3: `grep -c -- "--opus" plugins/spec-flow/reference/coordinator-contract.md` — Expected: ≥1.
  **Phase-level check:**
  - Run: LLM-agent-step — read the new `[SPIKE]`-resolve subsection + the model-policy report edit; confirm resolve dispatch is Opus+isolated, records the artifact, writes back Test Data, has a no-re-spike guard, BLOCKED escalates; confirm no non-`[SPIKE]`/non-`--opus` Opus-upgrade path exists.
  - Expected: all true; no silent upgrade path.
  - Failure: any non-`[SPIKE]` Opus upgrade, missing write-back, or missing escalation.

- [x] **[QA]** Phase review
  - Review against: AC-2, AC-3
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 6: Execute ROLE 2 — Step 6c admission + threshold + scope spike + no-bypass gate
**Exit Gate:** Step 6c admits both triggers (agent-discovered unchanged; operator-initiated via detect-and-confirm); the 50% threshold is evaluated in both modes; `ratio ≥ 0.5` (and undefined-ratio) dispatches a `scope`-mode spike before `plan-amend`; the no-bypass gate invariant is stated.
**ACs Covered:** AC-4, AC-5, AC-10
**In scope:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md` (Step 6c admission + threshold lift + scope-spike dispatch + gate invariant).
**NOT in scope:** placement + budget + discovery-log ref (Phase 7); resolve mode (Phase 5).
**Steps traversed (P2):** the operator-change admission path is a NEW entry into Step 6c (L936-1178) running alongside the existing agent-discovered aggregation (L944-963); the threshold computation (currently only in the `--auto`/FR-17 branch L989-1021) is lifted so the operator-mode triage path also evaluates it; the scope-spike runs before the existing Amend dispatch (L1023). No existing Step 6c outcome (fork/defer) is altered.
**Dispatch sites (P3):** adds one new dispatch site — the `scope`-mode spike agent (`model: opus`) before `plan-amend` on the amend path. The `plan-amend` dispatch (L1027) is unchanged except it now also receives the scoping artifact (Phase 7 passes the placement directive).
**Charter constraints honored in this phase:**
- NN-P-002 (no silent/mid-stream change): operator changes enter Step 6c (not applied mid-stream); above-threshold changes get a recorded scope spike; no-bypass gate enforced.
- NN-P-003 (operator-invoked): detect-and-confirm reacts to operator input; no self-invocation.
- NN-P-005 (Opus thinking isolated): scope spike is Opus+isolated.
- NN-C-008 (self-contained dispatch): scope dispatch injects all inputs.

- [x] **[Implement]** Wire admission + threshold + scope spike
  - Architecture constraints: thin orchestrator (CR-008). Reuse the existing diff-ratio computation; do not introduce a new config key. Cite `reference/spike-agent.md` `## Threshold reuse` and `## No-bypass gate`.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`** — operator-change detect-and-confirm admission
  - Anchor: Step 6c aggregation, after the three agent-discovered sources (L944-963).
  - Target: add a `#### Operator-initiated change admission (FR-008)` block: when a free-form operator turn (NOT a structured answer to an active execute prompt — triage choice, QA sign-off, etc.) reads as a behavior/scope change (imperative/suggestion: "add…", "change…", "we should…", "what if we…"), the coordinator emits ONE confirmation: `That reads as a scope change. Route it through scope→amend→execute? (y/n)`. On `y`: append it to the Step 6c discovery list with `source_agent: operator`, `default_triage: amend`, `row_text` = the change text. On `n`: treat as a comment, no routing. State that detection is SUPPRESSED while awaiting a structured prompt answer.
  - Done: the admission block enumerates the detect trigger, the `y` and `n` branches, and the suppression rule.
  - Verify: `grep -n "Route it through scope\|Operator-initiated change admission" plugins/spec-flow/skills/execute/SKILL.md` returns matches.

  **T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`** — lift threshold to both modes + spike decision
  - Anchor: the threshold computation (`#### Auto-mode threshold (FR-17)` / `Threshold computation`, L989-1021) currently inside the `--auto` branch.
  - Current (L1011, L1013): `ratio < 0.5` auto-amends; `ratio ≥ 0.5` escalates — only under `--auto`.
  - Target: lift the ratio computation so it is evaluated for EVERY admitted change in both `--auto` and operator modes, driving the spike-vs-direct decision: `ratio ≥ 0.5` (and the undefined-ratio / zero-cumulative-diff case, per the existing L1003 CARVE-OUT) → dispatch a `scope`-mode spike BEFORE `plan-amend`; `ratio < 0.5` → direct `plan-amend` (today's path). Preserve the existing `--auto` auto-amend-vs-escalate semantics as a SEPARATE decision layered on top (auto-mode still escalates ≥0.5 to operator; the spike decision is orthogonal and applies in both modes). No new config key — reuse the 0.5 value.
  - Done: ratio computed in both modes; the ≥0.5→spike and <0.5→direct branches stated; undefined-ratio→spike; auto-mode semantics preserved.
  - Verify: `grep -n "both.*mode\|operator mode\|scope.*spike.*before" plugins/spec-flow/skills/execute/SKILL.md` shows the lift; the threshold is no longer described as `--auto`-only.

  **T-3: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`** — scope-spike dispatch + no-bypass gate
  - Anchor: the Amend dispatch (`#### Amend dispatch`, L1023), before step 1 (plan-amend dispatch L1027).
  - Target: insert a `scope`-spike pre-step: when the change is above threshold, dispatch the spike agent in `scope` mode — `Agent({prompt: <inject mode:scope + change text + current plan + diff/neighborhood scope>, model: "opus"})`. On `OK`: read the scoping artifact (classification + task list) and pass it to `plan-amend` as input (placement directive consumed in Phase 7). On `BLOCKED`: escalate (shared T-3 handler from Phase 5 — no amendment, no patch). State the **no-bypass gate** invariant: no above-threshold change reaches `plan-amend` without a completed scope spike (verified by qa-plan + review-board per NN-P-002).
  - Done: scope-spike pre-step exists (Opus); OK→artifact→plan-amend; BLOCKED→escalate; gate invariant stated.
  - Verify: `grep -n "scope.*mode\|mode:scope\|No-bypass\|no-bypass" plugins/spec-flow/skills/execute/SKILL.md` returns matches.

- [x] **[Verify]** Confirm admission + threshold + gate
  **Per-change checks:**
  - T-1: `grep -c "y/n\|(y/n)" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1 (confirm prompt).
  - T-2: `grep -c "0.5" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ baseline (threshold reused, not removed).
  - T-3: `grep -ci "no-bypass\|scope.*spike" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1.
  **Phase-level check:**
  - Run: LLM-agent-step — read the Step 6c admission + threshold + scope-spike edits; confirm (a) operator changes enter via detect+confirm with both y/n branches + suppression, (b) the ratio is evaluated in both modes with ≥0.5→spike / <0.5→direct / undefined→spike, (c) the scope spike runs before plan-amend and BLOCKED escalates, (d) the no-bypass gate is stated. Trace that no above-threshold path reaches plan-amend without the spike.
  - Expected: all four true; gate holds.
  - Failure: a bypass path, missing branch, or threshold left `--auto`-only.

- [x] **[QA]** Phase review
  - Review against: AC-4, AC-5, AC-10
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 7: Execute ROLE 2 — block-aware placement + soft-checkpoint budget + discovery-log ref
**Exit Gate:** the amend dispatch uses block-aware placement (replacing "resume at first amendment phase"); the amendment budget is a soft checkpoint (replacing the hard refusal + lockout); the `.discovery-log.md` Resolution-commit cell references the spike artifact; cross-phase schema consistency holds.
**ACs Covered:** AC-5 (audit-trail), AC-6 (consumer side), AC-7
**In scope:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md` (amend-dispatch placement L1043-1057; amendment budget L1100-1151; `.discovery-log.md` authoring L1153-1174).
**NOT in scope:** the placement rule definition (Phase 1); the scope-spike dispatch (Phase 6); plan-amend's directive consumption (Phase 3).
**Steps traversed (P2):** the placement change rewrites the Amend dispatch resume target (L1057); the budget change rewrites the pre-dispatch budget check (L1116-1138) and the exhaustion escalation (L1132-1151); both run inside the existing Step 6c amend flow without adding a new loop. The `blocking-on-current` class introduces a re-open-current-phase path that traverses the per-phase loop's resume logic (must re-derive from plan.md checkboxes).
**Dispatch sites (P3):** none new — `plan-amend` (L1027) now receives the placement directive computed from the Phase-6 scope-spike classification; no other dispatch site changes.
**Charter constraints honored in this phase:**
- NN-C-003 (backward compat): block-aware placement + soft checkpoint re-derive from disk on resume (a fresh context lands the same next phase); absent directive → before-next-phase default; counters + resume-recovery grep retained.
- NN-P-002/NN-P-004 (operator-gated, no forced halt): the checkpoint prompts rather than blocks; `block` is operator-chosen.
- NN-C-006 (confirmation, not forced destructive op): the `block` outcome is the operator's explicit choice.
- CR-009 (heading hierarchy + `phase_<N>_amend_<K>`): preserved.

- [x] **[Implement]** Block-aware placement + soft checkpoint + log ref
  - Architecture constraints: cite `reference/spike-agent.md` `## Placement rule` + `## Soft-checkpoint budget`. Preserve the counters and the resume-recovery grep (L1109-1114). Pass the classification to `plan-amend` as the placement directive (consumed by Phase 3's contract).

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`** — block-aware placement
  - Anchor: `#### Amend dispatch`, step 6 (L1057): "Resume execution at the first amendment phase ... `phase_<N>_amend_<K>`."
  - Current (L1057): unconditionally resumes at the first amendment phase (preempt).
  - Target: replace with block-aware placement driven by the scope-spike `classification` (passed to `plan-amend` as the placement directive): `blocking-on-current` → re-open the in-progress phase as `phase_<N>_amend_<K>` and supersede its remainder (the current work itself changed); `blocking-on-later` → insert before the dependent later phase and let current WIP finish first; `additive` → append after current WIP at the dependency-correct slot. No amendment phase preempts the in-progress phase except `blocking-on-current` or an explicit operator force-stop. Below-threshold direct amends (no spike, no classification) default to `additive` unless the discovery names a dependent phase. State that resume re-derives placement from plan.md checkboxes + amendment IDs on disk.
  - Done: all three classes + force-stop + below-threshold default enumerated; the old unconditional resume is gone; resume-from-disk stated.
  - Verify: `grep -c "blocking-on-current\|blocking-on-later\|additive" plugins/spec-flow/skills/execute/SKILL.md` ≥3 AND `grep -c "Resume execution at the first amendment phase" plugins/spec-flow/skills/execute/SKILL.md` returns 0 (replaced).

  **T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`** — soft-checkpoint budget
  - Anchor: `#### Amendment budget tracking`, the pre-dispatch budget check (L1116-1123) + the budget-exhaustion escalation prompt (L1132-1151).
  - Current: at `piece_amendment_count >= 5` refuses the dispatch + (on `y`) locks out further amendments (fork/defer only); spec-amend `>= 1` hard-refuses.
  - Target: replace the hard refusal + lockout with a **soft checkpoint**: when the count reaches the threshold (default 5 total; 1 spec sub-cap), prompt `Hit <N> amendments — this piece may be under-scoped. (c) continue amending  (f) fork remaining  (d) defer  (b) block piece`. On `c`: dispatch the amendment and re-surface the prompt on each subsequent amendment. On `f`/`d`/`b`: today's fork/defer/block outcomes (`b` = the existing halt-and-set-blocked flow). Keep both counters and the resume-recovery grep (L1109-1114) unchanged. The spec-amend sub-cap uses the same checkpoint (prompt, not refuse). The count never resets and never hard-blocks.
  - Done: the hard refusal + lockout is replaced by the four-option checkpoint; `c` continues + re-prompts; counters + grep retained; spec-amend sub-cap aligned.
  - Verify: `grep -c "continue amending\|may be under-scoped" plugins/spec-flow/skills/execute/SKILL.md` ≥1 AND `grep -c "no further amendments allowed" plugins/spec-flow/skills/execute/SKILL.md` returns 0 (lockout removed).

  **T-3: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`** — discovery-log artifact reference
  - Anchor: `#### .discovery-log.md authoring`, the Resolution-commit cell convention (L1168-1174).
  - Current: the row's Resolution-commit cell records the commit subject.
  - Target: when a scope spike produced an artifact, append its path inside the existing Resolution-commit cell (e.g. `abc1234 chore(plan): amend — … (spike: spikes/<id>.md)`); NO new column is added (the FR-15 column set is unchanged).
  - Done: the cell convention names the appended `(spike: spikes/<id>.md)` reference; no column added.
  - Verify: `grep -n "spike: spikes/\|spikes/<id>" plugins/spec-flow/skills/execute/SKILL.md` returns a match.

- [x] **[Verify]** Confirm placement + budget + log + cross-phase schema
  **Per-change checks:**
  - T-1: `grep -c "Resume execution at the first amendment phase" plugins/spec-flow/skills/execute/SKILL.md` — Expected: 0.
  - T-2: `grep -c "no further amendments allowed" plugins/spec-flow/skills/execute/SKILL.md` — Expected: 0.
  - T-3: `grep -c "spike: spikes/" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1.
  **Cross-phase schema-consistency check (FR-PROC-01):**
  - Placement-directive vocabulary must be identical across the three files that define/produce/consume it: `reference/spike-agent.md` (Phase 1, def), `skills/execute/SKILL.md` (Phase 7, producer), `agents/plan-amend.md` (Phase 3, consumer). Run: `for f in plugins/spec-flow/reference/spike-agent.md plugins/spec-flow/skills/execute/SKILL.md plugins/spec-flow/agents/plan-amend.md; do echo "$f:"; grep -c "blocking-on-current" "$f"; done` — Expected: each file ≥1 (the class names agree).
  - Spike-artifact path schema must agree across `reference/spike-agent.md`, `agents/spike.md`, and `skills/execute/SKILL.md`: Run: `grep -rl "spikes/" plugins/spec-flow/reference/spike-agent.md plugins/spec-flow/agents/spike.md plugins/spec-flow/skills/execute/SKILL.md` — Expected: all three listed.
  **Anti-drift sweep (FR-PROC-03) — superseded behavior strings:**
  - Run: `grep -rn "Resume execution at the first amendment phase\|no further amendments allowed\|spec-amend budget exhausted" plugins/spec-flow/skills/execute/SKILL.md` — Expected: 0 hits (all superseded by block-aware placement + soft checkpoint).
  - Run (cross-file, covers the Phase 3 plan-amend edits): `grep -rn "before the next original phase. Does NOT commit\|resumes execute from the first amendment phase" plugins/spec-flow/agents/plan-amend.md` — Expected: 0 hits (Phase 3 T-3/T-4 updated the description + resume sentence to directive-driven wording).
  **Phase-level check:**
  - Run: LLM-agent-step — read the placement + budget + log edits; confirm all three placement classes + force-stop, the four-option soft checkpoint with `c` re-prompting, the retained counters/grep, the artifact reference in the existing cell, and that resume re-derives from disk.
  - Expected: all true; no superseded strings remain.
  - Failure: residual preempt/lockout wording, added log column, or broken cross-file schema.

- [x] **[QA]** Phase review
  - Review against: AC-5 (audit-trail), AC-6 (consumer side), AC-7
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 8: Version bump 5.6.0 → 5.7.0
**Exit Gate:** all four version-bearing files read 5.7.0 identically; CHANGELOG has a `## [5.7.0] — <date>` section with non-empty groupings.
**ACs Covered:** AC-9
**In scope:** MODIFY the four version-bearing files per `releasing.md`.
**NOT in scope:** any behavior change (all prior phases).
**Charter constraints honored in this phase:**
- NN-C-009 (always bump version, all files): minor bump across all four version-bearing files.
- NN-C-001 (version ⇄ marketplace sync): marketplace entry bumped in lockstep.
- NN-C-007 (CHANGELOG Keep-a-Changelog): `## [5.7.0]` with Added/Changed groupings.
- CR-004 (conventional commits): the version-bump commit uses the plugin scope (e.g. `chore(spike-agent): bump spec-flow 5.7.0`); the amend-commit conventions touched in Phases 6/7 keep the `chore(plan): amend — <reason>` form.

- [x] **[Implement]** Bump version + CHANGELOG
  - Architecture constraints: this phase runs LAST so the CHANGELOG can describe the full piece. Follow `plugins/spec-flow/docs/releasing.md`.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/plugin.json`** — `"version": "5.6.0"` → `"5.7.0"`. Verify: `grep '"version"' plugins/spec-flow/plugin.json` shows 5.7.0.
  **T-2: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json`** — `"version": "5.6.0"` → `"5.7.0"`. Verify: shows 5.7.0.
  **T-3: MODIFY `.claude-plugin/marketplace.json`** — spec-flow entry `"version"` → `"5.7.0"`. Verify: the spec-flow entry shows 5.7.0.
  **T-4: MODIFY `plugins/spec-flow/CHANGELOG.md`** — prepend `## [5.7.0] — <date>` below `## [Unreleased]`. Groupings: **Added** — `agents/spike.md` (Opus spike agent, resolve+scope modes); `reference/spike-agent.md` (canonical contract); operator `--opus=<phase-id|all>` override; mid-execution scope-change workflow (detect-and-confirm admission, scope spike, block-aware placement). **Changed** — Step 6c amend now scope-spikes above-threshold changes before plan-amend; amendment budget is a soft checkpoint (was a hard wall); `plan-amend` gains an optional placement directive; plan-finalize `[SPIKE]` gate relaxed to routed-resolution (FR-005 shipped). Verify: `head -15 plugins/spec-flow/CHANGELOG.md` shows `## [5.7.0]` with both groupings.

- [x] **[Verify]** Confirm version sync
  **Phase-level check:**
  - Run: `grep '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json` — Expected: both print 5.7.0.
  - Run: LLM-agent-step — read `.claude-plugin/marketplace.json`, confirm the spec-flow entry `version` is 5.7.0; read `plugins/spec-flow/CHANGELOG.md`, confirm the top dated section is `## [5.7.0]` with ≥1 non-empty grouping.
  - Expected: all four strings 5.7.0; CHANGELOG section present.
  - Failure: any mismatch or empty grouping.

- [x] **[QA]** Phase review
  - Review against: AC-9
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | Spike agent contract (Opus, isolated, 2 modes, STATUS, no-partial, no sub-agents) | COVERED | Phase 1 (contract), Phase 2 (agent) |
| AC-2 | Resolve mode + durable resolution + test-data write-back + no re-spike | COVERED | Phase 5 |
| AC-3 | No silent Opus upgrade + `--opus` operator override | COVERED | Phase 5 |
| AC-4 | Admission — agent-discovered + operator detect-and-confirm (+ suppression) | COVERED | Phase 6 |
| AC-5 | Threshold (both modes) → scope spike vs direct amend + audit-trail ref | COVERED | Phase 6 (threshold), Phase 7 (audit-trail) |
| AC-6 | Block-aware placement (3 classes, no preempt unless force-stop) | COVERED | Phase 1 (rule), Phase 3 (plan-amend producer), Phase 7 (execute consumer) |
| AC-7 | Soft-checkpoint budget (keep count, prompt not block) | COVERED | Phase 1 (rule), Phase 7 (execute) |
| AC-8 | Spike BLOCKED (both modes) → escalate, no amendment/no patch | COVERED | Phase 2 (agent contract), Phase 5 (resolve escalate), Phase 6 (scope escalate) |
| AC-9 | Version bump 5.6.0 → 5.7.0 across 4 files + CHANGELOG | COVERED | Phase 8 |
| AC-10 | No-bypass gate (above-threshold change never reaches plan-amend without a spike) | COVERED | Phase 1 (invariant), Phase 6 (enforcement) |
| AC-11 | Plan-finalize gate relaxed (hard-refuse → routed-resolution annotation) | COVERED | Phase 4 |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `grep -E "^name: spike$" plugins/spec-flow/agents/spike.md && grep -E "^model: opus$" plugins/spec-flow/agents/spike.md` | both match |
| AC-1 | agent-step | Read `reference/spike-agent.md` + `agents/spike.md`; confirm both modes, ≤2K/STATUS/no-partial contract, no sub-agents | all present |
| AC-2 | agent-step | Read execute `[SPIKE]`-resolve subsection; confirm Opus dispatch, artifact record, Test-Data write-back, no-re-spike guard | all present |
| AC-3 | shell | `grep -c -- "--opus" plugins/spec-flow/skills/execute/SKILL.md` | ≥2 |
| AC-3 | agent-step | Trace execute for any non-`[SPIKE]`/non-`--opus` Opus-upgrade path | none found |
| AC-4 | shell | `grep -c "Route it through scope" plugins/spec-flow/skills/execute/SKILL.md` | ≥1 |
| AC-5 | agent-step | Read threshold edit; confirm both-modes evaluation + ≥0.5→spike / <0.5→direct + artifact ref in Resolution-commit cell | all present |
| AC-6 | shell | `for f in reference/spike-agent.md skills/execute/SKILL.md agents/plan-amend.md; do grep -c "blocking-on-current" plugins/spec-flow/$f; done` | each ≥1 |
| AC-7 | shell | `grep -c "continue amending" plugins/spec-flow/skills/execute/SKILL.md && grep -c "no further amendments allowed" plugins/spec-flow/skills/execute/SKILL.md` | ≥1 then 0 |
| AC-8 | agent-step | Read both dispatch sites; confirm BLOCKED → escalate-with-findings, no artifact, no plan-amend | all present |
| AC-9 | shell | `grep '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json` | both 5.7.0 |
| AC-10 | agent-step | Trace every above-threshold admission→amend path; confirm each passes scope-spike before plan-amend | gate holds |
| AC-11 | shell | `grep -c "Plan finalize refused" plugins/spec-flow/skills/plan/SKILL.md` (outside worked-example comment) | 0 |

## Contracts

No TDD-track phases in this plan — contracts section present for forward compatibility. `tdd-red` agents will not be dispatched; no contract injection occurs. The piece's boundary-crossing interfaces (the spike-artifact schema and the placement-directive vocabulary) are defined canonically in `reference/spike-agent.md` (Phase 1) and verified by the cross-phase schema-consistency check in Phase 7's `[Verify]`.

## Parallel Execution Notes

All phases run **serial**. Phases 5–7 edit the same file (`execute/SKILL.md`) and cannot parallelize (file overlap). Phases 2–4 touch disjoint files and could parallelize after Phase 1, but are kept serial deliberately (see the `Why serial:` line on Phase 2) to preserve per-phase Opus QA on each shipped-contract edit. Phase 1 must precede all (defines the cited contract); Phase 8 must be last (CHANGELOG describes the finished piece). No Phase Groups; no Phase 0 Scaffold (serial phases do not contend).

## Agent Context Summary
| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, the phase `[Implement]` Change Specs, spec ACs, the phase `[Verify]` commands, arch constraints, pattern blocks, `introspection.md` anchors for phase scope | Spec rationale, brainstorming history |
| Verify | The phase `[Verify]` commands + expected outputs, spec ACs | Implementation reasoning |
| QA | Phase diff, spec, plan, PRD sections | Any agent conversation history |
| Refactor (optional) | Current code (phase files only), the `[Verify]` command, quality principles | Prior agent conversations |
