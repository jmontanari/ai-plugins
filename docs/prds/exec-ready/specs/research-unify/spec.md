---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: research-unify

**PRD Sections:** FR-001, NFR-001, NFR-003, G-1
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** none

## Goal

Run codebase gathering **exactly once per piece** — in an isolated Opus sub-agent, before the
first spec brainstorm question — and have both the spec and plan stages consume the single
durable artifact it produces (`research.md`). Today the same exploration happens up to three
times: the spec stage's L-10 convention scan, the plan stage's `introspection.md` derivation,
and ad-hoc reads in between. This piece folds all three into one pass whose result is committed
to the piece branch and read (not re-derived) downstream. When the pass cannot run, every stage
falls back to its current behavior, so the change is purely additive (NFR-003). This is the
prerequisite half of G-1 (execution-ready plans): the plan cannot be dense if context is
re-gathered from scratch at plan time.

## In Scope

- **New agent** `plugins/spec-flow/agents/research.md` — an isolated, Opus, single-task agent that
  reads the codebase against the piece's PRD sections, writes `research.md`, and returns a
  ≤2K-token structured digest. It does not dispatch sub-agents.
- **New reference** `plugins/spec-flow/reference/research-artifact.md` — the canonical definition of
  `research.md`'s section schema, the marker contract (`[RESEARCH-CONSUMED]` / `[RESEARCH-ABSENT]`
  / `[RESEARCH-UNAVAILABLE]`), the ≤2K return contract, and the definition of a "covered file."
- **`spec` skill edits** (`skills/spec/SKILL.md` + `reference/brainstorm-procedure.md`) — reorder so
  the worktree/branch is created (after slug validation and the decomposition scope-check) before
  brainstorm; dispatch the research agent into the worktree; commit `research.md`; lead brainstorm
  with the digest's inferences. The standalone L-10 convention scan becomes the fallback path, run
  only on `[RESEARCH-UNAVAILABLE]`.
- **`plan` skill edits** (`skills/plan/SKILL.md`) — Phase 1, on the CONSUMED path, **seeds**
  `introspection.md` from `research.md`'s cluster-grouped sections (a structural copy) instead of
  running the full per-cluster sweep, then appends targeted top-ups for non-covered spec target files
  and re-reads stale covered files; emits the consumption markers. Phase 2's section-by-section reader
  keeps reading `introspection.md` unchanged on both paths. On the ABSENT path the legacy full sweep
  populates `introspection.md` exactly as today.
- **`v3-path-conventions.md` edit** — change the reserved `research/` (directory) to `research.md`
  (file) in the layout diagram and path table.
- **Plugin version bump** — minor bump across all version-bearing files + `marketplace.json` sync +
  CHANGELOG entry (NN-C-009 / NN-C-001 / NN-C-007).

## Out of Scope / Non-Goals

- **Test-data blocks, plan concreteness contract, spike agent, model policy, flywheel** — owned by the
  later pieces (`plan-concrete`, `test-data-up`, `sonnet-coord`, `spike-agent`, `flywheel-repo`,
  `flywheel-global`). This piece only unifies the gathering pass.
- **A `research: auto|off` config toggle** — explicitly cut. Research always runs; the only skip paths
  are `[RESEARCH-UNAVAILABLE]` (spec, on error) and `[RESEARCH-ABSENT]` (plan, on missing file).
- **Changing plan Phase 2's reader or the `introspection.md` section schema** — Phase 2 keeps reading
  `introspection.md` section-by-section unchanged on **both** paths; this piece changes only *how
  `introspection.md` is populated* (seeded by structural copy from `research.md` on the CONSUMED path
  vs the live full sweep on the ABSENT path). The four-block cluster-grouped schema is preserved
  verbatim so the seed is a copy, not a translation.
- **Correcting the root vs `.claude-plugin` `plugin.json` version skew** — that cleanup is assigned to
  `sonnet-coord` (NFR-004); this piece performs only the normal minor bump on the files it touches.

## Requirements

### Functional Requirements

- **FR-1 (research agent):** `plugins/spec-flow/agents/research.md` exists with frontmatter
  `name: research` and `model: opus`. Its prompt is self-contained — every input (the piece's PRD
  sections, the piece description from the manifest, the resolved charter) is injected by the
  dispatching skill; it assumes no conversation history. It performs codebase gathering only and
  does not dispatch sub-agents. It writes `research.md` and returns a ≤2K-token structured digest
  whose final line is `STATUS: OK` or `STATUS: BLOCKED`.
