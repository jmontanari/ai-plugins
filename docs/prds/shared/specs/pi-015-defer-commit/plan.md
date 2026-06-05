---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-01
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
tdd: false
fast: false
---

# Plan: pi-015-defer-commit

**Spec:** docs/prds/shared/specs/pi-015-defer-commit/spec.md
**PRD Sections:** G-2, FR-004, NFR-003, NN-P-002
**Status:** final-review-pending

## Overview

Flip the default Phase Group model to **serial + git-free section + single deferred barrier
work-commit**, made resumable by a Tier-1 journal and sibling-safe by file-scoped recovery; default
on via `deferred_commit: auto`, with `deferred_commit: off` preserving today's concurrent +
per-sub-phase-commit behavior (major bump 5.0.0). Concurrency + Race-2 scoped oracle are carved to
pi-016.

**Non-TDD mode:** all phases use the **Implement track** (`[Implement]` → `[Verify]` → optional
`[Refactor]` → `[QA]`). There is no runtime service under test; the `[Verify]` blocks hold
structural oracles (grep / `cmp` / `diff` / version-equality) with concrete expected output, per the
pi-014 convention. The AC Coverage Matrix is included for traceability; QA and Final Review remain
intact. The runtime model was already proven by the 9-invariant concurrent harness (VALIDATION.md,
`/tmp/ptdd`); these phases assert the prose now encodes that behavior and the worked-example traces
are present.

**Prose-vs-executed-trace convention (explicit):** several spec Independent Tests are phrased as
"run the synthetic trace and assert ordering / commit count …" (AC-1, AC-2, AC-3, AC-5, AC-7). In
this Implement-track prose piece those are satisfied by **asserting the worked-example trace is
encoded in the prose** (grep), not by executing a runtime trace — the runtime behavior itself was
already proven by the 9-invariant harness (VALIDATION.md). This is the deliberate pi-014 convention,
not a coverage downgrade; the `[Verify]` greps gate the documented trace's presence.

**Why serial (whole plan):** the disjoint-file phases (reference doc, config, doctrine, version)
*could* be a parallel Phase Group, but running pi-015's own edits through the **current** (concurrent,
unsafe) Phase Group machinery would risk the exact commit-stage race this piece removes. Serialize
until pi-015 ships; pi-016 re-enables safe concurrency. The execute SKILL.md phases (3–6) are
additionally serial because they edit the same file sequentially with content dependencies.

## Architectural Decisions

### ADR-1: Serial default; concurrent dispatch gated to `deferred_commit: off`
**Context:** Current Step G4 dispatches Phase Group sub-phases concurrently against a shared index — the source of the documented commit-stage race (Race 1) and `index.lock` contention; operators already fall back to serial.
**Decision:** Under the new default `deferred_commit: auto`, dispatch sub-phases serially with a git-free section and one barrier commit. `off` preserves the exact concurrent + per-sub-phase-commit path for one release.
**Alternatives considered:** (a) keep concurrent + add pathspec-commit mutex — still leaves Race-2 live; (b) per-sub-phase worktrees — rejected by operator (overhead). 
**Consequences:** zero Race-1/Race-2 under the default; commit count drops N+1 → 2 per group; concurrency deferred to pi-016. Behavior change on upgrade → major bump.
**Charter alignment:** NN-C-003 (`off` rollback), NN-C-009 (major bump), NN-P-002 (gates untouched).

### ADR-2: Working-tree-hash anti-cheat (no HEAD mid-group)
**Context:** Today the integrity gate re-hashes Red tests AS COMMITTED in HEAD; the git-free group has no per-sub-phase commit.
**Decision:** Re-hash Red tests in the **working tree** against the journal-recorded manifest, at sub-phase completion and again before the barrier commit.
**Alternatives considered:** (a) dangling commit-tree snapshots per sub-phase (Tier-2) — more machinery; (b) drop the anti-cheat in groups — unacceptable.
**Consequences:** equivalent tamper-evidence (validated INV-3/Q3); slightly more mutable window, closed by hashing immediately pre-commit.
**Charter alignment:** preserves the spec-flow anti-cheat invariant; CR-008 (orchestrator-side).

### ADR-3: Tier-1 journal only; Tier-2 documented future
**Context:** Crash recovery needs a durable checkpoint; commits are today's only one.
**Decision:** Ship a Tier-1 journal (file + surviving working tree). Tier-2 (dangling commit-tree checkpoints via private GIT_INDEX_FILE, gated by a future `journal_tier` knob) is documented-only.
**Alternatives considered:** Tier-2 now — covers a working-tree wipe but rarer; deferred.
**Consequences:** covers session death (common case); a working-tree wipe is unrecovered (documented limit).
**Charter alignment:** NN-C-005 (journal-absent → fresh start), NN-P-001 (readable JSON).

