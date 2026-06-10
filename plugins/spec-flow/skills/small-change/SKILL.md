---
name: small-change
description: >-
  Use for a small, focused, single-session change that doesn't warrant a full PRD pipeline.
  Triggers: "small feature", "quick fix", "minor change", "one-off", "tweak", "patch",
  "small bug fix". Conducts a coverage-based brainstorm, produces a change brief
  and inline plan, creates a worktree, and routes to execute — all in one session.
---

# Small-Change — One-Session Brief + Plan + Execute

Create `brief.md` and `plan.md` for a bounded one-session change, create the `change/<slug>` worktree, and hand off to `/spec-flow:execute change/<slug>` as a separate invocation.

## Step 0: Load Config

- Read `.spec-flow.yaml`; capture `docs_root` and `worktrees_root`. If absent, default to `docs` and `worktrees`.
- Default directory for change briefs: `<docs_root>/changes/`. All `brief.md` and `plan.md` paths below live under `<docs_root>/changes/<slug>/`.
- Run the Charter Context Loading Protocol in `plugins/spec-flow/reference/brainstorm-procedure.md` per `## Charter Context Loading Protocol`; store `charter_root`, `charter_snapshot`, and `integration_cfg`.
- Read `integrations.issue_tracker.enabled` from `.spec-flow.yaml`.
- Run the integration capability check in `plugins/spec-flow/reference/integration-capability-check.md` for operation `create_phase_issue`; store the result as `jira_available`.
- If the integration capability check fails, emit the standard warning block, set `jira_available = false`, and continue (NN-C-005).

## Step 1: Slug Collision Guard (FR-SC-7)

- Accept `<slug>` from the user argument.
- **Slug format validation:** The slug must satisfy all three rules from `plugins/spec-flow/reference/slug-validator.md`: (1) lowercase letters, digits, and hyphens only — no uppercase, underscores, spaces, or other characters; (2) must not start or end with a hyphen; (3) maximum 20 characters. If the provided slug is invalid, prompt the operator to re-enter with a valid example such as `fix-login-timeout` or `update-rate-limits`.
- If `<docs_root>/changes/<slug>/` exists and `<docs_root>/changes/<slug>/brief.md` is absent, refuse with: "A changes directory for `<slug>` exists without a brief.md — the directory may be corrupted. Provide a different slug or clean up the directory manually."
- **Branch-based collision guard:** Check whether branch `change/<slug>` already exists using `git branch --list change/<slug>`. If the branch exists, the slug is already taken — proceed to Step 2 (resume path). FR-SC-4 governs reuse of the existing session.
- If the branch does not exist, continue to Step 2.

## Step 2: Resume Warning (FR-SC-4)

- If branch `change/<slug>` already exists (checked via `git branch --list change/<slug>`), display this non-suppressible warning verbatim:
  "⚠️ A brief for slug `<slug>` already exists from a previous session. The small-change planning phase is designed to complete in one sitting — if the scope has grown, consider converting to a full PRD with /spec-flow:prd. Acknowledge to continue."
- Require operator acknowledgment before proceeding.
- If the branch does not exist, skip this step silently.
- Running `/spec-flow:execute change/<slug>` after `brief.md` and `plan.md` are complete is the expected workflow and must NOT trigger this warning.

## Step 3: Jira Gate (FR-SC-3, NN-P-003)

- If `integrations.issue_tracker.enabled` is false or `jira_available = false`, skip silently, proceed to Step 4, and leave `jira_key` absent from `brief.md`.
- If `jira_available = true`, prompt: "Do you have an existing Jira issue for this change? Enter the issue key (e.g., EIT-123) or type 'new'."
- If an existing key is provided:
  - **Jira key format validation:** Validate that the provided key matches the pattern `[A-Z][A-Z0-9_]+-\d+` (e.g., `EIT-51095`, `PROJ-123`). If invalid, prompt the operator to re-enter with a valid example before proceeding.
  - Run the integration capability check for `get_issue`.
  - Call `jira_get_issue(issue_key: <provided_key>)`.
  - Extract the issue summary, description, acceptance criteria, and relevant comments; store them as `jira_context`.
  - Record `jira_key: <provided_key>` in orchestrator state so `brief.md` and `plan.md` can reference it.
