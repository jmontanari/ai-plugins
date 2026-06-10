# Deliberation Depth Policy

This document is the single source of truth for the deliberation depth policy. Cited by the four calling skills (`spec`, `prd`, `small-change`, `charter`) at the step-0 depth-resolution step, and documented by the `.spec-flow.yaml deliberation` key.

## Depth profiles

| Depth | Phases run | Lenses | Default for | Cost |
|-------|-----------|--------|-------------|------|
| `full` | A → B(parallel) → C* → D(parallel, 5 lenses) → E | 5 | spec, prd, charter | highest (deep investigation where it belongs) |
| `lite` | A → B(single pass over whole piece) → C* → D(subset, default 2) → E | 2 (scope/simplicity + risk) | small-change | ~3–4 dispatches |
| `off` | none — `[DELIBERATION-SKIPPED: depth=off]` + current brainstorm | 0 | (operator opt-out only) | zero |

`* Phase C is a no-op at any depth when there is ≤1 decision-unit cluster (nothing to integrate). See ## Phase C no-op rule.`

## Per-skill defaults

| Skill | Default depth |
|-------|---------------|
| `spec` | `full` |
| `prd` | `full` |
| `charter` | `full` |
| `small-change` | `lite` |

These defaults apply whenever the `.spec-flow.yaml deliberation.depth` key is absent and no explicit operator override is in effect.

## Lens subset (lite)

At `lite` depth, Phase D runs over a reduced lens subset rather than the full 5-lens board. The default subset is:

- `scope/simplicity` — is this the simplest solution? any scope creep or under-scope?
- `risk` — key failure modes, hidden assumptions, external dependencies?

This subset is overridable via the optional `.spec-flow.yaml deliberation.lenses` list. Absent the override, `[scope-simplicity, risk]` applies.

## Resolution order

1. **Explicit operator override** at invocation (highest precedence) — the operator may pass a depth flag directly to the calling skill at run time.
2. **`.spec-flow.yaml deliberation.depth`** — project-level config key; optional; absent means "use per-skill default".
3. **Per-skill default** (lowest precedence) — see ## Per-skill defaults above.

The chosen depth is recorded in `deliberation.md` §Investigation Summary (or in the `[DELIBERATION-SKIPPED]` marker for `off`) so a reviewer can see what depth produced the artifact.

## Phase C no-op rule

Phase C (synthesis / cross-cluster integration check) is depth-independent: it is a no-op whenever the piece has ≤1 decision-unit cluster, because there is nothing to integrate. The §Integration Check section of `deliberation.md` then records single-cluster coherence rather than a cross-cluster composition analysis.

Depth interaction:

- At `full` depth with ≥2 clusters, Phase C always runs.
- At `lite` depth the entire piece is treated as one cluster, so Phase C is always a no-op.

Cross-reference: FR-009-H. See `reference/deliberation-artifact.md` §Integration Check for the artifact-level recording rules; do not restate the schema here.

## off path

When the resolved depth is `off`, the calling skill:

1. Emits `[DELIBERATION-SKIPPED: depth=off]` as a single bracketed line in the skill's orchestrator output at the depth-resolution step.
2. Runs the current (pre-5.8.0) brainstorm unchanged — the operator sees no behavioral difference from a run without deliberation.
3. Does NOT dispatch any deliberation agents (Phases A–E are entirely skipped).
4. Does NOT commit a `deliberation.md` — the Tier 2 validation loop is inactive on this path.

The `[DELIBERATION-SKIPPED: depth=off]` marker is non-blocking. It appears in skill output only; it is not written into any artifact file.

## See also

- `plugins/spec-flow/skills/spec/SKILL.md` — calling skill (default depth: `full`)
- `plugins/spec-flow/skills/prd/SKILL.md` — calling skill (default depth: `full`)
- `plugins/spec-flow/skills/charter/SKILL.md` — calling skill (default depth: `full`)
- `plugins/spec-flow/skills/small-change/SKILL.md` — calling skill (default depth: `lite`)
- `plugins/spec-flow/reference/deliberation-artifact.md` — artifact schema, marker contract, VOQ-N IDs, return contract
- `.spec-flow.yaml` — project-level config; `deliberation:` key documents the override surface
