---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: Artifact size budgets

**PRD Sections:** FR-014, SC-008, G-1, G-6
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** none

## Goal

Give every generated pipeline artifact a documented size budget — the inverse of the FR-002 concreteness floor. The floor stops under-specification; budgets stop bloat ([R8]: spec-kit shipped 2,577 lines of duplicative markdown per ~700 lines of code; [R10]: context rot is measurable and degrades the executor). Budgets are defaults in a new SSOT reference doc, overridable in `.spec-flow.yaml`, derived **mechanically** from the size distribution of the merged exec-ready corpus — not invented. Over-budget artifacts are caught at the qa-spec/qa-plan gate as must-fix with split/condense guidance; irreducible overage routes to piece-splitting, never to a waiver.

## In Scope

- New SSOT reference doc `plugins/spec-flow/reference/artifact-budgets.md` defining per-class budgets (spec.md, plan.md per-phase + total, research.md, deliberation.md, learnings.md) in lines (primary) + approximate tokens (secondary), each with a **soft** (advisory) and **hard** (must-fix ceiling) tier.
- Additive optional `.spec-flow.yaml` `artifact_budgets:` override block (documented inline; absent ⇒ reference-doc defaults), mirrored in `plugins/spec-flow/templates/pipeline-config.yaml`.
- qa-spec criterion #16 and qa-plan criterion #32 — must-fix on **hard-ceiling** breach only, with named split/condense guidance.
- Orchestrator-supplied line counts: the spec and plan skills run `wc -l` on each gated artifact and interpolate the real count into the qa prompt (the agent judges from a trusted count, not from possibly-truncated artifact text).
- Passive budget-compliance metadata in the per-piece `metrics.yaml` (schema extension to `reference/metrics-artifact.md`).
- Plugin version bump to 5.12.0 (plugin.json + marketplace.json + CHANGELOG).

## Out of Scope / Non-Goals

- **No waiver / suppression mechanism.** Over-budget that can't be cut routes to the qa-prd ≤7-AC piece-split path. Do not copy qa-spec's `<!-- weasel-waived -->` comment dialect.
- **No cross-piece budget aggregator.** Budget compliance is passive per-piece metadata; extending `scripts/metrics-aggregate` (and its byte-identical python/awk parity test) is deferred to a real follow-up piece only if aggregate reporting is later demanded.
- **No must-fix gate on research.md or learnings.md.** Their budgets are documented and recorded, but no qa gate reviews them (define-all, gate-only-where-a-gate-already-exists).
- **No retroactive enforcement** on already-merged pieces (see AC-6 grandfather clause).

## Requirements

### Functional Requirements

- FR-014 (this piece): per-class artifact size budgets enforced at the qa-spec/qa-plan gate as the inverse of the FR-002 concreteness floor, with `.spec-flow.yaml` overrides and metrics recording.

### Non-Functional Requirements

- All new config keys are optional and additive (NN-C-003): absent ⇒ documented defaults; existing behavior unchanged within the 5.x major line.
- Tooling stays markdown/YAML/POSIX-bash only (charter-tools): line counts via `wc -l`, no tokenizer dependency. Token figures are approximate secondary guidance only.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-003 (backward-compat): `artifact_budgets:` is an additive optional nested block; absent ⇒ reference-doc defaults; criteria #16/#32 carry an "activate when budgets resolvable; skip if absent — not an error" guard. New metrics field is additive. No existing key/criterion renamed or removed.
- NN-C-008 (self-contained agent prompts): the orchestrator interpolates the resolved budget numbers **and** the `wc -l` count into the qa-spec/qa-plan prompt; the agents never read config or assume conversation history.
- NN-C-009 / NN-C-001 / NN-C-007 (version bump + marketplace sync + CHANGELOG): bump to 5.12.0 across `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and a new CHANGELOG `## [5.12.0]` section, in a final version-bump phase.

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-001 (human keystroke gate never removed): this piece only ADDS must-fix findings to existing gates; the keystroke flow and gate mechanics are untouched.
- NN-P-005 (thinking on Opus, mechanics on Sonnet): the budget check is mechanical line-counting — no model upgrade; it runs inside the existing Sonnet-tier qa agents.

### Coding Rules Honored