- **FR-2 (artifact contract):** `plugins/spec-flow/reference/research-artifact.md` is the single source
  of truth, defining: (a) `research.md`'s structure — two top-level `## Brainstorm Inference Digest`
  and `## Codebase Conventions` sections, followed by **per-cluster `## ` headings each containing the
  four bold-labelled blocks — `File Inventory`, `Dependency Map`, `Test Landscape`, `Pattern Catalog` —
  in the exact cluster-grouped layout `introspection.md` uses today** (per-cluster H2 heading; the four
  blocks beneath it; verbatim code blocks preserved), so the plan skill can seed `introspection.md`
  from it by structural copy. The research agent clusters by functional cohesion of the files it
  explores, since it has no finalized spec target list yet; (b) the marker contract for all three
  `[RESEARCH-*]` markers including exact trigger conditions; (c) the ≤2K return contract; (d) the
  definition of a **covered file** (a file appearing in any cluster's `File Inventory` block of
  `research.md`). `agents/research.md`, `skills/spec/SKILL.md`, and `skills/plan/SKILL.md` all cite
  this reference.
- **FR-3 (spec reorder + dispatch):** The `spec` skill, on a default run, performs the
  decomposition scope-check and slug validation, then creates the worktree/branch, then dispatches the
  research agent into the worktree, then commits `research.md` — all before the first brainstorm
  question. Brainstorm then leads with the digest's inferences (the existing "lead with your
  understanding" pattern, seeded by the digest). On this (OK) path the Charter Constraint
  Identification Protocol's Conventions Block reads `research.md`'s `## Codebase Conventions` section
  in place of the standalone L-10 output. `research.md` is committed before `spec.md`.
- **FR-4 (spec fallback):** The `spec` skill emits `[RESEARCH-UNAVAILABLE: <reason>]` and falls back to
  the current standalone L-10 convention scan — non-blocking — when any of: the research agent returns
  `STATUS: BLOCKED`; the dispatch errors; or `research.md` is missing or zero-length after dispatch. On
  the UNAVAILABLE path no `research.md` is committed. The standalone L-10 scan runs **only** on this
  path; on the success path L-10's role is served by `research.md`'s `## Codebase Conventions` section.
  On the UNAVAILABLE path the standalone L-10 scan runs and the Charter Constraint Identification
  Protocol's Conventions Block consumes its output exactly as today.
- **FR-5 (plan consume):** The `plan` skill Phase 1, when `research.md` exists on the piece branch,
  emits `[RESEARCH-CONSUMED: <N> files, <M> re-read]` and **seeds `introspection.md` by structural copy
  of `research.md`'s cluster-grouped sections** — it (a) does not run the full per-cluster introspection
  sweep; (b) for each spec target file that is not a covered file, performs a narrow targeted read (not
  a full sweep) and appends its four-block entry to `introspection.md`; (c) resolves `research.md`'s
  commit via `git log -1 --format=%H -- research.md` and re-reads (and updates the `introspection.md`
  entry for) any covered file changed since that commit (`git diff <commit>..HEAD -- <file>`
  non-empty). `N` = covered files; `M` = files re-read via (b)+(c). Phase 2 then reads the resulting
  `introspection.md` section-by-section with no change to its reader.
- **FR-6 (plan fallback):** The `plan` skill Phase 1, when `research.md` does not exist on the piece
  branch, emits `[RESEARCH-ABSENT: running full exploration]` and populates `introspection.md` via the
  existing per-cluster sweep unchanged; Phase 2 reads it section-by-section exactly as today.
- **FR-7 (path + version):** `v3-path-conventions.md` references `research.md` (file) in place of the
  reserved `research/` (directory). The plugin version is bumped (minor) in every version-bearing file,
  the `marketplace.json` entry is synced, and a CHANGELOG entry is added.

### Non-Functional Requirements

- **NFR-1 (isolation + bounded return):** The research agent always runs in a fresh isolated context
  (NN-C-008) and returns ≤2K tokens to the main thread; the on-disk `research.md` may be richer. (PRD
  NFR-001.)
