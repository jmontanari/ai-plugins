---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-01
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: pi-015-defer-commit

**PRD Sections:** G-2, FR-004, NFR-003, NN-P-002
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** pi-014-integ-tests (merged)

## Goal

Change the **default** Phase Group execution model from today's **concurrent dispatch + per-sub-phase commits** (the unsafe path that forces operators to manually fall back to serial) to a **serial, git-free section with a single deferred commit at the group barrier**, made crash-resumable by a durable **Tier-1 journal** and made sibling-safe by **file-scoped recovery**. The new model is on by default via `deferred_commit: auto`; `deferred_commit: off` preserves the exact pre-5.0.0 concurrent + per-sub-phase-commit behavior for one release.

This piece delivers the commit-reduction + clean-recovery win and establishes the architectural seam for a follow-up piece (`pi-016`) to **re-enable concurrent dispatch — safely** — on top of the now-git-free section. Under the serial default shipped here, only one sub-phase is ever mid-cycle at a time, so the documented "Race 2" (a whole-suite oracle seeing a sibling's red tests) **cannot occur** and the per-sub-phase oracle is unchanged. Re-enabling concurrency and adding Race-2's scoped-oracle handling are explicitly **out of scope** and deferred to `pi-016`.

### Background — the current model and its two races (context, not scope)

Today `plugins/spec-flow/skills/execute/SKILL.md` Step G4 ("Dispatch sub-phase pipelines concurrently", line 1166) dispatches a Phase Group's sub-phases **concurrently**, each running its own Red→Build→commit cycle against a **shared git index and working tree**. The 2026-06-05 research session that motivated this piece identified two distinct hazards of that shared-state concurrency:

- **Race 1 (commit):** a bare `git commit` commits the *whole* shared index, sweeping a sibling's staged files; `git add` itself also collides on `.git/index.lock` (both empirically confirmed). Real production hit: `pi-009-hardening` lost A.4's commit attribution to the A.2 staging race. The current mitigation (Step 3.7b reconciliation, "Shared staging area safety", SKILL.md line 1181) detects contamination *after* the fact and thrashes at fan-out — which is why operators manually serialize Phase Groups instead of trusting concurrent dispatch.
- **Race 2 (oracle):** the per-phase oracle invariant (a) — since pi-014's M2 split, "`0 failed` across the **non-integration suite**" (SKILL.md line 499) — sees a concurrent sibling's red tests on the shared working tree and fails spuriously. Occurs **only** under concurrent dispatch.

This piece eliminates Race 1 *and* the `index.lock` contention by removing git from the sub-phase section entirely and serializing dispatch; Race 2 is moot under serial dispatch and, together with the safe re-enablement of concurrency, is carved out to `pi-016` (which composes with pi-014's M2/M4 non-integration-suite split to scope the per-sub-phase oracle).

## In Scope

- **Default dispatch change** — under `deferred_commit: auto` (the new default), a detected Phase Group dispatches its sub-phases **serially** (replacing the current concurrent G4 dispatch).
- **Git-free Phase Group section** — within a Phase Group, sub-phase Red and Build steps write to the working tree and run their oracle; they perform **no** `git add` / `git commit`.
- **Single barrier work-commit** — at the group barrier (after all sub-phases are green and the existing group QA / hook sweep pass), the orchestrator creates exactly one commit containing the explicit-pathspec union of all sub-phases' files. (The separate plan.md progress commit is unaffected — see FR-2.)
- **Working-tree-hash anti-cheat + reconciliation** — the per-sub-phase content-hash integrity gate and the unified-commit reconciliation gate migrate from "re-hash AS COMMITTED in HEAD" to "re-hash in the working tree against the journal manifest," evaluated at sub-phase completion and again at the barrier.
- **Tier-1 journal** — a durable file recording `group_start_sha` + per-sub-phase status, written incrementally and removed after the barrier commit, kept out of commits by both an explicit `.gitignore` entry and the pathspec-only commit discipline.
- **Journal-based resume** — on execute resume mid-group, trust green sub-phases (re-verify working-tree hashes) and re-run only incomplete sub-phases.
- **File-scoped recovery** — the Phase Group auto-triage matrix's reset actions become file-scoped `git restore` (+ `rm` for created files), never `git reset` to a SHA.
- **`deferred_commit: auto | off` config knob** (default `auto`; `off` restores the current concurrent + per-sub-phase-commit behavior).
- **Barrier timing instrumentation** — wall-clock + commit-count per group in the session metrics summary (incorporates the PI-008 "Phase Group parallelism — empirical timing measurement" backlog item).
- **Agent contract updates** — `agents/implementer.md` Rule 8 and `agents/tdd-red.md` staging contract updated for the git-free section.
- **Doctrine + reference + version** — `reference/spec-flow-doctrine.md` commit-cadence section; new `reference/deferred-commit-journal.md`; major version bump (5.0.0) across all version-bearing files with a migration note.

## Out of Scope / Non-Goals

- **Re-enabling concurrent sub-phase dispatch** — under `auto`, dispatch is serial. Safe concurrent dispatch (on the now-git-free section) is `pi-016`. (`deferred_commit: off` still gives the current concurrent path for operators who want it this release.)
- **Race-2 scoped per-sub-phase oracle + barrier full-suite re-run** — unnecessary under serial dispatch; deferred to `pi-016` (where concurrency makes it mandatory, composing with pi-014's M2/M4 split).
- **Tier-2 dangling-commit checkpoints** (private `GIT_INDEX_FILE` → `commit-tree`) and the **`journal_tier` knob** — documented as a future addition in `reference/deferred-commit-journal.md`; **not** introduced this piece (no inert `journal_tier` key is added). The manifest's mention of a `journal_tier` knob is resolved here to "deferred."
- **Flat (non-group) phase commit behavior** — unchanged; flat phases keep their per-phase unified commit. Deferral applies only to Phase Groups.
- **Per-piece deferral** (commit once at end of piece) — out of scope; the deferral unit is the Phase Group.
- **Changes to the Final Review / merge gates** — untouched (NN-P-002).

## Requirements

### Functional Requirements

- **FR-1 (serial git-free section):** Under `deferred_commit: auto`, a detected Phase Group dispatches sub-phases **serially** (one mid-cycle at a time, replacing the concurrent G4 dispatch), and each sub-phase's Red and Build operate on the working tree only — no `git add`, no `git commit` during sub-phase execution. Red emits its `## Staged test manifest` (path → SHA-256) as today, but does **not** stage; Build reports its `## Files Created/Modified` and runs its oracle (the existing whole-non-integration-suite invariant, unchanged) against the working tree, but does **not** commit.
- **FR-2 (barrier work-commit + separate progress commit):** At the group barrier, after all sub-phases are green and the existing Group Deep QA (G8) + hook sweep (G9) pass, the orchestrator creates exactly **one work-commit** by **staging the union then committing it by explicit pathspec** — `git add -- <union paths>` followed by `git commit -m <msg> -- <union paths>` (validated: a bare `git commit -- <paths>` fails with `did not match any file(s) known to git` on the untracked files the git-free section produces, so the explicit `git add` step is mandatory) — whose file list equals the union over all sub-phases of (Red manifest paths ∪ Build reported paths). The existing G10 plan.md **progress commit** (the checkbox update) remains a *separate* commit, also pathspec-scoped to `plan.md`. Net per group: **2 commits** (barrier work + progress) versus today's N+1 (N per-sub-phase + 1 progress). Bare `git commit`, `git commit -a`, and `git add -A`/`git add .` are forbidden.
- **FR-3 (anti-cheat + reconciliation migration):** The content-hash integrity check (Red-test immutability) and the unified-commit reconciliation check are evaluated against the **working tree** using the journal-recorded Red manifest: per sub-phase at its completion, and once more for the assembled set immediately before the barrier work-commit. Any drift in a Red test, any stray file, or any missing file rejects the group barrier (with the same 2-attempt / escalation discipline as the flat-phase gate).
- **FR-4 (Tier-1 journal write):** When a Phase Group begins, the orchestrator records `group_start_sha`; as each sub-phase progresses it records, in a durable journal, the sub-phase `id`, declared `scope` (literal file paths), `status` (`pending` | `red-done` | `green` | `failed`), and Red-manifest hashes. The journal is removed after the barrier work-commit lands. It is kept out of git by **both** an explicit `.gitignore` entry for the journal filename **and** the FR-2 pathspec-only commit discipline (the journal path is never in any commit's pathspec). The same `.gitignore` requirement covers **test/build artifacts the git-free section generates while running oracles** (e.g. `__pycache__/`, `*.pyc`, coverage/temp outputs) — validated: a concurrent git-free section accumulates such artifacts in the shared working tree, and the pathspec-only barrier commit already excludes them, but the ignore entry prevents them from ever being swept by any non-pathspec git operation.
- **FR-5 (journal-based resume):** On execute resume mid-group (journal present), the orchestrator reads `group_start_sha` and per-sub-phase status; sub-phases marked `green` are trusted after re-verifying their working-tree hashes; incomplete sub-phases (`pending`/`red-done`/`failed`) are file-scoped-reset to `group_start_sha` **using the FR-6 recipe (restore modified, `rm` created)** and re-run. Sub-phases not in the journal are treated as not started. If no journal exists, the group starts fresh (NN-C-005 — no error).
- **FR-6 (file-scoped recovery):** Every reset action in the Phase Group auto-triage matrix and in resume uses file-scoped `git restore --source=$group_start_sha -- <sub-phase scope>` for **modified** files plus `rm` (and `git rm --cached` if staged) for files **created** in the sub-phase (which `git restore --source` does not remove). No `git reset` to a SHA is used for in-group sub-phase recovery; `git reset $group_start_sha` remains valid only for a whole-group human-abort.
- **FR-7 (config knob):** `.spec-flow.yaml` and `templates/pipeline-config.yaml` gain `deferred_commit: auto | off`, default `auto`. `auto` runs the serial git-free + barrier model (FR-1/FR-2); `off` restores the pre-5.0.0 concurrent-dispatch + per-sub-phase-unified-commit behavior verbatim. The key is documented inline (CR-007). No `journal_tier` key is added (see Out of Scope).
- **FR-8 (timing instrumentation):** When a Phase Group completes under `auto`, the orchestrator records the group's wall-clock duration and commit count (`2` deferred — work + progress — vs. the `N+1` it would have produced under `off`) in the session metrics summary.
- **FR-9 (agent contracts):** `agents/implementer.md` Rule 8 and `agents/tdd-red.md` staging contract are updated to describe the git-free Phase Group section (no per-sub-phase stage/commit) while preserving their flat-phase behavior. Both remain self-contained (NN-C-008) — the prompt states whether the agent is in a deferred (group) or committing (flat) context.
- **FR-10 (doctrine, reference, version):** `reference/spec-flow-doctrine.md`'s commit-cadence section documents the deferred-commit model and the working-tree-hash anti-cheat; a new `reference/deferred-commit-journal.md` documents the journal schema, the resume algorithm, the file-scoped recovery recipe (incl. the created-vs-modified asymmetry), and the Tier-2 / `journal_tier` future addition; `CHANGELOG.md` + `.claude-plugin/plugin.json` + the `marketplace.json` entry reflect the 5.0.0 major bump with a migration note naming `deferred_commit: off` as the rollback.

### Non-Functional Requirements

- **NFR-1 (no overhead):** For a Phase Group, the deferred path performs one barrier work-commit + one pre-commit hook run (plus the unchanged progress commit), versus N work-commits + N hook runs under `off` — it must not be slower than the legacy path (it removes hook runs, not adds them).
- **NFR-2 (cheap resume):** Journal-based resume reads a single small file and is O(number of sub-phases); it performs no full git-history scan to reconstruct in-group state.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- **NN-C-003** (backward compatibility within a major version): the default behavior change is delivered as a **major** bump (5.0.0); `deferred_commit: off` preserves the exact pre-5.0.0 concurrent + per-sub-phase-commit behavior for one release, and the CHANGELOG carries a migration note.
- **NN-C-005** (silent no-op when optional inputs absent): a missing journal on resume → fresh group start, no error; timing instrumentation degrades silently if no metrics sink is present.
- **NN-C-006** (no destructive operations without confirmation): resume / auto-triage file-scoped reset touches **only** files in the incomplete sub-phase's recorded `scope`, restores them to `group_start_sha`, and logs exactly which files it restored/removed (passive surface) — it never resets the whole tree, never touches a sibling's or a committed sub-phase's files. This is recovery of a sub-phase that is about to be re-run, scoped by construction.
- **NN-C-007** (CHANGELOG in Keep a Changelog format): a 5.0.0 entry documents the change + migration.
- **NN-C-008** (self-contained agent prompts): the implementer/tdd-red prompt updates carry the deferred-vs-committing context explicitly; no conversation-history assumption.
- **NN-C-009** (always bump version, per-semver scope): a config default flip (`concurrent+per-sub-phase-commit` → `serial+deferred`) is a breaking change → **major** bump 5.0.0 across `plugin.json`, the `marketplace.json` entry, and `CHANGELOG.md`.

**Product (NN-P — from `docs/prds/shared/prd.md`):**
- **NN-P-002** (no auto-merge to main without explicit human sign-off at two gates): the barrier work-commit is a phase-internal commit on the piece branch, not a merge; the Final Review board and human sign-off gates are untouched.
- **NN-P-001** (spec-flow artifacts are human-readable): the journal is a readable JSON file co-located with the piece's existing `.orchestra-state.json`, kept out of commits per FR-4.

### Coding Rules Honored

- **CR-007** (config keys documented inline): the `deferred_commit` key is added with an inline comment block (valid values, default `auto`, `off` rollback semantics) in both `.spec-flow.yaml` and `templates/pipeline-config.yaml`.
- **CR-008** (thin-orchestrator skills, narrow-executor agents): journal read/write, barrier-commit assembly, working-tree-hash gates, serialized dispatch, and resume logic live in the execute **skill** (orchestrator); `implementer`/`tdd-red` agents only *stop* staging/committing in the group context — they gain no decision logic.
- **CR-004** (conventional-commits with plugin scope): the barrier work-commit and the separate progress commit retain conventional messages (`progress: Phase Group <letter> complete` for the progress commit); the version-bump commit uses the conventional format.
- **CR-009** (semantic heading hierarchy): the new `reference/deferred-commit-journal.md` and the edited SKILL/doctrine sections follow the heading hierarchy.

## Acceptance Criteria

**AC-1 (serial git-free section):** Given a Phase Group running under `deferred_commit: auto`, When its sub-phases execute, Then the execute Phase Group Loop prose dispatches them **serially** (replacing the concurrent G4 dispatch) and the `implementer`/`tdd-red` agent contracts instruct Red/Build to write to the working tree with **no** `git add`/`git commit` during sub-phase execution; a synthetic 3-sub-phase trace shows one-mid-cycle-at-a-time ordering and **zero** per-sub-phase commits before the barrier.
  Independent Test: grep the Phase Group Loop section for serial dispatch under `auto` (and that Step G4's concurrent dispatch is gated to `off`); grep `agents/implementer.md` Rule 8 + `agents/tdd-red.md` for the git-free contract; run the synthetic trace and assert ordering + commit count == 0 before the barrier.

**AC-2 (barrier pathspec work-commit + separate progress commit):** Given all sub-phases of a group are green at the barrier, When the orchestrator commits, Then exactly **one work-commit** lands via staging the union then committing it by pathspec (`git add -- <paths>` then `git commit -m <msg> -- <paths>`) whose file list equals the union over sub-phases of (Red manifest ∪ Build files), the plan.md progress commit remains a separate pathspec commit, and bare/`-a`/`-A` forms are documented as forbidden.
  Independent Test: synthetic group of 3 sub-phases (disjoint scopes) → assert exactly one work-commit whose `--name-only` equals the computed union, plan.md is NOT in the work-commit but in a separate progress commit; grep the SKILL for the pathspec-commit form and the forbidden-form prohibition.

**AC-3 (working-tree-hash anti-cheat + reconciliation):** Given Red recorded SHA-256 manifests in the journal, When the barrier work-commit is prepared, Then the orchestrator re-hashes each Red test file **in the working tree** against the journal manifest and rejects on drift, and reconciles the assembled file set against the union, rejecting any stray or missing file — with the existing 2-attempt/escalation discipline.
  Independent Test: synthetic trace A (a Red test modified during Build) → barrier rejected with a drift signal; synthetic trace B (a stray file present) → barrier rejected; synthetic trace C (clean) → barrier accepted.

**AC-4 (Tier-1 journal write + clear + ignore):** Given a Phase Group begins, When sub-phases progress, Then a durable journal records `group_start_sha` + per-sub-phase `{id, scope, status, red_manifest_hashes}` updated incrementally; the journal is removed after the barrier work-commit; and it is kept out of commits by **both** a new explicit `.gitignore` entry for its filename **and** the pathspec-only commit discipline (its path never appears in any commit pathspec).
  Independent Test: assert the journal schema is documented in `reference/deferred-commit-journal.md`; assert the SKILL writes it at group start / per-sub-phase transition and clears it post-barrier; assert a `.gitignore` rule for the journal filename was added; synthetic trace asserts the journal path is absent from the work-commit and progress-commit pathspecs.

**AC-5 (journal resume, sibling-safe):** Given execute resumes mid-group with a journal present (e.g. 2 sub-phases `green`, 1 `failed`), When the orchestrator loads it, Then green sub-phases are trusted after working-tree-hash re-verification, the incomplete sub-phase is file-scoped-reset to `group_start_sha` via the FR-6 recipe (restore modified + `rm` created) and re-run, green sub-phases' files are **untouched**, and the reset is logged (NN-C-006 passive surface).
  Independent Test: synthetic resume trace asserts the incomplete sub-phase's modified files are restored and its created files removed and it re-runs, while the two green sub-phases' files are byte-identical pre/post; assert the log line is emitted.

**AC-6 (file-scoped recovery in auto-triage):** Given a Phase Group auto-triage matrix row triggers a sub-phase reset (contamination / scope-violation / etc.), When recovery runs, Then it uses `git restore --source=$group_start_sha -- <scope>` (+ `rm`/`git rm --cached` for created files) and **no** `git reset` to a SHA appears in any in-group sub-phase recovery path (it may remain only for a whole-group human-abort).
  Independent Test: grep the auto-triage matrix + "What stays committed during failures" section — assert every in-group sub-phase reset is file-scoped (restore + rm) and that `git reset $group_start_sha`/`$sub_phase_start_sha` is not used for sub-phase recovery.

**AC-7 (config knob):** Given `.spec-flow.yaml`, When `deferred_commit` is read, Then `auto` (default) runs the serial git-free + barrier model and `off` restores the legacy concurrent + per-sub-phase-commit behavior, the key is present with an inline comment (valid values + default + rollback) in both `.spec-flow.yaml` and `templates/pipeline-config.yaml`, and no `journal_tier` key is introduced.
  Independent Test: assert the commented `deferred_commit` key exists in both files and `journal_tier` does not; synthetic trace under `off` produces N per-sub-phase commits via concurrent dispatch (legacy), under `auto` produces 1 barrier work-commit via serial dispatch.

**AC-8 (timing instrumentation):** Given a Phase Group completes under `auto`, When the barrier work-commit lands, Then the session metrics summary records the group's wall-clock duration and commit count (`2` deferred vs. the legacy `N+1`).
  Independent Test: assert the Measurement / session-metrics section lists the new fields; synthetic trace asserts both values are emitted for a completed group.

**AC-9 (doctrine, reference, version sync):** Given the release, Then `reference/spec-flow-doctrine.md`'s commit-cadence section documents the deferred-commit model + working-tree-hash anti-cheat, `reference/deferred-commit-journal.md` exists with the journal schema + resume algorithm + file-scoped recovery recipe (created-vs-modified) + the Tier-2 / `journal_tier` future addition, and `plugin.json` / the `marketplace.json` entry / `CHANGELOG.md` all read 5.0.0 with a migration note naming `deferred_commit: off`.
  Independent Test: grep the doctrine section + reference-doc presence; assert version equality across the three version-bearing files (the NN-C-001 sync check); assert the CHANGELOG 5.0.0 entry names the rollback knob.

## Technical Approach

**Detection & branching.** The Phase Group Loop reads `deferred_commit` (default `auto`). Under `auto`, a detected Phase Group runs the **serial git-free section** (this piece); under `off`, the loop behaves exactly as pre-5.0.0 — the current Step G4 concurrent dispatch + per-sub-phase unified commits + Step 3.7b reconciliation. Flat phases are unaffected by the knob.

**Serial git-free section.** Sub-phases dispatch one at a time (the orchestrator waits for each sub-phase's Build to go green before dispatching the next — replacing G4's "issue all sub-phase Red dispatches in the same turn"). For each: Red writes its test files to the working tree and emits its path→SHA-256 manifest (recorded in the journal) but does not `git add`; Build writes production files, runs its oracle against the working tree (the unchanged whole-non-integration-suite invariant, per pi-014 M2), and does not commit. Because exactly one sub-phase is mid-cycle at a time, the working tree at each Build oracle contains: prior sub-phases' completed green files + this sub-phase's red→green transition + nothing from later sub-phases — so the existing oracle invariants hold without scoping (Race 2 cannot arise).

**Barrier commit.** After the last sub-phase is green and the existing G8 (Group Deep QA) + G9 (hook sweep) pass, the orchestrator: (1) re-hashes each sub-phase's Red tests in the working tree against the journal manifest (anti-cheat); (2) computes the union file set; (3) stages the union (`git add -- <union>`) then commits it by explicit pathspec (`git commit -m "<work msg>" -- <union>`) — the **work-commit** (the explicit `git add` is required because the git-free section's files are untracked); (4) reconciles the commit's `--name-only` against the union; (5) creates the existing G10 plan.md **progress commit** separately (`git add plan.md && git commit -m "progress: Phase Group <letter> complete"`); (6) records timing + commit-count; (7) removes the journal. The pre-commit hook runs once for the whole group's work.

**Journal (Tier 1).** A JSON file co-located with the piece's existing `.orchestra-state.json`, e.g. `{group_start_sha, group_letter, sub_phases: {<id>: {scope[], status, red_manifest_hashes{}}}}`, written at group start and updated at each sub-phase status transition. It is kept out of commits two ways: a new `.gitignore` entry for its filename, and the pathspec-only commit discipline (its path is never in a commit pathspec). Recovery rides the surviving working tree; the journal records *where we are*, the working tree holds *the content*. (Tier-2 — dangling `commit-tree` checkpoints via a private `GIT_INDEX_FILE`, surviving a working-tree wipe, gated by a future `journal_tier` knob — is documented in the reference doc but not built.)

**Resume.** On execute start, if a journal exists for the active group: trust `green` sub-phases after re-hashing their working-tree files; for each incomplete sub-phase, apply the FR-6 file-scoped recipe — `git restore --source=$group_start_sha -- <its scope>` (modified) + `rm`/`git rm --cached` (created) — log the reset, and re-run; then continue to the barrier. Empirically validated in the research session: pathspec commit ignores sibling staged files; file-scoped restore-to-start reverts a sub-phase even with interleaved history; created files require explicit `rm` (restore-from-source leaves them).

**File-scoped recovery.** The auto-triage matrix's "Reset sub-phase to `sub_phase_start_sha`" rows are rewritten to the FR-6 recipe. `git reset` to a SHA remains valid only for the whole-group human-abort path (`git reset $group_start_sha`), never for a single sub-phase.

**pi-016 seam.** This piece ships serial dispatch as the safe default. pi-016's delta is: re-enable concurrent dispatch of the git-free sub-phases + scope each sub-phase oracle to its own test IDs + add a whole-(non-integration-)suite green check at the barrier (Race-2, composing with pi-014's M2/M4 split). The git-free section, journal, barrier commit, and file-scoped recovery are all reused unchanged — which is the reason for sequencing this piece first.

**Empirical validation (2026-06-05).** A 9-invariant concurrent harness (real OS processes running real `unittest` against a shared git worktree) confirmed the model end-to-end: git-free concurrent writes produce an exact, uncorrupted union (INV-1); a **scoped** per-sub-phase oracle stays green while a sibling's red test is on disk, whereas the whole-suite oracle is polluted (INV-2/3 — proves Race-2 is real and that scoping both necessary and sufficient); the pathspec barrier commit captures the exact union and excludes the journal (INV-5); concurrent per-sub-phase commits collide on `index.lock` (INV-6 — git-free is mandatory, not optional); file-scoped recovery leaves siblings byte-identical (INV-7); and journal resume trusts hash-verified greens while re-running only the incomplete sub-phase (INV-8). The harness also found the FR-2 add-then-commit requirement and the artifact-`.gitignore` requirement (both folded in above).

**pi-016 residual — runtime-resource isolation (lightweight).** The harness's one boundary result (INV-9): sub-phases with fully **disjoint source files** still collide under concurrency if their tests share a **mutable runtime resource** (fixed temp path, port, or test DB) — file-disjointness (the existing G2 check) is static and does not imply runtime-disjointness. pi-016 handles this the way every parallel test runner does, **not** with per-resource declaration: (1) inject per-sub-phase isolation (`TMPDIR`/tmp-dir, port offset, DB namespace) into each concurrent agent; (2) document a parallel-safety contract (shared external singletons are the test author's responsibility, as in `pytest-xdist`); (3) **serial-replay backstop** — because serial execution is proven-correct here, any concurrent-group failure triggers a serial re-run of the group, so a runtime collision degrades to *slower*, never *wrong* (collisions surface as loud failures, not silent false-greens — INV-9 collided via a thrown assertion). This is captured for pi-016; it is out of scope for this serial-first piece.

## Testing Strategy

These pipeline pieces have no runtime service under test; "tests" are **structural prose assertions** (grep presence of required contracts in SKILL/agent/doctrine/config) plus **synthetic trace scenarios** that walk the documented algorithm and assert its decisions — the same pattern used by pi-009-hardening and pi-014-integ-tests.

- **Unit-equivalent (~70%):** per-FR prose-presence checks (serial-dispatch-under-`auto` + concurrent-gated-to-`off`, git-free contract, pathspec-commit form + forbidden-form prohibition, knob + inline comment + no `journal_tier`, journal schema, `.gitignore` entry, doctrine section, reference-doc presence); single-scenario traces (anti-cheat drift rejection, stray-file rejection, knob `off` → N commits / `auto` → 1 work-commit).
- **Integration-equivalent (~30%):** one end-to-end multi-sub-phase group trace exercising serial git-free section → anti-cheat → barrier union work-commit → reconciliation → separate progress commit → journal clear, and one resume trace (2 green + 1 failed) asserting sibling files untouched.
- **Edge cases:** empty journal on resume (fresh start, no error); a sub-phase that created (not modified) files (recovery must `rm`); reconciliation stray/missing; `deferred_commit: off` legacy concurrent path; plan.md excluded from the work-commit but present in the progress commit; version-sync equality across the three version-bearing files.

## Integration Coverage

None in scope. This piece modifies orchestrator prose, agent contracts, doctrine, and config — there is no runtime cross-component wiring with a true external to double. The journal↔resume↔git and work-commit↔post-commit-gate interactions are validated by the synthetic trace scenarios in Testing Strategy, not by runtime integration tests with contract-tested externals.

## Open Questions

- **OQ-1 (journal location):** new sibling file vs. extending the existing `.orchestra-state.json`. **Default:** a separate file `.phase-group-journal.json` in the piece's spec dir (cleaner incremental-write semantics), kept out of commits by a new `.gitignore` rule for that filename + the pathspec-only commit discipline. Plan may fold it into `.orchestra-state.json` if that proves simpler — either satisfies FR-4/AC-4 (and either way the `.gitignore` entry covers the chosen filename).
- **OQ-2 (commit count per group):** confirmed at FR-2 — the deferred path produces **2** commits (one barrier work-commit via pathspec union; one separate G10 plan.md progress commit, unchanged from today). The barrier work-commit does NOT collapse the progress commit into itself. No open ambiguity remains; recorded here only to make the count explicit for the plan.
