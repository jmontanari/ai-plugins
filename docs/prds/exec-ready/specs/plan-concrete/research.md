# Research: exec-ready / plan-concrete

## Brainstorm Inference Digest

**Purpose.** This is the core piece of the exec-ready PRD (FR-002, G-1, G-2). It adds a **plan concreteness contract** to the plan-authoring stage and a **concreteness floor** to the `qa-plan` gate, so that a passing plan yields *zero unmarked execute-time discoveries* (measured: Step 6c discovery events not attributable to a `[SPIKE]` marker). Three concreteness demands:

1. **Per-phase concreteness** — every phase names the exact target file, the exact location/anchor within it, and the exact content or signatures to add — not "implement X." `qa-plan` flags non-specific deliverables ("implement", "handle", "add support for") as must-fix.
2. **Explicit `[SPIKE: <unknown>]` markers** — any decision the plan cannot resolve from spec+codebase is written as an explicit marker, never left implicit. `qa-plan` flags an unresolved-but-unmarked ambiguity as must-fix.
3. **Doc-as-code branch-enumeration ACs** — for Implement-track (non-TDD, no test data) phases, every conditional branch in the deliverable must have a corresponding branch-enumeration AC; `qa-plan` flags a missing branch AC as must-fix. This codifies the pi-011 finding (see below).