- If the operator types `new`:
  - Prompt for the parent Epic key.
  - Record `jira_key` as pending; do not write `brief.md` yet.
  - Run the integration capability check for `create_issue`.
  - Defer the `jira_create_issue(project_key: <integration_cfg.project_key>, issue_type: "Task", summary: "<slug> — <problem-statement>", additional_fields: {parent: "<epic_key>"})` call until Step 8 after the problem statement is approved.
- Finalization block: when `jira_available = true`, the skill must NOT advance to Step 12 or write `brief.md` / `plan.md` without a recorded `jira_key`. If sign-off is reached without `jira_key`, halt with: "Cannot finalize brief without a Jira key. Return to Step 3 and provide a key or select 'new'."

## Step 4: Charter Context Loading

- `charter_root`, `charter_snapshot`, and `integration_cfg` should already be populated from Step 0.
- Treat this step as a validation checkpoint before drafting `brief.md` and `plan.md`.
- If any output is missing, re-run the Charter Context Loading Protocol in `plugins/spec-flow/reference/brainstorm-procedure.md` under `## Charter Context Loading Protocol`.
- Carry the validated `charter_snapshot` forward into `brief.md` front-matter in Step 12.

## Step 5: L-10 Convention Context Scan

- Run the L-10 Convention Context Scan in `plugins/spec-flow/reference/brainstorm-procedure.md` under `## Core Brainstorm Building Blocks` → `### L-10: Convention Context Scan`.
- Scan 2–3 peer components of the same target type so the eventual `brief.md` and `plan.md` reflect real codebase conventions.
- Surface the conventions before closing the brainstorm.
- If no peer component of the target type exists, skip L-10 silently; there are no conventions to surface.

## Step 5b: Deliberation Protocol (lite depth)

**[Deliberation protocol]** *(runs after Step 5, before the first brainstorm question)*:

Depth levels and per-skill defaults are defined in `reference/deliberation-depth.md` (full / lite / off profiles, operator override contract). The artifact structure, VOQ-N IDs, marker contract, and STATUS line are defined in `reference/deliberation-artifact.md` — cite both; do not restate.

Small-change is excluded from the model capability check that runs in other skills (FR-009-N). No such check runs here.

0. **Resolve depth:** read `.spec-flow.yaml` `deliberation.depth`; apply any operator override; else use per-skill default (`lite` for small-change — see `reference/deliberation-depth.md`). On `depth=off` → emit `[DELIBERATION-SKIPPED: depth=off]`, run current Step-6 brainstorm, STOP here.

1. **Dispatch Phase A** (`agents/deliberation-coordinator.md`): inject the change description, Step 5 conventions, and charter constraints.
   On `STATUS: BLOCKED` → emit `[DELIBERATION-UNAVAILABLE: phase-A-blocked]`, fall back to current Step-6 brainstorm.

2. **Consume decision-unit cluster from Phase A:** the decision unit is **the change** (singular). At `lite` depth the whole change is treated as one cluster regardless of what Phase A returned — collapse to a single cluster.

3. **Dispatch Phase B** — single `agents/deliberation-viability.md` agent over the one cluster: inject Phase A investigation seed + change description + charter constraints. The agent enumerates reuse/extend-existing paths, not only greenfield.
   On `STATUS: BLOCKED` → emit `[DELIBERATION-UNAVAILABLE: phase-B-blocked]`, fall back to current Step-6 brainstorm (non-fatal if partial output is available — proceed with available output).

4. **Phase C — skipped (≤1 cluster, no-op).** The whole change is one cluster; there is nothing to synthesize across clusters. The `## Integration Check` section of `deliberation.md` records single-cluster coherence rather than a cross-cluster composition analysis.

5. **Dispatch Phase D** — configured lens subset (`agents/deliberation-lens.md` dispatched 2×): inject Phase B viability output + one lens label per agent.
   Default lite subset: `scope/simplicity` + `risk` (see `reference/deliberation-depth.md`).
   **Barrier:** wait for both Phase D agents.
   On any/all Phase D `STATUS: BLOCKED` → log blocked lens(es); proceed to Phase E with available verdicts (non-fatal).