- CR-005 (repo-root-relative doc paths): the reference doc and all cross-references use repo-root-relative paths.
- CR-007 (config keys documented inline): the `artifact_budgets:` block is documented inline in `pipeline-config.yaml` with purpose, valid values, default, and `Absent ⇒ <default> (non-blocking; NN-C-003)`.
- CR-008 (thin-orchestrator / narrow-executor): the skill resolves config and computes `wc -l` (measurement plumbing, config-resolution-adjacent — same shape as the existing concreteness-floor #28–#31 split); the agent judges over/under and authors guidance. No business logic moves into the agent.
- CR-009 (markdown heading hierarchy): the reference doc follows the `plan-concreteness.md` house style (one H1, numbered H2 sections, SSOT preamble, worked-example comments, "No secrets" clause).

## Acceptance Criteria

AC-1: Given the plugin, When `plugins/spec-flow/reference/artifact-budgets.md` is read, Then it defines a budget for each of the six classes (spec.md, plan.md per-phase, plan.md total, research.md, deliberation.md, learnings.md) in lines (primary) + approximate tokens (secondary), each with a soft (advisory) and hard (must-fix ceiling) value, AND documents the additive `.spec-flow.yaml artifact_budgets:` override keys; the same block is present and inline-documented in `templates/pipeline-config.yaml`.
  Independent Test: `grep` the reference doc for all six class names, the soft/hard columns, and the override-key names; `grep` `pipeline-config.yaml` for the `artifact_budgets:` block and its inline comment. Machine-checkable.

AC-2: Given a spec.md or deliberation.md whose orchestrator-supplied line count exceeds its **hard** ceiling, When qa-spec runs, Then criterion #16 raises a must-fix finding naming the class, the actual vs hard-ceiling lines, and split/condense guidance; When the count is over **soft** but under **hard**, Then it emits an advisory note only (no must-fix, no round-trip); When budgets are unresolvable/absent, Then the criterion skips silently (not an error).
  Independent Test: qa-spec criterion #16 text inspected for the three branches + activation guard; exercised against an over-hard fixture (must-fix), an over-soft-under-hard fixture (advisory), and an absent-budget fixture (skip). Judgment + structural.

AC-3: Given a plan.md, When qa-plan runs, Then criterion #32 evaluates BOTH per-phase line counts and the total, and raises a must-fix with split/condense guidance when EITHER exceeds its hard ceiling (over-soft-under-hard = advisory only; absent budgets = skip).
  Independent Test: qa-plan criterion #32 inspected for per-phase + total evaluation and the same three branches; exercised against a one-bloated-phase fixture and a sum-over-total fixture. Judgment + structural.

AC-4: Given any gated artifact, When the spec or plan skill dispatches its qa agent, Then the skill computes the artifact's real line count via `wc -l` and interpolates "artifact is N lines; soft S; hard H" into the prompt; the agent judges from that supplied count and never counts lines from the (possibly-truncated) interpolated artifact text.
  Independent Test: spec/plan SKILL.md dispatch steps inspected for the `wc -l` + interpolation instruction and an explicit "judge from the supplied count" directive in the qa criterion. Structural.

AC-5: Given an artifact that genuinely cannot be cut below its hard ceiling, When the must-fix finding is authored, Then it routes the operator to the qa-prd ≤7-AC piece-split path; AND the diff introduces no waiver/suppression token or comment dialect.
  Independent Test: criterion text names the piece-split route; `grep` the diff confirms no new waiver marker (e.g. no `weasel-waived` analogue) was added. Structural.

AC-6: Given spec-preresearch is already merged (885-line plan), When the deliberation.md budget is defined, Then it binds FORWARD (future deliberation.md producers are checked at their qa-spec gate), the merged spec-preresearch plan is recorded in the reference doc as the grandfathered baseline (not retroactively flagged), and deliberation.md's hard ceiling is set generously (350 lines) from its 7-section structure + research.md analogy since it has zero on-disk samples.
  Independent Test: reference doc inspected for the forward-binding statement, the grandfather baseline note, and the deliberation.md soft/hard values with their "no samples — analogy" rationale. Structural.

AC-7: Given a piece executed after this ships, When its metrics.yaml is written, Then it records budget compliance per gated artifact (actual lines, soft, hard, verdict) as passive metadata per the extended `reference/metrics-artifact.md` schema, written by the stage owner (spec writes spec + deliberation rows; plan writes plan row); no aggregator/script is changed.
  Independent Test: `reference/metrics-artifact.md` inspected for the additive `budget_compliance:` block; `scripts/metrics-aggregate` + its parity test confirmed unchanged in the diff. Machine-checkable.

## Technical Approach

**Budget derivation (mechanical).** Defaults come from the merged-corpus distribution measured in `research.md`: **soft = p75** (rounded to a clean number), **hard = observed-max + ~10% headroom** (rounded up). The headroom on the hard tier keeps must-fix from firing on an atypically-large-but-valid artifact (small-sample protection; defends SC-008). Representative table (authoritative version lives in the reference doc):

| Class | Soft (advisory) | Hard (must-fix) | Gate | Basis |
|---|---|---|---|---|
| spec.md | 300 | 520 | qa-spec #16 | p75 302; max 467 |
| plan.md (total) | 750 | 1000 | qa-plan #32 | p75 748; max 885 |
| plan.md (per-phase) | 90 | 220 | qa-plan #32 | p75 91; max 197 |
| research.md | 200 | 320 | documented-only | p75 192; max 287 |
| deliberation.md | 200 | 350 | qa-spec #16 | no samples — research.md analogy + 7-section structure (generous) |
| learnings.md | 30 | 50 | documented-only | p75 30; max 39 |

**Operator decision — deliberation.md enforcement (overrides deliberation R-3 / VOQ-2).** The lite deliberation *recommended* shipping deliberation.md observe-only for one cycle (R-3) to avoid binding a zero-sample number as must-fix. At sign-off the operator chose instead to bind it as **must-fix now** with a deliberately generous **350-line** hard ceiling — ~5× the 66-line lite deliberation.md on disk and ~1.2× research.md's observed max (287). Rationale: this closes the loop today with **no deferred re-bind obligation** (no silent backlog defer — honoring the repo's no-defer doctrine), and the generous ceiling makes a false-positive must-fix on a legitimate deliberation.md highly unlikely while still catching egregious bloat (e.g. a 500+-line artifact). If real samples later show 350 is mis-set, the number re-derives mechanically from their p75/max like every other class. This is a deliberate, recorded divergence from the deliberation's advisory recommendation — not an inconsistency.

