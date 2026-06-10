---
charter_snapshot:
  architecture: "2026-06-01"
  non-negotiables: "2026-06-05"
  tools: "2026-06-01"
  processes: "2026-06-01"
  flows: "2026-06-01"
  coding-rules: "2026-06-01"
legacy_deferred_rows: false
fast: false
---

# Plan: dispatch-integrity — Dispatch integrity hardening

**Brief:** docs/changes/dispatch-integrity/brief.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates honored NN-C/CR entries)
**Status:** final-review-pending

## Overview

Seven Implement-track phases harden the execute / review-board dispatch contract. Build inside-out:
Phase 1 defines the two contract additions (worktree preamble + manifest ownership) once in
`reference/coordinator-contract.md`; Phases 2–3 wire them into the agent input contracts and the
dispatch sites; Phase 4 enforces manifest ownership at the Step 6b sweep; Phase 5 hardens the
Step 5.5 → Step 6 merge-gate ordering; Phase 6 adds the implementer truncation/resume protocol;
Phase 7 bumps the version and writes the CHANGELOG. Every phase is doc-as-code (markdown contracts
+ SKILL.md orchestration prose) — no test harness exists, so verification is grep / file-check /
agent-step. All phases use the **Implement track**.

**Twin-file invariant (load-bearing across Phases 2, 3, 6):** Agent templates ship as identical
twins `agents/<name>.agent.md` and `agents/<name>.md` (same git blob, dual-host discovery for
Claude Code + Copilot CLI). Every edit to an agent contract MUST be applied identically to BOTH
files so their git blob hashes stay equal (AC-8).

## Architectural Decisions

### ADR-1: Manifest sweep and truncation detection as orchestrator prose, not new mechanisms
**Context:** FR-2b (manifest sweep) and FR-4 (truncation/resume) are net-new behavior. They could
be implemented as a new hook script or a Python helper.
**Decision:** Implement both as orchestrator prose / git-diff logic inside existing SKILL.md steps
(Step 6b, Step 3). No new binary, hook, or interpreter.
**Alternatives considered:** (a) New `hooks/` script for the manifest sweep — rejected: adds a
dependency surface and a SessionStart/PreCommit wiring burden for a one-line `git diff --name-only`
grep; NN-C-002 pushes toward markdown+config. (b) Standalone resume daemon for truncation —
rejected: massively over-scoped; the orchestrator already re-dispatches on BLOCKED, so a marker
check folds into the existing Step 3 oracle/circuit-breaker flow.
**Consequences:** Easier: zero new dependencies, stays charter-clean. Harder: the guards are prose
the orchestrator must honor, not mechanically enforced by a binary — so the [Verify] steps assert
the prose exists and is unambiguous; field behavior is validated by execute's own QA on next use.
**Charter alignment:** NN-C-002 (no runtime deps), CR-008 (orchestration logic in the skill).

### ADR-2: WORKTREE preamble standardized as one verbatim block, cited everywhere
**Context:** FR-1 touches one contract doc, ~N agent contracts, and every dispatch site. Drift
between copies would reintroduce the bug.
**Decision:** Define the preamble text once in `coordinator-contract.md` (Phase 1); agent contracts
and dispatch sites reference the contract and reproduce the exact `WORKTREE:` line, not a paraphrase.
**Alternatives considered:** Free-form per-site wording — rejected: paraphrase drift is exactly the
failure mode. **Consequences:** A single grep token (`WORKTREE:`) verifies coverage everywhere.
**Charter alignment:** NN-C-008 (self-contained prompts), CR-005 (absolute paths).

## Phases

### Phase 1 (Implement track): Define worktree-preamble + manifest-ownership in coordinator-contract.md
**Exit Gate:** `reference/coordinator-contract.md` carries both new contract sections; grep passes.
**ACs Covered:** AC-1
**In scope:** `plugins/spec-flow/reference/coordinator-contract.md` only.
**NOT in scope:** Agent contracts (Phase 2), dispatch sites (Phase 3).
**Charter constraints honored in this phase:**
- NN-C-008 (self-contained prompts): documents the orchestrator-attached WORKTREE context.
- CR-009 (semantic headings): new `##` sections nest under the existing document structure.