**Critical current-state finding — `[SPIKE]` is NOT YET DEFINED in the plugin.** `grep -rn "SPIKE" plugins/spec-flow/` returns ZERO hits (exit 1). The `[SPIKE]` marker is named only in the exec-ready PRD, its manifest, and PRD-local specs — it has no definition, syntax, or handling anywhere in `plugins/spec-flow/skills/`, `agents/`, `templates/`, or `reference/`. This piece is the FIRST to introduce a concrete `[SPIKE: <unknown>]` definition into the plan-authoring path. The *spike agent* that resolves markers at execute time is explicitly owned by a LATER piece (`spike-agent` per the research-unify spec's Out-of-Scope; FR-005 in the PRD). So plan-concrete defines the marker as a plan-authoring artifact + a `qa-plan` check; it does NOT build the resolution mechanism. The marker must degrade gracefully until `spike-agent` lands (NFR-003 additive).

**The pi-011 finding (codified by this piece).** The actual finding lives in `docs/prds/shared/specs/pi-011-branch-fix/learnings.md`, "Recommendations for future specs" #1 (verbatim): *"For non-TDD doc-as-code pieces, state every execution branch as an explicit AC. If the plan prose says 'if merge strategy is pr' or 'if rejection occurs' — those are branches that need to be AC-numbered and independently verifiable. Spec-compliance reviewer checks ACs; if branches aren't ACs, they won't be checked. This is the spec-authoring discipline change that would have prevented the Edge-A through Edge-F cascade."* The defect: pi-011's Phase 2 introduced multi-branch control flow (`merge_strategy` branch, rejection path, rework re-entry) where per-phase QA used structural grep and returned clean, but the Final Review edge-case reviewer then found 6 must-fix items (Edges A–F) across iterations 2–5 — a scope-explosion cascade because the branches were not enumerated as independently verifiable ACs. (Note: pi-011's *spec/learnings* are about branch integrity; the branch-AC discipline is the secondary learning the PRD names. The "circuit-breaker hard-3" / 4-iter Final Review cap is recommendation #4, NOT this piece's scope.)

**Design constraints the spec author must resolve (open ambiguities):**
- **PRD's own open question — doc-as-code "exact prose" concreteness bar.** "How exact is enforceable by qa-plan?" The existing `qa-plan` already enforces verb alignment (crit 16), Verify-command concreteness (crit 17), placeholder leakage (crit 18), `[Build]`/`[Implement]` specificity (crit 19), exit-gate falsifiability (crit 20), change-spec completeness (crit 23). The bar must be a *mechanically checkable* rule (grep-able vague-verb list; presence/absence of branch ACs) — not "is this prose good enough," which `qa-plan` cannot adjudicate.
- **Where the contract lives.** Three candidate homes, all conventionally used by peers: (a) plan `SKILL.md` Phase 2 authoring rules (where steps 2a–2e, 3, 9a already live); (b) `qa-plan.md` review criteria (where the must-fix list lives, 27 criteria today); (c) the plan `templates/plan.md` (phase block structure); (d) a new/extended `reference/` doctrine doc (the `[SPIKE]` semantics have no home today — `research-artifact.md` defines the three RESEARCH markers but not SPIKE). Likely all of: SKILL authoring rule + qa-plan criterion + template marker syntax + a reference definition for `[SPIKE]`.
- **Concreteness floor without brittleness.** The vague-verb blocklist ("implement", "handle", "add support for") risks false positives — those words appear legitimately (e.g., "the `[Implement]` block", "implementer agent"). The check must scope to *deliverable/TARGET prose* not block labels, mirroring how step 2a's phase-sizing check filters checkbox markers, HTML comments, fenced code, and table separators.
- **Interaction with merged research-unify `[SPIKE]`/research path.** research-unify added `[RESEARCH-CONSUMED/ABSENT/UNAVAILABLE]` markers and a `research.md`-seeded `introspection.md`. The new concreteness contract should reference research.md as the source the plan resolves decisions *against* — an unknown is spike-able only if it can't be resolved from spec + research.md/codebase. SPIKE and the RESEARCH markers are distinct families; keep the `[SPIKE: <unknown>]` syntax parallel to but separate from the RESEARCH markers.
- **Branch-enumeration AC mechanics.** How does `qa-plan` (no codebase access — "review the plan document structurally") detect a "conditional branch in the deliverable" for a doc-as-code phase? It can only see the plan's own prose. Likely: the plan author must enumerate branches in the phase's `[Implement]`/`[Verify]` block or ACs, and `qa-plan` checks that each "if/when/unless/either/otherwise" clause in the deliverable description has a matching AC. Define what "conditional" means greppably.
- **Measuring "zero unmarked discovery" (AC-4 / SC-003).** This is a cross-piece success criterion measured at execute Step 6c; it is observational, not a `qa-plan` check. The spec author should not try to enforce it inside `qa-plan` — `qa-plan` enforces the *floor*; the zero-discovery outcome is the downstream effect.

## Codebase Conventions

- **SKILL → reference citation idiom:** SKILL.md cites reference docs by path and says "cite it; do not restate" / "Reference X for definitions — do not redefine here." Example (plan SKILL §2d): *"Reference `plugins/spec-flow/reference/spec-flow-doctrine.md` for definitions — do not redefine schema terms here."* Authoritative definitions live in ONE reference doc; skills and agents defer to it (see `research-artifact.md` opening line). The new `[SPIKE]` definition should follow this: define once (likely a reference doc), cite from plan SKILL.md + qa-plan.md + template.
- **qa-plan must-fix criteria structure:** numbered list (currently 1–27) in `## Review Criteria`. Each criterion: a bolded name, an optional activation guard ("activate only when plan.md contains `## X`; skip if absent — pre-existing plans without the section are not errors"), a "Flag:" bullet list of patterns, an **Evidence:** requirement, and a severity tag **(`Must-fix.`** / **`Should-fix.`**). New criteria append as #28+. Backward-compat guard pattern (NN-C-003): activation conditioned on section presence so pre-existing plans don't fail.
- **Vague-deliverable precedent:** crit 16 (verb alignment — flags "documented"/"reviewed"/"inspected" substitution for action verbs), crit 19 (`[Implement]` specificity — flags "directory-only references", "edit src/auth/ without specific file paths"), crit 23 (change-spec completeness — flags "prose ('edit file X — add Y') instead of structured block"). The new vague-deliverable check is a sibling to these.
- **Authoring-rule numbering in plan SKILL Phase 2:** sub-numbered steps (2a phase-sizing, 2b exit-gate semantics, 2c dense-algorithm-prose guard, 2d cross-phase schema oracle, 2e superseded-ordinal sweep, 3 change-spec blocks, 9a/9b/9c). New authoring rules append as 2f / 9d etc. Each rule states a trigger condition, the required output, and an example.
- **Marker syntax convention:** bracketed uppercase tokens — `[TDD-Red]`, `[QA-Red]`, `[Build]`, `[Implement]`, `[Verify]`, `[Integration-Test]`; orchestration markers `[RESEARCH-CONSUMED: <N> files, <M> re-read]`, `[RESEARCH-ABSENT: ...]`, `[PENDING-DECISION: <area>]`. The `[SPIKE: <unknown>]` form (bracket, uppercase token, colon, free-text param) matches `[PENDING-DECISION: <area>]` exactly — that is the closest existing analog (an in-document unresolved-uncertainty marker the downstream gate scans for).
- **`[PENDING-DECISION]` scan precedent (plan SKILL Prerequisites):** the plan skill already refuses to proceed on surviving `[PENDING-DECISION` strings, with a scan that "skip[s] lines inside fenced code blocks (between ``` fences) and skip[s] lines inside HTML comments (between `<!--` and `-->`). Only raw marker text in prose counts." This is the exact precedent for how a `[SPIKE]` scan should be scoped (and how qa-plan should detect unmarked-vs-marked unknowns).
- **Heading-anchor conventions (CR-009):** `### Phase N:` (H3) and `#### Sub-Phase N.m:` (H4) are Phase Scheduler detection anchors; `## Phase Group <letter>` (H2). qa-plan criteria reference these. Multi-step-orchestration-file definition (≥3 `^#{3,4} (Step|Phase|Sub-Phase)\b` headings) recurs in SKILL §9c and qa-plan crit 27.
- **Version/CHANGELOG convention (NN-C-009 / NN-C-001):** any `plugins/*` change requires a version bump synced across `plugins/spec-flow/.claude-plugin/plugin.json` (currently **`5.3.0`**) + `marketplace.json` + a `CHANGELOG.md` entry (Keep-a-Changelog format: `## [X.Y.Z] — DATE` with `### Added` / `### Changed` subsections; `## [Unreleased]` placeholder present). This piece is additive → minor bump (likely 5.4.0).
- **Backward-compat additivity (NN-C-003 / NFR-003):** pieces without a concreteness contract run current plan/execute behavior. New qa-plan criteria must be guarded so pre-existing plans don't suddenly fail; the contract must be opt-in-by-presence or default-tolerant.
- **CR-008 / NN-C-008:** skills are thin orchestrators (validators run orchestrator-side); agents are self-contained narrow executors. A `qa-plan` criterion is agent-side review prose (no codebase access — "review the plan document structurally"); a plan-author validator (like 2a/2b) is orchestrator-side. Choose the right side per CR-008.

## Plan Skill (authoring stage)

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/plan/SKILL.md` (~642 lines). Phase 1 (read-only exploration + research.md CONSUMED/ABSENT seeding of `introspection.md`, lines ~61–133). Phase 2 (generate plan, lines ~135–558) holds all authoring rules: step 1 (define phases), 1a (verb alignment), 2 (track selection: TDD vs Implement vs Non-TDD), **2a** (phase-sizing 150-line check w/ filter rules + `phase_size_override`), **2b** (exit-gate-semantics check w/ `exit_gate_override`), **2c** (dense-algorithm-prose guard — requires inline worked example + Verify assertion), **2d** (cross-phase schema-consistency oracle), **2e** (superseded-ordinal anti-drift sweep), **3** (self-contained Change Specification Blocks — T-N MODIFY/CREATE/DELETE w/ required fields + worked example), 9/9a/9b/9c (AC matrix, Executable AC Binding, phase-boundary decls, P2/P3 cross-step). Phase 3 (QA loop, lines ~569–591). Phase 4 (finalize, ~593–642). No existing `[SPIKE]` or concreteness-floor language.

### Dependency Map
**Dependency Map:** plan SKILL.md Phase 2 reads `introspection.md` (seeded from `research.md` per Phase 1 / `reference/research-artifact.md`) + spec.md + `templates/plan.md`. Phase 3 dispatches `agents/qa-plan.md` (Opus) in an iter-until-clean loop (`reference/qa-iteration-loop.md`, 3-iter circuit breaker). Authoring rules 2a/2b are *orchestrator-side validators* (per CR-008); qa-plan is the *agent-side* gate. Track selection (TDD/Implement/Non-TDD) governs which doc-as-code branch-AC rule applies — Implement-track + Non-TDD-mode phases are the doc-as-code phases FR-002 targets. The success metric (zero unmarked discovery) is observed downstream at `skills/execute/SKILL.md` Step 6c (Discovery Triage, lines ~906–981).

### Test Landscape
**Test Landscape:** No unit-test harness for SKILL.md markdown (per pi-011 spec Testing Strategy: "skills are prose instructions (not executable code)"). Verification = structural `grep`/read checks (e.g., `grep -c "git checkout main" execute/SKILL.md` returns 0) + adversarial QA agents (`qa-plan` here). A plan-concrete plan will use Implement-track phases with `[Verify]` LLM-agent-steps reading the edited SKILL/qa-plan/template/reference files and confirming criterion presence — this is itself a doc-as-code piece subject to its own branch-enumeration-AC rule (dogfood).

### Pattern Catalog
**Pattern Catalog:** existing orchestrator-side validator rule (the template for a new concreteness validator), from plan SKILL §2b:
```
2b. **Exit-gate semantics check (FR-12).** After all phases are drafted, scan each
    phase's `**Exit Gate:**` line and each `[Verify]` step's expected-output prose for the
    following patterns (case-insensitive):
    - `is documented to run`
    ...
    If any pattern matches, plan validation FAILS immediately with:
    ERROR: Phase <num> (<title>): exit-gate downgrade not allowed ...
```
Vague-deliverable precedent the new check mirrors, from plan SKILL §184 (Implement-track):
```
   **Bad (insufficient):** `edit src/auth/token.py — add refresh logic`
   **Good (sufficient):**
   T-3: MODIFY src/auth/token.py
   Anchor: class TokenManager (lines 42-67) ...
```
Track-selection prose that scopes "doc-as-code phases" (plan SKILL §183):
```
   **Implement track** (for config, infra, scaffolding, glue/wiring, docs-as-code,
   fixtures, migrations — where unit-level TDD is ceremony without payoff):
```

## qa-plan Gate (concreteness floor)

### File Inventory
**File Inventory:** `plugins/spec-flow/agents/qa-plan.md` (~173 lines). `## Review Criteria` numbered 1–27. Most relevant existing criteria to extend/sibling: **16** (verb alignment — must-fix, flags documentation/inspection substitution for action verbs), **17** (Verify-command concreteness — must-fix, flags prose-only/generic/placeholder), **18** (placeholder leakage — `{{...}}`, TODO/TBD, `<INSERT>`), **19** (`[Build]`/`[Implement]` specificity — must-fix, flags directory-only refs, missing change type, MODIFY without anchor/line-range), **20** (exit-gate falsifiability — must-fix, flags "implementation complete"/"working correctly"), **23** (change-spec completeness — must-fix, flags prose "edit file X — add Y" vs structured T-N block), **27** (P2/P3 cross-step discipline). `## Output Format`: "must-fix and acceptable sections. Every must-fix must cite a criterion." `## Input Modes`: Full (iter 1, every criterion) / Focused re-review (iter 2+, delta only). `## Rules`: "NO context from spec conversation"; "Do not have codebase access — review the plan document structurally."

### Dependency Map
**Dependency Map:** Dispatched by plan SKILL.md Phase 3 (Opus, Input Mode: Full then Focused). Receives plan + spec + PRD sections + charter skills. Returns must-fix/acceptable. New criteria (#28+) for: (1) per-phase concreteness / vague-deliverable; (2) unmarked-`[SPIKE]` detection; (3) doc-as-code branch-enumeration AC presence. Each must carry an activation guard for backward-compat (NN-C-003) and the **Evidence:** + severity convention. Constraint: qa-plan has NO codebase access — every check must be evaluable from the plan document text alone (e.g., branch detection must read the plan's own enumerated branches/ACs, not the real deliverable file).

### Test Landscape
**Test Landscape:** Same as plan skill — structural reads + adversarial review; no harness. A plan-concrete plan's `[Verify]` for qa-plan edits is an LLM-agent-step: *"read `plugins/spec-flow/agents/qa-plan.md` and confirm criterion 28 contains the string 'vague deliverable' / the vague-verb list"* — matching the existing crit-presence verification idiom (plan SKILL §217, §464).

### Pattern Catalog
**Pattern Catalog:** existing must-fix criterion shape (the template for new #28+), qa-plan crit 19:
```
19. **[Build]/[Implement] specificity:** Each `[Build]` or `[Implement]` block must
    reference specific files with change types (CREATE/MODIFY/DELETE). For MODIFY: must
    include a semantic anchor (function/class name) and line range ...
    Flag:
    - Directory-only references (e.g., "edit src/auth/") without specific file paths
    ...
    Evidence: quote the block showing missing specificity. **Must-fix.**
```
Backward-compat activation-guard pattern (qa-plan crit 12) for new section-conditioned criteria:
```
12. **AC Coverage Matrix — bidirectional validation (activate only when plan.md contains
    `## AC Coverage Matrix`; skip if absent — pre-existing plans without the section are
    not errors).**
```
Verb-substitution flag (crit 16) — the closest sibling to a vague-deliverable check:
```
16. **Verb alignment (spec→plan semantic fidelity):** ... verify the covering plan phase
    contains a concrete step that PERFORMS that action — not documents, reviews, or
    inspects it.
    ... AC "X runs" → phase "X is documented" ❌ (documentation substitution)
```

## Plan Template (phase block structure)

### File Inventory
**File Inventory:** `plugins/spec-flow/templates/plan.md` (~346 lines). Front-matter (`charter_snapshot`, `legacy_deferred_rows`, `fast`). `## Architectural Decisions` (ADR). `## Phases` preamble (TDD vs Implement vs Non-TDD track explanation, lines ~39–47). `## Integration-Test Registry`. Three phase exemplars: **Phase 1 TDD** (`[TDD-Red]`→`[QA-Red]`→`[Build]`→`[Verify]`→`[Integration-Test]`→`[Refactor]`→`[QA]`, lines ~59–123), **Phase 2 Implement** (`[Implement]`→`[Verify]`→`[Integration-Test]`→`[Refactor]`→`[QA]`, ~125–181), **Phase 2 Non-TDD** (`[Implement]`→`[Write-Tests]`→`[Verify]`→..., ~183–246). Phase header fields: `**Exit Gate:**`, `**ACs Covered:**`, `**In scope:**`, `**NOT in scope:**`, optional `**Steps traversed (P2):**` / `**Dispatch sites (P3):**`, `**Charter constraints honored in this phase:**`. `## AC Coverage Matrix`, `## Executable AC Binding`, `## Contracts`. No `[SPIKE]` marker slot, no branch-enumeration-AC slot today.

### Dependency Map
**Dependency Map:** Consumed by plan SKILL.md Phase 2 as the authoring scaffold. Header-field additions here must be matched by an authoring rule in plan SKILL.md and a check in qa-plan.md (the cross-phase schema-consistency discipline the codebase itself follows). A new `[SPIKE: <unknown>]` marker convention and a branch-enumeration-AC slot (likely in the Implement-track / Non-TDD phase exemplar) would be added here, mirrored by SKILL authoring rule + qa-plan criterion.

### Test Landscape
**Test Landscape:** No harness; template correctness verified by reading it back. A plan-concrete `[Verify]` confirms the new marker/slot strings exist verbatim in `templates/plan.md`.

### Pattern Catalog
**Pattern Catalog:** Implement-track phase header (where a doc-as-code branch-AC slot likely attaches), template lines ~125–135:
```
### Phase 2 (Implement track example): {{phase_name}}
**Exit Gate:** {{exit_criteria}}
**ACs Covered:** {{ac_list}}
**In scope:** {{explicit_scope_list}}
**NOT in scope:** {{explicit_exclusions_with_forward_phase_references}}
```
Conditional-comment convention used for optional/conditional header fields (template §64, the model for documenting a conditionally-required branch-AC or SPIKE field):
```
<!-- The two fields below are REQUIRED only when this phase edits a multi-step orchestration
file (a skills/*/SKILL.md with ≥3 headings matching `^#{3,4} (Step|Phase|Sub-Phase)\b`);
omit otherwise. See plan SKILL.md §9c. -->
```

## SPIKE Marker & Execute Step 6c (success-criterion context)

### File Inventory
**File Inventory:** `[SPIKE]` has NO definition in `plugins/spec-flow/` (grep exit 1). It is named only in `docs/prds/exec-ready/prd.md` (FR-002/003/004/005, G-2, SC-003/005, NN-P-002) and `docs/prds/exec-ready/manifest.yaml`. Execute Step 6c (`plugins/spec-flow/skills/execute/SKILL.md` lines ~906–981, `### Step 6c: Discovery Triage`) is where execute-time discoveries are triaged (amend / fork / defer); FR-002's measurable AC counts "Step 6c discovery events not attributable to a `[SPIKE]` marker." Step 6c today knows nothing about `[SPIKE]` — that wiring is the later `spike-agent` piece (FR-005). Closest existing in-document uncertainty marker: `[PENDING-DECISION: <area>]` (spec skill + plan SKILL Prerequisites scan).

### Dependency Map
**Dependency Map:** This piece defines `[SPIKE: <unknown>]` as (a) a plan-authoring marker (placed in a phase when a decision is unresolvable from spec+research.md/codebase) and (b) a `qa-plan` must-fix trigger (unmarked unknown). It must NOT depend on the spike *agent* or Step 6c spike-awareness — those are downstream (`spike-agent`, FR-005). NN-P-002: every unknown is either a `[SPIKE]` (with later recorded resolution) or a Step 6c amendment. The marker degrades to "visible, human-resolvable plan annotation" until spike-agent lands (additive, NFR-003). PRD FR-003 also adds a `[SPIKE]` fallback for unpredictable TDD test data (owned by `test-data-up`) — keep the `[SPIKE]` syntax this piece defines reusable by that sibling.

### Test Landscape
**Test Landscape:** Success criterion AC-4 / SC-003 ("zero unmarked execute-time discoveries"; downward trend across a PRD) is OBSERVATIONAL at execute Step 6c — not a `qa-plan` check and not unit-testable here. This piece's testable surface is the *floor* (qa-plan criteria + plan authoring rules), verified structurally. Do not attempt to enforce the zero-discovery outcome inside qa-plan.

### Pattern Catalog
**Pattern Catalog:** `[PENDING-DECISION]` scan scoping (plan SKILL Prerequisites) — the exact precedent for a marked-vs-unmarked `[SPIKE]` scan:
```
**No surviving `[PENDING-DECISION]` markers:** Scan ... for any `[PENDING-DECISION`
strings. When scanning, skip lines inside fenced code blocks (between opening ``` and
closing ``` fences) and skip lines inside HTML comments (between `<!--` and `-->`).
Only raw marker text in prose counts as a surviving marker.
```
Step 6c discovery-event framing (execute SKILL §906) — what FR-002's metric counts:
```
### Step 6c: Discovery Triage
This step consumes ... routed discoveries together with the per-phase QA gate's
deferred-to-reflection findings and any Build oracle escalations citing missing
prerequisites. It runs once per phase ... every discovery surfaced during the phase
is triaged into one of three outcomes — amend, fork, defer.
```
pi-011 branch-AC finding (verbatim, `docs/prds/shared/specs/pi-011-branch-fix/learnings.md` §Recommendations #1) — the deliverable this piece codifies:
```
1. For non-TDD doc-as-code pieces, state every execution branch as an explicit AC. If
   the plan prose says "if merge strategy is pr" or "if rejection occurs" — those are
   branches that need to be AC-numbered and independently verifiable. ... This is the
   spec-authoring discipline change that would have prevented the Edge-A through Edge-F
   cascade.
```
