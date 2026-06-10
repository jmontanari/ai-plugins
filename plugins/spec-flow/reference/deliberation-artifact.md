# Deliberation Artifact (deliberation.md) — Contract

This document is the single source of truth for the `deliberation.md` artifact produced by the spec-flow deliberation protocol. It is cited by the six deliberation agents (`deliberation-coordinator`, `deliberation-viability`, `deliberation-synthesis`, `deliberation-lens`, `deliberation-convergence`, `deliberation-validate`), the four calling skills (`spec`, `prd`, `small-change`, `charter`), and the `plan` skill (Phase-1 consumption). Any schema detail, marker definition, VOQ/Validation-Round format, or return-contract rule lives here and nowhere else; the agents and all skills defer to this file for authoritative definitions.

## Location

`deliberation.md` is written to the following path on the piece branch by the Phase E convergence agent:

```
docs/prds/<prd-slug>/specs/<piece-slug>/deliberation.md
```

`<prd-slug>` and `<piece-slug>` are resolved from `docs/prds/<prd-slug>/manifest.yaml`. This path is the single authoritative location — the convergence agent writes here, the calling skill commits here, and the plan skill reads here.

## deliberation.md structure

The file uses 7 core H2 sections, written in this exact order by the Phase E convergence agent:

1. `## Investigation Summary` — records the resolved depth (`full` / `lite`) and a high-level description of what the investigation found.
2. `## Viability Analysis` — one entry per **decision unit** (FR for `spec`, candidate piece/decomposition boundary for `prd`, domain rule/principle for `charter`, the change for `small-change`). Each entry is a markdown table with the following columns:

   | Path | Verdict | Reasoning | Reuse? | Blocker |
   |------|---------|-----------|--------|---------|

   - **Path** — the candidate implementation path or option.
   - **Verdict** — `VIABLE` or `NON-VIABLE`.
   - **Reasoning** — justification relative to charter constraints, codebase conventions, and PRD goals.
   - **Reuse?** — flag indicating whether this path reuses or extends existing code (surfaced from `research.md` findings); must be explicitly evaluated, not defaulted to "no".
   - **Blocker** — required if and only if the verdict is `NON-VIABLE`; must be a concrete identified blocker (EARS-style — never a bare "seems hard", "should", or "may").

3. `## Integration Check` — cross-cluster path composition analysis. When Phase C is a no-op (≤1 cluster, depth-independent rule), this section records single-cluster coherence. When Phase C ran, this section records conflicts, the narrowed composable path set, and any unresolvable cross-cluster conflicts (which become validated open questions).
4. `## Adversarial Review` — lens-by-lens challenge and verdict from Phase D. Each lens documents what was challenged and whether the verdict was `HOLDS` or `CONTESTED`. When Phase D is entirely unavailable (all lens agents BLOCKED), this section explicitly states "adversarial review unavailable" rather than being omitted.
5. `## Recommendation` — the finalized recommendation after Phase D verdicts are folded by Phase E. Revised from the Phase C recommendation if CONTESTED verdicts required changes.
6. `## Validated Open Questions` — questions that survived adversarial review unresolved; see `## VOQ-N ID contract` below for the stable ID assignment rules. Each entry carries a `VOQ-N` ID. Brainstorm questions and qa-spec cite these IDs.
7. `## Answered by Investigation` — dimensions that deliberation resolved or confirmed N/A. Each entry records the dimension, whether it was resolved or N/A, and the rationale. Consumed by the mandatory-block skip logic in `reference/brainstorm-procedure.md`.

**Optional 8th section:** `## Validation Rounds` may be appended after `## Answered by Investigation` by the Tier 2 validate loop (`deliberation-validate` agent) during brainstorm. A reviewer or qa-spec **MUST tolerate the presence OR absence of this 8th section** — its presence is not an error and its absence is not a finding.

## VOQ-N ID contract

Every entry in `## Validated Open Questions` carries a stable, sequentially assigned identifier: `VOQ-1`, `VOQ-2`, `VOQ-3`, and so on.

Rules:

