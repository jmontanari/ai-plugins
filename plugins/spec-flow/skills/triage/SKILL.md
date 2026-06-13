---
name: triage
description: >-
  Classify a discovery — agent-found or operator-stated — to exactly one disposition and route it
  to a recorded, provenance-bearing manifest/backlog entry, out of band from any session. Five
  dispositions: fix-now via small-change / amend the current working piece's plan / new manifest
  piece / note on a scheduled piece / explicit defer with rationale. Dispatches the spike agent in
  scope mode when a change needs design; never patches code, merges, or auto-applies. Use when the
  user says "triage this", "what should we do with this finding", "route this discovery", or an
  FR-020 campaign hands off findings.
argument-hint: "<discovery-text | finding-ref> [--source <s>] [--rationale <r>] [--piece <slug>]"
---

# Triage — Standalone Discovery Classification and Routing

Classify a discovery (agent-found or operator-stated) to exactly one of the five dispositions defined in `plugins/spec-flow/reference/triage-contract.md`, record it with provenance, and route it to the correct target surface. This skill is **standalone** — it does NOT require an active piece, a manifest, or even a running execute loop. It requires only a spec-flow project layout (a git repo with `docs_root`).

## Step 0: Load config (best-effort)

- Read `.spec-flow.yaml` if present; capture `docs_root` (default `docs`). Used to locate the manifest and any active piece context — never required.
- Confirm the working directory is inside a git repo (`git rev-parse --is-inside-work-tree`). If not, STOP and tell the user the skill needs a git repo.

## Step 1: Parse input

Accept any of the following three input forms — all map to one internal classification record:

**Form A — positional + flags:**
- Positional `<discovery-text | finding-ref>`: the raw discovery string or a finding reference (e.g., `qa-phase:phase-3:AC-7`)
- `--source <s>`: session ID, agent name, or origin label (e.g., `qa-phase`, `operator`)
- `--rationale <r>`: operator rationale (required for `explicit-defer-with-rationale`)
- `--piece <slug>`: hint that this discovery relates to a specific manifest piece

**Form B — structured field set** (FR-020 / execute Step 6c handoff):
Fields: `source_piece`, `source_phase`, `source_agent`, `finding_text`, `operator_rationale`, `target?`, `discovery_type?`

**Form C — batch** (FR-020 campaign): a list of Form A or Form B findings. All findings in a batch proceed through Steps 2–4 together and are presented as a single aggregated confirm prompt.

For Form B the field mapping is: `piece_hint` ← `source_piece`; `rationale` ← `operator_rationale`; `source` ← `<source_phase>:<source_agent>`. A non-null `target?` field is treated as a **classification hint** — present it as the pre-selected disposition at Step 4 but allow the operator to correct it.

Normalize all three forms into an internal record:
```
{finding_text, source, rationale?, piece_hint?, discovery_type?}
```

## Step 2: Bug-signal scan

Scan `finding_text` for the keyword set defined in `plugins/spec-flow/reference/triage-contract.md` `## Red-first obligation`: `fix` / `bug` / `broken` / `regression` / `patch`.