- **NFR-2 (additive / backward-compatible):** All changes are additive within the current major
  (NN-C-003). A piece with no `research.md` (specced before this feature, or after an UNAVAILABLE run)
  produces current spec/plan behavior via the fallback paths. No existing on-disk layout that projects
  depend on is broken. (PRD NFR-003.)
- **NFR-3 (no secret leakage):** The research agent summarizes source; it must not transcribe
  credentials, tokens, or secrets verbatim into the committed `research.md`. Its instructions state
  this explicitly.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-002 (markdown + config only): all deliverables are markdown skill/agent/reference files and a
  YAML config sync; no runtime dependencies are introduced.
- NN-C-003 (backward compat within major): additive only; fallback paths preserve current behavior —
  see NFR-2 and FR-4 / FR-6.
- NN-C-004 (bare agent `name:`): `agents/research.md` frontmatter is `name: research`, not prefixed.
- NN-C-008 (self-contained agent prompts): the research agent runs before brainstorm and receives all
  context by injection; it contains no "as discussed / from the brainstorm above" assumptions.
- NN-C-001 (version/marketplace sync) + NN-C-009 (always bump on plugin change): a minor bump is applied
  to all version-bearing files and the marketplace entry is kept in sync (FR-7).
- NN-C-007 (CHANGELOG present, Keep a Changelog): a new versioned CHANGELOG section is added (FR-7).

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-001 (human approval gate on spec/plan never removed): the reorder moves worktree creation and the
  research dispatch earlier but does not touch the spec sign-off gate; the human still approves the spec.

### Coding Rules Honored

- CR-001 (agent frontmatter schema): `agents/research.md` carries `name:` + `description:` (+ `model:`).
- CR-005 (repo-root-relative paths): all cross-file references use repo-root-relative paths.
- CR-007 (config keys documented inline): N/A for new keys (no config key added); the existing files
  touched retain their inline-comment discipline.
- CR-008 (thin orchestrator / narrow agent): the `spec` skill orchestrates the dispatch; the research
  agent performs the single gathering task and dispatches no sub-agents.
- CR-009 (heading hierarchy): `research.md`'s schema and all edited docs keep one H1 and a clean H2/H3
  hierarchy; the four introspection blocks and their per-cluster H2 grouping are preserved exactly as
  `introspection.md` uses them, so plan's section extraction and context-windowing stay stable.

## Acceptance Criteria

AC-1: Given a piece run on the default path, When the research agent returns `STATUS: OK` and writes
`research.md`, Then `research.md` exists at `docs/prds/<prd-slug>/specs/<piece-slug>/research.md` and is
committed to the piece branch before the `spec.md` commit.
  Independent Test: in a sandbox piece run, assert `git log --format=%H -- .../research.md` is non-empty
  and that commit is an ancestor of (precedes) the `spec.md` commit (`git merge-base --is-ancestor
  <research-commit> <spec-commit>`). Branch coverage: the OK path commits `research.md`; the
  UNAVAILABLE path (AC-4) commits no `research.md` — both asserted.

AC-2: Given `agents/research.md`, When inspected, Then it has frontmatter `name: research` and
`model: opus`, mandates a ≤2K structured return ending in a `STATUS: OK|BLOCKED` line, contains no
conversation-history assumptions (NN-C-008), and instructs against transcribing secrets (NFR-3), and
dispatches no sub-agents (CR-008).
  Independent Test: `grep -E '^name:\s*research$'` and `grep -E '^model:\s*opus$'` match; the file
  contains the `STATUS: OK` / `STATUS: BLOCKED` contract and a ≤2K return statement; `grep -iE 'as
  discussed|from the brainstorm above|you already know|per my previous'` returns nothing; the file
  contains an explicit no-secrets instruction and no `Agent(` sub-dispatch.