- [x] **[Implement]** Add two contract sections to coordinator-contract.md

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/reference/coordinator-contract.md`**
  - Anchor: end of the `## Coordinator Return Discipline` section (currently around line 29),
    before `## Resume-Critical State`.
  - Target: insert a new `## Dispatch Preamble — Worktree Resolution` section that states: every
    agent dispatched by execute or review-board receives, as the FIRST lines of its prompt, the
    verbatim block below; the absolute path is the active worktree root; an agent that does not
    receive this preamble MUST stop and report `[WORKTREE-ABSENT]` rather than infer a path.
  - Pattern (the canonical preamble block to document verbatim):
    ```
    WORKTREE: <absolute-path>
    Resolve every file read and write from this root. Do not read from or
    write to the main repository checkout. If this WORKTREE preamble is
    absent from your prompt, STOP and report `[WORKTREE-ABSENT]`.
    ```
  - Target (second addition): add a manifest-ownership row/subsection — a `## Orchestrator-Owned
    Files` section (or a row in an existing table) stating: `manifest.yaml` files are
    orchestrator-owned; no dispatched agent (implementer, tdd-red, fix-code, refactor, or any
    other) may create, modify, or delete a `manifest.yaml`; an agent whose task appears to need a
    manifest change reports it to the orchestrator instead.
  - Done: both sections present with the verbatim preamble block and the manifest-ownership statement.
  - Verify: `grep -n "WORKTREE: <absolute-path>" plugins/spec-flow/reference/coordinator-contract.md`
    and `grep -ni "manifest.yaml.*orchestrator-owned" plugins/spec-flow/reference/coordinator-contract.md`

- [x] **[Verify]** Confirm both sections present
  **Per-change checks:**
  - T-1: `grep -c "WORKTREE: <absolute-path>" plugins/spec-flow/reference/coordinator-contract.md` — Expected: ≥1
  - T-1: `grep -ci "\`\[WORKTREE-ABSENT\]\`\|WORKTREE-ABSENT" plugins/spec-flow/reference/coordinator-contract.md` — Expected: ≥1
  - T-1: `grep -ci "manifest.yaml" plugins/spec-flow/reference/coordinator-contract.md` — Expected: ≥1
  **Phase-level check:**
  - Run: Read `plugins/spec-flow/reference/coordinator-contract.md` and confirm the two new
    sections read coherently and the preamble block matches the canonical text in ADR-2.
  - Expected: both sections present, no contradiction with existing Model Policy / Return Discipline.

- [x] **[QA]** Phase review
  - Review against: AC-1
  - Diff baseline: git diff <phase_start>..HEAD

### Phase 2 (Implement track): Add WORKTREE + manifest-ownership fields to agent input contracts
**Exit Gate:** Every dispatched-agent twin pair carries the WORKTREE field; the four
manifest-owning agents carry the ownership line; twins stay byte-identical.
**ACs Covered:** AC-2, AC-3, AC-8
**In scope:** `plugins/spec-flow/agents/<name>.agent.md` + `<name>.md` for every agent dispatched
by execute or review-board: implementer, tdd-red, qa-tdd-red, verify, refactor, fix-code,
qa-phase, qa-phase-lite, reflection-process-retro, reflection-future-opportunities, spike,
spec-amend, plan-amend, and every review-board-* (architecture, blind, edge-case, ground-truth,
integration, prd-alignment, security, spec-compliance).
**NOT in scope:** Dispatch-site prompt composition (Phase 3); upstream-only authoring agents
(qa-spec, qa-plan, qa-prd, qa-prd-review, qa-charter, research) get the WORKTREE field too since
they read repo files, but verify the dispatched set first — do not skip any agent that resolves a
file path.
**Charter constraints honored in this phase:**
- NN-C-008 (self-contained prompts): the field documents required orchestrator-attached context.
- NN-C-004 (bare agent name in frontmatter): edits touch the body, not the `name:` field.
- CR-008 (narrow executors): agent contracts stay declarative.