### ADR-4: Barrier commit is add-then-commit by pathspec union
**Context:** The git-free section leaves files untracked; a bare `git commit -- <paths>` fails on untracked files (validated INV-5).
**Decision:** `git add -- <union>` then `git commit -- <union>`; the G10 plan.md progress commit stays separate (2 commits/group).
**Alternatives considered:** fold plan.md into the work-commit — breaks the strict (Red∪Build) union and the existing G10 contract.
**Consequences:** exact-union work-commit; journal/artifacts excluded; progress commit unchanged.
**Charter alignment:** CR-004 (conventional messages).

### ADR-5: This plan's own phases run serial (Why-serial)
**Context:** pi-015 fixes the parallel-Phase-Group race; the current execute would run a Phase Group here concurrently.
**Decision:** author all phases as serial flat phases.
**Alternatives considered:** parallel Phase Group for the disjoint-file phases — risks the very race under repair.
**Consequences:** marginal wall-clock cost; zero dogfooding-the-bug risk.
**Charter alignment:** NN-P-002 / NN-C-006 (no risk to in-flight work).

## Phases

### Phase 1: New reference doc — `reference/deferred-commit-journal.md`
**In scope:** CREATE `plugins/spec-flow/reference/deferred-commit-journal.md` (journal schema, resume algorithm, file-scoped recovery recipe, barrier recipe, Tier-2 future).
**NOT in scope:** execute SKILL.md wiring (Phases 3–5); config knob (Phase 2); doctrine (Phase 6).
**ACs Covered:** AC-4 (schema), AC-5 (resume algorithm — doc), AC-6 (recovery recipe — doc), AC-9 (reference-doc presence).
**Charter constraints honored in this phase:** NN-P-001 (journal is human-readable JSON), CR-009 (semantic heading hierarchy).

- [x] **[Implement]**
  - T-1: CREATE `plugins/spec-flow/reference/deferred-commit-journal.md`
    Structure outline (H2 sections):
    1. `## Purpose` — what the journal is (durable mid-group checkpoint decoupled from commits) and when it exists (only during a deferred Phase Group).
    2. `## Journal schema (Tier 1)` — a JSON object, fields documented inline:
       `group_start_sha` (string), `group_letter` (string), `sub_phases` (map keyed by sub-phase id `<letter>.<n>`) where each value has `scope` (string[] literal paths), `status` (`pending` | `red-done` | `green` | `failed`), `red_manifest_hashes` (map path→sha256). Include a concrete example object with real values.
    3. `## Lifecycle` — written at Step G1 (group start, `group_start_sha` + empty sub_phases), updated at each sub-phase status transition, removed after the barrier work-commit. Kept out of commits by the `.gitignore` entry (Phase 2) AND the pathspec-only barrier commit (its path is never in a commit pathspec).
    4. `## Resume algorithm` — ordered steps: (1) on execute start, look for the journal for the active group; (2) read `group_start_sha`; (3) `green` sub-phases: re-hash only the Red test files (the keys of `red_manifest_hashes`) against their stored hashes — trust on match; the production files listed in `scope` are trusted by association and are NOT independently re-hashed; (4) incomplete sub-phases (`pending`/`red-done`/`failed`): apply the file-scoped recovery recipe, re-run; (5) sub-phases absent from the journal: not started; (6) no journal → fresh group start (no error). Include a worked example trace (2 green + 1 failed → only the failed re-runs; greens byte-identical, clarifying that only Red test files were checked).
    5. `## File-scoped recovery recipe` — the created-vs-modified asymmetry: `git restore --source=$group_start_sha --worktree -- <modified paths>` for files that existed at group start; `rm` + `git rm --cached` (if staged) for files CREATED in the sub-phase (which `git restore --source` does NOT remove). State that `git reset` to a SHA is never used for sub-phase recovery (only whole-group human-abort). Include a worked example.
    6. `## Barrier commit recipe` — `git add -- <union>` then `git commit -m "<msg>" -- <union>` (the explicit `git add` is required: a bare `git commit -- <paths>` fails `did not match any file(s) known to git` on the untracked git-free files). Union = ⋃ sub-phases (Red manifest ∪ Build files). plan.md progress commit is separate.
    7. `## Tier 2 (future — not implemented)` — dangling `commit-tree` checkpoints via a private `GIT_INDEX_FILE`, gated by a future `journal_tier` knob; survives a working-tree wipe; recoverable via `git checkout <sha> -- .`. Documented for forward reference only.
    Pattern (heading + inline-comment style from an existing reference doc, `plugins/spec-flow/reference/ac-matrix-contract.md`): H2 section headings, fenced code blocks for schemas/commands, `<!-- Example: … -->` or fenced worked examples with real values.
    Done: file exists with all 7 H2 sections, a concrete schema example, and worked examples in §4 and §5.
    Verify: see [Verify].