6. **Dispatch Phase E** (`agents/deliberation-convergence.md`): inject Phase B viability output + Phase D lens verdicts. Phase E tags each validated open question with a stable `VOQ-N` ID and records the resolved depth (`lite`) in §Investigation Summary.
   On `STATUS: OK` and `deliberation.md` present + non-empty: commit `deliberation.md`.
   On `STATUS: BLOCKED` → emit `[DELIBERATION-UNAVAILABLE: phase-E-blocked]`, fall back to current Step-6 brainstorm.
   On `deliberation.md` missing or zero-length after dispatch → emit `[DELIBERATION-UNAVAILABLE: deliberation.md-empty-after-dispatch]`, fall back.
   On `git commit` of `deliberation.md` failing (zero files staged or non-zero exit) → emit `[DELIBERATION-UNAVAILABLE: deliberation.md-commit-failed]`, fall back.

7. **First Step-6 message:** present Investigation Summary + Recommendation + "I have N validated questions for you."

8. **Questions:** draw from §Validated Open Questions in order; each question cites its `VOQ-N` ID (or a named deliberation section for an emergent follow-up, e.g. "Following deliberation §Integration Check: …").

On the `[DELIBERATION-UNAVAILABLE]` or `[DELIBERATION-SKIPPED]` path: run today's Step-6 brainstorm (open brainstorm from Step 6's current procedure).

<!-- Example: slug="add-rate-limit-header"
  Decision unit = the change (singular). lite depth (default for small-change).
  Phase A coordinator reads change description + charter, returns one cluster.
  Phase B: 1 viability agent over the whole change → single pass.
  Phase C: SKIPPED — ≤1 cluster, no-op; Integration Check records single-cluster coherence.
  Phase D: 2 lens agents (scope/simplicity + risk) in parallel → barrier.
  Phase E: folds any CONTESTED verdicts into VOQs, writes deliberation.md (depth=lite).
  First Step-6 message: Investigation Summary + Recommendation + "I have N validated questions." -->

## Step 6: Focused Brainstorm (FR-SC-1, FR-SC-2)

- **Seeded input (e.g. a review-board findings digest).** When this skill is invoked with a pre-formed requirement set — most commonly a `source: review-board` findings digest handed off from `/spec-flow:review-board --fix` — treat that digest as the authoritative requirements, not a topic to brainstorm from zero. The findings ARE the functional requirements; each finding's suggested correction seeds an acceptance criterion. Run a brief **scope-confirmation** pass instead of an open brainstorm: confirm the finding set is complete and correctly scoped, ask only what's needed to make the four `brief.md` sections draftable (e.g. ambiguous fixes, ordering), and still apply the C-2 security and C-3 floor checks and the scope gate. Record provenance in `brief.md` (a `## Source` line naming the review-board run / target) so the fix is traceable to the review that found it. Then proceed normally from the draft.
- The brainstorm is complete when you can draft the four sections of `brief.md` from the discussion alone: problem statement, functional requirements, acceptance criteria, and out-of-scope list. Ask only the questions needed to make each section draftable. Skip areas that are already clear from context or prior responses. No theater questions.
- The C-2 security sub-questions are additive and run after coverage is established.
- **Scope signal:** If the discussion keeps surfacing new dimensions — unresolved unknowns growing rather than shrinking, scope expanding rather than clarifying — treat that as a scope signal rather than asking more questions. Surface the scope gate (see below). A change where understanding expands without converging is likely better served by the full pipeline.
- Apply the C-2 Security Sub-Block from `plugins/spec-flow/reference/brainstorm-procedure.md` under `### C-2: Security Sub-Block (always-run)`.
- Apply the C-3 Floor Check Pattern from `plugins/spec-flow/reference/brainstorm-procedure.md` under `### C-3: Floor Check Pattern`.
- Before any artifact is written, evaluate the scope gate:
  - If brainstorm results imply 4 or more implementation phases, or multiple independent subsystems, present: "This looks larger than a small change (4+ phases or multiple subsystems detected). Consider the full pipeline (/spec-flow:prd → /spec-flow:spec → /spec-flow:plan). Continue as small-change or stop?"
  - If the operator chooses `stop`, exit immediately: no `brief.md`, no `plan.md`, no worktree, and no Jira issue are created.
  - If the operator chooses `continue`, record `scope_gate_override = true` in orchestrator state and continue.
