---
name: campaign
description: >-
  Run a results-campaign gate: execute the target system on Sonnet, grade its real output with
  three Opus adversarial lens agents (ground-truth, seam, edge-case) against an oracle derived
  from in-scope FR-018 outcome ACs + declared money/safety rules, apply a per-finding
  theater-guard VERIFY pass, route confirmed findings through /spec-flow:triage as a Form C
  batch, and record source:campaign to metrics + flywheel. Use when the user says "run the
  results campaign", "grade a running system's output", "adversarial validation of a
  pilot/backtest/e2e against the spec's outcome ACs", or wants outcome AC coverage checked on
  real run output. Out-of-band like review-board — does NOT require an active execute session.
  Never patches the target; never merges or amends; the convergence loop (Pass A/B re-hunt) is
  NOT in v1 and lives in campaign-converge (unshipped).
argument-hint: "<piece-set | system-entrypoint> [--run <cmd>]"
---

# Campaign — Results-Campaign Gate

Run the target system on Sonnet, grade its real output with Opus adversarial lens agents, verify each finding, and route confirmed findings to triage. This skill is **read-safety-gated** — it runs code and the operator confirms the exact command before first execution.

## Step 0: Load config + git check

- Read `.spec-flow.yaml` best-effort from the project root; capture `docs_root` (default `docs`). Confirm the working directory is inside a git repo (`git rev-parse --is-inside-work-tree`). If not a git repo, STOP with: `"Error: spec-flow:campaign requires a git repository."`
- Read `campaign.entrypoint` from `.spec-flow.yaml`.
  - **Absent or empty `campaign.entrypoint` ⇒ emit `SKIPPED: no-entrypoint (campaign unavailable)` and STOP.** (An empty string `""` is treated the same as absent.) (Not an error — the campaign is simply not configured for this project.)
- Read `campaign.run_mode` from `.spec-flow.yaml`.
  - **Absent `campaign.run_mode` ⇒ REFUSE:** `"Error: campaign.run_mode is required (dry-run|sandbox|live). Set it in .spec-flow.yaml and re-run."` STOP.
  - Valid values: `dry-run`, `sandbox`, `live`. Any other value ⇒ REFUSE: `"Error: campaign.run_mode '<value>' is not a valid value. Expected: dry-run|sandbox|live. Set it in .spec-flow.yaml and re-run."` STOP.

## Step 1: Resolve target + oracle

Parse the skill argument for the target piece-set or system entrypoint path. If blank, use `campaign.entrypoint` from config.

**Resolve the ORACLE by AC id** (not by re-derivation):

1. Read the target piece-set's `spec.md` files (from `docs_root/prds/<prd-slug>/specs/<piece-slug>/spec.md`) and extract **in-scope FR-018 outcome ACs** by ID. These are ACs tagged as outcome or results-bearing — look for the `(FR-018)` marker or an explicit `## Outcome ACs` section.
2. Read declared product money/safety rules from the charter's non-negotiables skill (`<charter_root>/skills/charter-non-negotiables/SKILL.md`) and any explicit `## Money/Safety Rules` section in the spec.
3. Assemble the oracle as a delimited data block:

   ```
   === ORACLE ===
   Outcome ACs (by id):
   - <AC-id>: <AC text>
   ...
   Money/Safety Rules:
   - <rule>: <text>
   ...
   === END ORACLE ===
   ```

4. **Empty oracle handling:** If no in-scope outcome ACs resolve AND no money/safety rules exist, the oracle is empty. Note this in the run report. Oracle-bound lenses (`campaign-seam`, `campaign-edge-case`) will emit `SKIPPED: no-oracle`; `campaign-ground-truth` still runs (degeneracy needs no oracle).

## Step 2: Run-safety gate (NN-C-006 / risk lens)

Resolve the exact run command: `campaign.entrypoint` from config, overridden by `--run <cmd>` if provided.