AC-3: Given `reference/research-artifact.md`, When inspected, Then it defines `research.md`'s structure
— the two fixed top-level headings `## Brainstorm Inference Digest` and `## Codebase Conventions`, the
per-cluster `## ` heading pattern, and the four bold-labelled blocks within each cluster (`File
Inventory`, `Dependency Map`, `Test Landscape`, `Pattern Catalog`) — all three `[RESEARCH-*]` markers
with their exact trigger conditions, the ≤2K return contract, and the "covered file = a file appearing
in any cluster's `File Inventory` block" definition; and `agents/research.md`, `skills/spec/SKILL.md`,
and `skills/plan/SKILL.md` each cite it by path.
  Independent Test: `grep` confirms the two fixed top-level heading strings, the four bold block labels,
  the three marker strings, and the covered-file (block-under-cluster) definition in
  `research-artifact.md`; `grep -l 'reference/research-artifact.md'` matches the agent and both skill
  files.

AC-4: Given the `spec` skill, When read, Then it (a) creates the worktree/branch — after the
decomposition scope-check and slug validation — before the first brainstorm question and dispatches the
research agent before brainstorm; (b) on a non-OK/dispatch-error/missing-file outcome emits
`[RESEARCH-UNAVAILABLE: <reason>]` and runs the standalone L-10 scan non-blocking; (c) runs the
standalone L-10 scan only on the UNAVAILABLE path; (d) wires the Charter Constraint Identification
Protocol's Conventions Block to `research.md`'s `## Codebase Conventions` on the OK path and to the
standalone L-10 output on the UNAVAILABLE path.
  Independent Test: structural read of `skills/spec/SKILL.md` + `reference/brainstorm-procedure.md`:
  worktree-creation/slug-validation/research-dispatch steps appear before the brainstorm-question step;
  the `[RESEARCH-UNAVAILABLE: <reason>]` emission with all three enumerated triggers and a non-blocking
  continuation is present; L-10 is marked conditional (success → consumed from `research.md`; UNAVAILABLE
  → run standalone); the Conventions Block's input source is stated for both paths. Both branches
  (OK / UNAVAILABLE) are enumerated in the skill text.

AC-5: Given the `plan` skill and an existing `research.md`, When Phase 1 runs, Then it emits
`[RESEARCH-CONSUMED: <N> files, <M> re-read]`, seeds `introspection.md` by structural copy of
`research.md` (skipping the full per-cluster sweep), appends a targeted-read entry for each spec target
file that is not a covered file, and re-reads/updates each covered file changed since the `research.md`
commit (`git diff <commit>..HEAD`); Phase 2 then reads the resulting `introspection.md` unchanged.
  Independent Test: structural read of `skills/plan/SKILL.md`: the `[RESEARCH-CONSUMED: ...]` marker, an
  explicit "seed `introspection.md` from `research.md` — do not run the full per-cluster sweep when
  `research.md` is present" instruction, the `git log -1 --format=%H -- research.md` anchor resolution,
  the `git diff <commit>..HEAD` staleness re-read, and the targeted (non-sweep) append for non-covered
  files are all present; the Phase 2 reader is unchanged from the ABSENT path.

AC-6: Given the `plan` skill and no `research.md` on the piece branch, When Phase 1 runs, Then it emits
`[RESEARCH-ABSENT: running full exploration]` and populates `introspection.md` via the existing
per-cluster sweep unchanged, and Phase 2 reads it section-by-section exactly as today (backward-compat,
NFR-2).
  Independent Test: structural read of `skills/plan/SKILL.md`: a file-existence branch gates the
  CONSUMED vs ABSENT paths; the ABSENT path emits the marker and preserves the legacy sweep text and the
  unchanged Phase 2 reader. Branch coverage: present → CONSUMED (AC-5); absent → ABSENT (this AC) — both
  enumerated.

AC-7: Given the repo after this piece, When inspected, Then `v3-path-conventions.md` references
`research.md` (file) not `research/` (directory); and the plugin version is bumped (minor) in every
version-bearing file with the `marketplace.json` entry synced and a CHANGELOG section added.
  Independent Test: `grep 'research.md' reference/v3-path-conventions.md` matches and the bare
  `research/` directory entry is gone; `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json)
  <(jq -r '.plugins[]|select(.name=="spec-flow").version' .claude-plugin/marketplace.json)` produces no
  output; `git diff` shows a new `## [<version>]` CHANGELOG section with at least one bullet.

## Technical Approach

