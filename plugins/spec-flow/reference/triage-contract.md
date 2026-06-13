# Triage contract

Single source of truth for the *context-free* discovery-triage contract. Both `spec-flow:triage` (`plugins/spec-flow/skills/triage/SKILL.md`) and execute's Step 6c (`plugins/spec-flow/skills/execute/SKILL.md`) cite this doc and neither restates the disposition vocabulary (CR-008 / NN-C-008). Execute-bound mechanics (ratio thresholds, amendment-budget counters, block-aware placement, WIP-preemption) are NOT here — they stay inline in execute.

## Dispositions → target surface

| Disposition | Target surface |
|---|---|
| small-change | seeded handoff into /spec-flow:small-change (digest = authoritative reqs) |
| plan-amend | agents/plan-amend.md against the CURRENT working piece's plan.md (only when a current working piece resolves) |
| new-piece | new manifest.yaml entry (fork's direct-YAML idiom, minus the block-current-piece coupling) |
| note-on-scheduled | additive per-piece manifest `notes:` field on the target scheduled/queued piece |
| explicit-defer-with-rationale | /spec-flow:defer structured form (--rationale / operator_rationale required) |

## Exactly-one-disposition rule

Every classification yields exactly one disposition — never zero, never two. A finding that cannot be cleanly mapped to one of the five dispositions above must be escalated to the operator before any write or handoff occurs.

## Spike scope-mode (the only sanctioned Opus dispatch)

When a change needs design, dispatch `plugins/spec-flow/agents/spike.md` in scope mode (Opus, isolated, ≤2K return, `STATUS: OK|BLOCKED`) per `plugins/spec-flow/reference/spike-agent.md` `## Threshold reuse`. When triage runs outside execute, no diff ratio is available → always use scope-spike (the spike-agent.md undefined-ratio branch). On `STATUS: BLOCKED`: record an **open needs-scoping item** carrying the blocker and surface it; never fabricate a disposition.

Do NOT restate spike-agent.md internals (NN-C-008). Cite, don't reproduce.

## Provenance & recorded-row convention

Every disposition writes a recorded, provenance-bearing entry. Provenance = `{source session/finding, date}`. The recorded row follows execute's `.discovery-log.md` one-row-per-discovery format (see `plugins/spec-flow/skills/execute/SKILL.md` `.discovery-log.md authoring`). No disposition is a silent mid-stream patch (NN-P-002); no defer is silent (NN-P-004).

## Operator gate (no auto-apply)

Every disposition requires explicit operator confirmation of the proposal before any write or handoff — there is NO auto-apply path (NN-P-004 "nothing is auto-applied"). When multiple findings are supplied at once (FR-020 campaign batch), present them in a **single aggregated confirm prompt** (execute's existing Step 6c aggregated-prompt pattern) — one confirmation event, not one keystroke per finding.

## Manifest `notes:` schema

The `note-on-scheduled` disposition appends to a per-piece `notes:` list. Schema (additive — a piece entry lacking `notes:` parses unchanged):

```yaml
# Optional, additive, per-piece. A piece entry lacking `notes:` parses unchanged.
notes:
  - source: <source session / finding ref>
    date: <YYYY-MM-DD>
    finding: <one-line finding text>
```

## Red-first obligation (NN-P-006 forward-record)

Bug-signal keyword set: `fix` / `bug` / `broken` / `regression` / `patch` (small-change's existing set).

On a bug-classified discovery routed to a **fix** disposition (`small-change` / `plan-amend` / `new-piece`), stamp the red-first reproduce→fail→fix→pass obligation onto **all three** provenance surfaces: (1) the downstream handoff digest, (2) the recorded `.discovery-log.md`-style row, (3) the manifest/backlog entry.

Forward-record only — NO dependency on the unmerged `bugfix-redfirst` machinery.

Cite PRD NN-P-006 / FR-022; do not restate the red-first cycle mechanics.

## FR-008 mid-execution change-signal phrasing set (the documented trigger set — ONE place)

The hardened set that execute's FR-008 admission uses. Documented here once; execute cites this section (NN-C-008 — do NOT restate it inline in execute).

```
Imperative / change-request signals (case-insensitive, leading-phrase match):
  add…, change…, remove…, delete…, rename…, replace…, update…, refactor…,
  we should…, what if we…, can you also…, let's also…, also need…, it should…,
  instead of…, make it…, switch to…, drop…, get rid of…, handle… (when phrased as a new requirement)
Suppression rule (PRESERVED): free-form input is treated as a structured ANSWER — never a change-signal —
  whenever the coordinator is awaiting a constrained response (a y/n triage choice, a model-policy
  confirmation, a QA sign-off, a BLOCKED-escalation response, or any active prompt expecting a constrained reply).
A false positive is a harmless, cancellable confirmation prompt (operator answers n).
```

## Consumed by

`plugins/spec-flow/skills/triage/SKILL.md` (the standalone skill) and `plugins/spec-flow/skills/execute/SKILL.md` Step 6c (the FR-008 admission `y`-path) both classify through this contract.
