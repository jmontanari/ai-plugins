# AC Coverage Matrix contract

This document defines the AC Coverage Matrix shape that Build agents emit at the end of every phase report and that the verify gate in `plugins/spec-flow/skills/execute/SKILL.md` Step 4 validates before advancing the phase. All skills, agents, and templates that produce or consume an AC Coverage Matrix defer to this reference for schema, validation rules, reason interpretation, refusal contracts, and the legacy opt-out flag.

## Purpose

The AC Coverage Matrix is the orchestrator's structured handoff from a Build agent's claim ("I implemented these ACs") to the verify gate's check ("the implementation actually covers each in-scope AC, or explicitly declares why it doesn't"). A complete, specific matrix unlocks Audit-mode verification (3 min) on the current phase and the next; a missing, vague, or malformed matrix forces Full-mode re-verification (15 min) and re-dispatches the Build agent.

A second purpose, introduced in v3.2.0: when a phase legitimately cannot cover an AC, the matrix is the single place where the agent declares *why* and the orchestrator decides *what to do next* (pause for inline operator confirmation, route to spec amendment, or route to a fork). This routing is governed by the `Reason:` field defined below.

## Schema

The matrix is a single GitHub-flavored markdown table with exactly four columns, in this order:

| Column | Required | Allowed values |
|--------|----------|----------------|
| AC ID | always | The AC identifier from the spec (e.g. `AC-1`, `AC-13a`). |
| Status | always | One of: `covered`, `NOT COVERED`, `NOT COVERED — deferred to <pointer>`. |
| Pointer | always | For `covered`: a concrete `file:line` (TDD mode) or a concrete assertion reference inside the `[Verify]` command (Implement mode). For `NOT COVERED — deferred to <pointer>`: the phase or spec amendment where the AC will be picked up (e.g. `Phase N+1 per plan.md:L120`). For bare `NOT COVERED`: `—` (em dash). |
| Reason | required ONLY when Status starts with `NOT COVERED — deferred` | One of: `does-not-block-goal`, `requires-amendment`, `requires-fork`. Empty (`—`) for `covered` rows and bare `NOT COVERED` rows. |

The expected literal column header row is:

```
| AC ID | Status | Pointer | Reason |
|-------|--------|---------|--------|
```

The orchestrator parses this as a markdown table; columns must appear in this order. Build agents must not rename, reorder, or merge columns.

### Example (well-formed)

```
| AC ID  | Status                                    | Pointer                                | Reason               |
|--------|-------------------------------------------|----------------------------------------|----------------------|
| AC-1   | covered                                   | tests/path/to/test_file.py:42          | —                    |
| AC-2   | covered                                   | tests/path/to/test_other.py:71         | —                    |
| AC-3   | NOT COVERED — deferred to Phase 4         | plan.md:L210                           | does-not-block-goal  |
| AC-4   | NOT COVERED — deferred to spec amendment  | Step 6c routing → amend                | requires-amendment   |
```

## Validation rules

The verify gate REJECTS the Build report (and re-dispatches the Build agent within the 2-attempt budget) when ANY of the following are true:

