# Spike Agent — modes, artifact schema, classification, placement, threshold, budget

Single source of truth for the spike agent (`plugins/spec-flow/agents/spike.md`), its two modes, the spike-artifact schema, the change-classification + placement rules, the threshold-reuse rule, and the soft-checkpoint budget. Cited by `plugins/spec-flow/agents/spike.md`, `plugins/spec-flow/skills/execute/SKILL.md` (Step 6c + `[SPIKE]` dispatch + budget), `plugins/spec-flow/agents/plan-amend.md` (placement directive), and `plugins/spec-flow/skills/plan/SKILL.md` (Phase-4 finalize). Definitions live here and nowhere else.

## Agent modes

| mode | trigger | inputs | output |
|------|---------|--------|--------|
| resolve | a `[SPIKE]` plan phase | the `[SPIKE]` marker text + phase plan context + (if a test oracle) the `Test Data` skeleton to fill | the resolution recorded to the artifact (+ a `Test Data` block when the unknown is a test oracle) |
| scope | an admitted mid-execution change above threshold | the change text (operator request or discovery `row_text`) + current plan + diff/neighborhood scope | the scoping artifact (classification + enumerated task list) consumed by `plan-amend` |

Both modes: Opus, isolated context, ≤2K digest returned to coordinator, `STATUS: OK|BLOCKED`. A BLOCKED result writes no partial artifact and dispatches no sub-agents.

## Spike artifact

### Location

`docs/prds/<prd-slug>/specs/<piece-slug>/spikes/<id>.md`

`<id>` = phase id for resolve mode, discovery/change id for scope mode

### Schema

**Mode:** `resolve` or `scope`

**Trigger:** the unknown or change text

**Classification:** (scope mode only) one of: `blocking-on-current` | `blocking-on-later: <phase-id>` | `additive: <after-phase-id>`

**Scope / Task list:** enumerated task list

**Resolution:** (resolve mode) the concrete answer to the unknown

**Test Data:** (optional) plan-concreteness §5 schema — cite `plugins/spec-flow/reference/plan-concreteness.md`, do not restate the schema here

### No secrets

Never transcribe credentials, tokens, or private keys into the artifact or the digest.

## Change classification

| class | rule |
|-------|------|
| `blocking-on-current` | the change targets the in-progress phase's own deliverable → that phase is re-planned and re-run |
| `blocking-on-later` | a not-yet-started phase depends on the change → the amendment is inserted before that dependent phase; current WIP finishes first |
| `additive` | no existing phase depends on it → appended at a dependency-correct position after current WIP |

All three class names are the canonical vocabulary; `plugins/spec-flow/agents/plan-amend.md` and `plugins/spec-flow/skills/execute/SKILL.md` must use these exact strings.

## Placement rule

Placement is realized via `plugins/spec-flow/agents/plan-amend.md`'s optional placement directive: execute computes the classification, passes it; `plan-amend` encodes the position. Absent directive → before-next-phase default.

No amendment phase preempts the in-progress phase except `blocking-on-current` or an explicit operator force-stop.

Resume re-derives placement from `plan.md` checkboxes + amendment IDs on disk.

## Threshold reuse

The 50% diff-ratio gate (absorption-size ÷ cumulative-diff) is evaluated for every admitted change in BOTH `--auto` and operator modes.

- `ratio ≥ 0.5` (and the undefined-ratio / zero-cumulative-diff case) → scope spike dispatched before `plan-amend`.
- `ratio < 0.5` → direct amend (no spike dispatched).

No new config key. Reuses the value at `plugins/spec-flow/skills/execute/SKILL.md` threshold computation.

## Amendment budget (spike-phase soft-checkpoint + execute hard-cap)

Two counters track amendment pressure within a piece:

- `piece_amendment_count` — total amendments this piece
- `piece_spec_amendment_count` — spec amendments this piece

Default thresholds: `amendment_budget` total (configurable in `.spec-flow.yaml`, default 5); 1 spec sub-cap (fixed constant, not configurable).

At threshold: HALT and prompt the operator `raise amendment_budget and resume / fork / defer / block`. No per-event continue option — raise-and-resume is an operator-level config change.

Count never resets within a piece. The spike-phase soft-checkpoint never hard-blocks (the operator's `continue` choice dispatches the spike); the configurable `amendment_budget` amendment hard-cap halts at its threshold (no per-event continuation — only raise-and-resume, fork, defer, or block).

Recovery grep: count committed amendments in branch history to recompute on resume.

## No-bypass gate

Invariant: no execute path applies an above-threshold mid-execution change without (1) a scope spike AND (2) a plan amendment via `plan-amend`.

Verified by `qa-plan` + `review-board spec-compliance` per NN-P-002.

## See also

- `plugins/spec-flow/agents/spike.md`
- `plugins/spec-flow/skills/execute/SKILL.md`
- `plugins/spec-flow/agents/plan-amend.md`
- `plugins/spec-flow/skills/plan/SKILL.md`
- `plugins/spec-flow/reference/plan-concreteness.md`
- `plugins/spec-flow/reference/coordinator-contract.md`