**Enforcement split (CR-008, mirrors concreteness floor #28–#31).** The skill owns measurement: resolve `.spec-flow.yaml` overrides → reference defaults, run `wc -l` on each gated artifact (and per `### Phase`/`#### Sub-Phase` anchor for plan.md), interpolate the counts + budgets into the qa prompt. The agent owns judgment: compare supplied count to soft/hard, branch (must-fix / advisory / skip), and author split/condense guidance. This closes the truncation under-count failure mode — a too-large artifact can no longer read as "short" because the count comes from `wc -l`, not from the agent eyeballing interpolated (possibly-truncated) text.

**deliberation.md gate wiring.** qa-spec is the named gate for deliberation.md (PRD AC2). When the spec skill dispatches qa-spec it supplies counts for BOTH spec.md and deliberation.md.

**Reference-doc house style.** Follows `reference/plan-concreteness.md`: SSOT preamble ("budgets are defined here and nowhere else; cited by qa-spec, qa-plan, metrics-artifact"), numbered H2 sections, explicit numeric thresholds, a worked example, and a "No secrets" clause.

## Testing Strategy

- Per charter-tools, reference docs are not unit-tested. Validation is: (1) the version-bump citation-consistency sweep, (2) the qa agents as live consumers, and (3) the FR-013 e2e harness (L1 static structure + L2 fixture-replay) once it exercises a gated artifact.
- qa criterion behavior (AC-2/AC-3) is validated by inspection + small fixtures (over-hard, over-soft-under-hard, absent-budget) at the criterion level.
- Edge cases: artifact with no resolvable budget (skip, not error); plan with one bloated phase but under total (per-phase must-fix); truncated interpolation (count comes from `wc -l`, unaffected); deliberation.md not present (skip).

## Integration Coverage

- None in scope. This piece adds two qa criteria, one reference doc, additive config keys, and a metrics-schema field — all within the spec-flow plugin; no cross-component wiring with true externals to double.

## Open Questions

- None. The four deliberation VOQs are resolved: VOQ-1 forward-bind + grandfather (AC-6); VOQ-2 operator override of the deliberation's observe-only recommendation → generous deliberation.md must-fix ceiling now, no follow-up obligation (see Technical Approach "Operator decision"; AC-6, 350-line hard ceiling); VOQ-3 passive metrics metadata (AC-7); VOQ-4 orchestrator `wc -l` is config-adjacent under CR-008 (AC-4).
