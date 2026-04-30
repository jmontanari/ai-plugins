---
charter_snapshot:
  architecture: 2026-04-21
  non-negotiables: 2026-04-21
  tools: 2026-04-21
  processes: 2026-04-21
  flows: 2026-04-21
  coding-rules: 2026-04-21
---

# Spec: Branch Integrity — Eliminate Direct-Main Writes During Pipeline Execution

**PRD Sections:** FR-004, NN-P-002
**Charter:** docs/charter/ (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** none

## Goal

Remove all `git checkout main` + commit patterns from pipeline skills (execute, spec, plan)
so that every write during execution stays on the feature branch. Make the status skill
worktree-aware so it can discover in-progress pieces without relying on main-branch
manifest state. Add a `merge_strategy` config key so PR-based repos and self-contained
repos can each describe their topology.

## In Scope

- **Execute skill**: Remove Pre-Loop `git checkout main` → update manifest → `git checkout
  back` pattern. Replace with a manifest update on the execute branch itself.
- **Execute skill**: Move the manifest `merged` update (Final Review Step 7) from "on main
  after squash-merge" to "on the execute branch before PR/merge" — so the PR carries the
  final manifest state to main.
- **Execute skill**: Update `plan.md` `**Status:**` field to `final-review-pending` when
  dispatching the review board (on the execute branch).
- **Execute skill Step 6**: Add `merge_strategy` config key (`squash_local | pr`). When
  `pr`, replace the local `git merge --squash` with a `gh pr create` (or equivalent)
  signal. When `squash_local` (default), existing behavior is preserved.
- **Spec skill Phase 5**: Remove `git checkout main` → update manifest → `git checkout back`
  pattern. Replace with a manifest update on the spec branch, plus instructions for the
  user to merge/PR that change to main.
- **Plan skill**: Same fix as spec skill — remove `git checkout main` manifest update,
  keep all writes on the spec branch (`spec/<prd-slug>-<piece-slug>`) on which the plan
  skill operates.
- **Status skill**: Reorder scan — run `git worktree list` first (new Step 1), read each
  execute-branch worktree's manifest as authoritative for that piece's in-progress status.
  Fall back to main-branch manifest only for pieces with no active worktree.
- **Status skill**: Add targeted field extraction for manifests > 10KB to avoid read
  truncation and multi-round-trip overhead.
- **`.spec-flow.yaml`**: Document and add the `merge_strategy` key with inline comment.

## Out of Scope / Non-Goals

- No changes to the plan skill's worktree setup logic (only the manifest update step).
- No changes to how phase-level commits are structured within execute.
- No CI enforcement of the branch-integrity rule (separate piece).
- No changes to agent files — this is skills and config only.
- No automated PR title/body templating (beyond what `gh pr create` provides natively).
- No changes to how the review-board agents receive context.

## Requirements

### Functional Requirements

- **FR-1:** During execute, all writes to tracked files (manifest, plan.md) occur on the
  execute branch. No `git checkout main` is issued between Pre-Loop start and Final
  Review Step 5 completion.
- **FR-2:** The execute branch's manifest carries `status: in-progress` from the Pre-Loop
  commit, and `status: merged` from the final pre-merge commit. When the branch merges
  to main (via squash or PR), main receives the correct terminal state.
- **FR-3:** `merge_strategy: squash_local` (default) preserves existing execute Step 6
  behavior exactly — no user-visible change for self-contained repos.
- **FR-4:** `merge_strategy: pr` replaces Step 6's local squash-merge with a PR creation
  signal. The skill displays the `gh pr create --base main --head execute/<prd-slug>-<piece-slug>` command for the human to run and then halts — the
  human opens or confirms the PR. The skill does NOT execute this command — no `gh` CLI
  dependency is introduced. Step 7 (manifest `merged` update) runs on the execute
  branch before the PR signal, not after merge.
- **FR-5:** Status skill discovers in-progress pieces via `git worktree list` in ≤ 2
  tool-call rounds, without reading the main-branch manifest for those pieces.
- **FR-6:** Spec skill updates the manifest on the `spec/<prd-slug>-<piece-slug>` branch;
  plan skill does the same on that same spec branch on which it operates. Neither skill
  issues `git checkout main` to update the manifest mid-skill.
- **FR-7:** `plan.md` `**Status:**` is set to `final-review-pending` on the execute branch
  when the review board is dispatched, so a human reading plan.md can determine the
  piece's state without counting checkboxes.

### Non-Functional Requirements

- **NFR-1:** No user-visible behavior change for repos where `merge_strategy` defaults to
  `squash_local` **in a serial, one-active-piece-at-a-time workflow**. In parallel
  workflows (multiple execute branches active concurrently), `manifest.yaml` squash-merge
  conflicts are possible when sibling branches also updated the manifest; these are handled
  by the existing Step 6 "If merge conflicts: escalate to human" clause.
  Backward-compatible addition only.
- **NFR-2:** Status skill worktree scan adds no more than one additional tool call compared
  to the current main-branch-only scan in the common case (one execute branch active).

### Non-Negotiables Honored

**Project (NN-C — from `docs/charter/non-negotiables.md`):**
- **NN-C-001** (version sync): plugin.json, marketplace.json, and CHANGELOG.md are updated
  together as part of this piece's merge commit. All three touched in the same branch.
- **NN-C-002** (no new runtime dependencies): The `merge_strategy: pr` path displays a
  `gh pr create` command for the human to copy-paste; the skill does not execute it. No
  runtime dependency beyond `git` and POSIX shell is introduced. NN-C-002 is honored.
- **NN-C-003** (backward compat): `merge_strategy` defaults to `squash_local`, preserving
  all existing execute behavior. No existing config key renamed or removed.
- **NN-C-006** (no destructive ops without confirmation): the `merge_strategy: pr` path
  explicitly halts at PR creation and requires human confirmation before merge — a
  stronger guard than the existing flow, not weaker.
- **NN-C-008** (fresh context per agent dispatch): No agent prompt templates, context
  injection blocks, or dispatch patterns are modified by this piece. All changes are to
  orchestration flow (which branch receives commits) — agent prompt content and the
  fresh-context-per-dispatch invariant are preserved.
- **NN-C-009** (always bump version): skill behavior changes (manifest update location,
  status field writes, merge strategy) are a minor-version bump (new behavior, backward-
  compatible). Three places updated: `plugin.json`, `marketplace.json`, `CHANGELOG.md`.

**Product (NN-P — from `docs/prds/shared/prd.md`):**
- **NN-P-002** (no auto-merge without sign-off): `merge_strategy: pr` makes the human PR
  approval gate explicit. `squash_local` retains the existing Step 4 human sign-off gate.
  Neither path auto-merges.
- **NN-P-003** (dog-food significant spec-flow changes on a maintainer-controlled repo
  first): This piece is being exercised on this repo (shared-plugins) before any release
  guidance to external users. The corrected branch-integrity behavior is exercised by the
  pi-011 spec/plan/execute cycle itself.

### Coding Rules Honored

- **CR-004** (conventional commits): all commits produced by the corrected skills use
  `feat(spec-flow):` / `fix(spec-flow):` / `chore(spec-flow):` prefixes.
- **CR-007** (config keys documented inline): `merge_strategy` key in `.spec-flow.yaml`
  template carries a comment block explaining valid values, default, and rationale.
- **CR-008** (thin-orchestrator skills): all changes are to skill orchestration instructions
  (which branch to write to, which step comes when). No agent logic changed.

## Acceptance Criteria

**AC-1 — Execute Pre-Loop writes to execute branch only**
Given: a piece with status `planned` and an active execute worktree.
When: execute Pre-Loop runs for the first time (fresh start, not resume).
Then: manifest.yaml is updated to `in-progress` by a commit on the execute branch; no
`git checkout main` is issued; main-branch manifest retains `planned` until the PR merges.
Independent Test: `git log --oneline main..execute/<prd>-<piece>` shows a `manifest:` commit;
`git show main:docs/prds/<prd>/manifest.yaml | grep status` still shows `planned`.

**AC-2 — Execute never issues `git checkout main` during execution**
Given: any execute run (fresh or resumed).
When: the full execution from Pre-Loop through Final Review Step 5 completes.
Then: `git log --all --oneline` shows no commits on `main` authored during this run;
the execute branch is the only branch that advanced.
Independent Test: `git diff main..execute/<prd>-<piece>` contains all execution commits.

**AC-3 — Execute branch manifest carries `merged` before PR/squash**
Given: Final Review board has passed and human has signed off.
When: execute reaches the step just before Step 6 (merge/PR).
Then: manifest.yaml on the execute branch shows `status: merged` for this piece.
Independent Test: `git show execute/<prd>-<piece>:docs/prds/<prd>/manifest.yaml | grep -A1 "name: <piece>"` shows `status: merged`.

**AC-4 — plan.md Status: updated to final-review-pending on execute branch**
Given: all phases have completed and the review board is about to be dispatched.
When: execute transitions to Final Review Step 1.
Then: plan.md `**Status:**` field reads `final-review-pending`; committed on execute branch.
Independent Test: `git show execute/<prd>-<piece>:docs/prds/<prd>/specs/<piece>/plan.md | grep "Status:"` shows `final-review-pending`.

**AC-5 — merge_strategy: squash_local preserves existing Step 6 behavior**
Given: `.spec-flow.yaml` has `merge_strategy: squash_local` (or key absent — default).
When: execute Step 6 runs.
Then: behavior is identical to the current `git merge --squash` + `git commit` + worktree
remove + branch delete sequence. No user-visible change.
Independent Test: diff of execute/SKILL.md Step 6 section under `squash_local` branch matches
current Step 6 behavior verbatim.

**AC-6 — merge_strategy: pr halts at PR creation, not local merge**
Given: `.spec-flow.yaml` has `merge_strategy: pr`.
When: execute Step 6 runs.
Then: the skill displays a `gh pr create --base main --head execute/<prd>-<piece>` command
for the human to run and halts with a message indicating the PR must be reviewed and merged
externally. No local `git merge --squash` is issued. No local main-branch commit is made.
The skill does NOT execute the `gh` command.
Independent Test: execute SKILL.md Step 6 `pr` branch contains no `git merge` or `git checkout main` instructions.

**AC-7 — Status skill discovers in-progress pieces via worktree scan**
Given: a piece is `in-progress` with an active execute worktree, but main-branch manifest
still shows `planned` (pre-loop not yet reflected on main).
When: `/spec-flow:status` is run.
Then: the piece is shown as `in-progress` with correct current phase, sourced from the
worktree's manifest.
Independent Test: manually set main-branch manifest to `planned`; confirm status still
reports the piece as `in-progress` by reading from the worktree.

**AC-8 — Status skill worktree scan runs before manifest reads**
Given: any status invocation.
When: the scan workflow runs.
Then: `git worktree list` is issued as Step 1 of the scan, before any manifest file read.
Independent Test: SKILL.md workflow order shows worktree list preceding Step 3 manifest reads.

**AC-9 — Status skill uses targeted extraction on large manifests**
Given: a manifest.yaml file exceeding 10KB.
When: status reads it.
Then: only `id:`, `status:`, and `depends_on:` fields are extracted (not full-file read),
avoiding truncation. Full read is used only for manifests ≤ 10KB.
Independent Test: SKILL.md Step 3 note specifies the 10KB threshold and grep pattern.

**AC-10 — Spec skill manifest update stays on spec branch**
Given: spec skill Phase 5 finalize runs after user sign-off.
When: manifest status is updated to `specced`.
Then: the update is committed on the `spec/<prd>-<piece>` branch. No `git checkout main`
is issued inside the skill. A note instructs the user to merge/PR the spec branch to
advance main's manifest.
Independent Test: spec/SKILL.md Phase 5 Step 2 contains no `git checkout main` instruction.

**AC-11 — Plan skill manifest update stays on the spec branch**
Given: plan skill finalize runs after user sign-off.
When: manifest status is updated to `planned`.
Then: the update is committed on the `spec/<prd>-<piece>` branch (the branch created by the
spec skill and on which the plan skill operates). No `git checkout main` is issued inside
the skill.
Independent Test: plan/SKILL.md finalize section contains no `git checkout main` instruction;
any branch reference shows `spec/...` not `plan/...`.

**AC-12 — squash_local manifest conflict is handled, not hidden**
Given: `merge_strategy: squash_local` and another piece having updated `manifest.yaml` on
main since this execute branch was created.
When: execute Step 6 squash-merge detects a conflict on `manifest.yaml`.
Then: the skill escalates to the human per the existing "If merge conflicts: escalate to
human" clause — it does NOT attempt to auto-resolve the conflict.
Independent Test: execute/SKILL.md Step 6 `squash_local` branch retains the "If merge
conflicts: escalate to human" clause.

## Technical Approach

### The Core Change: Branch Ownership Model

All skills currently assume they can reach over to `main` mid-execution to update the
manifest (a shared index). This works only in self-contained repos where the skill operator
has direct write access to `main`. The fix is to adopt a strict ownership model:

> **A branch owns its own writes. Cross-branch writes are forbidden during execution.**

For execute:
- Pre-Loop commits `status: in-progress` to `manifest.yaml` on the execute branch.
- Final pre-merge commit updates `manifest.yaml` to `status: merged` on the execute
  branch (new — currently this happens on main after squash).
- `plan.md` **Status:** field is updated on the execute branch at `final-review-pending`.

For spec and plan skills:
- The manifest update at finalize happens on the feature branch (spec/... or plan/...).
- The user is responsible for landing that branch to main (via PR or direct merge),
  at which point main's manifest advances naturally.
- A note in the skill's finalize step explains this contract clearly.

### merge_strategy Key

Added to `.spec-flow.yaml` template with two values:

```yaml
# merge_strategy: controls how execute Step 6 lands the piece on main
#   squash_local — git merge --squash to local main, then push (default; suits
#                  self-contained repos with direct main write access)
#   pr           — emit gh pr create command; halt for human to merge via PR
#                  (suits PR-based repos where main is protected)
merge_strategy: squash_local
```

Default is `squash_local` for backward compatibility. The `pr` path adds a manifest
`merged` update on the execute branch (AC-3) before signaling the PR — so the squash
or merge brings the correct terminal state.

### Status Skill Scan Reorder

Current order: Step 1 PRD discovery → Step 3 per-PRD manifest parse → Step 5 worktree list.
New order: Step 1 worktree list → Step 2 PRD discovery → Step 3 per-PRD manifest parse
(with worktree-sourced overrides for in-progress pieces).

The worktree list provides: worktree path, branch name, HEAD SHA. From the branch name
`execute/<prd-slug>-<piece-slug>`, the skill derives the manifest path within the worktree
and reads only the fields it needs (`id:`, `status:`, `depends_on:`). It also reads the
plan.md checkbox count (`[x]` vs `[ ]`) to determine the current phase.

### Targeted Manifest Read (AC-9)

When `wc -c manifest.yaml` > 10240 bytes, use:
```bash
grep -E "^\s{0,4}(id|name|status|depends_on):" manifest.yaml
```
This returns only the structural fields status needs, avoiding the 50KB tool truncation
and the multi-round read overhead documented in the friction log (Problem 4).

## Testing Strategy

This piece modifies skill markdown files (SKILL.md) — the "tests" are structural checks
on the skill text and behavioral verification in the Verify step. Since skills are prose
instructions (not executable code), verification is:

- **AC-binding structural checks** (plan Verify blocks): `grep`/`view` the relevant
  SKILL.md sections to confirm forbidden patterns are absent and required patterns are present.
  E.g., `grep -c "git checkout main" execute/SKILL.md` must return 0 after the fix.
- **Schema check for `.spec-flow.yaml`**: confirm `merge_strategy:` key present with
  inline comment, valid values, and default documented.
- **Behavioral read-through**: for each AC, a human or verify agent reads the relevant
  SKILL.md section and confirms the prose instruction matches the AC's Then-clause.

No unit test harness exists for skill markdown. The QA agents (`qa-spec`, `qa-phase`)
serve the adversarial review role.

## Open Questions

- **OQ-1**: Should `merge_strategy` be per-PRD or global in `.spec-flow.yaml`?
  (Default: global — a repo either uses PRs or doesn't. Per-PRD override is unnecessary
  complexity until a use case emerges.)
- **OQ-2**: For `merge_strategy: pr`, should the skill construct the full PR body from
  learnings.md / phase summary automatically, or just title + head branch?
  (Default: title + head branch only. Body authoring is out of scope; users add context
  manually in the PR.)