- IDs are assigned only to questions that survived adversarial review (Phase D) unresolved. The Phase E convergence agent assigns them.
- IDs are not assigned to questions resolved during deliberation (those go in `## Answered by Investigation`).
- Once assigned, a `VOQ-N` ID is stable for the lifetime of the piece — it is not renumbered if earlier questions are later resolved.
- The calling skill's Phase 2 brainstorm instructions require every question presented to the operator to cite either a `VOQ-N` ID (for a listed validated open question) or a named deliberation section (for an emergent follow-up, e.g., "Following deliberation §Integration Check: …").
- qa-spec treats absence of `VOQ-N` IDs in `## Validated Open Questions` as a must-fix finding when `deliberation.md` is present. **Exemption:** a `## Validated Open Questions` section whose body is an explicit "None — …" sentinel (indicating no questions survived adversarial review) is a valid clean state and is NOT a must-fix finding. The VOQ-N-presence check applies only to actual question entries; the sentinel is not a question entry.

## Validation Round contract

The optional `## Validation Rounds` H2 holds one `### Validation Round <n>` subsection per Tier-2 pass, in the order the passes completed. Each subsection records the following fields in order:

```
**Assertion:** <verbatim operator assertion that triggered this round>
**Verdict:** CONFIRM | FLAG-HARD | FLAG-SOFT
**Evidence:** <evidence cited by the deliberation-validate agent>
**Resolution:** folded | revised | overridden-with-rationale
```

- **Assertion** — the verbatim operator free-form input that triggered the `deliberation-validate` dispatch.
- **Verdict** — exactly one of `CONFIRM`, `FLAG-HARD`, or `FLAG-SOFT` (see `## Marker contract` for the verdict semantics; the skill, not the agent, owns the override interaction).
- **Evidence** — the agent's cited evidence supporting the verdict.
- **Resolution** — how the assertion was handled: folded (assertion accepted), revised (brainstorm answer revised), or overridden-with-rationale (operator invoked FLAG-SOFT override).

Validation Rounds are appended during brainstorm by the Tier 2 loop. Phase E (`deliberation-convergence`) does NOT write the 8th section; it writes only the 7 core sections.

New conflicts surfaced in a Validation Round become `VOQ-N`-tagged validated open questions (appended to `## Validated Open Questions`). The Tier 2 loop terminates only on operator sign-off with no new assertions outstanding — there is no artificial round cap.

## Marker contract

Four markers are defined for use across the calling skills and the plan skill. Each marker has an exact emitter and a defined trigger set. No other marker forms are valid.

### `[DELIBERATION-UNAVAILABLE: <phase>-<reason>]`

Emitted by the **calling skill** (spec, prd, small-change, or charter). Triggers on any of the following **5 fatal conditions**:

- **(a)** Phase A (`deliberation-coordinator`) returns `STATUS: BLOCKED`.
- **(b)** Phase C (`deliberation-synthesis`) returns `STATUS: BLOCKED`.
- **(c)** Phase E (`deliberation-convergence`) returns `STATUS: BLOCKED`.
- **(d)** `deliberation.md` is missing or zero-length on the piece branch after Phase E returns `STATUS: OK`.
- **(e)** The `git commit` of `deliberation.md` fails (staging zero files or a non-zero exit from `git commit`). On this trigger, the calling skill MUST remove the uncommitted `deliberation.md` (e.g. `git checkout -- <path>` if previously committed, else `rm -f <path>`) before falling back, so downstream consumers cannot pick up a disowned artifact.

The marker is **non-blocking**: the calling skill logs it inline and falls back to current (pre-5.8.0) brainstorm behavior, indistinguishable from a run without deliberation. No `deliberation.md` is committed on this path. `<phase>-<reason>` is a short human-readable description of which trigger fired (e.g., `phase-A-blocked`, `phase-E-blocked`, `deliberation.md-empty-after-dispatch`, `deliberation.md-commit-failed`).

**2 non-fatal partial conditions (do NOT emit `[DELIBERATION-UNAVAILABLE]` for these):**

- **(f)** Phase B (`deliberation-viability`) returns `STATUS: BLOCKED` for some-but-not-all clusters — the skill proceeds to Phase C with the remaining cluster outputs; Phase C notes the missing clusters. This is a non-fatal partial: deliberation continues. **Single cluster (lite/small-change): the only cluster is blocked, so no viability output exists and a valid `deliberation.md` cannot be produced — the calling skill falls back to the current brainstorm. No `[DELIBERATION-UNAVAILABLE]` marker is emitted in either case (Phase B is non-fatal); the single-cluster fallback is surfaced to the operator as a plain one-line note, not a marker.**
- **(g)** Phase D (`deliberation-lens`) returns `STATUS: BLOCKED` for any or all lens agents — the skill proceeds to Phase E with the available verdicts (which may be empty); Phase E notes "adversarial review unavailable" in `## Adversarial Review`. This is a non-fatal partial: deliberation continues. When ALL Phase D lens agents are BLOCKED, the calling skill also surfaces a one-line operator note: "deliberation proceeded without adversarial review — recommendation not adversarially vetted."

