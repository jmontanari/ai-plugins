---
charter_snapshot:
  architecture: 2026-04-21
  non-negotiables: 2026-04-21
  tools: 2026-04-21
  processes: 2026-04-21
  flows: 2026-04-21
  coding-rules: 2026-04-21
tdd: false
fast: false
---

# Plan: pi-013-goal-exec

**Spec:** docs/prds/shared/specs/pi-013-goal-exec/spec.md
**Charter:** docs/charter/ (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** final-review-pending

## Overview

Non-TDD mode: all phases use Implement track + Verify; AC Coverage Matrix is not required; QA and Final Review remain intact.

Wire four Claude Code v2.1.139+ capabilities — GoalCreate, PushNotification, Monitor, and background agent dispatch — into the spec-flow execute skill. The work is entirely prose edits to `skills/execute/SKILL.md` and YAML frontmatter additions to the twelve review-board agent files; no runtime code is introduced.

Phase structure:
- **Phase 1** — add the Step 0 capability probe block to `SKILL.md` (GoalCreate invocation + Monitor arming + four independent probe variables)
- **Phase 2** — add PushNotification wiring to seven locations in `SKILL.md` (Step 6c informational, Step 5.5 merge gate, and five action-required blocks covering the four hard-stop conditions — "auto-mode cannot resolve" maps to two trigger paths in the file)
- **Phase Group A** — in parallel:
  - **A.1** — update `SKILL.md` Final Review Step 1 concurrent dispatch to include TeammateIdle aggregation and 10-minute timeout fallback
  - **A.2** — add `background: true` to all twelve review-board agent files (6 `.md` + 6 `.agent.md`)
- **Phase 3** — version bump across all four version-bearing files to 4.7.0

## Phases

All phases use Implement track.

### Phase 1: execute SKILL.md — Step 0 Capability Probe Block

**Exit Gate:** `SKILL.md` Step 0 section contains the four capability probe variables, GoalCreate invocation block, and Monitor arming block, each with correct guard semantics and silent-fallback branches.
**ACs Covered:** AC-1, AC-2, AC-7, AC-8, AC-9, AC-12
**Charter constraints honored in this phase:**
- NN-C-002 (markdown + config only): all deliverables in this phase are prose additions to a markdown file — no runtime code
- NN-C-003 (backward compat within major version): capability probe pattern ensures GoalCreate/Monitor no-op silently when tools are absent; no behavior change on pre-4.7.0 hosts
- NN-C-005 (hooks and probes silently no-op on missing deps): the probe follows the pattern "check availability → if available: do X; else: skip silently" with no warning on the absent path
- NN-P-001 (all pipeline artifacts are plain markdown or YAML): SKILL.md is plain markdown
- NN-P-003 (backward compat within major version): product-level echo of NN-C-003 — all four features degrade silently when tools are absent
- CR-004 (conventional-commits with plugin scope): commit for this phase uses `feat(spec-flow):` prefix
- CR-009 (markdown section headings follow semantic hierarchy): new capability probe block is added as prose inside the existing `## Step 0` H2 section; no new heading levels added, removed, or skipped

- [x] **[Implement]** Add capability probe block to `SKILL.md` Step 0

  File: `plugins/spec-flow/skills/execute/SKILL.md`

  The current `## Step 0: Load Config` section ends at the integration config paragraph (closing with `set integration_cfg = null and skip all integration steps in this skill.`). Immediately after that closing sentence and before `## Prerequisites`, insert a new `### Capability Probe` sub-section. Content:

  - **Four independent probe variables.** The sub-section opens with a prose paragraph explaining the four independent probes run at Step 0 startup. Each probe checks whether its tool is available and stores the result in orchestrator state:
    - `goal_available` — GoalCreate tool is present
    - `push_notif_available` — PushNotification tool is present
    - `monitor_available` — Monitor tool is present
    - `background_available` — background agent dispatch is supported by the host
    Each variable is initialized independently; no probe depends on another's result (AC-12). When a tool is absent the variable is set to `false`; no warning or error is emitted (FR-8, NN-C-005).

  - **GoalCreate invocation block (if `goal_available`).**  After the four probe variables, add a conditional GoalCreate block:
    ```
    if goal_available:
      invoke GoalCreate(
        piece = <slug>,
        completion = "Step 5 (Capture Learnings) committed on piece branch"
      )
      record goal_id in orchestrator state
    # else: skip silently (FR-8, NN-C-005)
    ```
    Precede the code block with a brief prose sentence: "If `goal_available`, set a goal at execute startup. The goal runs autonomously through all phase loops, QA gates, Step 6c discovery triage, and Final Review fix-up. It stops only at the merge gate (Step 5.5) or at a hard-stop condition."
    The completion condition string must be quoted exactly as shown: `"Step 5 (Capture Learnings) committed on piece branch"` (AC-1). Note: this string is a user-facing descriptor of the observable goal state — the `learnings:` commit on the piece branch. The goal's completion condition maps to the last automatic commit execute produces before the merge gate. The host may auto-close the goal when it detects the completion condition in git (in which case the Step 5.5 merge-gate PushNotification fires from a "completed" goal), or may require operator confirmation (in which case it fires from an "active" goal). Both behaviors satisfy the spec's intent.
    Add a silent-fallback comment: `# else: skip silently` (AC-2).
    Add an orphaned-goal note immediately after the `# else: skip silently` line: `# If execute halts at Prerequisites or charter-drift checks (fires after this block), the goal may remain open as an orphan; the operator must cancel it manually or re-run execute after resolving the gate failure.`

  - **Monitor arming block (if `monitor_available`).** After the GoalCreate block, add a conditional Monitor block:
    ```
    if monitor_available:
      arm monitor on docs/prds/<prd-slug>/specs/<piece-slug>/plan.md
      emit one-line notification per [ ] → [x] checkbox transition
      debounce: ≥1 second between notifications for the same write session
    # else: skip silently (FR-8, NN-C-005)
    ```
    Precede the code block with a brief prose sentence: "If `monitor_available`, arm a monitor on `plan.md` for the active piece. Each `[ ] → [x]` checkbox transition emits a one-line notification; rapid writes within the same write session are debounced with a ≥1-second minimum between notifications."
    Add a silent-fallback comment: `# else: skip silently` (AC-9).
    The debounce rationale sentence: "Plan.md may receive multiple rapid checkbox writes within a single phase commit; debouncing prevents a notification flood while still emitting a timely event per distinct write session." (AC-8)

  Ordering of the new sub-section (checkpoint progression):
  1. Four probe variables (data/state first)
  2. GoalCreate block (first consumer of probe state)
  3. Monitor arming block (second consumer of probe state)

- [x] **[Verify]** Confirm Step 0 prose is correct

  Read `plugins/spec-flow/skills/execute/SKILL.md`. Confirm:
  1. A `### Capability Probe` sub-section exists inside `## Step 0: Load Config`, positioned after the integration-config closing sentence and before `## Prerequisites`.
  2. The section declares all four probe variables: `goal_available`, `push_notif_available`, `monitor_available`, `background_available` — each described as an independent check (AC-12).
  3. The GoalCreate block is present with completion condition `"Step 5 (Capture Learnings) committed on piece branch"` (AC-1).
  4. A `# else: skip silently` fallback comment appears on the GoalCreate absent-path (AC-2).
  5. The Monitor block is present referencing `plan.md` as the monitored file (AC-7).
  6. The Monitor block describes `[ ] → [x]` checkbox transitions and ≥1-second debounce (AC-8).
  7. A `# else: skip silently` fallback comment appears on the Monitor absent-path (AC-9).
  8. No heading level is skipped or introduced below H3 for this sub-section (CR-009).

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-2, AC-7, AC-8, AC-9, AC-12
  - Diff baseline: `git diff phase_1_start_sha..HEAD`

---

### Phase 2: execute SKILL.md — PushNotification Wiring

**Exit Gate:** `SKILL.md` contains PushNotification guard clauses at all seven required locations: one informational at Step 6c auto-mode resolution, one action-required at Step 5.5 merge gate, and five action-required blocks covering the four hard-stop conditions (the "auto-mode cannot resolve discovery" condition has two trigger paths in the file — ratio ≥ 0.5 and zero-diff edge case — each getting its own guard clause).
**ACs Covered:** AC-3, AC-4, AC-5, AC-6
**Charter constraints honored in this phase:**
- CR-008 (separation of concerns — thin-orchestrator skills, narrow-executor agents): all PushNotification additions remain within the orchestrator role in `SKILL.md`; no changes to agent files in this phase

- [x] **[Implement]** Add PushNotification guard clauses to seven locations in `SKILL.md`

  File: `plugins/spec-flow/skills/execute/SKILL.md`

  All seven additions follow the same guard pattern:
  ```
  if push_notif_available:
    send <informational|action-required> notification: "<message text>"
  # else: skip silently
  ```
  The `push_notif_available` state variable was set by Phase 1's capability probe. Each clause is preceded by a brief inline prose label so reviewers can identify it.

  **Location 1 — Step 6c auto-mode resolution (informational, AC-3).**
  Find `### Step 6c: Discovery Triage` → `#### Auto-mode threshold (FR-17)`. Locate the "**Auto-amend if `ratio < 0.5`.**" paragraph — the paragraph that ends with "...refused exactly as in operator mode." Insert IMMEDIATELY AFTER this paragraph and BEFORE the "**Otherwise (`ratio ≥ 0.5`) auto-mode escalates**" paragraph:
  ```
  if push_notif_available:
    send informational notification: "Discovery resolved: <summary> — goal continues"
  # else: skip silently
  ```
  Precede the block with the label: "**Informational notification (goal continues):**". This fires at the auto-mode decision point (ratio < 0.5 → dispatching amend without operator prompting); it does NOT fire when ratio ≥ 0.5 or on the zero-diff edge case (those trigger Locations 2 and 3 instead).

  **Location 2 — Step 6c auto-mode escalation — ratio ≥ 0.5 (action-required, AC-5).**
  Find the paragraph beginning "**Otherwise (`ratio ≥ 0.5`) auto-mode escalates**" with the verbatim message (the triple-backtick fence block). That fence block is followed by a "where `<phase>` is…" clarification paragraph. Insert IMMEDIATELY AFTER the "where `<phase>` is…" clarification paragraph (i.e., after the entire ratio ≥ 0.5 escalation block including its explanatory sentence) and BEFORE the "**Auto-mode never auto-forks or auto-defers.**" paragraph:
  ```
  if push_notif_available:
    send action-required notification: "Hard stop: auto-mode cannot resolve discovery in <phase> (>50% expansion) — <piece-slug> needs operator attention"
  # else: skip silently
  ```
  Precede the block with the label: "**Action-required notification (hard stop — goal halts awaiting operator):**".

  **Location 3 — Step 6c auto-mode escalation — zero-diff edge case (action-required, AC-5).**
  Find `#### Auto-mode threshold (FR-17)` → "**Edge case: `<cumulative-diff-size>` is zero.**" paragraph. That paragraph contains a triple-backtick CARVE-OUT message fence block (text: "Discovery in <phase> surfaced before any cumulative diff exists — auto-amend cannot evaluate threshold. Operator triage required."), followed by a "where `<phase>` is…" clarification paragraph, followed by the "**Auto-amend if `ratio < 0.5`.**" paragraph. Insert IMMEDIATELY AFTER the "where `<phase>` is…" clarification paragraph that follows the CARVE-OUT fence (i.e., between the CARVE-OUT clarification and the "**Auto-amend if `ratio < 0.5`.**" paragraph):
  ```
  if push_notif_available:
    send action-required notification: "Hard stop: auto-mode cannot evaluate threshold in <phase> (no cumulative diff yet) — <piece-slug> needs operator attention"
  # else: skip silently
  ```
  Precede the block with the label: "**Action-required notification (hard stop — goal halts awaiting operator):**".

  **Location 4 — Per-phase QA circuit breaker (action-required, AC-5).**
  Find `### Step 6: Phase QA`. Locate "**Circuit breaker:** 3 iterations max, then escalate." Insert immediately BEFORE "then escalate":
  ```
  if push_notif_available:
    send action-required notification: "Hard stop: QA circuit breaker fired in <phase> — <piece-slug> needs operator attention"
  # else: skip silently
  ```
  Precede the block with the label: "**Action-required notification (hard stop — goal halts):**". Ensure the escalation text immediately follows the notification block.

  **Location 5 — Amendment budget exhausted, operator chooses `n` (action-required, AC-5).**
  Find `#### Amendment budget tracking` → "**On `n`:**" path. Locate the sentence "the orchestrator halts execute." Insert BEFORE that sentence (i.e., before the status-to-blocked update and manifest commit):
  ```
  if push_notif_available:
    send action-required notification: "Hard stop: amendment budget exhausted — <piece-slug> halting, re-spec recommended"
  # else: skip silently
  ```
  Precede the block with the label: "**Action-required notification (hard stop — goal halts):**".

  **Location 6 — Step 5.5 merge gate (action-required, AC-4).**
  Find `### Step 5.5: Update Manifest to Merged`. Locate the opening prose paragraph (ending with "do not push or open a PR before this"). After the opening paragraph and BEFORE the `git add / git commit` block for Step 5.5, insert:
  ```
  if push_notif_available:
    send action-required notification: "<piece-slug> ready to merge — operator action required"
  # else: skip silently
  # goal halts here; no auto-merge
  ```
  Precede the block with the label: "**Action-required notification (merge gate — goal halts):**".

  **Location 7 — Final Review circuit breaker (action-required, AC-5).**
  Find `### Step 3: Fix Loop (iterations 2+, focused)` inside `## Final Review`. Locate "**Circuit breaker:** 3 full review cycles maximum." Immediately AFTER that sentence, insert:
  ```
  if push_notif_available:
    send action-required notification: "Hard stop: Final Review circuit breaker fired — <piece-slug> needs operator attention"
  # else: skip silently
  ```
  Precede the block with the label: "**Action-required notification (hard stop — goal halts):**".

  **Verification of AC-6 (PushNotification absent → no call, no behavior change).**
  The `push_notif_available` probe (Phase 1) gates every clause above. No call is made when `push_notif_available` is false (AC-6). No warning is emitted on the absent path.

  Ordering of edits (checkpoint progression — ordered by location in the file):
  1. Location 4 — per-phase QA circuit breaker (earliest in file, Step 6 section)
  2. Locations 1, 2, 3 — Step 6c auto-mode blocks (Step 6c section, later in file)
  3. Location 5 — amendment budget halt (still within Step 6c)
  4. Location 7 — Final Review circuit breaker (Final Review section)
  5. Location 6 — Step 5.5 merge gate (Step 5.5 section, near end of file)

- [x] **[Verify]** Confirm PushNotification wiring is correct

  Read `plugins/spec-flow/skills/execute/SKILL.md`. Confirm:
  1. **Step 6c informational block** exists after the "Auto-amend if ratio < 0.5" dispatch description, reads "send informational notification: 'Discovery resolved:…'" with `# else: skip silently` (AC-3).
  2. **Step 6c ratio ≥ 0.5 action-required block** exists after the verbatim escalation message block, reads "send action-required notification: 'Hard stop: auto-mode cannot resolve…'" with `# else: skip silently` (AC-5).
  3. **Step 6c zero-diff action-required block** exists after the CARVE-OUT verbatim message block, reads "send action-required notification: 'Hard stop: auto-mode cannot evaluate threshold…'" with `# else: skip silently` (AC-5).
  4. **Per-phase QA circuit breaker action-required block** exists at the "3 iterations max" sentence, reads "send action-required notification: 'Hard stop: QA circuit breaker…'" with `# else: skip silently` (AC-5).
  5. **Amendment budget halt action-required block** exists before the "orchestrator halts execute" sentence in the "On `n`:" path, reads "send action-required notification: 'Hard stop: amendment budget exhausted…'" with `# else: skip silently` (AC-5).
  6. **Step 5.5 merge gate action-required block** exists before the `git add` command in Step 5.5, reads "send action-required notification: '<piece-slug> ready to merge…'" with `# else: skip silently` and `# goal halts here; no auto-merge` (AC-4).
  7. **Final Review circuit breaker action-required block** exists after "3 full review cycles maximum", reads "send action-required notification: 'Hard stop: Final Review circuit breaker…'" with `# else: skip silently` (AC-5).
  8. Every clause is guarded by `if push_notif_available:` (AC-6).

- [x] **[QA]** Phase review
  - Review against: AC-3, AC-4, AC-5, AC-6
  - Diff baseline: `git diff phase_2_start_sha..HEAD`

---

## Phase Group A: Final Review Update + Agent Frontmatter

**Exit Gate:** all sub-phases pass their verifications + group-level QA clean
**ACs Covered:** AC-10, AC-11, AC-14

#### Sub-Phase A.1 [P]: execute SKILL.md — Final Review TeammateIdle Aggregation

**Scope:** `plugins/spec-flow/skills/execute/SKILL.md`
**ACs:** AC-11, AC-14
**Charter constraints honored in this phase:**
- NN-C-008 (agent prompts self-contained): execute SKILL.md Final Review description references review-board agent files by name (the self-contained unit); the prose addition makes TeammateIdle aggregation explicit without adding context from other agents

- [x] **[Implement]** Update Final Review Step 1 concurrent dispatch description

  File: `plugins/spec-flow/skills/execute/SKILL.md`

  Find `## Final Review` → `### Step 1: Iteration 1 — Full Review (6 Parallel Agents; 7 in fast mode)`. Locate the six `Agent({...})` dispatch calls block ending with:
  ```
  Agent({ description: "Security review (iter 1, full)", ... })
  ```
  After the six Agent calls (and after the fast-mode 7th-board-member block that conditionally follows), add a new sub-section:

  **TeammateIdle aggregation and timeout fallback.**

  Prose to add (as a paragraph after the Agent dispatch block):

  > **TeammateIdle aggregation.** After dispatching all review-board agents concurrently, arm a `TeammateIdle` handler. When the last background agent completes and `TeammateIdle` fires, collect all results and advance the orchestrator to Step 2 (Triage).
  >
  > **10-minute timeout fallback (hard stop, AC-14).** If `TeammateIdle` has not fired within 10 minutes of the last review-board agent dispatch — for example because a background agent crashed or timed out and will never signal — treat as a hard stop:
  > ```
  > if push_notif_available:
  >   send action-required notification: "Hard stop: Final Review TeammateIdle timeout — <piece-slug> needs operator attention"
  > # else: skip silently
  > ```
  > Halt execute awaiting operator action. Do NOT auto-advance to Step 2 (Triage).

  Ensure the heading `### Step 1:` title is not altered. Add the TeammateIdle paragraph immediately after the existing `Agent({...})` dispatch block and its associated fast-mode note. No new H3/H4 heading needed — add as prose continuation.

  **Note on `TeammateIdle` event name:** `TeammateIdle` is the Claude Code v2.1.139+ event that fires when the last concurrently-dispatched background agent completes. If the Claude Code host uses a different event name for this concept (e.g., `BackgroundAgentsComplete` or similar), substitute that name in the prose above. The semantics — "fires when last background agent finishes" — are canonical; the identifier is what to verify against the host's actual API.

  **Note on `background_available` probe:** the `background_available` variable set in Phase 1's Capability Probe represents whether the host supports `background: true` agent dispatch. The concrete check: if the host's Agent() call supports a `background: true` parameter, set `background_available = true`; otherwise `false`. The implementer may look for an environment capability flag or attempt a probe call — the exact mechanism is host-specific. The prose in SKILL.md should describe the intent ("host supports background agent dispatch") rather than a host-specific API call.

- [x] **[Verify]** Confirm TeammateIdle aggregation prose is present

  Read `plugins/spec-flow/skills/execute/SKILL.md`. Confirm:
  1. `TeammateIdle` handler text is present in `### Step 1` of `## Final Review` (AC-11).
  2. The prose explicitly says: dispatch all review-board agents concurrently, arm TeammateIdle handler, collect results when TeammateIdle fires, then advance to Step 2 (AC-11).
  3. A 10-minute timeout fallback is described that fires an action-required PushNotification (guarded by `push_notif_available`) and halts execute (AC-14).
  4. The `### Step 1` heading text is unchanged.

- [x] **[QA-lite]** Sonnet narrow review
  - Scope: Sub-Phase A.1 files only (`plugins/spec-flow/skills/execute/SKILL.md` diff since group start)
  - Review: plan alignment, AC-11 and AC-14 coverage, heading-hierarchy discipline, scope discipline (no changes outside SKILL.md)

#### Sub-Phase A.2 [P]: Review-Board Agent Frontmatter — `background: true`

**Scope:** `plugins/spec-flow/agents/review-board-architecture.agent.md`, `plugins/spec-flow/agents/review-board-architecture.md`, `plugins/spec-flow/agents/review-board-blind.agent.md`, `plugins/spec-flow/agents/review-board-blind.md`, `plugins/spec-flow/agents/review-board-edge-case.agent.md`, `plugins/spec-flow/agents/review-board-edge-case.md`, `plugins/spec-flow/agents/review-board-prd-alignment.agent.md`, `plugins/spec-flow/agents/review-board-prd-alignment.md`, `plugins/spec-flow/agents/review-board-security.agent.md`, `plugins/spec-flow/agents/review-board-security.md`, `plugins/spec-flow/agents/review-board-spec-compliance.agent.md`, `plugins/spec-flow/agents/review-board-spec-compliance.md`
**ACs:** AC-10
**Charter constraints honored in this phase:**
- CR-001 (agent frontmatter schema — `name` + `description` in YAML): adding `background: true` as an additional key; existing `name:` and `description:` required keys are preserved in every file; no body changes

- [x] **[Implement]** Add `background: true` to all twelve review-board agent frontmatter blocks

  For each of the twelve files listed above, open the YAML frontmatter block (between `---` delimiters at the top of the file). Add the line `background: true` as the last key before the closing `---` delimiter, regardless of which other keys are present in that file's frontmatter. Do NOT modify the prompt body (any content below the closing `---`).

  Per-file exit criteria:
  - `review-board-architecture.agent.md`: frontmatter contains `background: true`; `name:` and `description:` are unchanged
  - `review-board-architecture.md`: same
  - `review-board-blind.agent.md`: same
  - `review-board-blind.md`: same
  - `review-board-edge-case.agent.md`: same
  - `review-board-edge-case.md`: same
  - `review-board-prd-alignment.agent.md`: same
  - `review-board-prd-alignment.md`: same
  - `review-board-security.agent.md`: same
  - `review-board-security.md`: same
  - `review-board-spec-compliance.agent.md`: same
  - `review-board-spec-compliance.md`: same

  Rationale note (do not add to files): Copilot CLI hosts that do not support background dispatch will ignore the unknown frontmatter key per NN-C-002/CR-008.

- [x] **[Verify]** Confirm `background: true` is present in all twelve agent files

  Run each of the twelve files through a frontmatter-scoped check:
  ```bash
  for f in \
    plugins/spec-flow/agents/review-board-architecture.agent.md \
    plugins/spec-flow/agents/review-board-architecture.md \
    plugins/spec-flow/agents/review-board-blind.agent.md \
    plugins/spec-flow/agents/review-board-blind.md \
    plugins/spec-flow/agents/review-board-edge-case.agent.md \
    plugins/spec-flow/agents/review-board-edge-case.md \
    plugins/spec-flow/agents/review-board-prd-alignment.agent.md \
    plugins/spec-flow/agents/review-board-prd-alignment.md \
    plugins/spec-flow/agents/review-board-security.agent.md \
    plugins/spec-flow/agents/review-board-security.md \
    plugins/spec-flow/agents/review-board-spec-compliance.agent.md \
    plugins/spec-flow/agents/review-board-spec-compliance.md; do
    awk '/^---$/{n++; if(n==2) exit} n==1' "$f" | grep -q '^background: true$' \
      && echo "OK: $f" || echo "MISSING: $f"
  done
  ```
  Expected: all twelve lines print `OK: <file>`. Any `MISSING:` line is a failure.

  Also confirm no prompt body was modified: Read `plugins/spec-flow/agents/review-board-architecture.agent.md`; confirm `name:` and `description:` values are identical to pre-phase values; confirm `background: true` appears in the frontmatter block only (between the first and second `---` lines).

- [x] **[QA-lite]** Sonnet narrow review
  - Scope: Sub-Phase A.2 files only (all twelve agent files)
  - Review: CR-001 compliance (name + description preserved), frontmatter placement, no body modifications, all 12 files covered

#### Group-level tasks

- [x] **[Refactor]** (auto-skip if all sub-phase implementations are clean)
  - Scope: union of A.1 and A.2 files
  - Check for: inconsistent frontmatter placement, duplicate notification blocks in SKILL.md

- [x] **[QA]** Opus deep review
  - Review against: AC-10, AC-11, AC-14
  - Diff baseline: `git diff group_A_start_sha..HEAD`

- [x] **[Progress]** Single commit for Phase Group A

---

### Phase 3: Version Bump — 4.6.2 → 4.7.0

**Exit Gate:** all four version-bearing files show `4.7.0`; CHANGELOG.md has a correctly-formatted `[4.7.0]` section prepended; marketplace.json spec-flow entry reconciled to 4.7.0.
**ACs Covered:** AC-13
**Charter constraints honored in this phase:**
- NN-C-009 (version bump on changes): all four version-bearing files are updated in sync — `plugin.json`, `.claude-plugin/plugin.json`, marketplace.json, and CHANGELOG.md
- CR-006 (CHANGELOG format — Keep a Changelog): `CHANGELOG.md` update prepends a new `## [4.7.0] — YYYY-MM-DD` section in Keep a Changelog format listing Added items for all four features

- [x] **[Implement]** Update all four version-bearing files to 4.7.0

  Files and changes:

  **`plugins/spec-flow/plugin.json`**
  Change `"version": "4.6.2"` → `"version": "4.7.0"`. No other fields modified.
  Per-file exit criterion: `grep '"version": "4.7.0"' plugins/spec-flow/plugin.json` matches.

  **`plugins/spec-flow/.claude-plugin/plugin.json`**
  Change `"version": "4.6.2"` → `"version": "4.7.0"`. No other fields modified.
  Per-file exit criterion: `grep '"version": "4.7.0"' plugins/spec-flow/.claude-plugin/plugin.json` matches.

  **`.claude-plugin/marketplace.json`**
  The spec-flow entry currently shows `"version": "3.7.9"` (stale — needs reconciliation). Change to `"version": "4.7.0"`. No other fields modified.
  Per-file exit criterion: `grep '"version": "4.7.0"' .claude-plugin/marketplace.json` matches.

  **`plugins/spec-flow/CHANGELOG.md`**
  Prepend a new section BEFORE the existing `## [Unreleased]` entry (or immediately after it as the first versioned section, per the Keep a Changelog convention that `Unreleased` stays at the top). The new section format:
  ```markdown
  ## [4.7.0] — YYYY-MM-DD

  ### Added
  - **GoalCreate integration at execute Step 0**: when `GoalCreate` is available, execute sets a goal that runs autonomously through all phase loops, QA gates, discovery triage (Step 6c), and Final Review fix-up, stopping only at the merge gate (Step 5.5) or a hard-stop condition.
  - **Background dispatch for review-board agents**: all twelve review-board agent files (six `.md` + six `.agent.md`) carry `background: true` in YAML frontmatter. Execute Final Review Step 1 now arms a `TeammateIdle` handler to aggregate results; a 10-minute timeout fallback fires as a hard stop if TeammateIdle never arrives.
  - **PushNotification wiring**: informational notification at Step 6c auto-mode resolution (goal continues); action-required notifications at the merge gate (Step 5.5) and at each of the four hard-stop conditions (per-phase QA circuit breaker, amendment budget exhausted, auto-mode cannot resolve discovery, Final Review circuit breaker).
  - **Monitor for plan.md progress**: execute Step 0 arms a monitor on `plan.md` when `Monitor` is available; each `[ ] → [x]` checkbox transition emits a one-line notification, debounced at ≥1 second per write session.
  - **Backward-compatible capability detection**: four independent probes at Step 0 (`goal_available`, `push_notif_available`, `monitor_available`, `background_available`); each feature silently no-ops when the tool is absent (NN-C-005).
  ```
  Replace `YYYY-MM-DD` with today's date at implementation time.
  Per-file exit criterion: `head -20 plugins/spec-flow/CHANGELOG.md` shows `## [4.7.0]` as the first versioned section.

  Ordering (checkpoint progression):
  1. `plugin.json` (Copilot CLI descriptor — simplest change)
  2. `.claude-plugin/plugin.json` (Claude Code descriptor — same pattern)
  3. `.claude-plugin/marketplace.json` (marketplace registry — reconcile stale version)
  4. `CHANGELOG.md` (longest edit, last)

- [x] **[Verify]** Confirm all four version-bearing files show 4.7.0 (AC-13)

  Run from the worktree root:
  ```bash
  grep '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json
  ```
  Expected: all three JSON lines print `"version": "4.7.0"`.

  Check CHANGELOG.md (the fourth version-bearing file):
  ```bash
  grep -n '^\#\# \[' plugins/spec-flow/CHANGELOG.md | head -5
  ```
  Expected: first line shows `## [4.7.0] — <date>`, second line shows `## [4.6.2]` (or `## [Unreleased]` followed by `## [4.7.0]`).

  Read the top 35 lines of `plugins/spec-flow/CHANGELOG.md`; confirm:
  - `## [4.7.0] — <date>` is the first versioned section (immediately after `## [Unreleased]` if present)
  - Five `### Added` bullet entries are present (GoalCreate, background dispatch + TeammateIdle/background aggregation, PushNotification, Monitor, capability detection)
  - `## [4.6.2]` section is still present and intact below the new section

  All four files confirming `4.7.0` satisfies AC-13. Run `plugins/spec-flow/docs/releasing.md`'s authoritative verification commands if that file specifies additional checks.

- [x] **[QA]** Phase review
  - Review against: AC-13
  - Diff baseline: `git diff phase_3_start_sha..HEAD`

---

## Parallel Execution Notes

Sub-Phases A.1 and A.2 have disjoint file scopes (SKILL.md vs. twelve agent files) and no symbol dependencies on each other — they can dispatch concurrently. Phases 1, 2, and the Phase Group A sub-phases targeting SKILL.md (A.1) are serial because they each modify SKILL.md. Phase 3 (version bump) follows Phase Group A because the CHANGELOG.md entry should describe all four features once they are fully wired.

## Agent Context Summary

| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | Phase [Implement] tasks with exact file paths and semantic anchors, per-location insertion descriptions, charter constraints, pattern pointers | Spec rationale, brainstorming history |
| Verify | Verification commands (grep, read, head), expected output descriptions | Implementation reasoning |
| QA-lite (sub-phase) | Sub-phase diff, sub-phase ACs, scope block | Full piece spec, PRD sections, other sub-phases' diffs |
| QA | Phase or group diff, spec ACs, charter constraints, plan context | Agent conversation history |
