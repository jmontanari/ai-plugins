---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-01
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: pi-020-dc-harden — execute-robustness hardening

**PRD Sections:** G-2, FR-004, NFR-003, NN-P-002
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** pi-015-defer-commit (merged)

## Goal

Harden the deferred-commit Phase Group model that pi-015 shipped, on its own execute/SKILL.md +
`reference/deferred-commit-journal.md` surface, with three sequenced changes that one codebase
exploration and one review board cover together:

1. **Close the anti-cheat trust hole (CWE-345).** Under `deferred_commit: auto`, the Red-test
   integrity manifest is currently *self-asserted by the policed actor*: the Red agent computes
   its own `sha256sum` baseline and the orchestrator trusts it. Move anchor production to the
   orchestrator using an immutable `git hash-object -w` blob written to the object store at
   `red-done`, verified at the barrier — a digest the Build agent cannot forge by editing the
   journal or the file.
2. **Re-enable Phase Group concurrency safely.** pi-015 carved concurrency out and forced serial
   dispatch as a safety measure. Restore concurrent sub-phase dispatch on the git-free foundation
   *without* reintroducing the shared-index race (Race-1, already removed) and *without* the
   Race-2 spurious-oracle-failure (a per-phase "0 failed across the suite" oracle seeing a
   sibling's still-red tests). Add lightweight runtime isolation (INV-9) so file-disjoint
   sub-phases are also runtime-disjoint.
3. **Stop hardcoding `main` as the diff base.** execute and the verify agent compute
   `git diff main..HEAD` in eight places; on a repo whose default branch is `master` (this one)
   those resolve to nothing. Resolve the default branch once and thread it through.

Sequencing is **item 1 → item 2** (the anti-cheat anchor must land before concurrency widens the
tamper window, per the pi-015 reflection); item 3 is independent.

**PRD traceability.** This hardening directly serves **G-2** (ship spec-flow as a flagship plugin
that turns a PRD into merged, reviewed code through a *disciplined* pipeline): item 1 closes an
integrity hole in that pipeline, item 2 restores safe parallelism, item 3 removes a default-branch
foot-gun that silently breaks the Final Review diff on `master`-default repos. It serves **FR-004**
by hardening the execute stage of the charter→…→execute pipeline; **NFR-003** via backward-compatible
journal versioning + the `deferred_commit: off` escape hatch + a minor bump; and **NN-P-002** by
strengthening — never bypassing — the two human sign-off gates.

## In Scope

- **Anti-cheat hash-object anchoring (Red test files only).** Orchestrator-produced `git hash-object -w`
  blob anchor at `red-done`, stored in the journal `red_manifest_hashes`, verified at the G9b
  barrier and on resume; replaces the agent's self-asserted `sha256sum` baseline.
- **Journal format versioning + graceful fallback** for in-flight journals written by ≤5.1.0.
- **Concurrent Phase Group dispatch** restored under `deferred_commit: auto` + `phase_groups: auto`/`always`.
- **Race-2 scoped per-sub-phase oracle** (scoped to each sub-phase's own Red test IDs) + a single
  whole-(non-integration-)suite-green re-assertion at the barrier.
- **INV-9 lightweight runtime isolation:** unique `TMPDIR` (and where applicable port / DB-name)
  injection + a parallel-safety contract + a serial-replay-on-failure backstop ("slower-never-wrong").
- **Flag-injection invariant preserved** across every (re-)dispatch site (G4 / G6 recovery / G9b
  reject / resume).
- **Base-ref parameterization:** a single default-branch resolution (detect via
  `git symbolic-ref refs/remotes/origin/HEAD` → `git remote show origin` → new `.spec-flow.yaml`
  `default_branch:` key → loud error), threaded through every `git diff main..HEAD` site in
  `execute/SKILL.md` (×6) and `agents/verify.md` + `agents/verify.agent.md` (×2 each).
- **Version bump 5.1.0 → 5.2.0** (plugin.json + marketplace.json synced) + CHANGELOG entry.

## Out of Scope / Non-Goals

- **`gh pr create --base main` in the `merge_strategy: pr` path.** The same default-branch
  resolution helper this piece introduces would serve it, but applying it to the `pr` strategy is
  explicitly deferred (operator decision). The backlog item stays open. *(See Explicitly Deferred.)*
- **Anchoring production files.** Only Red test files get the blob anchor; production-file drift
  across a resume stays "trusted by association," unchanged from pi-015 (Tier-1 limitation).
- **Heavyweight per-resource declaration for INV-9.** No exhaustive resource-manifest schema;
  isolation is injected defaults + a parallel-safety contract + serial-replay backstop only.
- **Changing the merge model, the barrier-commit mechanics, file-scoped recovery, or the journal's
  resume algorithm** beyond the `red_manifest_hashes` field-format change and the version marker.
- **User-facing doc edits beyond what the version bump requires** (e.g. the `review-board.md`
  userguide `main..HEAD` *example* is illustrative, not executable, and is left as-is).

## Requirements

### Functional Requirements

**Item 1 — anti-cheat anchor**

- **FR-1:** In the `deferred_commit: auto` Phase Group flow, when a sub-phase reaches `red-done`,
  the **orchestrator** (not the Red or Build agent) computes an immutable content anchor for each
  Red test file via `git hash-object -w <path>` (which writes the blob into the git object store
  and returns its blob SHA) and records `{ <path>: <blob_sha> }` in that sub-phase's journal
  `red_manifest_hashes`. The agent's self-reported `## Staged test manifest` is no longer the
  trusted integrity baseline — it may be used as a cross-check, but the orchestrator's
  `git hash-object` output is authoritative.
- **FR-2:** At the G9b barrier — and on resume of any `red-done`/`green` sub-phase — the
  orchestrator re-computes `git hash-object <working-tree-path>` for each Red test file and
  verifies it equals the journal-stored blob SHA. Any mismatch routes to the existing barrier
  integrity-failure / file-scoped recovery path. (Build cannot forge: it cannot write the
  orchestrator-owned journal, and cannot produce a tampered test file that hashes to the original
  blob SHA.)
- **FR-3:** Anchoring covers **Red test files only**. Production files in each sub-phase's scope
  remain trusted-by-association (NOT re-hashed), unchanged from pi-015. The `red_manifest_hashes`
  value format changes from a bare `sha256sum` hex digest to a `git hash-object` blob SHA. The SF3
  ordering guard (re-anchor every Red test file the trusted G9 sweep autofix modified) is preserved
  using the new anchor.

**Item 1 — migration**

- **FR-4:** The journal records a format marker distinguishing blob-anchored `red_manifest_hashes`
  (this version onward) from sha256-anchored entries (≤5.1.0). On resume, a journal lacking the
  blob-anchor marker is honored as-is: its sha256 entries are verified with `sha256sum` for that
  in-flight piece. No forced migration, no refusal, no re-anchoring of an old journal (NFR-003).
  New journals created at/after this version use blob anchors exclusively.

**Item 2 — concurrency + Race-2 + INV-9**

- **FR-5:** Under `deferred_commit: auto` with `phase_groups: auto` or `always`, the orchestrator
  dispatches a Phase Group's sub-phases **concurrently** on the git-free foundation (restoring the
  pre-5.0.0 parallelism that pi-015 disabled). `deferred_commit: off` (legacy per-sub-phase commits)
  and the serial path remain reachable as the rollback/escape hatch.
- **FR-6:** Each concurrently-dispatched sub-phase's Build oracle is **scoped to that sub-phase's
  own Red test IDs** (the set captured in `phase_N_oracle_block`), so a sibling sub-phase's
  still-red tests on the shared working tree do not spuriously fail it (Race-2). The
  whole-(non-integration-)suite-green guarantee is re-asserted **once at the barrier (G9b)**, after
  every sub-phase is individually green.
- **FR-7:** Concurrently-dispatched sub-phases receive injected runtime isolation: a unique
  `TMPDIR` per sub-phase (and, where the work declares them, isolated port / DB-name values) plus a
  stated parallel-safety contract. If a concurrent group fails in a manner attributable to runtime
  collision, the orchestrator performs a **serial replay** of that group before declaring a real
  failure — the worst case degrades to *slower*, never to *wrong* or *silently-green*.
- **FR-8:** The deferred-commit flag and the concurrency mode are injected at **every** dispatch and
  re-dispatch site — G4 initial dispatch, G6 recovery re-dispatch, G9b reject re-dispatch, and
  mid-group resume — so a flagless re-dispatch can never silently revert to serial or to
  per-sub-phase commits (the pi-015 flag-injection invariant, extended to the concurrency mode).

**Item 3 — base-ref**

- **FR-9:** A single default-branch resolution computes the diff base in priority order:
  (1) `git symbolic-ref --short refs/remotes/origin/HEAD` (strip the `origin/` prefix);
  (2) `git remote show origin` → `HEAD branch`;
  (3) the `.spec-flow.yaml` `default_branch:` key.
  If none resolve, the orchestrator errors loudly with a clear message and does **not** silently
  assume `main`.
- **FR-10:** Every `git diff main..HEAD` site uses the resolved base ref: `execute/SKILL.md`
  (Final Review Step 1 full diff; Step 1a coherence-linter `--name-only` scope; `verify Mode: Piece
  Full` prompt; CHANGELOG cross-check `-- CHANGELOG.md`; CHANGELOG discrepancy prose; Step 8 amend
  re-entry) and `agents/verify.md` + `agents/verify.agent.md` (both `git diff main..HEAD`
  occurrences in each). The new `.spec-flow.yaml` `default_branch:` key is documented inline
  (CR-007), defaulting to auto-detect when unset.

**Version**

- **FR-11:** Bump `plugins/spec-flow/.claude-plugin/plugin.json` and the spec-flow entry in
  `.claude-plugin/marketplace.json` from `5.1.0` to `5.2.0` (kept in sync per NN-C-001), and add a
  `## [5.2.0]` Keep-a-Changelog entry to `plugins/spec-flow/CHANGELOG.md`.

### Non-Functional Requirements

- **NFR-1 (backward compatibility — NFR-003 / NN-C-003):** A piece interrupted under ≤5.1.0 resumes
  after this upgrade without error (FR-4 fallback); `deferred_commit: off` reproduces pre-concurrency
  behavior; the change ships as a **minor** version bump. No user-project artifact format breaks.
- **NFR-2 (performance):** Concurrent dispatch restores Phase Group parallelism — group wall-clock
  approximates the slowest single sub-phase chain rather than the sum. The INV-9 serial-replay
  backstop trades latency for correctness only on collision (slower-never-wrong); it never converts a
  real failure into a green.
- **NFR-3 (charter-tools — NN-C-002):** All new logic stays within POSIX Bash + `git`
  (`hash-object`, `symbolic-ref`, `remote show`, `diff`) + `sha256sum` + `awk`. No runtime
  dependency of any kind is introduced.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- **NN-C-001** (plugin/marketplace version sync): FR-11 bumps plugin.json and marketplace.json
  together to 5.2.0.
- **NN-C-002** (markdown + config only — no runtime deps): NFR-3 — every new mechanism uses git /
  POSIX bash / sha256sum / awk only.
- **NN-C-003** (backward compatibility within a major version): FR-4 graceful journal fallback +
  the `deferred_commit: off` escape hatch + minor bump; in-flight resume across the upgrade is
  non-breaking.
- **NN-C-006** (no destructive operations without explicit confirmation): the INV-9 serial-replay
  backstop and barrier recovery re-run work that already failed; they introduce no new destructive
  action (no new `rm`/`git restore` beyond the existing file-scoped recovery, which keeps its
  sanitization guards).
- **NN-C-007** (CHANGELOG present, Keep a Changelog): FR-11 adds the `## [5.2.0]` entry.
- **NN-C-009** (always bump version, per-semver scope across all version-bearing files): FR-11.

**Product (NN-P — from `docs/prds/shared/prd.md`):**
- **NN-P-002** (no auto-merge to main without explicit human sign-off at two gates): concurrency,
  the anti-cheat anchor, and base-ref resolution all sit *inside* the per-phase and end-of-piece
  flows; none bypasses the per-phase QA gate or the Final Review board. Item 1 *strengthens* the
  integrity guarantee feeding those gates.

### Coding Rules Honored

- **CR-004** (conventional commits with plugin scope): piece commits use `feat(spec-flow):` /
  `fix(spec-flow):`.
- **CR-005** (repo-root-relative paths in docs pointing to repo files): every repo-file reference in
  this spec uses a repo-root-relative path (e.g. `plugins/spec-flow/skills/execute/SKILL.md`,
  `.claude/skills/charter-*/SKILL.md`) — no user-home absolute paths and no `../` relative paths.
- **CR-007** (config keys documented inline via comments): the new `.spec-flow.yaml`
  `default_branch:` key ships with an inline comment block in the config template.
- **CR-008** (thin-orchestrator skills, narrow-executor agents): item 1 *moves* anchor production
  *into* the orchestrator and *out of* the Red/Build agents — the orchestrator owns integrity, the
  agents stay narrow. This reinforces CR-008 rather than merely honoring it.
- **CR-009** (semantic heading hierarchy): all SKILL.md / journal-doc edits preserve heading levels.

## Acceptance Criteria

**Item 1 — anti-cheat anchor**

AC-1: Given a sub-phase reaching `red-done` under `deferred_commit: auto`, When the orchestrator
records the integrity manifest, Then each Red test file's journal `red_manifest_hashes` entry is the
output of `git hash-object -w <path>` (the blob exists in the object store, `git cat-file -t <sha>`
== `blob`), produced by the orchestrator — not copied from the agent's self-reported manifest.
  Independent Test: VALIDATION harness — drive a sub-phase to `red-done`; assert the journal value
  equals `git hash-object <path>` and `git cat-file -e <sha>` succeeds; assert the orchestrator step,
  not the agent, performed the write.

AC-2: Given a recorded blob anchor, When the Build agent tampers with a Red test file (or the file
drifts) before the barrier, Then the barrier `git hash-object <wt-path>` ≠ the journal blob SHA and
the group routes to integrity-failure/recovery — and there is **no** journal edit the Build agent can
make that re-greens the check (the journal is orchestrator-owned).
  Independent Test: harness — mutate a Red test file post-`red-done`; assert barrier detects the
  mismatch; separately assert that rewriting the journal entry to match the tampered file is not a
  path available to the Build-agent role (orchestrator-only write).

AC-3: Given a sub-phase scope with both Red test files and production files, When anchoring runs,
Then only Red test files are blob-anchored; production files are not re-hashed (unchanged pi-015
behavior).
  Independent Test: grep-oracle + harness — assert anchoring iterates the Red manifest paths only;
  assert a production-file change does not trip the barrier integrity check.

AC-4: Given the G9 sweep autofix modifies a Red test file, When SF3 ordering runs, Then the
orchestrator re-anchors that file with `git hash-object -w` before the barrier verify (the
re-capture guard survives the format change).
  Independent Test: grep-oracle on execute/SKILL.md SF3 block — the re-capture step uses the blob
  anchor; harness asserts a swept file passes the barrier.

**Item 1 — migration**

AC-5: Given a journal written by ≤5.1.0 (sha256 `red_manifest_hashes`, no blob marker), When a piece
is resumed after this upgrade, Then the orchestrator detects the absent marker and verifies those
entries with `sha256sum` (honored as-is), resumes without error, and does not re-anchor or refuse.
  Independent Test: harness — author a v5.1.0-format journal fixture; resume; assert no error, sha256
  verification path taken, greens trusted.

**Item 2 — concurrency + Race-2 + INV-9**

AC-6: Given `deferred_commit: auto` + `phase_groups: auto` and a Phase Group with ≥2 parallelizable
sub-phases, When the group dispatches, Then sub-phases run concurrently (more than one mid-cycle at
once) on the git-free foundation, and the barrier commit is the exact uncorrupted union of all
sub-phase scopes (INV-1/INV-5).
  Independent Test: pi-015 VALIDATION harness re-run in the concurrent end-state — assert overlap of
  sub-phase execution windows; assert the barrier commit file set equals the union, journal excluded.

AC-7: Given two concurrent sub-phases where sibling B's Red tests are still failing on the shared
working tree, When sub-phase A's Build oracle runs scoped to A's own Red test IDs, Then A's oracle is
green (not polluted by B), and the whole-non-integration-suite-green check is asserted only at the
barrier (INV-2 green / INV-3 demonstrates the unscoped oracle would be polluted in the same state).
  Independent Test: VALIDATION harness INV-2 + INV-3 — scoped oracle green while sibling red; whole-
  suite oracle polluted in the identical state.

AC-8: Given two file-disjoint concurrent sub-phases that share a runtime resource (e.g. the same
`/tmp` path), When they run concurrently, Then injected isolation (unique `TMPDIR` etc.) prevents the
collision; and if a collision-attributable failure still occurs, the orchestrator serial-replays the
group and only a failure that persists under serial replay is reported as a real failure (no silent
false-green — INV-9).
  Independent Test: VALIDATION harness INV-9 — reproduce the shared-`/tmp` collision; assert isolation
  injection prevents it; assert a forced collision triggers serial replay, and a genuine failure under
  replay surfaces loudly.

AC-9: Given any re-dispatch site (G6 recovery, G9b reject, mid-group resume), When the orchestrator
re-dispatches a sub-phase, Then the deferred-commit flag and concurrency mode are present in the
re-dispatch (no flagless re-dispatch reverts to serial/per-sub-phase commits).
  Independent Test: grep-oracle on execute/SKILL.md — every (re-)dispatch site names the flag +
  concurrency mode; absence at any site fails.

**Item 3 — base-ref**

AC-10: Given a repo whose default branch is `master` (origin/HEAD → master), When the orchestrator
resolves the diff base, Then it resolves to `master` via `git symbolic-ref refs/remotes/origin/HEAD`
and every `git diff <base>..HEAD` site uses it (no occurrence of literal `main..HEAD` remains in the
execute/verify runtime paths).
  Independent Test: grep-oracle — zero `main..HEAD` literals remain in execute/SKILL.md +
  verify.md + verify.agent.md; a shell check in this repo confirms resolution yields `master`.

AC-11: Given no `origin/HEAD`, no `origin` remote, and no `.spec-flow.yaml default_branch:` key,
When base-ref resolution runs, Then it errors loudly with a clear message and does not assume `main`.
  Independent Test: shell harness — unset all three sources; assert non-zero/clear-error, no silent
  `main` fallback.

AC-12: Given a `.spec-flow.yaml` with `default_branch: trunk` and detection sources absent, When
resolution runs, Then it returns `trunk` (config fallback honored), and the key is documented inline
in the config template.
  Independent Test: shell harness with a config fixture; grep-oracle on the config template comment.

**Version**

AC-13: Given the piece is complete, When versions are checked, Then plugin.json and the marketplace
spec-flow entry both read `5.2.0` and CHANGELOG has a `## [5.2.0]` entry (NN-C-001 / NN-C-007).
  Independent Test: shell check parsing both JSONs equal + grep CHANGELOG heading.

## Technical Approach

**Item 1.** `git hash-object -w <path>` is content-addressed and deterministic (same bytes →
same SHA), and `-w` persists the blob in `.git/objects`, making the anchor an artifact the
orchestrator controls and the agent cannot retro-fit. The orchestrator already performs a
"defensive re-hash at capture time" (execute Step 2.6 / G4) — that step changes from
`sha256sum` to `git hash-object -w` and writes the result to the journal itself, so the agent's
`## Staged test manifest` becomes advisory. Barrier verify (G9b) and resume re-hash become
`git hash-object <wt-path>` compared to the stored blob SHA. The journal's per-sub-phase
`red_manifest_hashes` schema doc is updated; a top-level format marker (e.g. `anchor: blob`
vs absent/`sha256`) drives the FR-4 fallback. tdd-red.md Rule 9 and implementer.md are updated to
stop presenting the self-asserted hash as authoritative.

**Item 2.** Reuse the existing primitives the surface map identified: path/ID-scoped re-run
(`pytest <ids>` style) already exists for Red invariant (b); the per-phase Red ID set already lives
in `phase_N_oracle_block`. The serial carve-out language at Step G4 ("Dispatch the group's
sub-phases serially…") becomes concurrent dispatch gated on `phase_groups`. The barrier gains the
whole-non-integration-suite re-run (composing with pi-014's M2/M4 integration/non-integration split).
INV-9 isolation injects `TMPDIR` (and optional port/DB) per sub-phase via the dispatch prompt + a
parallel-safety contract; the serial-replay backstop reruns a failed concurrent group serially before
declaring failure. All of this is validated against the pi-015 VALIDATION harness, which already
drives real OS processes + a real shared git worktree in the concurrent end-state.

**Item 3.** Converge on the existing `review-board/SKILL.md` `git merge-base` idiom. A small
resolution recipe (symbolic-ref → remote show → config key → error) computes `$default_branch`
once near the top of Final Review; every `git diff main..HEAD` site interpolates it. The new
`.spec-flow.yaml default_branch:` key is optional (auto-detect when unset).

## Testing Strategy

- **Behavioral (the bar):** extend / re-run the pi-015 `specs/pi-015-defer-commit/VALIDATION.md`
  harness — real `git`, real subprocesses, real shared worktree — in the concurrent end-state.
  New/[re-]exercised invariants: item-1 anchor authenticity + forge-resistance (AC-1/AC-2),
  migration fallback (AC-5), INV-1/2/3/5/9 in the concurrent state (AC-6/7/8), base-ref resolution
  (AC-10/11/12). This harness is integration-level by construction (it is not a unit mock).
- **Structural (prose oracles, pi-014 convention):** grep-oracles over execute/SKILL.md, the journal
  doc, tdd-red.md, implementer.md, and the config template assert: blob-anchor language at G4/G9b/SF3,
  concurrency + scoped-oracle + barrier-suite language at G4/G9b, flag+mode at every (re-)dispatch
  site (AC-9), zero `main..HEAD` literals remain (AC-10), `default_branch:` documented (AC-12).
- **Edge cases:** old-format journal resume (AC-5); base-ref with all sources absent (AC-11);
  swept-file re-anchor (AC-4); collision forced under isolation (AC-8); production-file change does
  not trip the test-only anchor (AC-3).

## Integration Coverage

None in scope (registry sense). The plugin ships no runner-discoverable test suite (charter-tools:
bash hooks only — NN-C-002), so there are no `[integration]` tests tracked in an Integration-Test
Registry. The behavioral claims that span real components (anchor forge-resistance over the git object
store; concurrency + Race-2 + INV-9 over real subprocesses on a shared worktree; base-ref resolution
over git ref plumbing; migration) are validated by a one-off `VALIDATION.md` harness (real git + real
OS processes) — a **validation artifact** recorded under Testing Strategy, mirroring the pi-015
precedent (`specs/pi-015-defer-commit/VALIDATION.md`). It is run and its results recorded; it is not a
registry-tracked integration test and is not discovered by a project test runner.

## Open Questions

- OQ-1: Exact journal format-marker spelling (`anchor: blob` top-level vs a per-entry tag).
  (Default: a single top-level `anchor: blob` marker on journals created at/after 5.2.0; absence ⇒
  treat as sha256 ≤5.1.0 — resolved at plan time, no behavioral ambiguity.)
- OQ-2: Whether INV-9 port/DB-name injection is always-on or only when the piece declares such
  resources. (Default: `TMPDIR` always injected; port/DB injection only when the plan/phase declares
  them — the parallel-safety contract states the assumption; serial-replay backstop covers the rest.)

## Explicitly Out of Scope / Deferred

- **`gh pr create --base main` default-branch fix (backlog item, priority high).** The
  default-branch resolver introduced by item 3 is the mechanism this backlog item needs, but applying
  it to the `merge_strategy: pr` path is deferred per operator decision (this session). Owner: a future
  touch of the execute `pr`-strategy block (candidate: fold into pi-022-vsync-ci or its own small
  amendment). The backlog entry remains in `docs/prds/shared/backlog.md`.
