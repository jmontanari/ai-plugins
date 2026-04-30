---
charter_snapshot:
  architecture: 2026-04-21
  non-negotiables: 2026-04-21
  tools: 2026-04-21
  processes: 2026-04-21
  flows: 2026-04-21
  coding-rules: 2026-04-21
tdd: false
---

# Plan: Branch Integrity — Eliminate Direct-Main Writes During Pipeline Execution

**Spec:** docs/prds/shared/specs/pi-011-branch-fix/spec.md
**Charter:** docs/charter/ (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** final-review-pending

## Overview

Non-TDD mode: all phases use Implement track. All work is prose edits to SKILL.md files
and YAML config. No unit test harness exists for skill markdown — verification is structural
grep checks on the modified files. AC Coverage Matrix is not required. QA and Final Review
remain fully intact.

**Files modified:**
| File | Phase |
|------|-------|
| `plugins/spec-flow/skills/execute/SKILL.md` | Phase 1, Phase 2 |
| `.spec-flow.yaml` | Phase 2 |
| `plugins/spec-flow/skills/spec/SKILL.md` | Sub-Phase A.1 |
| `plugins/spec-flow/skills/plan/SKILL.md` | Sub-Phase A.2 |
| `plugins/spec-flow/skills/status/SKILL.md` | Phase 3 |
| `plugins/spec-flow/plugin.json` | Phase 4 |
| `.claude-plugin/marketplace.json` | Phase 4 |
| `plugins/spec-flow/CHANGELOG.md` | Phase 4 |

## Phases

---

### Phase 1: Execute Pre-Loop — branch-ownership fix

**Exit Gate:** `grep -c "git checkout main" plugins/spec-flow/skills/execute/SKILL.md`
returns `1` (only the Step 6 `squash_local` occurrence remains; this occurrence is
intentionally kept because Step 6 runs after Final Review Step 5, outside the AC-2
constraint window).
**ACs Covered:** AC-1, AC-2
**Charter constraints honored in this phase:**
- NN-C-008 (fresh context per agent dispatch): Pre-Loop change is orchestration-only — no
  agent prompt templates or context injection blocks are touched.
- NN-P-003 (dog-food before recommend): this change is being applied to this repo first
  (pi-011 cycle on shared-plugins) before any external release guidance is updated.
- CR-004 (conventional commits): the Pre-Loop commit uses `fix(spec-flow):` prefix.
- CR-008 (thin-orchestrator): only orchestration flow (branch routing) is changed; no
  agent dispatch logic is modified.

- [x] **[Implement]** Edit `plugins/spec-flow/skills/execute/SKILL.md`

  Locate the "Pre-Loop: Mark Piece as In-Progress" section (search for the heading
  `## Pre-Loop: Mark Piece as In-Progress`). The current section reads:

  > Before the first phase runs (and only on a fresh start, not a resume), update the
  > PRD's manifest **on `main`** to mark this piece's status as `in-progress` (per the
  > spec's piece-status state machine). Skip if it's already `in-progress` (resumed session).
  >
  > ```bash
  > git checkout main
  > # update docs/prds/<prd-slug>/manifest.yaml: set this piece's status to "in-progress"
  > git add docs/prds/<prd-slug>/manifest.yaml
  > git commit -m "manifest: mark <prd-slug>/<piece-slug> as in-progress"
  > git checkout execute/<prd-slug>-<piece-slug>
  > ```
  >
  > This makes `status` report an accurate picture — a piece is `in-progress` while
  > execute is in progress, and flips to `merged` (or the `done` alias) after the final
  > merge.

  Replace it with:

  > Before the first phase runs (and only on a fresh start, not a resume), update the
  > PRD's manifest **on the execute branch** to mark this piece's status as `in-progress`
  > (per the spec's piece-status state machine). Skip if it's already `in-progress`
  > (resumed session). The execute branch is already the active working branch — no
  > checkout is needed.
  >
  > ```bash
  > # update docs/prds/<prd-slug>/manifest.yaml: set this piece's status to "in-progress"
  > git add docs/prds/<prd-slug>/manifest.yaml
  > git commit -m "manifest: mark <prd-slug>/<piece-slug> as in-progress"
  > ```
  >
  > This commit lives on the execute branch. Main's manifest retains `planned` until the
  > branch is merged (via squash or PR), at which point main receives the correct terminal
  > state in one step. The `status` skill discovers the correct `in-progress` state by
  > scanning active execute-branch worktrees (see Status skill, AC-7).

- [x] **[Write-Tests]** No test harness — verification is grep checks in [Verify]; skip.

- [x] **[Verify]** Structural check
  - Run: `grep -c "git checkout main" plugins/spec-flow/skills/execute/SKILL.md`
  - Expected: output is `1` (one remaining occurrence in Step 6 `squash_local` path,
    which is correct — Step 6 runs after Final Review Step 5, outside the AC-2 window).
  - Run: `grep -n "git checkout main" plugins/spec-flow/skills/execute/SKILL.md`
  - Expected: the one hit must be on a line containing `git checkout main` inside the
    Step 6 block (search context should show "Step 6" in nearby lines), NOT in the
    Pre-Loop block.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-2
  - Diff baseline: `git diff <phase_1_start_sha>..HEAD`

---

### Phase 2: Execute — merge_strategy, manifest timing, plan.md Status

**Why serial:** Phase 2 edits `plugins/spec-flow/skills/execute/SKILL.md` — the same file Phase 1 edits — making concurrent execution impossible (file-scope overlap). Additionally, Phase 2's merge_strategy logic depends on the clean branch-routing prose that Phase 1 establishes; Phase 2 must read the Phase 1 result to anchor its edits correctly.

**Exit Gate:**
- `grep -c "git checkout main" plugins/spec-flow/skills/execute/SKILL.md` returns `1`
  (only inside the Step 6 `squash_local` path).
- `grep -c "merge_strategy" plugins/spec-flow/skills/execute/SKILL.md` returns ≥ 2.
- `grep -c "merge_strategy" .spec-flow.yaml` returns ≥ 1.
- `grep -c "final-review-pending" plugins/spec-flow/skills/execute/SKILL.md` returns ≥ 1.
- "### Step 7" heading no longer present in `plugins/spec-flow/skills/execute/SKILL.md`.
**ACs Covered:** AC-3, AC-4, AC-5, AC-6, AC-12
**Charter constraints honored in this phase:**
- NN-C-002 (no new runtime dependencies): the `merge_strategy: pr` path displays the
  `gh pr create` command for the human — the skill does not execute it. No `gh` dep added.
- NN-C-003 (backward compat): `squash_local` default preserves all existing execute
  behavior; no existing key renamed or removed.
- NN-C-006 (no destructive ops without confirmation): `pr` path halts and requires human
  to run the PR command manually — stronger gate than before.
- NN-P-002 (no auto-merge without sign-off): `squash_local` retains Step 4 human sign-off;
  `pr` requires human PR review/merge. Neither path auto-merges.
- CR-007 (config keys documented inline): `merge_strategy` key in `.spec-flow.yaml`
  carries a comment block explaining valid values, default, and rationale.

- [x] **[Implement]** Three edits to `plugins/spec-flow/skills/execute/SKILL.md` and
  one edit to `.spec-flow.yaml`.

  **Edit A — plan.md Status at Final Review entry (AC-4)**

  Locate "## Final Review" heading and "### Step 1: Iteration 1 — Full Review (5 Parallel
  Agents)". Immediately before the `git diff main..HEAD` code block (which starts the
  review agent dispatch), insert the following new paragraph:

  > Before dispatching the review board, record that final review is in progress by
  > updating `plan.md` on the execute branch:
  >
  > ```bash
  > # Update the Status: field in plan.md from its current value to "final-review-pending"
  > # Use sed (or equivalent text replacement) to change the line:
  > #   **Status:** <current-value>
  > # to:
  > #   **Status:** final-review-pending
  > sed -i '' 's/^\*\*Status:\*\* .*/\*\*Status:\*\* final-review-pending/' \
  >     docs/prds/<prd-slug>/specs/<piece-slug>/plan.md
  > git add docs/prds/<prd-slug>/specs/<piece-slug>/plan.md
  > git commit -m "plan: <prd-slug>/<piece-slug> final-review-pending"
  > ```
  >
  > This lets a human inspect `plan.md` and know the piece is in final review without
  > counting phase checkboxes.

  **Edit B — pre-merge manifest update and Step 7 removal (AC-3)**

  Locate "### Step 5: Capture Learnings" and its trailing learnings commit block. After
  that commit block (after the closing ` ``` `), and before "### Step 6: Merge", insert a
  new heading:

  > ### Step 5.5: Update Manifest to Merged (pre-merge)
  >
  > Before merging or signalling PR creation, commit the terminal manifest state to the
  > execute branch so that main receives the correct `merged` state when the branch lands:
  >
  > ```bash
  > # update docs/prds/<prd-slug>/manifest.yaml: set status to "merged"
  > git add docs/prds/<prd-slug>/manifest.yaml
  > git commit -m "manifest: mark <prd-slug>/<piece-slug> as merged (pre-merge)"
  > ```

  Then locate "### Step 7: Update Manifest" (after Step 6) and **delete the entire Step 7
  section** (heading + body). It is superseded by Step 5.5.

  **Edit C — Step 6 merge_strategy conditional (AC-5, AC-6, AC-12)**

  Locate "### Step 6: Merge". The current content is:

  > **Integration — transition all phase tasks to Done …**
  >
  > ```bash
  > git checkout main
  > git merge --squash execute/<prd-slug>-<piece-slug>
  > git commit -m "execute/<prd-slug>-<piece-slug>: <summary of what was built>"
  > git worktree remove {{worktree_root}}
  > git branch -d execute/<prd-slug>-<piece-slug>
  > ```
  >
  > If merge conflicts: escalate to human.

  Replace the code block and the "If merge conflicts" sentence (preserve the Integration
  paragraph above it) with:

  > Read `merge_strategy` from `.spec-flow.yaml` (default: `squash_local` if the key is
  > absent or not set). Branch on the value:
  >
  > **If `merge_strategy: squash_local` (default):**
  > ```bash
  > git checkout main
  > git merge --squash execute/<prd-slug>-<piece-slug>
  > git commit -m "feat(spec-flow): execute/<prd-slug>-<piece-slug> — <summary of what was built>"
  > git worktree remove {{worktree_root}}
  > git branch -d execute/<prd-slug>-<piece-slug>
  > ```
  > If merge conflicts: escalate to human.
  >
  > **If `merge_strategy: pr`:**
  > Display the following command for the human to copy-paste and run manually:
  > ```
  > gh pr create --base main --head execute/<prd-slug>-<piece-slug>
  > ```
  > Print: "PR-based merge required. Run the command above to open a pull request. After
  > the PR is reviewed and merged externally, the piece will be complete. The execute branch
  > and worktree can be cleaned up after the PR merges."
  > **Halt.** Do NOT execute the `gh` command — no `gh` CLI dependency is introduced.

  **Edit D — `.spec-flow.yaml` merge_strategy key (CR-007)**

  In `.spec-flow.yaml`, locate the `refactor:` key. After the `refactor:` block (after its
  comment lines), insert the following block before the `tdd:` key:

  ```yaml
  # merge_strategy: controls how execute Step 6 lands the piece on main
  #   squash_local — git merge --squash to local main, then push (default; suits
  #                  self-contained repos with direct main write access)
  #   pr           — display gh pr create command for the human to run; halt
  #                  (suits PR-based repos where main is protected; no gh CLI dep added)
  merge_strategy: squash_local
  ```

- [x] **[Write-Tests]** No test harness — verification is grep checks in [Verify]; skip.

- [x] **[Verify]** Structural checks — run ALL of the following:
  - `grep -c "git checkout main" plugins/spec-flow/skills/execute/SKILL.md` → `1`
    (only inside the `squash_local` branch of Step 6).
  - `grep -n "git checkout main" plugins/spec-flow/skills/execute/SKILL.md` → the
    single hit must be adjacent to `git merge --squash` in the Step 6 `squash_local` block.
  - `grep -c "merge_strategy" plugins/spec-flow/skills/execute/SKILL.md` → ≥ 2
    (once in the "Read merge_strategy" prose, at least once more in the branch labels).
  - `grep -c "merge_strategy" .spec-flow.yaml` → ≥ 1.
  - `grep -c "final-review-pending" plugins/spec-flow/skills/execute/SKILL.md` → ≥ 1.
  - `grep -c "Step 5.5" plugins/spec-flow/skills/execute/SKILL.md` → ≥ 1.
  - `grep -c "### Step 7" plugins/spec-flow/skills/execute/SKILL.md` → `0`
    (Step 7 heading removed).
  - `grep -c "squash_local\|merge_strategy: pr" plugins/spec-flow/skills/execute/SKILL.md`
    → ≥ 2.

- [x] **[QA]** Phase review
  - Review against: AC-3, AC-4, AC-5, AC-6, AC-12
  - Diff baseline: `git diff <phase_2_start_sha>..HEAD`

---

## Phase Group A: Spec and plan skill manifest fixes

**Exit Gate:** all sub-phases pass oracle + group-level QA clean.
**ACs Covered:** AC-10, AC-11

#### Sub-Phase A.1 [P]: Spec skill — remove git checkout main

**Scope:** `plugins/spec-flow/skills/spec/SKILL.md`
**ACs:** AC-10
**Charter constraints honored in this phase:** (all charter entries allocated; none
uniquely belong to this sub-phase — see Phase 1 and Phase 2 for the full allocation)

- [x] **[Implement]** Edit `plugins/spec-flow/skills/spec/SKILL.md`

  Locate "### Phase 5: Finalize" then Step 2 ("Update `docs/prds/<prd-slug>/manifest.yaml`
  on main"). The current content is:

  > 2. Update `docs/prds/<prd-slug>/manifest.yaml` on main: piece status → `specced`
  >    ```bash
  >    git checkout main
  >    # update docs/prds/<prd-slug>/manifest.yaml status for this piece
  >    git add docs/prds/<prd-slug>/manifest.yaml
  >    git commit -m "manifest: mark <prd-slug>/<piece-slug> as specced"
  >    git checkout spec/<prd-slug>-<piece-slug>
  >    ```

  Replace with:

  > 2. Update `docs/prds/<prd-slug>/manifest.yaml` on the spec branch (the current
  >    working branch — no checkout needed):
  >    ```bash
  >    # update docs/prds/<prd-slug>/manifest.yaml status for this piece
  >    git add docs/prds/<prd-slug>/manifest.yaml
  >    git commit -m "manifest: mark <prd-slug>/<piece-slug> as specced"
  >    ```
  >    > **Branch ownership:** The manifest update stays on the spec branch
  >    > (`spec/<prd-slug>-<piece-slug>`). Main's manifest advances when this branch
  >    > is merged or a PR is opened. For PR-based repos, the human merges the spec branch
  >    > to main as part of the normal review workflow.

- [x] **[Write-Tests]** No test harness; skip.

- [x] **[Verify]** `grep -c "git checkout main" plugins/spec-flow/skills/spec/SKILL.md`
  → `0`.

- [x] **[QA-lite]** Sonnet narrow review, scope: Sub-Phase A.1 only.
  - Review against: AC-10.

#### Sub-Phase A.2 [P]: Plan skill — remove git checkout main

**Scope:** `plugins/spec-flow/skills/plan/SKILL.md`
**ACs:** AC-11

- [x] **[Implement]** Edit `plugins/spec-flow/skills/plan/SKILL.md`

  Locate "### Phase 4: Finalize" then Step 4 ("Update manifest on main"). The current
  content is:

  > 4. Update manifest on main: piece status → `planned`
  >    ```bash
  >    git checkout main
  >    # update manifest.yaml status for this piece in its PRD-local manifest
  >    git add <docs_root>/prds/<prd-slug>/manifest.yaml
  >    git commit -m "manifest: mark <prd-slug>/<piece-slug> as planned"
  >    git checkout spec/<prd-slug>-<piece-slug>
  >    ```

  Replace with:

  > 4. Update manifest on the spec branch (the current working branch — no checkout needed):
  >    ```bash
  >    # update manifest.yaml status for this piece in its PRD-local manifest
  >    git add <docs_root>/prds/<prd-slug>/manifest.yaml
  >    git commit -m "manifest: mark <prd-slug>/<piece-slug> as planned"
  >    ```
  >    > **Branch ownership:** The manifest update stays on `spec/<prd-slug>-<piece-slug>`.
  >    > Main's manifest advances when this branch is merged or a PR is opened.

- [x] **[Write-Tests]** No test harness; skip.

- [x] **[Verify]** `grep -c "git checkout main" plugins/spec-flow/skills/plan/SKILL.md`
  → `0`.

- [x] **[QA-lite]** Sonnet narrow review, scope: Sub-Phase A.2 only.
  - Review against: AC-11.

#### Group-level

- [x] **[Refactor]** Scope: `plugins/spec-flow/skills/spec/SKILL.md` and
  `plugins/spec-flow/skills/plan/SKILL.md` — auto-skip if both edits are clean and the
  blockquote wording is consistent between the two files.
- [x] **[QA]** Opus deep review, diff baseline: `git diff <group_A_start_sha>..HEAD`
  - Review against: AC-10, AC-11

---

### Phase 3: Status skill worktree scan reorder

**Why serial: Phase 1 and Phase 3 are edits to different files with no symbol cross-references, but Phase 3's new Step 1 references the execute-branch naming pattern established by Phase 1's rewrite — keeping them serial ensures Phase 3's wording is coherent with Phase 1's final prose. Additionally, the four sequential phases (1→2→3→4) each touch the same execute/SKILL.md narrative flow in a way that makes reviewing the cumulative diff clearer when phases run serially; converting 1+3 into a sub-group would add Phase Group overhead for minimal wall-clock gain on a prose-editing piece.**

**Exit Gate:**
- `grep -n "worktree list\|git worktree" plugins/spec-flow/skills/status/SKILL.md`
  shows the `git worktree list` reference at a **lower line number** than the first
  "PRD discovery" reference.
- `grep -c "10KB\|10240\|wc -c" plugins/spec-flow/skills/status/SKILL.md` ≥ 1.
**ACs Covered:** AC-7, AC-8, AC-9
**Charter constraints honored in this phase:** (no additional charter entries — all
allocated in Phases 1, 2, and 4)

- [x] **[Implement]** Edit `plugins/spec-flow/skills/status/SKILL.md`

  **Edit A — Update the Workflow order declaration (AC-8)**

  Find the line near the top of "## Workflow (scan flow)":
  > **Order:** PRD discovery → all-PRDs default view → drill-in mode → archive filter →
  > drift surfacing.

  Replace with:
  > **Order:** Worktree scan → PRD discovery → archive filter → per-PRD parse (with
  > worktree overrides for in-progress pieces) → drift surfacing → all-PRDs default view
  > → drill-in mode.

  **Edit B — Insert new Step 0: Worktree scan (AC-7, AC-8)**

  After Step 0 ("Load config") and before Step 1 ("PRD discovery"), insert a new numbered
  step. Renumber: the new step becomes **Step 1**, and the current Step 1 through Step 9
  each increment by one (Step 1 → Step 2, Step 1a → Step 2a, Step 2 → Step 3, etc.). 

  New **Step 1: Worktree scan**:

  > 1. **Worktree scan (AC-7 / AC-8):** Run `git worktree list --porcelain` to discover
  >    all active worktrees. For each worktree whose branch matches the pattern
  >    `execute/<prd-slug>-<piece-slug>` (per v3 naming conventions in
  >    `plugins/spec-flow/reference/v3-path-conventions.md`):
  >    - Derive the manifest path within that worktree:
  >      `<worktree_path>/docs/prds/<prd-slug>/manifest.yaml`.
  >    - Read the fields `id:`, `name:`, `status:`, and `depends_on:` from that manifest.
  >      If the manifest exceeds 10 KB (`wc -c` output > 10240), use targeted extraction
  >      instead of a full read:
  >      ```bash
  >      grep -E '^\s{0,4}(id|name|status|depends_on):' \
  >          <worktree_path>/docs/prds/<prd-slug>/manifest.yaml
  >      ```
  >    - Record: `<prd-slug>/<piece-slug>` → `{status, worktree_path, branch}`. This data
  >      is **authoritative** for that piece — it supersedes any main-branch manifest entry
  >      for the same piece during this status run.
  >    - Also read `plan.md` from the worktree (`<worktree_path>/docs/prds/<prd-slug>/specs/
  >      <piece-slug>/plan.md`) and count `[x]` vs `[ ]` checkboxes to determine the current
  >      phase number and name.
  >
  >    Store all worktree-sourced piece data in memory as `worktree_overrides` keyed by
  >    `<prd-slug>/<piece-slug>`.

  **Edit C — Per-PRD parse: honour worktree overrides (AC-7, AC-9)**

  In the per-PRD parse step (now Step 4 after renumbering), add the following note after
  "Extract the pieces list and aggregate piece counts by status":

  > **Worktree override:** Before reading the main-branch manifest for a piece, check
  > `worktree_overrides` (populated in Step 1). If an entry exists for
  > `<prd-slug>/<piece-slug>`, use its `status`, `phase`, and `worktree_path` data instead
  > of the main-branch manifest value for that piece. The main-branch manifest is still read
  > for all other pieces with no active worktree.
  >
  > **Large manifest:** If `wc -c <manifest_path>` > 10240 bytes, use the targeted
  > extraction pattern from Step 1 rather than reading the full file.

  **Edit D — Remove "Check worktrees" step (now redundant)**

  The old Step 5 was "Check worktrees: Run `git worktree list` to identify active
  worktrees…". Since this work is now done in the new Step 1, **delete the step whose
  heading reads "Check worktrees" (which becomes Step 6 after Edit B's renumbering)**
  entirely — it is now fully superseded. After deletion, update all four known
  cross-references in the body prose that become stale after Edit B's renumbering:

  1. Step 1a's text: `"for the drift comparison in **step 4**"` → change to `"step 5"`
     (drift surfacing is now Step 5 after Edit B's renumbering).
  2. Step 4's text: `"loaded in **step 1a**"` → change to `"step 2a"`
     (Step 1a becomes Step 2a after Edit B's renumbering).
  3. Line ~135 text: `"(see **step 1**)"` → change to `"(see step 2)"`
     (PRD discovery is now Step 2 after Edit B's renumbering).
  4. Any remaining "step 5" reference in the drill-in display prose → change to "step 6"
     if it referred to the old "Check worktrees" step.

- [x] **[Write-Tests]** No test harness; skip.

- [x] **[Verify]** Structural checks:
  - `grep -n "git worktree\|worktree list" plugins/spec-flow/skills/status/SKILL.md`
    → first hit line number must be **lower** than the line for "PRD discovery".
  - `grep -c "10KB\|10240\|wc -c" plugins/spec-flow/skills/status/SKILL.md` → ≥ 1.
  - `grep -c "worktree_overrides" plugins/spec-flow/skills/status/SKILL.md` → ≥ 2.
  - Read the area around the first `git worktree` reference and confirm it appears under
    a "Step 1" heading (not "Step 5" or higher).

- [x] **[QA]** Phase review
  - Review against: AC-7, AC-8, AC-9
  - Diff baseline: `git diff <phase_3_start_sha>..HEAD`

---

### Phase 4: Version bump

**Exit Gate:**
- `python3 -c "import json,sys; d=json.load(open('plugins/spec-flow/plugin.json')); print(d['version'])"` → `3.5.0`.
- `grep '"version"' .claude-plugin/marketplace.json` → contains `"3.5.0"` adjacent to
  the `spec-flow` entry.
- `grep -c "3.5.0" plugins/spec-flow/CHANGELOG.md` → ≥ 1.
**ACs Covered:** (none — version bump covers charter obligations NN-C-001, NN-C-009)
**Charter constraints honored in this phase:**
- NN-C-001 (version sync): `plugin.json` and `.claude-plugin/marketplace.json` updated
  to `3.5.0` in the same commit.
- NN-C-009 (always bump version): new behavior (merge_strategy key, branch-ownership
  corrections) is a minor-version bump (new capability, backward-compatible default).
  Three places updated together: `plugin.json`, `.claude-plugin/marketplace.json`,
  `CHANGELOG.md`.

- [x] **[Implement]**

  1. **`plugins/spec-flow/plugin.json`** — change `"version": "3.4.1"` → `"version": "3.5.0"`.

  2. **`.claude-plugin/marketplace.json`** — find the spec-flow entry (search for
     `"name": "spec-flow"` or `"source": "./plugins/spec-flow"`). Change its `"version"`
     value from `"3.4.1"` → `"3.5.0"`.

  3. **`plugins/spec-flow/CHANGELOG.md`** — insert a new section immediately after the
     `# Changelog` heading and before the existing `## [3.4.1]` entry:

     ```markdown
     ## [3.5.0] — 2026-04-30

     ### Added
     - `merge_strategy` config key in `.spec-flow.yaml` (`squash_local` | `pr`). When set
       to `pr`, execute Step 6 displays a `gh pr create` command for the human to run and
       halts — no local squash-merge. Supports PR-based repos where `main` is protected.
       Default is `squash_local` for full backward compatibility.

     ### Changed
     - **Execute Pre-Loop:** manifest `in-progress` update now commits on the execute
       branch (branch-ownership model). No more `git checkout main` before the first phase
       or after Final Review Step 5.
     - **Execute Step 5.5 (new):** manifest `merged` update is committed on the execute
       branch before Step 6 merge/PR, so the branch carries its terminal manifest state
       to main rather than requiring a post-merge commit on main.
     - **Execute Final Review Step 1:** `plan.md **Status:**` is updated to
       `final-review-pending` on the execute branch when the review board is dispatched.
     - **Spec skill Phase 5:** manifest `specced` update stays on the spec branch (no
       `git checkout main`). A note explains that main's manifest advances when the spec
       branch is merged.
     - **Plan skill Phase 4:** same fix as spec skill — manifest `planned` update stays
       on the spec branch.
     - **Status skill:** worktree scan (`git worktree list`) is now Step 1 (was Step 5),
       running before PRD discovery. Worktree-sourced manifest data is authoritative for
       in-progress pieces. Manifests > 10 KB use targeted field extraction.

     ### Removed
     - Execute Step 7 (separate manifest `merged` update on main after squash-merge) is
       superseded by the new Step 5.5.
     ```

  Commit all three files together in one commit:
  ```bash
  git add plugins/spec-flow/plugin.json .claude-plugin/marketplace.json \
      plugins/spec-flow/CHANGELOG.md
  git commit -m "chore(spec-flow): bump version to 3.5.0"
  ```

- [x] **[Write-Tests]** No test harness; skip.

- [x] **[Verify]**
  - `python3 -c "import json; d=json.load(open('plugins/spec-flow/plugin.json')); print(d['version'])"` → `3.5.0`.
  - `grep '"version"' .claude-plugin/marketplace.json` (scoped to the spec-flow block) → `"3.5.0"`.
  - `grep -c "\[3.5.0\]" plugins/spec-flow/CHANGELOG.md` → `1`.

- [x] **[QA]** Phase review
  - Review against: NN-C-001, NN-C-009
  - Diff baseline: `git diff <phase_4_start_sha>..HEAD`

---

## Agent Context Summary

| Agent | Inputs | Outputs |
|-------|--------|---------|
| Implementer (Phase 1) | Pre-Loop section of execute/SKILL.md (lines ~44–56) | Edited Pre-Loop block |
| Implementer (Phase 2) | Final Review Step 1 block, Step 5 learnings block, Step 6 merge block, Step 7 block, `.spec-flow.yaml` refactor/tdd section | Edited execute/SKILL.md (3 edits), new merge_strategy key in .spec-flow.yaml |
| Implementer (A.1) | Phase 5 Finalize section of spec/SKILL.md (lines ~93–103) | Edited Phase 5 Step 2 |
| Implementer (A.2) | Phase 4 Finalize section of plan/SKILL.md (lines ~246–258) | Edited Phase 4 Step 4 |
| Implementer (Phase 3) | Workflow section of status/SKILL.md (lines 1–63, Step 5) | Reordered steps, inserted new Step 1, updated per-PRD parse step, deleted old Step 5 |
| Implementer (Phase 4) | plugin.json, .claude-plugin/marketplace.json, CHANGELOG.md | Version 3.5.0 in all three + changelog entry |

## Open Questions

None — all resolved during spec authoring.