These two partial conditions do not trigger `[DELIBERATION-UNAVAILABLE]`. They are documented here to make the fatal/non-fatal distinction unambiguous.

### `[DELIBERATION-SKIPPED: depth=off]`

Emitted by the **calling skill** when the resolved depth is `off` (per the resolution order in `reference/deliberation-depth.md`). The skill runs the current (pre-5.8.0) brainstorm unchanged. The Tier 2 loop does not fire (no `deliberation.md` exists on this path).

### `[DELIBERATION-CONSUMED: <recommendation-one-liner>]`

Emitted by the **plan** skill Phase 1 when `deliberation.md` exists on the piece branch and is non-empty. `<recommendation-one-liner>` is a brief summary of the `## Recommendation` section. The plan skill uses the recommendation as the approach anchor for planning.

### `[DELIBERATION-ABSENT: no deliberation artifact]`

Emitted by the **plan** skill Phase 1 when `deliberation.md` is absent or zero-length on the piece branch at the start of Phase 1. On this path the plan skill continues with current plan behavior unchanged.

### STATUS lines and marker placement

Each marker is emitted as a single bracketed line in the calling skill's orchestrator output at the point where the branch decision is made. Markers are NOT written into `deliberation.md` — they appear in the skill's progress output only.

## Return contract

Each deliberation agent (`deliberation-coordinator`, `deliberation-viability`, `deliberation-synthesis`, `deliberation-lens`, `deliberation-convergence`, `deliberation-validate`) returns a structured digest to the calling skill at the end of its run.

- The digest is **≤ 2 000 tokens**.
- The on-disk `deliberation.md` written by Phase E may be richer (longer, more complete sections); the digest is a summary for the skill's in-context use and marker-emission decisions.
- The **FINAL line** of every agent's return must be exactly one of:

```
STATUS: OK
```

```
STATUS: BLOCKED
```

- `STATUS: OK` means the agent completed its phase successfully.
- `STATUS: BLOCKED` means the agent could not complete its phase (missing inputs, unresolvable issue, or error preventing useful output). On `STATUS: BLOCKED` the agent must include a brief reason in the digest body **before** the status line and must **NOT** write a partial artifact to disk.
- No other STATUS values are valid. The calling skill keys its fallback decisions on whether this final line equals `STATUS: OK`.

## See also

- `plugins/spec-flow/agents/deliberation-coordinator.md` — Phase A agent; reads injected inputs, fires web research on genuine unknowns.
- `plugins/spec-flow/agents/deliberation-viability.md` — Phase B agent (parallel, one per cluster); enumerates all viable paths with verdicts and blockers.
- `plugins/spec-flow/agents/deliberation-synthesis.md` — Phase C agent; cross-cluster composition check and integration recommendation.
- `plugins/spec-flow/agents/deliberation-lens.md` — Phase D agent (parallel, one per lens); adversarial challenge from a single injected lens (`{lens}`).
- `plugins/spec-flow/agents/deliberation-convergence.md` — Phase E agent; writes the 7-core-section `deliberation.md`, assigns VOQ-N IDs.
- `plugins/spec-flow/agents/deliberation-validate.md` — Tier 2 agent; validates a single operator assertion during brainstorm, appends a Validation Round.
- `plugins/spec-flow/skills/spec/SKILL.md` — calling skill that dispatches deliberation pre-brainstorm; emits UNAVAILABLE/SKIPPED markers.
- `plugins/spec-flow/skills/prd/SKILL.md` — calling skill; same deliberation dispatch contract.
- `plugins/spec-flow/skills/small-change/SKILL.md` — calling skill; same dispatch contract, default depth `lite`.
- `plugins/spec-flow/skills/charter/SKILL.md` — calling skill; same dispatch contract.
- `plugins/spec-flow/skills/plan/SKILL.md` — consumes `deliberation.md` in Phase 1; emits CONSUMED/ABSENT markers.
- `plugins/spec-flow/reference/deliberation-depth.md` — depth policy: `full`/`lite`/`off` profiles, per-skill defaults, resolution order.
- `plugins/spec-flow/reference/research-artifact.md` — the analogous contract for `research.md`; this file mirrors its structure.