- [x] **[Verify]** Structural oracle (this IS the test):
  - `test -f plugins/spec-flow/reference/deferred-commit-journal.md && echo OK` — Expected: `OK`
  - `grep -cE "^## (Purpose|Journal schema \(Tier 1\)|Lifecycle|Resume algorithm|File-scoped recovery recipe|Barrier commit recipe|Tier 2)" plugins/spec-flow/reference/deferred-commit-journal.md` — Expected: `7`
  - `grep -E "group_start_sha|red_manifest_hashes|status.*pending.*red-done.*green.*failed|git restore --source=.group_start_sha|git rm --cached|git add -- .*git commit -m" plugins/spec-flow/reference/deferred-commit-journal.md` — Expected: matches for schema fields, the restore recipe, and the add-then-commit recipe
  - `grep -E "journal_tier|commit-tree|git checkout <sha> -- \." plugins/spec-flow/reference/deferred-commit-journal.md` — Expected: Tier-2 future note present
  - Worked-example presence (guard 2c): `grep -cE "Example|2 green|byte-identical" plugins/spec-flow/reference/deferred-commit-journal.md` — Expected: ≥ 2 (resume + recovery examples)
- [x] **[QA]** ACs: AC-4, AC-5, AC-6, AC-9 (reference-doc half). Diff baseline: phase_1_start_sha.
- [x] **[Progress]**