**Capability-detect stages:** identify any declared stages (pilot / backtest / e2e) in the entrypoint. A stage that cannot run (missing binary, unavailable env) emits `SKIPPED: <stage>` — the campaign continues with remaining stages. Never fail the whole campaign for a single stage; never emit a false-green (a skipped stage is reported as skipped, not as passed).

**Confirm the exact resolved command with the operator before first execution.** Show precisely:

```
Campaign will run:
  Command: <resolved command>
  Run mode: <dry-run|sandbox|live>
  Stages: <detected or all>

Confirm? (yes / no / change <new-cmd>)
```

- `live` run_mode requires explicit operator opt-in at this gate.
- `dry-run` / `sandbox` proceed after confirm.
- If the operator responds `no`: STOP without running anything.
- If the operator responds `change <new-cmd>`: substitute the new command and re-present the confirm block before proceeding.

## Step 3: Run on Sonnet

Execute the confirmed command **from the main window** (Sonnet — NN-P-005: execution/observation needs no Opus). Capture:

- **stdout:** the full terminal output of the command.
- **Named output artifacts:** any files the command writes to predictable paths (declared in `campaign.outputs` if present in config, or auto-detected from stdout paths like `Output written to: <path>`).

Assemble the run-output buffer:

```
=== RUN OUTPUT ===
Exit code: <n>
Stdout:
<captured stdout>

Artifacts:
- <path>: <brief description or first 5 lines>
...
=== END RUN OUTPUT ===
```

Do NOT dispatch the run to an Opus sub-agent. The run happens here, in the main window.

**REDACT BEFORE FORWARDING.** Before passing the run-output buffer to any agent (Steps 4 and 5), scan stdout for secret patterns: `KEY=<token>` / `Authorization: ...` / bearer tokens / PEM blocks. Replace matched values with `[REDACTED]`. Do not forward unredacted secrets to lens or verify agents. The Step 6 no-secrets reminder is a second gate — redaction happens here, at buffer assembly.

## Step 4: Dispatch Opus lens agents (parallel)

Dispatch all three lens agents **concurrently** with `model: "opus"`. Each agent receives:
- The `WORKTREE:` dispatch preamble (per `plugins/spec-flow/reference/coordinator-contract.md` → `## Dispatch Preamble — Worktree Resolution`) — **first lines of every prompt**.
- The run-output buffer from Step 3.
- The oracle block from Step 1.

Agents dispatched:
- `campaign-ground-truth` — degeneracy / dead-knob grader
- `campaign-seam` — cross-piece integration behavior grader
- `campaign-edge-case` — boundary / regime behavior grader

**v1 always-on:** all three lenses run on every campaign run. Conditional activation (FR-016b) is not yet available. Emit the following hook line before dispatching:

```
[conditional-activation: not-yet-available (FR-016b unshipped)] All three lenses active for this run.
```

**Never silently drop a lens.** If a lens agent errors, report `[LENS-ERROR: <lens> — <reason>]` and continue with remaining lenses. An errored lens is not a passing lens.

**Total lens failure halt.** After collecting lens results, if ALL three lenses errored (zero findings collected AND all three returned `[LENS-ERROR]`), STOP and emit: `[CAMPAIGN-ABORTED: all lens agents errored — no findings collected. Campaign result is inconclusive, not a clean pass.]` Do not proceed to Step 5 or report 0 confirmed findings.

**Oracle-bound lenses** (`campaign-seam`, `campaign-edge-case`) emit `SKIPPED: no-oracle` when the oracle is empty; `campaign-ground-truth` still runs (degeneracy needs no oracle). This is a valid outcome, not an error.

Collect lens findings. Each finding has: `lens`, `finding_text`, `output_evidence` (≤3 lines verbatim run output), `oracle_ac_id` (or `no-oracle`).

## Step 5: Theater-guard VERIFY (per finding)