- If any keyword matches (case-insensitive), set `bug_classified = true`.
- Forward-record only: this flag is consumed at Step 7 to stamp provenance surfaces. It does NOT constrain the disposition choice. (Consistent with intake's `small_change_signals_detected` precedent — FR-T7.)

## Step 3: Classify (exactly one disposition)

Classify to **exactly one** of the five dispositions per `plugins/spec-flow/reference/triage-contract.md` `## Dispositions → target surface`. Never zero, never two — per the contract's `## Exactly-one-disposition rule`.

The five dispositions are defined in `plugins/spec-flow/reference/triage-contract.md`. Cite the contract; do not restate the vocabulary here (NN-C-008 / CR-008).

**Classification decision tree:**

1. Is the discovery a standalone, bounded fix or improvement that does not depend on an open piece's plan? → `small-change`
   > Note: a bug-signal finding whose natural home is an already-scheduled piece may fit `note-on-scheduled` (item 4) better — do not assume `small-change` is always the right call for bug-signal findings. Present the classification rationale to the operator at Step 4 when both `small-change` and `note-on-scheduled` are viable.
2. Does the discovery require amending the plan of the *current working piece*? → `plan-amend` **only if** `--piece` was supplied AND that piece resolves to a current working piece in the worktree (via defer's reverse-lookup). If `--piece` was not supplied, `plan-amend` is NOT presented as an option. If `--piece` was supplied but resolves to a manifest piece that is **not** `in-progress` (e.g., `scheduled`, `queued`, `open`, or `done`), withhold `plan-amend` AND surface an advisory before the disposition menu: "Note: `--piece <slug>` names a piece in `<status>` state — `plan-amend` requires an `in-progress` piece; the option is withheld." Record this advisory in the provenance row at Step 7. (AC-11, FR-T1)
3. Does the discovery warrant a new scoped piece of work in the manifest? → `new-piece`
4. Is this a finding to attach to an already-scheduled/queued piece without modifying its plan? → `note-on-scheduled`
5. Is the discovery acknowledged but intentionally deferred with a recorded rationale? → `explicit-defer-with-rationale`

When the finding cannot be cleanly mapped to one disposition, escalate to the operator before any write or handoff (per contract `## Exactly-one-disposition rule`).

## Step 4: Operator confirm (no auto-apply)

Present the proposed disposition(s) and require explicit operator confirmation before ANY write or handoff. There is **no auto-apply path** (contract `## Operator gate`, NN-P-004).

For a single finding: present the proposed disposition, target surface, and rationale; wait for `y` / `n` / correction. (When the finding has not yet been scoped — i.e., a spike is pending — confirm "proceed with scope-spike?" here; the actual disposition is finalized after the spike returns `STATUS: OK` and Step 6 routing begins.)

For a batch (FR-020 campaign): present all findings and their proposed dispositions as **one aggregated confirm prompt** — one confirmation event, not one keystroke per finding. When one or more batch items require a spike (disposition not yet final), mark those items as `disposition: pending scope-spike` in the prompt and include them under "proceed with scope-spike for N item(s)?" alongside the already-classified others. Step 5 spikes run after the batch confirmation; dispositions for spike-pending items are finalized in Step 6 after spikes complete. (AC-5, contract `## Operator gate`.)

If the operator declines (`n`): surface the finding unchanged for manual disposition. Do not write anything.

## Step 5: Spike scope-mode (when the change needs design)

When the confirmed disposition indicates the change requires design work before it can be routed (i.e., the finding is too ambiguous to map to a concrete target surface without a scoping pass), dispatch the spike agent in scope mode:

For a `plan-amend` disposition **outside execute** (no diff ratio available), the threshold rule at line 91 applies: always dispatch the scope-spike — do NOT treat this as a design-work judgment call.

```
Agent({
  description: "Scope discovery for triage: <one-line summary>",
  subagent_type: "${CLAUDE_PLUGIN_ROOT}/agents/spike.md",  // scope mode
  prompt: "<inject: mode:scope + the discovery text (+ the current piece's plan.md when --piece resolves) + WORKTREE preamble>",
  model: "opus"
})
```

This is the **only** sub-agent dispatch this skill performs (CR-008 thin orchestrator).

**Threshold rule:** When triage runs outside execute, no diff ratio is available. Per `plugins/spec-flow/reference/spike-agent.md` `## Threshold reuse` (undefined-ratio / zero-cumulative-diff case) → always use scope-spike. (FR-T5)

**On `STATUS: OK`:** consume the scoping artifact; use it to finalize the disposition and populate the target surface routing in Step 6.

**On `STATUS: BLOCKED`:** record an **open needs-scoping item** carrying the blocker text. Surface the blocked item to the operator. Write **no** fabricated disposition — the finding remains unresolved and open until the operator decides how to proceed. (AC-2, AC-3)

## Step 6: Route to target surface

After operator confirmation, route per `plugins/spec-flow/reference/triage-contract.md` `## Dispositions → target surface`:

**`small-change`**
Seed `/spec-flow:small-change` with the discovery as the change-brief. Include a `## Source` provenance line in the brief (session/finding ref + date). The seeded brief is the authoritative requirements input to small-change's Step 6 "Seeded input".

**`plan-amend`**
Resolve the current working piece via defer's reverse-lookup. Dispatch `${CLAUDE_PLUGIN_ROOT}/agents/plan-amend.md` against that piece's `plan.md`. If Step 5 ran and returned `STATUS: OK`, include the scoping artifact in the dispatch payload (the scope artifact is the authoritative design input for the amendment).
If no current working piece resolves: **refuse with a recorded message** — write a `.discovery-log.md`-style row noting the refusal and the reason (`plan-amend requires a resolvable current working piece`), then surface the refusal to the operator for re-classification. Do not silently drop the finding. (AC-11)

**`new-piece`**
Author a new `manifest.yaml` entry using fork's direct-YAML idiom:
```yaml
status: open
depends_on: <operator-specified or []>
```
Do NOT set any current piece to `blocked` — this omits fork's "block-current-piece" coupling. The new entry is additive only.

**`note-on-scheduled`**
Append to the target piece's `notes:` list in `manifest.yaml` per `plugins/spec-flow/reference/triage-contract.md` `## Manifest \`notes:\` schema`:
```yaml
notes:
  - source: <source session / finding ref>
    date: <YYYY-MM-DD>
    finding: <one-line finding text>
```
The `notes:` field is additive — a piece entry lacking it parses unchanged. (AC-8)

If no target piece slug can be resolved (neither `piece_hint` from `--piece` nor a `target?` field from Form B): enumerate all `scheduled`/`queued` manifest pieces and ask the operator to select before writing. If still unresolvable (no such pieces exist), **refuse with a recorded message** (matching the `plan-amend` refusal pattern at line 106) and surface for re-classification. Do not silently drop or guess the target.

**`explicit-defer-with-rationale`**
Invoke `/spec-flow:defer` in structured form. Read `rationale` from the normalized internal record (populated by `--rationale` on Form A or `operator_rationale` on Form B). This field is **mandatory** — refuse if `rationale` is absent, empty, or contains only whitespace after trimming; surface the requirement to the operator. (AC-10, AC-4)

## Step 7: Record provenance (+ red-first stamp)

Every disposition writes a provenance-bearing recorded entry using execute's `.discovery-log.md` one-row-per-discovery format (see `plugins/spec-flow/skills/execute/SKILL.md` `.discovery-log.md authoring`). Provenance = `{source session/finding, date}`. No disposition is a silent mid-stream patch (NN-P-002, NN-P-004). (AC-4)

**Red-first stamp (AC-6):** When `bug_classified = true` AND the disposition is a fix disposition (`small-change` / `plan-amend` / `new-piece`), stamp the red-first reproduce→fail→fix→pass obligation onto **all three** provenance surfaces:

1. The downstream handoff digest (the seeded change-brief, the plan-amend dispatch payload, or the new manifest entry)
2. The recorded `.discovery-log.md`-style row
3. The manifest/backlog entry

Citation: `plugins/spec-flow/reference/triage-contract.md` `## Red-first obligation` (NN-P-006 / FR-022). Do not restate the red-first cycle mechanics.

## Step 8: Return digest

Return a ≤2K disposition summary containing:
- **Disposition chosen** (one of the five)
- **Target surface** (which file, skill, or agent was invoked)
- **Provenance** (source session/finding ref + date)
- **Red-first stamp confirmation** (if `bug_classified = true` and a fix disposition was chosen)
- **Open needs-scoping item** (if spike returned `STATUS: BLOCKED`)

## Boundaries — what this skill does NOT do

- **No merge.** This skill never merges branches, PRs, or worktrees.
- **No code patch / mid-stream edit.** This skill writes no production code, applies no diffs, and makes no edits to source files.
- **No preemption of in-progress work.** Routing a `plan-amend` to an active piece does not halt or restart that piece's current phase.
- **No silent write.** Every disposition is operator-confirmed before any write or handoff occurs.
- **No sign-off-gate removal.** Routing a finding into small-change or plan-amend does not bypass the QA or sign-off gates of those flows.
- **No new `manifest-query` verb.** This skill reads the manifest but does not introduce any new query interface.