### Phase 2: Config knob + `.gitignore`
**In scope:** add `deferred_commit: auto | off` to `templates/pipeline-config.yaml` (authoritative/committed) and mirror into local `.spec-flow.yaml` (dogfood, NOT committed — gitignored); add journal/artifact entries to `.gitignore`.
**NOT in scope:** orchestrator reading the knob (Phase 3); journal write (Phase 3).
**ACs Covered:** AC-7 (knob), AC-4 (gitignore half).
**Charter constraints honored in this phase:** CR-007 (config keys documented inline).

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/templates/pipeline-config.yaml`
    Anchor: the `phase_groups:` block (lines 42-46).
    CURRENT (lines 42-46):
    ```
    # phase_groups: controls Phase Group parallel execution (new in v1.4.0)
    #   auto    — dispatch sub-phases concurrently when plan uses Phase Groups; fall back to serial for flat phases (default)
    #   always  — same as auto but errors if a plan has no parallelism (catches over-flat plans)
    #   off     — treat Phase Groups as if they were flat serial phases (disable new scheduler; useful for rollback)
    phase_groups: auto
    ```
    TARGET: Add a new commented block immediately AFTER the `phase_groups: auto` line:
    ```
    # deferred_commit: controls Phase Group commit model (new in v5.0.0)
    #   auto — serial git-free section + ONE deferred work-commit at the group barrier;
    #          journal-based resume; file-scoped recovery (default; replaces pre-5.0.0 behavior)
    #   off  — pre-5.0.0 behavior: concurrent sub-phase dispatch + per-sub-phase unified commits
    #          (rollback for one release; see CHANGELOG 5.0.0 migration note)
    deferred_commit: auto
    ```
    Done: the `deferred_commit: auto` key + 5-line comment exists after `phase_groups`. NO `journal_tier` key.
    Verify: grep below.
  - T-2: MODIFY `/Volumes/joeData/ai-plugins/.spec-flow.yaml` (dogfood mirror — GITIGNORED, will NOT be committed; this edit is for running pi-015 on this repo, not a deliverable)
    Add the same `deferred_commit: auto` key + comment after the file's `phase_groups:` block.
    Done: local config carries the key (uncommitted). Note in [Verify] that this file is gitignored.
  - T-3: MODIFY `.gitignore` (repo root, tracked)
    CURRENT (lines 1-15) end with the `.spec-flow.yaml` block. TARGET: append:
    ```
    # spec-flow Phase Group resume journal (per-piece, transient) + test/build artifacts
    .phase-group-journal.json
    __pycache__/
    *.pyc
    ```
    Done: `.gitignore` contains the three new patterns.
    Verify: grep below.
- [x] **[Verify]** Structural oracle:
  - `grep -nE "^deferred_commit: auto" plugins/spec-flow/templates/pipeline-config.yaml` — Expected: one match
  - `grep -cE "^#.*deferred_commit|^#.*serial git-free|^#.*rollback for one release" plugins/spec-flow/templates/pipeline-config.yaml` — Expected: ≥ 3 (inline doc present, CR-007)
  - `grep -c "journal_tier" plugins/spec-flow/templates/pipeline-config.yaml` — Expected: `0` (no such key)
  - `grep -E "^\.phase-group-journal\.json$|^__pycache__/$|^\*\.pyc$" .gitignore` — Expected: all three present
  - LLM-agent-step: confirm `.spec-flow.yaml` is matched by `.gitignore:15` (`git check-ignore .spec-flow.yaml` → prints `.spec-flow.yaml`), so T-2 is correctly non-committed.
- [x] **[QA]** ACs: AC-7, AC-4 (gitignore half). Diff baseline: phase_2_start_sha.
- [x] **[Progress]**

### Phase 3: execute/SKILL.md — serial git-free section + journal write (G1, G4)
**In scope:** Step G1 journal-init; Step G4 branch on `deferred_commit` (`auto`=serial git-free, `off`=current concurrent); replace the "Shared staging area safety (v2.7.0)" paragraph; journal write at each sub-phase status transition.
**NOT in scope:** barrier commit + anti-cheat (Phase 4); recovery/resume (Phase 5); metrics (Phase 6).
**ACs Covered:** AC-1 (serial git-free section — orchestrator half), AC-4 (journal write).
**Charter constraints honored in this phase:** CR-008 (journal + dispatch logic lives in the orchestrator skill, agents stay narrow).

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
    Anchor: `### Step G1: Capture group-start SHA` (line 1154). TARGET: after recording `group_start_sha`, add: "Under `deferred_commit: auto`, initialize the Phase Group journal (`reference/deferred-commit-journal.md` schema) with `group_start_sha`, `group_letter`, and an empty `sub_phases` map."
  - T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
    Anchor: `### Step G4: Dispatch sub-phase pipelines concurrently` (line 1166).
    CURRENT title + body assert concurrent dispatch ("issue all sub-phase Red agent dispatches in the same orchestrator turn … do not wait for sibling Reds").
    TARGET: Branch on `deferred_commit` (read in Step 0 / Phase Scheduler):
    - **`deferred_commit: auto` (default):** dispatch sub-phases **serially** — one sub-phase's full Red→Build cycle completes (green, working-tree only, NO `git add`/`git commit`) before the next dispatches. Retitle the step or add an explicit "Serial git-free section (deferred_commit: auto)" subsection. Red writes tests + emits its SHA-256 manifest (recorded in the journal) but does NOT stage; Build writes code, runs its oracle against the working tree (the existing whole-non-integration-suite invariant at line 499, unchanged), does NOT commit. Record each sub-phase status transition in the journal (`pending`→`red-done`→`green`/`failed`).
    - **`deferred_commit: off`:** the existing concurrent dispatch (current body) applies verbatim.
    Add an inline worked example (guard 2c): a 3-sub-phase serial trace showing one-mid-cycle-at-a-time + zero per-sub-phase commits + journal status transitions.
  - T-3: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
    Anchor: `**Shared staging area safety (v2.7.0).**` paragraph (line 1181).
    TARGET: Gate this paragraph to `deferred_commit: off` (it describes the concurrent shared-index path). Under `auto`, replace with a one-line pointer: "Under `deferred_commit: auto` the section is git-free and serial — there is no shared-index staging race; see `reference/deferred-commit-journal.md`." Anti-drift (guard 2e): no remaining prose asserts concurrent dispatch is the default.
    Done: G1 inits journal; G4 branches auto/off with a worked example; the v2.7.0 staging paragraph is gated to `off`.
    Verify: grep below.