For **each** lens finding collected in Step 4, dispatch `campaign-verify` (model: "opus", with `WORKTREE:` preamble) with:
- The single finding (lens + finding text + output evidence + oracle AC id)
- The run-output buffer
- The oracle block

**Precision-biased:** route ONLY findings for which `campaign-verify` returns `CONFIRMED`. Suppress (drop) any finding `campaign-verify` returns `REFUTED` or does not clearly confirm. Record the suppression count.

The verify loop is orchestrated HERE (CR-008 — the skill orchestrates, agents execute one task each; `campaign-verify` dispatches no sub-agents).

Surviving findings after VERIFY: those with `verdict: CONFIRMED` from `campaign-verify`, carrying the `bug_classified` boolean the verify agent returned.

If zero findings survive VERIFY: report `Campaign complete — 0 findings confirmed (all suppressed by theater-guard). No triage batch dispatched.` and proceed to Step 6 metrics/flywheel recording only.

## Step 6: Route via triage + record

**6a. Assemble Form C triage batch.** If zero findings survive VERIFY, skip Step 6a entirely and proceed to Step 6b. For each CONFIRMED finding, construct a Form B record:

```
source_phase: campaign
source_agent: <lens>  # campaign-ground-truth | campaign-seam | campaign-edge-case
finding_text: <verbatim from campaign-verify echo>
discovery_type: <degeneracy|seam|edge-case>
bug_classified: <true|false>  # from campaign-verify's verdict
```

Invoke `/spec-flow:triage` with the complete batch (Form C — all Form B records in one aggregated invocation, per `plugins/spec-flow/reference/triage-contract.md`). Single aggregated operator confirm per NN-P-004.

The campaign **never patches the target** (NN-P-002). A bug-classified finding that receives a `fix` disposition from triage will be stamped red-first by triage Step 7 (NN-P-006) — the campaign's `bug_classified: true` pre-seeds that path.

**No secrets:** findings and triage records never transcribe sensitive output values verbatim. Summarize or redact before routing.

**6b. Record to metrics.** Write the `findings_by_source.campaign` block to the piece's `metrics.yaml` (per `plugins/spec-flow/reference/metrics-artifact.md`). On unwritable path: emit `[METRICS-DEGRADED: <reason>]` and continue — never block on metrics.

```yaml
findings_by_source:
  campaign:
    total: <count of all lens findings before VERIFY>
    verified: <count confirmed by VERIFY>
    suppressed: <count REFUTED/suppressed by VERIFY>
    routed_to_triage: <count sent to triage (may be 0)>
    dispatches:
      lens: 3
      verify: <count of VERIFY dispatches = count of pre-VERIFY findings>
```

**6c. Record to flywheel.** For each CONFIRMED finding, record a `campaign` source_type occurrence to the flywheel via the existing operator-confirmed match/confirm flow (NN-P-004, per `plugins/spec-flow/reference/flywheel.md`). On unwritable path: emit `[FLYWHEEL-DEGRADED: <reason>]` and continue.

## Boundaries

- Does NOT merge, amend, fork, or sign off on any pipeline artifact.
- Does NOT patch or modify the target system in any way (NN-P-002).
- Does NOT mutate version-bearing files when run.
- Does NOT write to `improvement-backlog.md` or any spec/plan file.
- Triage disposition is the only output path for confirmed findings — no direct file edits.
- The convergence loop (Pass A/B re-hunt across multiple campaign runs) is NOT in v1; it lives in `campaign-converge` (unshipped).
- All three lenses run always-on in v1 (conditional activation FR-016b unshipped).

## Integration Coverage

| Boundary | Seam | AC |
|---|---|---|
| campaign → `/spec-flow:triage` | Form C batch with campaign-source Form B fields | AC-8 |
| campaign → `metrics.yaml` | `findings_by_source.campaign` block | AC-10 |
| campaign → flywheel | `campaign` source_type occurrence | AC-10 |
