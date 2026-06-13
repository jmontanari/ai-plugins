# Fixture: campaign → triage seam (AC-8)

**Scenario:** A graded + theater-guard-confirmed finding from spec-flow:campaign crosses the boundary into /spec-flow:triage as a Form C batch and receives a recorded triage disposition — not a chat-only note.

## Setup

- Campaign has completed Steps 4–5: three lens agents ran; one finding survived the `campaign-verify` theater-guard VERIFY with verdict `CONFIRMED`.
- The surviving finding carries:
  - `lens: campaign-ground-truth`
  - `finding_text: "The win-rate column reports 1.0 for all input configurations — dead-knob degeneracy."`
  - `output_evidence: "win_rate: 1.0 (config A), win_rate: 1.0 (config B), win_rate: 1.0 (config C)"`
  - `oracle_ac_id: AC-04`
  - `bug_classified: true`
  - `discovery_type: degeneracy`

## Expected behavior (AC-8)

1. **Form B record construction.** The skill assembles a Form B record with all required campaign-source fields:
   ```
   source_phase: campaign
   source_agent: campaign-ground-truth
   finding_text: "The win-rate column reports 1.0 for all input configurations — dead-knob degeneracy."
   discovery_type: degeneracy
   bug_classified: true
   ```

2. **Form C dispatch.** The skill invokes `/spec-flow:triage` exactly once with the complete batch (all surviving Form B records). The invocation is a single aggregated confirm (NN-P-004) — not one call per finding.

3. **Recorded disposition.** The triage flow produces a durable disposition (fix / spike / explicit-defer) recorded per the triage contract. The campaign reports the triage disposition in its run summary. A `fix` disposition for a `bug_classified: true` record triggers the NN-P-006 red-first stamp via triage Step 7 — the campaign's `bug_classified: true` pre-seeded this path (BRF-3).

## Falsifying conditions (would break AC-8)

- The skill DOES NOT invoke `/spec-flow:triage` — findings are logged as chat notes only. ❌
- The skill invokes triage once per finding (N separate calls) rather than as a single Form C batch. ❌
- The Form B record omits `bug_classified` or `source_phase`. ❌
- The triage disposition is not recorded (ephemeral only). ❌
- A `bug_classified: true` `fix` disposition does not trigger NN-P-006 red-first stamp. ❌

## Oracle

**Assert:** `spec-flow:campaign` SKILL.md contains `spec-flow:triage` (wiring assertion).
**Assert:** `spec-flow:campaign` SKILL.md contains `Form C` (batch invocation confirmed).
**Assert:** `spec-flow:triage` contract (`reference/triage-contract.md`) documents `source_phase: campaign` as a valid Form B/C source.
**Assert:** `reference/triage-contract.md` documents `bug_classified` as a Form B/C field.