- [x] **[Implement]** Add the input-contract fields to every agent twin pair

  **Change Specifications:**

  **T-1: MODIFY every dispatched agent `agents/<name>.agent.md` AND `agents/<name>.md`**
  - Anchor: the agent's input-contract / "what you receive" region (e.g. implementer.agent.md
    around the `Mode:`/inputs prose near lines 14–28; for review-board-* the short input list near
    the top). If an agent has no explicit input-contract heading, add a short `## Worktree` block.
  - Target: add a `WORKTREE:` field describing that the prompt's first lines carry
    `WORKTREE: <absolute-path>`, all reads/writes resolve from that root, and if the preamble is
    absent the agent STOPS and reports `[WORKTREE-ABSENT]`. Reference
    `plugins/spec-flow/reference/coordinator-contract.md` `## Dispatch Preamble — Worktree
    Resolution` rather than re-deriving the rule.
  - Pattern (text to add to each agent contract):
    ```
    **Worktree.** Your prompt's first lines are a `WORKTREE: <absolute-path>` preamble
    (see `plugins/spec-flow/reference/coordinator-contract.md`). Resolve every read and
    write from that root — never the main repo. If the preamble is absent, STOP and
    report `[WORKTREE-ABSENT]`; do not infer a path from the plan.
    ```
  - Done: both twin files of every dispatched agent contain the WORKTREE block, byte-identical.
  - Verify: `for f in plugins/spec-flow/agents/*.md; do grep -L "WORKTREE-ABSENT" "$f"; done`
    lists only agents legitimately out of scope (none of the dispatched set).

  **T-2: MODIFY `agents/implementer.{agent.md,md}`, `agents/tdd-red.{agent.md,md}`,
  `agents/fix-code.{agent.md,md}`, `agents/refactor.{agent.md,md}`**
  - Anchor: implementer.agent.md rule list near line 48 ("5. Do not modify files outside the phase
    scope listed in the plan."); analogous scope-rule prose in the other three.
  - Target: add an explicit manifest-ownership line next to the scope rule.
  - Pattern:
    ```
    `manifest.yaml` is orchestrator-owned: you MUST NOT create, modify, or delete any
    `manifest.yaml` file. If your task appears to require a manifest change, report it to
    the orchestrator instead of editing it.
    ```
  - Done: all four agents (both twins each) carry the line.
  - Verify: `for a in implementer tdd-red fix-code refactor; do grep -L "manifest.yaml is orchestrator-owned" plugins/spec-flow/agents/$a.agent.md plugins/spec-flow/agents/$a.md; done` — Expected: empty output.

- [x] **[Verify]** Confirm fields present and twins identical
  **Per-change checks:**
  - T-1: every dispatched agent twin pair contains `WORKTREE-ABSENT` (grep -L over the set returns empty).
  - T-2: the four manifest-owning agents (both twins) contain "manifest.yaml is orchestrator-owned".
  - AC-8: `for a in $(ls plugins/spec-flow/agents/*.agent.md | sed 's/.agent.md$//'); do git ls-files -s "$a.agent.md" "$a.md" 2>/dev/null | awk '{print $2}' | uniq | wc -l; done` — every pair reports `1` (identical blob).
  **Phase-level check:**
  - Run: Read 2–3 edited twin pairs (implementer, a review-board-*, verify) and confirm the added
    blocks are byte-identical between `.agent.md` and `.md`.
  - Expected: identical blocks; no twin drift.

- [x] **[QA]** Phase review
  - Review against: AC-2, AC-3, AC-8
  - Diff baseline: git diff <phase_start>..HEAD

### Phase 3 (Implement track): Inject WORKTREE preamble at every dispatch site
**Exit Gate:** Every agent dispatch in execute + review-board composes the `WORKTREE: <abs-path>`
preamble into the prompt; no un-prefixed dispatch remains.
**ACs Covered:** AC-4
**In scope:** `plugins/spec-flow/skills/execute/SKILL.md`, `plugins/spec-flow/skills/review-board/SKILL.md`.
**NOT in scope:** Agent contracts (Phase 2); the Step 6b sweep (Phase 4).
**Steps traversed (P2):** Step 2, Step 2.5, Step 3, Step 4, Step 5, Step 6, Step G4, Step G7, Step
G8, Final Review Step 1/Step 3, and every other `Agent(...)` dispatch site in execute; all 9
review-board dispatch sites.
**Dispatch sites (P3):** every `Agent({...})` call and every "compose prompt" step that precedes one.
**Charter constraints honored in this phase:**
- NN-C-008 (self-contained prompts): the preamble is composed into the prompt at dispatch time.
- CR-008 (thin orchestrator): prompt composition is orchestrator work.

- [x] **[Implement]** Add the preamble to the canonical prompt-composition instruction

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`**
  - Anchor: the canonical prompt-composition template in Step 3 (around lines 533–567, the
    ```markdown … ``` block) and each other dispatch step's prompt assembly.
  - Target: add a standing rule near the top of the dispatch machinery (e.g. in Pre-flight or a
    new `## Dispatch Preamble` note) that EVERY composed agent prompt begins with the
    `WORKTREE: <absolute worktree root>` block from `reference/coordinator-contract.md`, and add
    the `WORKTREE:` line as the first line of the Step 3 canonical template. Cite the contract;
    do not restate the full block at every step — one standing rule + the first-line marker in the
    canonical template, plus a one-line reminder at any dispatch step that composes its own prompt.
  - Pattern (first line of the canonical prompt template):
    ```
    WORKTREE: <absolute path to the active worktree root>
    (resolve every read/write from this root — see reference/coordinator-contract.md)

    Mode: TDD | Implement
    ```
  - Done: a standing dispatch-preamble rule exists AND the Step 3 canonical template leads with the
    WORKTREE line; every dispatch step references the standing rule.
  - Verify: `grep -n "WORKTREE:" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥2 (standing rule + canonical template).

  **T-2: MODIFY `plugins/spec-flow/skills/review-board/SKILL.md`**
  - Anchor: each of the 9 board-reviewer dispatch / prompt-composition sites.
  - Target: add the same standing dispatch-preamble rule and ensure each board dispatch composes
    the `WORKTREE: <abs-path>` block (board reviewers reading main-repo files was a logged incident).
  - Pattern: same `WORKTREE:` first-line block as T-1.
  - Done: review-board dispatches compose the preamble; standing rule present.
  - Verify: `grep -c "WORKTREE:" plugins/spec-flow/skills/review-board/SKILL.md` — Expected: ≥1.

- [x] **[Verify]** Confirm every dispatch carries the preamble
  **Per-change checks:**
  - T-1: `grep -c "WORKTREE:" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥2.
  - T-2: `grep -c "WORKTREE:" plugins/spec-flow/skills/review-board/SKILL.md` — Expected: ≥1.
  **Phase-level check:**
  - Run: Read each `Agent({...})` dispatch region in both skills and confirm a composed prompt
    that step produces begins with (or is governed by a standing rule that prepends) the WORKTREE
    block. No dispatch path omits it.
  - Expected: every dispatch site is covered by the standing rule or an explicit first-line marker.

- [x] **[QA]** Phase review
  - Review against: AC-4
  - Diff baseline: git diff <phase_start>..HEAD

### Phase 4 (Implement track): Manifest-ownership sweep at Step 6b / Step G9
**Exit Gate:** Step 6b and the Step G9 group sweep block any agent-produced diff touching a
`manifest.yaml` path.
**ACs Covered:** AC-5
**In scope:** `plugins/spec-flow/skills/execute/SKILL.md` (Step 6b ~lines 956–974; Step G9 ~line 1415).
**NOT in scope:** Agent contracts (Phase 2, done); Step 5.5/6 (Phase 5).
**Steps traversed (P2):** Step 6b, Step G9.
**Dispatch sites (P3):** none (this step inspects diffs; it does not dispatch).
**Charter constraints honored in this phase:**
- NN-C-002 (no runtime deps): the sweep is a `git diff --name-only` check in orchestrator prose.
- CR-008 (orchestration logic in the skill).

- [x] **[Implement]** Add the manifest-ownership check to the phase hook sweep

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md` Step 6b**
  - Anchor: Step 6b "Phase Hook Sanity Check" (lines 956–974), after the existing pre-commit sweep
    enumeration (after item 4 / before the "Why this step is usually a no-op" note).
  - Current:
    ```
    4. **Non-zero exit, no files modified** (real error the hooks couldn't autofix): dispatch fix-code once with the hook output as context. ...

    **Why this step is usually a no-op.** ...
    ```
  - Target: add a numbered "Manifest-ownership sweep" sub-step: compute the phase diff file list
    (`git diff --name-only $phase_N_start_sha..HEAD`); if ANY path matches `manifest.yaml`
    (basename match, any directory), this is a BLOCKING violation — manifest.yaml is
    orchestrator-owned (see reference/coordinator-contract.md) and no agent commit in this phase may
    touch it. Escalate to the operator; do not advance to Step 7. State that the orchestrator's own
    Step 5.5 / Step 7 manifest commits are exempt because they are made by the orchestrator outside
    the phase work-commit, not by a dispatched agent.
  - Pattern:
    ```
    5. **Manifest-ownership sweep (blocking).** From the phase diff
       (`git diff --name-only $phase_N_start_sha..HEAD`), if any path basename is
       `manifest.yaml`, STOP — manifest.yaml is orchestrator-owned (reference/coordinator-contract.md).
       A dispatched agent modified it; escalate to the operator and do NOT advance to Step 7.
       (Orchestrator-made manifest commits — Step 5.5, Step 7 — are not phase work-commits and are
       not swept here.)
    ```
  - Done: Step 6b contains the blocking manifest sweep.
  - Verify: `grep -ni "manifest-ownership sweep\|manifest.yaml is orchestrator-owned" plugins/spec-flow/skills/execute/SKILL.md`

  **T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md` Step G9**
  - Anchor: Step G9 "Step 6b hook sweep over the group diff" (~line 1415).
  - Target: extend the group sweep with the same manifest-ownership blocking check over the group
    diff (`git diff --name-only $group_start_sha..HEAD`).
  - Pattern: same blocking-sweep logic as T-1, scoped to the group diff.
  - Done: Step G9 carries the manifest sweep.
  - Verify: the Step G9 region references the manifest-ownership sweep (read-and-confirm).

- [x] **[Verify]** Confirm the sweep exists in both step bodies
  **Per-change checks:**
  - T-1: `grep -ni "manifest-ownership sweep" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1.
  - T-2: Read the Step G9 region and confirm the group sweep includes the manifest check.
  **Phase-level check:**
  - Run: Read Step 6b and Step G9 and confirm the check is blocking (escalate, do not advance) and
    correctly exempts orchestrator-made manifest commits.
  - Expected: unambiguous blocking semantics; no false-positive on Step 5.5/7 commits.

- [x] **[QA]** Phase review
  - Review against: AC-5
  - Diff baseline: git diff <phase_start>..HEAD

### Phase 5 (Implement track): Step 5.5 commit as a checked Step 6 precondition
**Exit Gate:** Step 6 states an explicit "HEAD contains the Step 5.5 manifest commit" precondition
for both merge strategies and every retry path; checklist line names it.
**ACs Covered:** AC-6
**In scope:** `plugins/spec-flow/skills/execute/SKILL.md` Step 5.5 (~1898) and Step 6 (~1922).
**NOT in scope:** Step 6b sweep (Phase 4); merge mechanics themselves.
**Steps traversed (P2):** Step 5.5, Step 6.
**Dispatch sites (P3):** none.
**Charter constraints honored in this phase:**
- NN-C-003 (backward compat): precondition tightens an existing flow without changing its interface.
- CR-008 (orchestration logic in the skill).

- [x] **[Implement]** Promote the Step 5.5 ordering from advisory prose to a checked precondition

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md` Step 6**
  - Anchor: Step 6 "### Step 6: Merge" header (~line 1922), before the `merge_strategy` branch.
  - Current:
    ```
    ### Step 6: Merge

    Read `merge_strategy` from `.spec-flow.yaml` (valid values: `squash_local`, `pr`; ...
    ```
  - Target: insert a **Precondition (checked, both strategies, every retry)** block immediately
    under the Step 6 header: before branching on `merge_strategy`, verify HEAD on the piece branch
    contains the Step 5.5 manifest commit (the commit setting `status: merged` + `merged_at`). The
    check: `git log --oneline -n 5 <branch>` shows the `chore(manifest): mark … merged` commit, OR
    `git show HEAD:docs/prds/<prd-slug>/manifest.yaml` shows `status: merged`. If absent — including
    on a retry after a Step 6 failure where Step 5.5 was reverted — re-run Step 5.5 first, then
    proceed. Make explicit that this precondition gates BOTH `squash_local` and `pr` and EVERY
    retry path (not just the first run).
  - Pattern:
    ```
    **Precondition (checked — both strategies, every retry path).** Before branching on
    `merge_strategy`, confirm HEAD of the piece branch contains the Step 5.5 manifest commit:
    `git show HEAD:docs/prds/<prd-slug>/manifest.yaml` must show `status: merged`. If it does
    not — including after a reverted Step 6 retry — re-run Step 5.5 first. Do NOT merge, push,
    or open a PR while this precondition is unmet.
    ```
  - Done: the precondition block is present and explicitly covers both strategies + retries.
  - Verify: `grep -ni "Precondition.*Step 5.5\|HEAD.*contains.*Step 5.5\|status: merged" plugins/spec-flow/skills/execute/SKILL.md`

  **T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md` operator checklist line**
  - Anchor: the push-ready / PR-open checklist message emitted to the operator in the Step 6 `pr`
    branch (the "PR-based merge required…" Print block) and the squash success path.
  - Target: add a checklist line naming the precondition: "✓ HEAD carries the Step 5.5 manifest
    commit (`status: merged`)."
  - Pattern: append a bullet to the emitted checklist text.
  - Done: the operator-facing checklist names the Step 5.5 precondition.
  - Verify: `grep -ni "Step 5.5 manifest commit\|carries.*status: merged" plugins/spec-flow/skills/execute/SKILL.md`

- [x] **[Verify]** Confirm the precondition and checklist line
  **Per-change checks:**
  - T-1: `grep -ci "Precondition" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1 in the Step 6 region.
  - T-2: checklist line present (grep above returns ≥1).
  **Phase-level check:**
  - Run: Read Step 5.5 and Step 6 and confirm the precondition is checked (not advisory), names
    both strategies, and covers the retry path; confirm no contradiction with the Step 5.5 failure-path revert prose.
  - Expected: coherent ordering guarantee, retry-safe.

- [x] **[QA]** Phase review
  - Review against: AC-6
  - Diff baseline: git diff <phase_start>..HEAD

### Phase 6 (Implement track): Implementer READY-TO-COMMIT marker + truncation/resume protocol
**Exit Gate:** implementer contract defines `READY-TO-COMMIT` before long gates; execute Step 3
treats marker-absent truncation as resumable; manual-commit bypass prohibited.
**ACs Covered:** AC-7, AC-8
**In scope:** `plugins/spec-flow/agents/implementer.agent.md` + `implementer.md` (twins);
`plugins/spec-flow/skills/execute/SKILL.md` Step 3 (~531–600).
**NOT in scope:** other agents; other steps.
**Steps traversed (P2):** Step 3.
**Dispatch sites (P3):** Step 3 implementer dispatch (does not add a dispatch; modifies handling of the return).
**Charter constraints honored in this phase:**
- NN-C-002 (no runtime deps): resume logic is orchestrator prose folded into the existing Step 3 circuit breaker.
- NN-C-008 (self-contained prompts): re-dispatch carries prior context per the contract.
- CR-008 (thin orchestrator / narrow executor): the agent emits a marker; the orchestrator owns the resume decision.

- [x] **[Implement]** Add the marker to the implementer contract and the resume handling to Step 3

  **Change Specifications:**

  **T-1: MODIFY `agents/implementer.agent.md` AND `agents/implementer.md` (twins)**
  - Anchor: the commit-discipline prose (around the Rule 8 / "single unified commit" region, lines ~53–90).
  - Target: instruct the implementer to (1) stage its work and complete its self-review checklist,
    then (2) emit a `READY-TO-COMMIT` marker line BEFORE invoking any long-running gate command
    (test/type-check runs that may exceed output limits), then (3) run the gate and commit. State
    that if its output is truncated before `READY-TO-COMMIT`, the orchestrator will re-dispatch —
    the agent must not assume a partial run was accepted.
  - Pattern:
    ```
    **READY-TO-COMMIT marker.** After staging your work and completing the self-review
    checklist — but BEFORE invoking any long-running gate command (full test/type-check
    runs) — emit a single line: `READY-TO-COMMIT`. This signals that staging + self-review
    are complete and the only remaining work is the gate run + commit. If your output is
    truncated before this marker, the orchestrator treats the dispatch as a resumable
    failure and re-dispatches you with prior context.
    ```
  - Done: both twins carry the marker definition, byte-identical.
  - Verify: `grep -L "READY-TO-COMMIT" plugins/spec-flow/agents/implementer.agent.md plugins/spec-flow/agents/implementer.md` — Expected: empty.

  **T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md` Step 3**
  - Anchor: Step 3 circuit-breaker / post-commit handling (item 6 "Circuit breaker", ~line 597, and
    the dispatch handling around items 4–7).
  - Current:
    ```
    6. **Circuit breaker:** If the oracle does not pass after 2 attempts in either mode, escalate to human. If the agent reports BLOCKED ... escalate — do not retry blindly.
    ```
  - Target: add truncation/resume handling: if the implementer's output is truncated (incomplete
    return) AND lacks the `READY-TO-COMMIT` marker, treat it as a resumable failure — re-dispatch
    with prior context (do NOT manually stage/commit on the agent's behalf). The orchestrator
    manually staging + committing a truncated implementer's work is PROHIBITED (it bypasses the
    self-review checklist). If the marker IS present but output truncated after it, the staging is
    trustworthy; the orchestrator may complete the gate/commit per the existing flow.
  - Pattern:
    ```
    **Truncation/resume (both modes).** If the implementer's return is truncated and does NOT
    contain the `READY-TO-COMMIT` marker, treat it as a resumable failure: re-dispatch with prior
    context. Manually staging + committing a truncated implementer's work is PROHIBITED — it
    bypasses the agent's self-review checklist. If `READY-TO-COMMIT` was emitted before truncation,
    staging + self-review are complete; finishing the gate/commit is safe.
    ```
  - Done: Step 3 carries the truncation/resume rule with the explicit bypass prohibition.
  - Verify: `grep -ni "READY-TO-COMMIT\|truncat" plugins/spec-flow/skills/execute/SKILL.md`

- [x] **[Verify]** Confirm marker + resume protocol
  **Per-change checks:**
  - T-1: implementer twins both contain `READY-TO-COMMIT` (grep -L returns empty) and are blob-identical (`git ls-files -s` → one blob).
  - T-2: `grep -ci "READY-TO-COMMIT" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1; bypass prohibition present.
  **Phase-level check:**
  - Run: Read the implementer commit-discipline region and Step 3 and confirm the marker is emitted
    BEFORE long gates and the orchestrator's manual-commit bypass is unambiguously prohibited.
  - Expected: coherent contract between agent (emits marker) and orchestrator (honors it).

- [x] **[QA]** Phase review
  - Review against: AC-7, AC-8
  - Diff baseline: git diff <phase_start>..HEAD

### Phase 7 (Implement track): Version bump + CHANGELOG
**Exit Gate:** version is 5.10.0 in both version-bearing files; CHANGELOG has a `## [5.10.0]` entry.
**ACs Covered:** AC-9
**In scope:** `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
(repo root), `plugins/spec-flow/CHANGELOG.md`.
**NOT in scope:** any behavior change (all in Phases 1–6).
**Charter constraints honored in this phase:**
- NN-C-009 (always bump version, all version-bearing files): bump in both files.
- NN-C-001 (plugin.json ↔ marketplace.json sync): both updated together.
- NN-C-007 + CR-006 (CHANGELOG, Keep a Changelog): add the entry.

- [x] **[Implement]** Bump version and write the CHANGELOG entry

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json`**
  - Anchor: `"version": "5.9.0",` (line ~4).
  - Target: `"version": "5.10.0",`.
  - Done: version reads 5.10.0.
  - Verify: `grep -n '"version": "5.10.0"' plugins/spec-flow/.claude-plugin/plugin.json`

  **T-2: MODIFY `.claude-plugin/marketplace.json`**
  - Anchor: the spec-flow plugin entry `"version": "5.9.0",` (line ~15, inside the `"name":
    "spec-flow"` block — NOT the other plugin's version on line ~24).
  - Target: `"version": "5.10.0",` in the spec-flow entry only.
  - Done: spec-flow marketplace entry reads 5.10.0; the other plugin's version is untouched.
  - Verify: `sed -n '11,17p' .claude-plugin/marketplace.json | grep '"version": "5.10.0"'`

  **T-3: MODIFY `plugins/spec-flow/CHANGELOG.md`**
  - Anchor: the `## [Unreleased]` line near the top, before `## [5.9.0]`.
  - Target: add a `## [5.10.0] — <today's date>` section under `## [Unreleased]` with an `### Added`
    / `### Changed` summary of the four guards: WORKTREE dispatch preamble + `[WORKTREE-ABSENT]`
    escalation; manifest.yaml orchestrator-ownership contract + Step 6b/G9 blocking sweep; Step 5.5
    commit as a checked Step 6 precondition; implementer `READY-TO-COMMIT` marker + truncation/resume
    protocol.
  - Done: a well-formed `## [5.10.0]` entry exists.
  - Verify: `grep -n '## \[5.10.0\]' plugins/spec-flow/CHANGELOG.md`

- [x] **[Verify]** Confirm version sync and CHANGELOG
  **Per-change checks:**
  - T-1: `grep -c '"version": "5.10.0"' plugins/spec-flow/.claude-plugin/plugin.json` — Expected: 1.
  - T-2: spec-flow marketplace entry reads 5.10.0 (sed+grep above).
  - T-3: `grep -c '## \[5.10.0\]' plugins/spec-flow/CHANGELOG.md` — Expected: 1.
  **Phase-level check:**
  - Run: confirm plugin.json and the marketplace spec-flow entry agree (both 5.10.0) and the
    CHANGELOG entry names all four guards.
  - Expected: versions in sync (NN-C-001); CHANGELOG complete.

- [x] **[QA]** Phase review
  - Review against: AC-9
  - Diff baseline: git diff <phase_start>..HEAD

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | coordinator-contract.md has WORKTREE preamble + manifest-ownership | COVERED | Phase 1 |
| AC-2 | dispatched-agent twins carry WORKTREE field + [WORKTREE-ABSENT] | COVERED | Phase 2 |
| AC-3 | implementer/tdd-red/fix-code/refactor carry manifest-ownership line | COVERED | Phase 2 |
| AC-4 | every execute + review-board dispatch injects WORKTREE preamble | COVERED | Phase 3 |
| AC-5 | Step 6b / G9 block agent diffs touching manifest.yaml | COVERED | Phase 4 |
| AC-6 | Step 6 checks Step 5.5 commit precondition (both strategies, retries) | COVERED | Phase 5 |
| AC-7 | implementer READY-TO-COMMIT + Step 3 resume; bypass prohibited | COVERED | Phase 6 |
| AC-8 | edited .agent.md/.md twins stay byte-identical | COVERED | Phases 2, 6 |
| AC-9 | version 5.10.0 in both files + CHANGELOG entry | COVERED | Phase 7 |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `grep -c "WORKTREE: <absolute-path>" plugins/spec-flow/reference/coordinator-contract.md` | ≥1 |
| AC-1 | shell | `grep -ci "manifest.yaml" plugins/spec-flow/reference/coordinator-contract.md` | ≥1 |
| AC-2 | agent-step | For each dispatched agent, confirm both twins contain `WORKTREE-ABSENT` | all present |
| AC-3 | shell | `for a in implementer tdd-red fix-code refactor; do grep -L "manifest.yaml is orchestrator-owned" plugins/spec-flow/agents/$a.agent.md plugins/spec-flow/agents/$a.md; done` | empty output |
| AC-4 | shell | `grep -c "WORKTREE:" plugins/spec-flow/skills/execute/SKILL.md` | ≥2 |
| AC-4 | shell | `grep -c "WORKTREE:" plugins/spec-flow/skills/review-board/SKILL.md` | ≥1 |
| AC-5 | shell | `grep -ni "manifest-ownership sweep" plugins/spec-flow/skills/execute/SKILL.md` | ≥1 |
| AC-6 | shell | `grep -ni "Precondition" plugins/spec-flow/skills/execute/SKILL.md` (Step 6 region) | ≥1 |
| AC-7 | shell | `grep -ci "READY-TO-COMMIT" plugins/spec-flow/skills/execute/SKILL.md` | ≥1 |
| AC-8 | shell | per edited twin pair: `git ls-files -s <a>.agent.md <a>.md` blob hashes equal | identical blob |
| AC-9 | shell | `grep -c '"version": "5.10.0"' plugins/spec-flow/.claude-plugin/plugin.json` and marketplace spec-flow entry and `## [5.10.0]` in CHANGELOG | 1 / 1 / 1 |

## Contracts

No TDD-track phases — this is a doc-as-code change with no boundary-crossing code interfaces. The
behavioral "contracts" are the prose contracts themselves (WORKTREE preamble, manifest ownership,
READY-TO-COMMIT marker), each defined once in Phase 1 / Phase 6 and cited elsewhere.

## Parallel Execution Notes

Phases are serial and ordered by dependency: Phase 1 defines the contract text that Phases 2–3
cite; Phase 4 depends on the manifest-ownership statement from Phase 1; Phases 5–7 are independent
of each other but kept serial for a clean single-session change. Phases 2 and 3 could in principle
run as a Phase Group (disjoint files: agents/* vs skills/*), but the small volume does not justify
the group machinery — keep serial.

## Agent Context Summary

| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | WORKTREE preamble, plan [Implement] tasks, brief ACs, plan [Verify] commands, charter constraints | Spec rationale, brainstorming history |
| Verify | WORKTREE preamble, grep/agent-step verification output, brief ACs | Implementation reasoning |
| QA | WORKTREE preamble, phase diff, brief, plan | Any agent conversation history |