**Sequencing (the load-bearing change).** Today the `spec` skill creates the worktree in Phase 3, after
brainstorm. This piece moves worktree/branch creation (and the slug validation that gates it) to run
right after the Phase-2 decomposition scope-check and before the first brainstorm question, so the
research agent can write and commit `research.md` onto the piece branch up front. Running the
decomposition check first keeps the orphan-worktree window small: a piece that turns out to need
decomposition is caught before the worktree exists. A brainstorm abandoned *after* the research commit
leaves a recoverable orphan worktree+branch — an accepted, low-frequency cost.

**One artifact, two readers — via seeding, not replacement.** The research agent writes `research.md`
in the **exact cluster-grouped layout `introspection.md` uses** (per-cluster H2 heading; the four
bold-labelled blocks — `File Inventory`, `Dependency Map`, `Test Landscape`, `Pattern Catalog` —
beneath it, verbatim code blocks preserved), preceded by two top-level sections `Brainstorm Inference
Digest` and `Codebase Conventions`. On the CONSUMED path the `plan` skill **seeds `introspection.md` by
structural copy** of those clusters rather than running the sweep — so plan Phase 2's section-by-section
reader is untouched on both paths; only the *populating* step changes. `Codebase Conventions` folds in
what L-10 produced and is the input the Charter Constraint Identification Protocol consumes on the OK
path (the standalone L-10 output serves that role on the UNAVAILABLE path). `Brainstorm Inference
Digest` is the ≤2K content the agent returns to the main thread; the `spec` skill uses it to seed
brainstorm inferences. `reference/research-artifact.md` is the one place the schema, markers, return
contract, and "covered file" definition live; the agent and both skills cite it to prevent drift.

**Pre-spec speculation is intentional.** The research agent runs before `spec.md` exists, so it gathers
against the piece's PRD sections + manifest description, not against finalized spec targets. The digest
is therefore a seed for "lead with your understanding," not an authority — the human still drives
brainstorm. This also means the plan stage may find target files the spec-time scan did not cover; FR-5's
targeted top-up (missing covered files) and staleness re-read (covered files changed since the research
commit) close that gap without re-running the whole sweep.

**Markers as the observability surface.** `[RESEARCH-UNAVAILABLE]` (spec), `[RESEARCH-ABSENT]` and
`[RESEARCH-CONSUMED]` (plan) are the only signals an operator needs to know which path ran. Each marker's
trigger is pinned in `research-artifact.md` so QA can verify them deterministically.

**Failure posture.** The research agent self-reports `STATUS: OK|BLOCKED`; the `spec` skill additionally
treats a dispatch/tool error or a missing/zero-length `research.md` as UNAVAILABLE. No path blocks the
pipeline — UNAVAILABLE degrades spec to L-10, ABSENT degrades plan to the legacy sweep.

## Testing Strategy

This piece is pure doc-as-code (markdown skills/agents/reference + a YAML version sync). Per NN-C-002 the
plugin ships no runtime dependencies and there is no test runner; verification is structural and is
performed by the execute oracle + review board:

- **Unit-equivalent (structural assertions):** `grep`/`jq`/`git` checks per the Independent Tests above —
  agent frontmatter and `STATUS` contract (AC-2), reference schema + citations (AC-3), spec reorder +
  UNAVAILABLE triggers (AC-4), plan CONSUMED top-up + ABSENT fallback markers (AC-5/AC-6), path-convention
  edit + version sync + CHANGELOG (AC-7).
- **Integration-equivalent (one wired walkthrough):** the commit-ordering check (AC-1) exercises the real
  reordered spec flow end-to-end — research dispatch → `research.md` commit → `spec.md` commit — and is
  the closest thing to an integration test for the seam.
- **Edge cases to cover:** OK vs BLOCKED return; dispatch error; missing/zero-length `research.md`;
  `research.md` present vs absent at plan time; a covered file changed between the research commit and plan
  time (staleness re-read); a spec target file absent from `File Inventory` (targeted top-up); a piece
  specced before this feature (no `research.md` → ABSENT, backward-compat).

## Integration Coverage

None in scope. The only cross-component seam is the `research.md` artifact, written by `agents/research.md`
and read by the `spec` skill (digest) and `plan` skill (four sections). There are no true externals to
double with a contract test; the seam's correctness is held by the centralized schema in
`reference/research-artifact.md` and the commit-ordering walkthrough (AC-1).

## Open Questions

- (none — all brainstorm questions resolved)