- Re-evaluate the scope gate whenever later steps expand the planned work.

Worked example for scope gate algorithm:

<!-- Example: slug="add-token-expiry-header"
  Brainstorm reveals: auth middleware change, request handler update, config schema update,
  test suite additions, documentation update → 5 implementation phases detected.
  scope_gate fires BEFORE any file write.
  Operator selects "continue as small-change".
  scope_gate_override = true.
  Brief writing proceeds. brief.md will contain ## Scope Gate Override section.

  Contrast: operator selects "stop".
  No files created. No worktree. Operator redirected to /spec-flow:prd.
-->

## Step 7: Charter Constraint Identification

- Run the Charter Constraint Identification Protocol in `plugins/spec-flow/reference/brainstorm-procedure.md` under `## Charter Constraint Identification Protocol`. The protocol reads the charter files and infers which entries apply from brainstorm context — do not present the full NN/CR list to the user; present only the inferred applicable set with rationale.
- Skip the `NN-P` enumeration subsection; it is annotated `[spec-only]` in the reference doc and does not apply to change-track `brief.md`.
- Record the confirmed lists for `brief.md` sections `## Non-Negotiables Honored` and `## Coding Rules Honored`.

## Step 8: Brief Sign-Off

- Assemble the `brief.md` draft in memory from the Step 6 brainstorm, Step 5 conventions, Step 7 constraint confirmation, and any Step 3 Jira context.
- Present the assembled brief draft to the operator for review before any `brief.md` write.
- If `jira_available = true` and the operator selected `new` in Step 3:
  - Re-run or confirm the `create_issue` capability check if needed.
  - **Epic key format validation:** Validate that the parent Epic key provided in Step 3 matches the pattern `[A-Z][A-Z0-9_]+-\d+` (e.g., `EIT-51095`, `PROJ-123`). If invalid, prompt the operator to re-enter with a valid example before calling `jira_create_issue`.
  - Call `jira_create_issue(project_key: <integration_cfg.project_key>, issue_type: "Task", summary: "<slug> — <problem-statement>", additional_fields: {parent: "<epic_key>"})`.
  - Record the returned `jira_key` so `brief.md` can receive `jira_key:` and `jira_url:`.
  - Set `jira_issue_created_this_session = true` in orchestrator state.
- If `jira_available = true` and no `jira_key` is recorded, halt with: "Cannot finalize brief without a Jira key. Return to Step 3 and provide a key or select 'new'."
- On operator approval, continue to Step 9.

## Step 9: Inline Plan Generation (FR-SC-5)

- Generate `<docs_root>/changes/<slug>/plan.md` inline in the same session using the structure from `plugins/spec-flow/templates/plan.md`.
- Keep `plan.md` to 1–4 phases.
- If 5 or more phases emerge while drafting `plan.md`, re-fire the Step 6 scope gate before writing `plan.md`.
  - If the operator chooses `stop` at this re-fired scope gate AND `jira_issue_created_this_session = true` (set in Step 8 after a successful `jira_create_issue` call): display "A Jira issue was created in Step 8 (`<jira_key>`). Since the change is being abandoned, please close or delete that issue manually via Jira, or transition it to Won't Do." Then exit with no `brief.md`, no `plan.md`, and no worktree created.
- For each phase in `plan.md`, recommend either TDD or Implement track and give one sentence of reasoning.
- Present all track recommendations to the operator and allow per-phase overrides.
- Do not write `plan.md` until the operator confirms the full phase list and all track selections.

## Step 10: Deferred Item Disposition (FR-SC-6)

- If the brainstorm or `plan.md` generation uncovers out-of-scope items, surface them as a numbered Deferred Item list.
- For each Deferred Item, offer exactly one disposition:
  1. `Address in this change` — re-run the scope gate; the 4 or more phases threshold still applies.
  2. `Defer to improvement-backlog.md` — invoke `/spec-flow:defer --rationale '<reason>'` with the deferred item text. The defer skill handles all writes to `improvement-backlog.md`.
  3. `Create a Jira ticket` — run the integration capability check; if available, create a Task via MCP; otherwise warn and tell the operator to file it manually.
  4. `Drop — not worth tracking` — acknowledge and make no file writes.
