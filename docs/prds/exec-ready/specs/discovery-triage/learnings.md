# Learnings — exec-ready/discovery-triage (5.18.0)

Completed 2026-06-12. Phase count: 5. Final Review: 8-member board (doc-as-code variant), 7 must-fix, 6 should-fix applied.

## What worked

**Scaffold-first static assertions.** Authoring all 7 static.sh assertions in Phase 5 and using them as phase oracles (inline greps per phase) worked cleanly. Every phase had a concrete, machine-checkable oracle.

**Context-free invariant as a spec primitive.** Stating "triage-contract.md must contain NO execute-bound mechanics" as a testable negative-grep invariant in the plan gave the Phase 1 implementer a precise boundary. When it failed (two "cumulative-diff" hits), the fix was a targeted rephrase rather than a redesign.

**NN-C-008 cite-not-restate as a structural principle.** Having the contract as the single source of truth and requiring both skills to cite-not-restate eliminated an entire class of future divergence. The Final Review caught exactly one restatement (execute's suppression sentence) that survived Phase 3 — confirming the invariant is worth enforcing.

**Two-plugin.json discovery.** Static suite failure caught the two-plugin.json issue (`.claude-plugin/plugin.json` vs `plugin.json`) during Phase 5 integration testing, before it could drift. The ground-truth reviewer then flagged the missing assertion for the third file — both are now guarded.

## What to improve

**Verify commands for negative-match assertions need explicit false-positive context.** The Phase 2 V5 false positive (`grep -nE "Edit\(|Write\(|patch the|..."` matching "dispatch the") slowed triage. Negative-match verify commands should include a comment noting what strings are in-scope vs. not, or the regex should be anchored more tightly.

**Version-bump checklist gap in the plan template.** The plan didn't enumerate all three version-bearing files. Add a checklist item to the plan template for doc-as-code pieces: "Verify version bump across: (1) `plugin.json`, (2) `.claude-plugin/plugin.json`, (3) `.claude-plugin/marketplace.json`."

**Batch+spike interaction left unspecified.** The original triage skill Step 4 handled single findings correctly but left the batch+spike ordering undefined. For future doc-as-code skills with interactive flows, explicitly map multi-step interactions (confirm → spike → finalize) in the spec ACs, not just the happy path.

**Form B field mapping implicit, not stated.** The normalization block listed Form B fields without showing the mapping to the internal record. For any skill with multiple input forms, the plan should require an explicit field-mapping table as an AC (not just "normalize to internal record").

## Key decisions

**ADR-1: execute-bound mechanics stay inline.** Ratio thresholds, amendment-budget counters, and WIP-preemption are NOT in triage-contract.md. This boundary is why the contract is usable standalone. The execute FR-008 `y`-path calls out to the contract for classification but the guard conditions are its own.

**ADR-2: FR-008 `y`-path only.** Only the operator-admitted change path uses the 5-disposition vocabulary. The agent-discovery `(a)/(f)/(d)` prompt menu is out of scope (explicitly excluded at brainstorm). The clarifying paragraph in execute/SKILL.md at ~line 1089 is the load-bearing text distinguishing the two paths.

**FR-023 fold-in scope.** Operator decision 2026-06-12: execute's Step 6c rewired to share the contract vocabulary. This makes plan-amend no longer the only reachable disposition on operator-initiated changes. The four new dispositions (small-change, new-piece, note-on-scheduled, explicit-defer-with-rationale) are now reachable from execute's FR-008 `y`-path.

## Follow-on pieces now unblocked

- **outcome-campaign**: dependency closure complete with this piece. `spec-flow:triage` is the routing primitive; outcome-campaign is the batch orchestration layer.
- **pipeline-economics**: the execute-bound mechanics (ratio thresholds, budget counters) that stayed inline here are the data for the economics piece.
- **ADR-2 tech debt**: agent-discovered rows in execute still use the `(a)/(f)/(d)` menu, not the shared contract. A future piece could unify this too.