- [x] **[Verify]** Structural oracle (each line gates a specific T-N):
  - **T-1:** `grep -nE "initialize the Phase Group journal|sub_phases map|red-done" plugins/spec-flow/skills/execute/SKILL.md` — Expected: G1 journal-init + status transitions present
  - **T-2:** `grep -nE "deferred_commit: auto|Serial git-free section|serially|git-free" plugins/spec-flow/skills/execute/SKILL.md` — Expected: serial git-free branch present in the G4 region
  - **T-2 (worked example, guard 2c):** `grep -cE "3-sub-phase|one-mid-cycle|zero per-sub-phase commit|Example" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 1 in the G4 region
  - **T-3:** `grep -nE "deferred_commit: off" plugins/spec-flow/skills/execute/SKILL.md` — Expected: the concurrent path is explicitly gated to `off`
  - **T-3 (anti-drift, guard 2e):** LLM-agent-step — read the Phase Group Loop section and confirm no prose states concurrent dispatch is the DEFAULT (it must be gated to `off`).
- [x] **[QA]** ACs: AC-1 (orchestrator half), AC-4 (write half). Diff baseline: phase_3_start_sha.
- [x] **[Progress]**

### Phase 4: execute/SKILL.md — barrier work-commit + working-tree-hash anti-cheat (G5/G8/G9/G10, Step 3 item 7)
**In scope:** barrier work-commit (add-then-commit pathspec union) at the group barrier; separate G10 plan.md progress commit retained; migrate the **Step 3 item 7** post-commit integrity + reconciliation gates (SKILL.md :507-601; note: there is NO literal "3.7b" heading at this location — locate via the "Post-commit integrity and reconciliation gates" prose and the line range) content-hash integrity + reconciliation to working-tree hashes evaluated at the barrier; journal cleared after the barrier work-commit.
**NOT in scope:** recovery/resume (Phase 5); metrics (Phase 6).
**ACs Covered:** AC-2 (barrier commit + separate progress), AC-3 (working-tree-hash anti-cheat + reconciliation).
**Charter constraints honored in this phase:** NN-P-002 (barrier is a phase-internal commit, not a merge; gates untouched), CR-004 (conventional commit messages).

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
    Anchor: end of the sub-phase barrier (after Step G9 hook sweep, before `### Step G10`).
    TARGET: Add a "Barrier work-commit (deferred_commit: auto)" step: (1) re-hash each sub-phase's Red tests in the working tree against the journal `red_manifest_hashes`; reject on drift (2-attempt/escalation as flat-phase). (2) compute the union = ⋃ sub-phases (Red manifest ∪ Build files). (3) `git add -- <union>` then `git commit -m "<work msg>" -- <union>` — NOTE the explicit `git add` is required (bare pathspec commit fails on untracked files). (4) reconcile the work-commit `--name-only` against the union; reject strays/missings. (5) remove the journal. Add a worked example (guard 2c): 3 sub-phases → one work-commit = exact union, journal excluded.
  - T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
    Anchor: Step 3 item 7 — "Post-commit integrity and reconciliation gates" (lines 507-601; no literal "3.7b" heading — locate by the prose + line range), gates (a) content-hash integrity and (b) reconciliation.
    TARGET: Add a deferred-group note: under `deferred_commit: auto`, gates (a) and (b) run ONCE at the barrier against the working tree / barrier work-commit (not per sub-phase, since sub-phases don't commit). The HEAD-hash form remains for flat phases and `off`.
  - T-3: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
    Anchor: `### Step G10: Group Progress commit` (line 1248).
    CURRENT: `git add … plan.md && git commit -m "progress: Phase Group <letter> complete"`.
    TARGET: clarify that under `auto` this plan.md progress commit is the SECOND, SEPARATE commit (after the barrier work-commit); net 2 commits/group. The pathspec stays `plan.md` only.
    Done: barrier work-commit step exists (add-then-commit, anti-cheat, reconcile, journal-clear, worked example); Step 3 item 7 notes the barrier evaluation; G10 clarified as the separate progress commit.
    Verify: grep below.
- [x] **[Verify]** Structural oracle (each line gates a specific T-N):
  - **T-1:** `grep -nE "Barrier work-commit|git add -- .*union|git commit -m .* -- .*union|re-hash .*working tree|reconcile" plugins/spec-flow/skills/execute/SKILL.md` — Expected: barrier recipe + working-tree anti-cheat + reconciliation present
  - **T-1 (add-then-commit rationale):** `grep -nE "bare .*git commit.*fails|did not match any file" plugins/spec-flow/skills/execute/SKILL.md` — Expected: present
  - **T-1 (journal clear):** `grep -nE "remove the journal|clear the journal" plugins/spec-flow/skills/execute/SKILL.md` — Expected: journal cleared post-barrier
  - **T-1 (worked example, guard 2c):** `grep -cE "exact union|journal excluded|3 sub-phases" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 1
  - **T-2:** LLM-agent-step — read the Step 3 item 7 gates (SKILL.md :507-601) and confirm a deferred-group note states gates (a)/(b) run ONCE at the barrier against the working tree under `deferred_commit: auto` (HEAD-hash form retained for flat phases / `off`).
  - **T-3:** `grep -nE "separate commit|second, separate|2 commits" plugins/spec-flow/skills/execute/SKILL.md` — Expected: G10 progress commit kept separate
- [x] **[QA]** ACs: AC-2, AC-3. Diff baseline: phase_4_start_sha.
- [x] **[Progress]**

### Phase 5: execute/SKILL.md — file-scoped recovery + journal resume (auto-triage matrix, Session Resumability)
**In scope:** rewrite auto-triage "Reset sub-phase to `sub_phase_start_sha`" rows to file-scoped `git restore`+`rm`; add journal-based mid-group resume to Session Resumability; sibling-safe + logged.
**NOT in scope:** metrics (Phase 6); version (Phase 7).
**ACs Covered:** AC-5 (journal resume, sibling-safe), AC-6 (file-scoped recovery in auto-triage).
**Charter constraints honored in this phase:** NN-C-005 (journal-absent resume → fresh start, no error), NN-C-006 (reset touches only the incomplete sub-phase's recorded scope, logged — passive surface).

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
    Anchor: `## Auto-triage decision matrix` rows (lines 1268-1269).
    CURRENT (verbatim): both Contamination and Scope-violation rows say `Reset sub-phase to \`sub_phase_start_sha\`; re-dispatch Build …`.
    TARGET: replace the recovery-action cell text with the file-scoped recipe: "file-scoped reset — `git restore --source=$group_start_sha --worktree -- <sub-phase scope>` for modified files + `rm`/`git rm --cached` for files the sub-phase created (`git restore --source` does not remove created files); re-dispatch Build." Add (near "What stays committed during failures") that `git reset` to a SHA is used ONLY for whole-group human-abort, never sub-phase recovery.
  - T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
    Anchor: `## Session Resumability` (line 1660).
    TARGET: add a "Mid-group resume (deferred_commit: auto)" bullet implementing `reference/deferred-commit-journal.md` §Resume algorithm: read the journal; trust `green` sub-phases after re-hashing their working-tree files; file-scoped-reset incomplete sub-phases (FR-6 recipe) and re-run; absent-from-journal = not started; no journal → fresh start (NN-C-005). State it touches only the incomplete sub-phase's recorded scope and logs the reset (NN-C-006).
    Done: auto-triage rows file-scoped; Session Resumability has the mid-group journal resume; `git reset`-for-sub-phase eliminated.
    Verify: grep below.
- [x] **[Verify]** Structural oracle:
  - `grep -nE "git restore --source=.group_start_sha --worktree -- |git rm --cached" plugins/spec-flow/skills/execute/SKILL.md` — Expected: file-scoped recipe in the auto-triage matrix
  - `grep -cE "Reset sub-phase to .sub_phase_start_sha" plugins/spec-flow/skills/execute/SKILL.md` — Expected: `0` (no commit-scoped sub-phase reset remains)
  - `grep -nE "Mid-group resume|trust .*green|re-hash|fresh start|no journal" plugins/spec-flow/skills/execute/SKILL.md` — Expected: journal resume present
  - `grep -nE "only the incomplete sub-phase|logs the reset|passive surface" plugins/spec-flow/skills/execute/SKILL.md` — Expected: NN-C-006 sibling-safety + logging present
  - **Cross-phase schema oracle (guard 2d):** the journal fields written in Phase 3 (`status`, `red_manifest_hashes`, `scope`) are consumed here. `grep -E "status|red_manifest_hashes|scope" plugins/spec-flow/skills/execute/SKILL.md` in the resume region AND `grep -E "red_manifest_hashes|status.*pending.*green" plugins/spec-flow/reference/deferred-commit-journal.md` — Expected: the same field names appear in the schema doc, the Phase-3 write, and the Phase-5 read (no schema drift).
- [x] **[QA]** ACs: AC-5, AC-6. Diff baseline: phase_5_start_sha.
- [x] **[Progress]**

### Phase 6: Metrics + agent contracts + doctrine
**In scope:** execute `## Measurement` — group wall-clock + commit-count; `agents/implementer.md` Rule 8 + `agents/tdd-red.md` git-free group branch; `reference/spec-flow-doctrine.md` commit-cadence subsection.
**NOT in scope:** version bump (Phase 7).
**ACs Covered:** AC-8 (timing instrumentation), AC-1 (agent-contract half), AC-9 (doctrine half).
**Charter constraints honored in this phase:** NN-C-008 (agent prompts self-contained — state deferred-vs-committing context).

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
    Anchor: `## Measurement` (line 1670-1672). TARGET: append to the summary field list: "**Phase Group commit model** (deferred vs legacy), **group wall-clock duration**, and **group commit count** (`2` deferred — work + progress — vs the `N+1` under `off`)."
  - T-2: MODIFY `plugins/spec-flow/agents/implementer.md`
    Anchor: Rule 8 "ONE unified commit" (lines 51-104). TARGET: add a branch — "**In a deferred Phase Group (orchestrator passes a deferred-group flag):** write production code to the working tree and run the oracle; do NOT `git add` or `git commit` — the orchestrator commits the whole group at the barrier. Report your `## Files Created/Modified` as usual. Flat phases and `deferred_commit: off`: the existing single unified commit applies." Keep self-contained (NN-C-008).
  - T-3: MODIFY `plugins/spec-flow/agents/tdd-red.md`
    Anchor: staging contract (lines 10, 36-67). TARGET: add the parallel branch — "**In a deferred Phase Group:** write tests + emit the `## Staged test manifest` (SHA-256 per path) but do NOT `git add`; the orchestrator records the manifest in the journal and commits at the barrier."
  - T-4: MODIFY `plugins/spec-flow/reference/spec-flow-doctrine.md`
    Anchor: `## Commit Cadence` (lines 63-92), specifically near the "Integrity preserved via SHA-256" paragraph (line 83). TARGET: add a "Deferred commit for Phase Groups (v5.0.0)" subsection: under `deferred_commit: auto`, a Phase Group runs git-free and lands ONE barrier work-commit (Red∪Build, add-then-commit pathspec) + the separate plan.md progress commit; anti-cheat re-hashes Red tests **in the working tree** against the journal manifest (not in HEAD); points to `reference/deferred-commit-journal.md`.
    Done: metrics field added; both agents carry the git-free group branch; doctrine subsection present.
    Verify: grep below.
- [x] **[Verify]** Structural oracle:
  - `grep -nE "group wall-clock|group commit count|2 deferred|N\+1|commit model" plugins/spec-flow/skills/execute/SKILL.md` — Expected: metrics fields present
  - `grep -nE "deferred Phase Group|do NOT .*git commit|orchestrator commits .*barrier" plugins/spec-flow/agents/implementer.md` — Expected: implementer group branch present
  - `grep -nE "deferred Phase Group|do NOT .*git add|orchestrator records the manifest" plugins/spec-flow/agents/tdd-red.md` — Expected: tdd-red group branch present
  - `grep -nE "Deferred commit for Phase Groups|barrier work-commit|in the working tree against the journal" plugins/spec-flow/reference/spec-flow-doctrine.md` — Expected: doctrine subsection present
- [x] **[QA]** ACs: AC-8, AC-1 (agent half), AC-9 (doctrine half). Diff baseline: phase_6_start_sha.
- [x] **[Progress]**

### Phase 7: Version bump 5.0.0
**In scope:** `plugin.json` + `marketplace.json` entry 4.12.0 → 5.0.0; CHANGELOG `## [5.0.0]` entry with migration note (`deferred_commit: off` rollback).
**NOT in scope:** any behavior change (all in Phases 1–6).
**ACs Covered:** AC-9 (version sync + CHANGELOG half).
**Charter constraints honored in this phase:** NN-C-003 (backward-compat: `off` rollback documented), NN-C-007 (Keep a Changelog), NN-C-009 (version bump across all version-bearing files).

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json` — `"version": "4.12.0"` → `"version": "5.0.0"`.
  - T-2: MODIFY `.claude-plugin/marketplace.json` — the spec-flow entry `"version": "4.12.0"` → `"5.0.0"`.
  - T-3: MODIFY `plugins/spec-flow/CHANGELOG.md` — under `## [Unreleased]`, add `## [5.0.0] — <today>` with Keep-a-Changelog sections. Must include a **Changed** entry (deferred-commit default for Phase Groups: serial git-free + barrier commit; working-tree-hash anti-cheat) and a **Migration** note naming `deferred_commit: off` as the one-release rollback to the pre-5.0.0 concurrent + per-sub-phase-commit behavior.
    Done: both version files read 5.0.0; CHANGELOG 5.0.0 entry with the migration note.
    Verify: grep below.
- [x] **[Verify]** Structural oracle (cross-file version sync, guard 2d / NN-C-001):
  - `grep '"version"' plugins/spec-flow/.claude-plugin/plugin.json` — Expected: `5.0.0`
  - `grep -A6 'spec-flow' .claude-plugin/marketplace.json | grep version` — Expected: `5.0.0`
  - LLM-agent-step: confirm plugin.json version == marketplace.json spec-flow entry version (both `5.0.0`) — the NN-C-001 sync invariant.
  - `grep -nE "^## \[5\.0\.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: one match
  - `grep -nE "deferred_commit: off|rollback|migration" plugins/spec-flow/CHANGELOG.md` — Expected: migration note names the rollback knob
- [x] **[QA]** ACs: AC-9 (version half). Diff baseline: phase_7_start_sha.
- [x] **[Progress]**

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | serial git-free section (no per-sub-phase add/commit) | COVERED | Phase 3 (orchestrator), Phase 6 (agents) |
| AC-2 | barrier pathspec work-commit + separate progress commit | COVERED | Phase 4 |
| AC-3 | working-tree-hash anti-cheat + reconciliation at barrier | COVERED | Phase 4 |
| AC-4 | Tier-1 journal write + clear + ignore | COVERED | Phase 1 (schema), Phase 2 (gitignore), Phase 3 (write), Phase 4 (clear) |
| AC-5 | journal resume, sibling-safe | COVERED | Phase 1 (algorithm), Phase 5 (implement) |
| AC-6 | file-scoped recovery in auto-triage | COVERED | Phase 1 (recipe), Phase 5 (implement) |
| AC-7 | `deferred_commit` config knob (no `journal_tier`) | COVERED | Phase 2 |
| AC-8 | timing instrumentation (wall-clock + commit count) | COVERED | Phase 6 |
| AC-9 | doctrine + reference doc + 5.0.0 version sync + CHANGELOG | COVERED | Phase 1 (reference), Phase 6 (doctrine), Phase 7 (version) |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `grep -E "Serial git-free section\|serially\|deferred_commit: auto" plugins/spec-flow/skills/execute/SKILL.md` + `grep -E "deferred Phase Group" plugins/spec-flow/agents/implementer.md plugins/spec-flow/agents/tdd-red.md` | matches in execute G4 region + both agents |
| AC-2 | shell | `grep -E "git add -- .*union.*git commit -m .* -- .*union\|Barrier work-commit" plugins/spec-flow/skills/execute/SKILL.md` | add-then-commit pathspec barrier present; G10 progress commit separate |
| AC-3 | shell | `grep -E "re-hash .*working tree\|reconcile" plugins/spec-flow/skills/execute/SKILL.md` | working-tree anti-cheat + reconciliation present |
| AC-4 | file-check | `test -f plugins/spec-flow/reference/deferred-commit-journal.md` + `grep -E "\.phase-group-journal\.json" .gitignore` + `grep "initialize the Phase Group journal" plugins/spec-flow/skills/execute/SKILL.md` | schema doc exists; gitignore entry; journal-init in execute |
| AC-5 | shell | `grep -E "Mid-group resume\|trust .*green\|no journal" plugins/spec-flow/skills/execute/SKILL.md` | journal resume present, fresh-start-on-absent |
| AC-6 | shell | `grep -E "git restore --source=.group_start_sha" plugins/spec-flow/skills/execute/SKILL.md` + `grep -c "Reset sub-phase to .sub_phase_start_sha" …` | file-scoped recipe present; 0 commit-scoped sub-phase resets |
| AC-7 | shell | `grep "^deferred_commit: auto" plugins/spec-flow/templates/pipeline-config.yaml` + `grep -c journal_tier …` | knob present + documented; 0 `journal_tier` |
| AC-8 | shell | `grep -E "group wall-clock\|group commit count\|2 deferred" plugins/spec-flow/skills/execute/SKILL.md` | metrics fields present |
| AC-9 | shell | `grep '"version"' plugins/spec-flow/.claude-plugin/plugin.json` == marketplace entry == `5.0.0`; `grep "## \[5.0.0\]" plugins/spec-flow/CHANGELOG.md`; `grep "deferred_commit: off" plugins/spec-flow/CHANGELOG.md` | versions synced at 5.0.0; CHANGELOG entry + migration note |

## Contracts

No TDD-track phases in this plan (all Implement track, `tdd: false`) — contracts section present for
forward compatibility. tdd-red agents will not be dispatched; no contract injection occurs.

## Parallel Execution Notes

All phases run **serial** (flat phases). **Why serial:** this piece fixes the parallel-Phase-Group
commit-stage race; authoring its own disjoint-file edits (reference doc, config, doctrine, version)
as a parallel Phase Group would run them through the **current** (concurrent, unsafe) machinery — the
exact race under repair. Phases 3–6 are additionally serial because they edit `execute/SKILL.md`
sequentially with content dependencies (journal schema written in Phase 3 is consumed by Phase 5;
barrier in Phase 4 precedes recovery in Phase 5). Once pi-015 ships, pi-016 re-enables safe
concurrency. No `[P]` markers, no Phase Groups in this plan — by deliberate design (ADR-5).