- If no Deferred Item exists, skip this step silently.

## Step 11: Worktree Creation

- Before creating the worktree, perform these pre-checks:
  1. Check if branch `change/<slug>` already exists: `git branch --list change/<slug>`
  2. Check if the worktree at `<worktrees_root>/<slug>` already exists: `git worktree list | grep -F "<worktrees_root>/<slug> "` (trailing space anchors to a full path segment, preventing false-positive substring matches against longer slugs like `<slug>-extra`)
  3. Based on the results:
     - **Neither exists:** run `git worktree add <worktrees_root>/<slug> -b change/<slug>` (original command).
     - **Branch exists but no worktree:** run `git worktree add <worktrees_root>/<slug> change/<slug>` (without `-b`, checking out the existing branch).
     - **Both worktree and branch exist:** skip creation and display: "Resuming in existing worktree at `<worktrees_root>/<slug>`"
     - **Worktree exists but branch does NOT:** corrupted state — display error and halt with instructions to run `git worktree remove <worktrees_root>/<slug>` first.
- Confirm the worktree exists with `git worktree list | grep <slug>`.
- If the worktree creation fails or the confirmation command does not show `change/<slug>`, report the error and halt.
- Do not proceed to writing `brief.md` or `plan.md` after a worktree failure.

## Step 12: Write Artifacts

- Ensure `<docs_root>/changes/<slug>/` exists on the newly created `change/<slug>` worktree branch, then write `<docs_root>/changes/<slug>/brief.md` using `plugins/spec-flow/templates/change-brief.md` as the structural template.
- Populate `brief.md` front-matter with `charter_snapshot:` from Step 0 / Step 4.
- If `jira_key` was recorded, write both `jira_key:` and `jira_url:` to `brief.md`, where `jira_url = <integration_cfg.base_url>/browse/<jira_key>`.
- If `scope_gate_override = true`, include a `## Scope Gate Override` section in `brief.md` that states the operator chose to continue and records the number of phases that triggered the gate.
- If Step 3 loaded existing Jira context, include a `## Jira Context` section in `brief.md` with the issue summary, description, acceptance criteria, and relevant comments.
- Write `<docs_root>/changes/<slug>/plan.md` from the Step 9 approved output.
- Commit both artifacts with `git add <docs_root>/changes/<slug>/brief.md <docs_root>/changes/<slug>/plan.md && git commit -m "small-change(<slug>): add brief and plan"`.

## Step 13: Route to Execute

- Display exactly: "Brief and plan ready. Run: /spec-flow:execute change/<slug>"
- Do NOT invoke execute directly. `/spec-flow:execute change/<slug>` is a separate operator-started session per NN-P-001.
- The warning in Step 2 applies only to resumed planning of `brief.md`; the execute handoff for `change/<slug>` is the normal next action once `brief.md` and `plan.md` exist.

**Jira guard discipline (NN-C-005, AC-RL-2).** Every Jira MCP call in this skill is preceded by both checks below:
1. `integrations.issue_tracker.enabled` is checked in Step 0 before any Jira path is considered.
2. The capability check from `plugins/spec-flow/reference/integration-capability-check.md` runs per operation at Step 3 (`get_issue`), Step 8 (`create_issue`), and Step 10 (deferred-item Jira ticket creation).

**Tie-breaking rule — two failure scenarios are distinct:**

- **Scenario 1 — Capability check fails** (`jira_available` cannot be determined; MCP is unreachable before any call is attempted): treat as `jira_available = false`. Emit the standard warning, skip all Jira steps, and continue normally. The finalization halt (requiring `jira_key` before advancing to Step 12) does NOT apply.

- **Scenario 2 — Capability check passes but a specific MCP API call fails at runtime** (e.g., `jira_create_issue` returns an error after `jira_available = true` was established): this is a runtime error. Display the error message and prompt the operator to retry or to manually create/link the Jira issue before continuing. The finalization halt still applies — a `jira_key` must be recorded before proceeding to Step 12.

Steps 3 and 8 reference this distinction. When the capability check fails (Scenario 1), skip the step per the warning. When the capability check passes but the API call fails (Scenario 2), display the error and prompt retry — do not auto-skip.
