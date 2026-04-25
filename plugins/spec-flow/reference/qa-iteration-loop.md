# QA iteration loop (iter-until-clean)

This document specifies the iter-until-clean pattern that every QA gate in spec-flow follows. All skills that run QA loops (`/spec-flow:spec`, `/spec-flow:plan`, `/spec-flow:charter`, `/spec-flow:execute`) defer to this reference for iteration numbering, input modes, and termination rules.

## Purpose

Every QA gate in the pipeline iterates until the reviewing agent returns must-fix=None. The 3-iter circuit breaker is the escalation guard — it fires when iteration 3 still has must-fix findings and the orchestrator cannot resolve them automatically. The circuit breaker is NOT a normal stopping condition; it escalates to the human rather than auto-advancing. A gate that finishes in 2 iterations did not "succeed at iter-2" — it succeeded when must-fix became None, which happened to occur at iter-2.

## Iteration numbering

- **iter-N** = the Nth dispatch of the QA reviewer agent for a single QA gate.
- Between iter-N and iter-(N+1), the orchestrator performs one fix-doc dispatch (for spec/plan/charter QA gates — the artifact is a document) or one fix-code dispatch (for `/spec-flow:execute` per-phase QA / Step 6, group QA / Step G8, mid-piece QA / Step 0a, and Final Review fix-up / Step 3). This is the fix-doc dispatch or fix-code dispatch that resolves findings before the focused re-review at iter-N+1.
- The fix agent does NOT commit; it returns a `## Diff of changes` section. The orchestrator applies the diff and commits before the next QA iteration.
- After the fix is committed, the orchestrator re-dispatches the QA agent with `Input Mode: Focused re-review` (iter-N+1). This focused re-review receives the prior iteration's must-fix findings and the fix diff — not the full artifact.
- The **3-iter circuit breaker** fires when iter-3 returns ≥ 1 must-fix finding. At that point the orchestrator escalates to the human with the iter-3 must-fix list intact and does NOT dispatch iter-4.

## Input modes

- **iter-1: Full** — the dispatched QA agent receives the complete artifact (spec.md / plan.md / charter file set / phase diff). The agent applies all review criteria — no sections are pre-filtered.

- **iter-2+: Focused re-review** — the dispatched QA agent receives the prior iteration's must-fix findings plus the fix-doc/fix-code unified diff. The agent does NOT re-examine unchanged sections. The agent template's iter-2 rules hard-cap out-of-scope reads (return BLOCKED rather than fetching content outside the diff and prior findings). This keeps focused iterations cheap and prevents regressing findings that were already clean.

## Iteration termination

- **must-fix=None terminates the loop.** The orchestrator proceeds to the next pipeline stage. A gate terminates cleanly regardless of which iteration number produced the clean result.
- **Circuit-breaker termination escalates to human.** When iter-3 returns ≥ 1 must-fix finding, the orchestrator surfaces the iter-3 must-fix list to the human and halts. The only forward paths are: (a) the human amends the artifact directly and re-runs the QA gate from iter-1, or (b) the human overrides the finding as out-of-scope with an explicit rationale.
- **Fix-agent "no diff" escalation.** If the fix agent returns `Diff of changes: (none)` (all findings were blocked or unaddressable), the orchestrator escalates immediately — no point dispatching another QA iteration against an unchanged artifact.

## Where this pattern is invoked

- `/spec-flow:spec` Phase 4 QA Loop
- `/spec-flow:plan` Phase 3 QA Loop
- `/spec-flow:charter` Phase 4 QA loop (bootstrap mode) and Phase U4 QA loop (update mode)
- `/spec-flow:execute` Step 6 Phase QA + Step G8 Group Deep QA + Step 0a Mid-piece QA + Final Review fix-up (Step 3)

## Migration from `qa_iter2: auto` (v3.0.x → v3.1.0)

In v3.0.x, the `qa_iter2` config key in `.spec-flow.yaml` controlled whether the orchestrator skipped iter-2 re-dispatch after a fix-code commit. In `auto` mode (the default), the orchestrator skipped the iter-2 re-dispatch when the fix diff was small AND the fix-code agent self-verified all findings resolved AND the oracle was green.

v3.1.0 retires this skip. The iter-until-clean pattern is now the default for all QA gates — every must-fix finding routes to a fix agent and then back to the QA reviewer, regardless of diff size or self-verification. The 3-iter circuit breaker provides the only automatic exit short of must-fix=None.

The `qa_iter2` config key is retained in `plugins/spec-flow/templates/pipeline-config.yaml` (and is valid in user `.spec-flow.yaml` files) for backwards-compatibility: existing user configs that set `qa_iter2: auto` or `qa_iter2: always` continue to parse without error or warning. The orchestrator-side logic that read and acted on this key is removed; the key is silently ignored on read.

## See also

- [plugins/spec-flow/reference/charter-drift-check.md](charter-drift-check.md) — charter drift check procedure run at Phase 1 of each skill.
- [plugins/spec-flow/reference/slug-validator.md](slug-validator.md) — slug rules, branch length budget, refusal contract.
- [plugins/spec-flow/reference/v3-path-conventions.md](v3-path-conventions.md) — v3 multi-PRD layout, path resolution table.