1. **Missing matrix.** The Build report has no `## AC Coverage Matrix` heading or no markdown table beneath it.
2. **Incomplete coverage.** Any in-scope AC for the current phase is missing from the matrix entirely. (In-scope ACs come from the phase's `**ACs Covered:**` line in `plan.md`.) Omission reads as "the agent forgot" rather than "there is nothing to report."
3. **Bare `NOT COVERED`.** A row with `Status: NOT COVERED` and no pointer (the row's Pointer column is `—`). The agent must either commit to coverage (`covered`) or explicitly defer with a pointer (`NOT COVERED — deferred to <pointer>`).
4. **Vague `covered` pointer.** A `covered` row whose Pointer column lacks a concrete `file:line` (TDD mode) or a concrete assertion reference inside the `[Verify]` command (Implement mode). Examples that fail validation: `see test file`, `covered by integration tests`, `tests/foo.py` (no line), `the build runs`. The pointer must be unambiguously verifiable.
5. **Deferred row missing `Reason:`.** A row with `Status: NOT COVERED — deferred to <pointer>` whose Reason column is empty or `—`, UNLESS the plan's front-matter sets `legacy_deferred_rows: true` (see Legacy mode below). On rejection, the verify gate emits the refusal string defined in Refusal contracts.
6. **Invalid `Reason:` value.** A Reason column value that is not one of `does-not-block-goal`, `requires-amendment`, `requires-fork`. The orchestrator does not auto-correct typos; the Build agent must re-emit the row with a valid value.

A matrix that passes all six rules is accepted, and the orchestrator proceeds with the verify gate's other checks (oracle output, plan adherence, etc.).

## Reason interpretation

The three valid `Reason:` values map to distinct orchestrator actions in `plugins/spec-flow/skills/execute/SKILL.md`:

- **`does-not-block-goal`** — the Build agent claims that deferring this AC does not block the piece's stated goals. Step 4 PAUSES the phase and emits an inline operator prompt of the shape `Phase claims AC <id> can defer without blocking <piece>'s goals — confirm? (y/n)`. On `y`, the deferral is accepted and the phase advances. On `n`, Build is re-dispatched within the existing 2-attempt budget. (FR-8 of pi-010-discovery.)

- **`requires-amendment`** — the Build agent claims the AC, as written, is incompatible with what the implementation actually requires; the spec needs an amendment before this AC can be covered. Step 4 records the row in orchestrator state under `phase_<id>_routed_discoveries` and routes it to Step 6c (discovery triage) with `amend` as the default option.

- **`requires-fork`** — the Build agent claims the AC reveals a structural conflict that cannot be resolved by amending the current spec — the implementation work belongs in a separate piece. Step 4 records the row under `phase_<id>_routed_discoveries` and routes it to Step 6c with `fork` as the default option.

In all three cases, the agent's *claim* is what the matrix records. The orchestrator's response (operator prompt, amend default, fork default) is invariant per Reason value; the human operator (for `does-not-block-goal`) or the Step 6c triage flow (for `requires-amendment` / `requires-fork`) decides the final outcome.

## Refusal contracts

When a deferred row is missing its `Reason:` field (validation rule 5 above) and `legacy_deferred_rows` is NOT `true`, the verify gate emits this exact string and re-dispatches Build:

```
REFUSED — deferred row missing Reason; specify does-not-block-goal | requires-amendment | requires-fork.
```

The string must match verbatim — Build agents and downstream tooling key off the literal text. (FR-7 of pi-010-discovery.)

When a Reason value is invalid (validation rule 6), the verify gate emits:

```
REFUSED — invalid Reason value; specify does-not-block-goal | requires-amendment | requires-fork.
```

Other validation-rule failures (1–4) reuse the existing pre-3.2.0 refusal prose in `plugins/spec-flow/skills/execute/SKILL.md` Step 4 — they are not changed by this contract.

## Legacy mode (`legacy_deferred_rows: true`)

A plan's front-matter MAY set `legacy_deferred_rows: true` to opt out of the v3.2.0 `Reason:` field requirement for one release. When this flag is set:

- Validation rule 5 is silenced: a deferred row may omit its `Reason:` field without triggering the refusal contract. The matrix is accepted with the `Reason:` column empty (or absent entirely if the agent emitted only three columns, matching pre-3.2.0 shape).
- Validation rules 1, 2, 3, 4, and 6 STILL apply. Legacy mode silences only the format check on the `Reason:` field; it does not weaken any other validation.
- **Triage routing for `requires-amendment` and `requires-fork` rows STILL fires.** If a Build agent under legacy mode chooses to populate the Reason column anyway (with a valid value), the orchestrator routes the row to Step 6c exactly as it would in v3.2.0+ mode. Legacy mode silences the *format check*, not the *routing*. This is by design: a project on the legacy flag during migration may still emit Reason values, and those values must be honored.

The flag is declared deprecated at introduction. It exists to preserve pre-3.2.0 acceptance behavior for one release while projects update their Build agents and templates, and it will be retired in v3.3.0. Plans that omit the flag, or set it to `false`, get the v3.2.0+ behavior (the `Reason:` field is required for deferred rows).

## See also

- [plugins/spec-flow/reference/qa-iteration-loop.md](qa-iteration-loop.md) — QA iter-until-clean pattern that Step 4 invokes when the matrix is rejected.
- [plugins/spec-flow/reference/v3-path-conventions.md](v3-path-conventions.md) — repo-relative path conventions referenced in `Pointer` column values.
- `plugins/spec-flow/skills/execute/SKILL.md` Step 4 — the verify gate that enforces every rule documented here.
- `plugins/spec-flow/templates/plan.md` — declares the `legacy_deferred_rows` front-matter key.
