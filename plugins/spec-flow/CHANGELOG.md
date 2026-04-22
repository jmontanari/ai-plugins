# Changelog

All notable changes to the `spec-flow` plugin. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the plugin uses [Semantic Versioning](https://semver.org/).

## [2.5.0] — 2026-04-22

Adds an adversarial test-quality gate between Red and Build: the new `qa-tdd-red` agent rejects theater tests (tautological, mock-echoing, truthy-only, no-assertion, implementation-coupled, etc.) before Build writes production code fit to weak assertions. Completes the TDD discipline trilogy started in v2.3.0 (Red → zero-passing) and v2.4.0 (Build → every-Red-passes): Red now also has a semantic quality floor, not just structural invariants.

### Added

- **New agent: `agents/qa-tdd-red.md`** (Sonnet, read-only). Dispatched between `tdd-red` and `implementer` in every TDD-track phase. Input: Red's `## Tests Written` list, authored test source, phase's `[TDD-Red]` block, phase ACs, Red's oracle block. Applies the 11-pattern Theater Pattern Catalog + an AC-binding check ("if I implemented this AC incorrectly, would this test catch it?"). FAIL re-dispatches Red once with findings surfaced; two consecutive FAILs escalate — signals spec or plan defect.
- **`reference/spec-flow-doctrine.md` — new "Theater Pattern Catalog" section.** Authoritative catalog of the 11 patterns `qa-tdd-red` enforces: (1) tautology, (2) self-referential, (3) mock-echo, (4) call-count only, (5) assert-the-assignment, (6) truthy-only, (7) exception swallowing, (8) no assertion at all, (9) name-vs-body mismatch, (10) implementation-coupled, (11) redundant cluster. Each pattern has a definition and a Python/pytest example. `qa-tdd-red` applies all 11 pre-Build; `verify` Full mode re-applies all 11 as Opus backstop; `verify` Audit mode spot-checks the top 5; `qa-phase` applies all 11 end-of-phase.
- **`skills/execute/SKILL.md` — new Step 2.5 (QA-TDD-Red)** inserted between Red (Step 2) and Implement/Build (Step 3) for Mode: TDD phases. Dispatches the new agent; parses PASS/FAIL; orchestrates one Red retry with findings on FAIL; escalates on second consecutive FAIL.
- **Plan template and plan skill updated** to emit a `[QA-Red]` checkbox between `[TDD-Red]` and `[Build]` in every TDD-track phase (flat and Phase Group sub-phases). Agent Context Summary table updated to include qa-tdd-red's inputs/exclusions.

### Changed

- **`agents/qa-plan.md` — criterion 3 (TDD structure)** now requires every TDD-track phase and every sub-phase with a `[TDD-Red]` block to include a `[QA-Red]` block immediately after. Missing `[QA-Red]` is a must-fix — plans without it would silently skip the theater gate at execute time.
- **`agents/verify.md` — Full-mode Review Task #4 (Test quality)** now references the full 11-pattern Theater Pattern Catalog in doctrine as the authoritative checklist instead of the old one-line "behavior not implementation details" criterion. Audit-mode "skip test-quality review" carve-out replaced with a top-5-pattern spot-check — the cheapest possible backstop for slips the pre-Build `qa-tdd-red` gate may have let through.
- **`agents/qa-phase.md` — criterion #6 (Test quality)** now references the full 11-pattern catalog as the Opus-tier adversarial backstop at phase end.
- **`reference/spec-flow-doctrine.md` — new safeguards-table row ("Red tests pass theater review before Build")** documenting the layered enforcement: Sonnet `qa-tdd-red` pre-Build → Opus `verify` Full-mode backstop → Sonnet `verify` Audit-mode spot-check → Opus `qa-phase` final backstop.
- **`docs/userguide/concepts/tdd-loop.md`** — "four agents" becomes "five agents" with `qa-tdd-red` added to the table; Step 1.5 (QA-Red) documented between Red and Build with the theater-catalog overview.
- **`README.md`** — pipeline diagram updated (`tdd-red → qa-tdd-red → implementer → ...`); stages table updated for execute; TDD-track flow description updated.

### Notes for upgraders

- **No user-visible API change.** Skill commands and orchestrator entry points are unchanged. The new gate runs automatically inside `execute` for TDD-track phases; Implement-track phases are unaffected.
- **New Sonnet dispatch per TDD phase.** Cost is small (scope is just the authored test files, typically <100 LOC), and it saves a full Build+Verify round-trip when theater is caught pre-Build instead of downstream.
- **Plans written pre-2.5.0** will have TDD phases without `[QA-Red]` checkboxes. The orchestrator still runs the gate (the step is in the skill, not the plan), but `qa-plan` will flag the missing checkboxes as must-fix on any re-review. Regenerate plans through `/spec-flow:plan` to pick up the new template, or let `qa-plan` drive the correction.
- **Caught defects shift left.** Under 2.4.0 and earlier, theater tests in Red could reach Build; the implementer would satisfy them with equally-theatrical production code; `verify` Full-mode would flag the test-quality issue but the Build commit was already landed. Under 2.5.0, the rejection lands at Red — cheaper to rewrite tests than tests + implementation.
- **Completes the TDD trilogy.** v2.3.0 enforced "Red has 0 passing tests" (structural — do all authored tests fail?). v2.4.0 enforced "Build has every Red test in PASSED" (structural — does the production code turn them green without skipping?). v2.5.0 enforces "Red's tests are non-theatrical" (semantic — do the assertions actually bind to the ACs?). Together: Red tests must fail, for the right reason, bound to the right ACs, with real assertions, and Build must make all of them pass without hiding any.

## [2.4.0] — 2026-04-22

Tightens the Build-side TDD discipline symmetrically to v2.3.0's Red-side tightening: every Red test must actually pass in the Build run — not merely "full suite green." Closes three evasion modes that `full suite must be GREEN` alone did not catch: silent skip decorators on Red tests, empty parameterize / collection errors that drop Red tests from the run entirely, and Red test deletion caught only later at Verify's integrity diff.

### Changed

- **`agents/implementer.md` — new TDD-mode-only rule ("Every Red test must pass — zero skipped, zero missing").** Every test ID from the `## Oracle` block must appear in the PASSED set of the final oracle run. Zero may be SKIPPED. Zero may be missing from the run (collection errors, empty `@pytest.mark.parametrize`, `describe.skip`, `t.Skip()`, etc.). If a Red test cannot go green without skipping it, report BLOCKED — do not land a "green suite" that silently drops Red tests.
- **`skills/execute/SKILL.md` — Step 3.5 validation expanded for Mode: TDD** from one invariant ("full suite green") to three: (a) full suite green, (b) every Red ID from `phase_N_oracle_block` is in the Build run's PASSED set, (c) zero Red IDs in SKIPPED. The orchestrator set-diffs the Red oracle block's FAILED list against the Build run's PASSED/SKIPPED sets. On violation of (b) or (c): one retry within the existing 2-attempt oracle budget with the offending IDs surfaced; escalate on second failure.
- **`reference/spec-flow-doctrine.md` — new Agent-Specific Safeguards row ("Build run has every Red test in PASSED").** Companion to v2.3.0's Red-side row — together they enforce the round-trip invariant: Red declares a set of tests that must fail; Build must turn every one of them into a pass, not a skip or a silent drop.
- **`docs/userguide/concepts/tdd-loop.md` — Step 2 Build section** rewritten to document all three invariants user-visibly instead of the previous "suite is fully green" one-liner.

### Notes for upgraders

- **No user-visible API change.** Skill commands and orchestrator entry points are unchanged. Well-behaved Build runs — which already had every Red test actually passing — are unaffected.
- **Stricter rejection.** Phases where the implementer previously got a "green suite" by adding a skip decorator, by an implicit collection error, or by tests silently disappearing will now be rejected at Build time (previously caught only partially by Verify's downstream test-file integrity diff, or not at all when the cause wasn't a test-file edit). The orchestrator will retry once with the offending IDs surfaced, then escalate if unresolved.
- **Symmetric with v2.3.0.** Red says "every test you authored must fail (0 passing, 0 missing from FAILED)." Build now says "every Red test must pass (0 skipped, 0 missing from PASSED)." The pair guarantees that what the Red agent declared as the phase's oracle of done is exactly what Build proved.

## [2.3.0] — 2026-04-22

Tightens the TDD-Red discipline: the Red phase must now produce **zero passing new tests**, not merely "at least one failing test." Closes a loophole where Red runs reporting `N failed, M passed` (with M > 0) were silently accepted by the orchestrator, allowing a phase's new test set to include already-green assertions that didn't exercise missing behavior.

### Changed

- **`agents/tdd-red.md` — new Rule 8 ("Zero passing tests among the ones you authored").** Every test ID listed in `## Tests Written` must appear in the `FAILED` (or `SKIPPED` with reason) list of the oracle block. The Output Format example summary now reads `"N failed, 0 passed, K skipped in T"` instead of the old `"N failed, M passed, K skipped in T"`, and a new paragraph below the identifier-format note spells out the invariant. A passing test in Red means either the feature already exists (wrong phase — escalate) or the assertion is tautological (rewrite).
- **`skills/execute/SKILL.md` — Step 2.4 ("Validate") rewritten as a two-invariant gate.** The old loose instruction ("Confirm tests FAIL") is replaced with: (a) every `## Tests Written` ID must appear in the oracle block's FAILED/SKIPPED list, and (b) a re-run scoped to the `## Tests Written` paths must report `0 passed`. On violation: one scoped retry with the specific offense appended; escalate on second failure.
- **`reference/spec-flow-doctrine.md` — new Agent-Specific Safeguards row ("Red commit has zero passing new tests").** Documents the orchestrator-side enforcement introduced in `execute/SKILL.md`.

### Notes for upgraders

- **No user-visible API change.** Skill commands and orchestrator entry points are unchanged. Well-behaved Red runs — which already reported `0 passed` — are unaffected.
- **Stricter rejection.** Plans that historically passed Red validation by relying on the looser "at least one failing test" reading may now be rejected. The orchestrator will retry once with the passing test IDs surfaced, and escalate if the agent cannot produce a Red run with zero passing new tests. If the escalation reveals the feature already exists, the plan needs correction — the test belongs in Verify as a regression check, not in this phase's Red.

## [2.2.0] — 2026-04-22

Completes the dual-host co-ship started in v2.1.0: every agent is now discoverable on both Claude Code and Copilot CLI, with no subdirectory carve-outs.

### Changed

- **Flattened `agents/reflection/` and `agents/review-board/` subdirectories.** Seven agents were living in nested subdirectories that Copilot CLI's flat-glob loader could not see. They are now top-level with prefixed names:
  - `agents/reflection/process-retro.md` → `agents/reflection-process-retro.md`
  - `agents/reflection/future-opportunities.md` → `agents/reflection-future-opportunities.md`
  - `agents/review-board/architecture.md` → `agents/review-board-architecture.md`
  - `agents/review-board/blind.md` → `agents/review-board-blind.md`
  - `agents/review-board/edge-case.md` → `agents/review-board-edge-case.md`
  - `agents/review-board/prd-alignment.md` → `agents/review-board-prd-alignment.md`
  - `agents/review-board/spec-compliance.md` → `agents/review-board-spec-compliance.md`
- **Added CR-001-compliant YAML frontmatter to the five review-board agents.** They were lacking `name:` / `description:` entirely (pre-existing CR-001 violation, inherited from before the charter was adopted). Each now declares its role and reinforces the "do not call directly" dispatch boundary.
- Updated `plugins/spec-flow/skills/execute/SKILL.md`, the plugin README, root README, and user guide to reference the flat filenames.

### Fixed

- Skills that dispatch end-of-piece reflection or review-board agents now work on Copilot CLI. Previously, these dispatches would fail on Copilot because the target agents were not discoverable.

### Notes for upgraders

- **No user-visible API change.** Skill commands and dispatch behavior are unchanged on both hosts. The plugin's public surface (skills, user-invocable commands) is identical to v2.1.0.
- **Internal agent names changed** — any external tooling that referenced the old nested paths (`review-board/blind`, `reflection/process-retro`, etc.) must update to the flat names. spec-flow's `execute` skill is the only supported dispatcher, and it has been updated.

## [2.1.0] — 2026-04-21

Added GitHub Copilot CLI install compatibility via a **dual-path co-ship** pattern (PI-007-copilot-coship). One source tree under `plugins/spec-flow/` serves both Claude Code and Copilot CLI. No mirror branch, no sync script, no content translation — each host discovers what it understands from the same files.

### Added

- Plugin-level overview at `plugins/spec-flow/CLAUDE.md` summarizing the pipeline and entry-point skills. Read by both hosts: Claude Code treats it as the plugin-level README; Copilot CLI auto-loads it as plugin context.
- GitHub Copilot CLI install paths documented — two supported forms: direct subdirectory install (`/plugin install jmontanari/ai-plugins:plugins/spec-flow`) and marketplace install (`/plugin marketplace add jmontanari/ai-plugins` followed by `/plugin install spec-flow@shared-plugins`). Both confirmed with Copilot CLI v1.0.34.
- YAML frontmatter added to `fix-doc.md`, `qa-plan.md`, `qa-prd-review.md`, and `qa-spec.md` (they were missing it — pre-existing CR-001 violations surfaced by Copilot CLI's stricter schema validation). `implementer.md`'s description now double-quotes the "Mode: TDD" / "Mode: Implement" substrings so YAML doesn't parse the colons as nested mappings. Both hosts now load all top-level agents without warnings.

### Changed

- The README's "Install on GitHub Copilot CLI" section now documents both install paths (direct and marketplace) and includes a high-level skills table. Slash-command invocation (`/<plugin>:<skill>`) works identically on both hosts — no host-specific rewriting needed.
- Root `.claude-plugin/marketplace.json` — removed `metadata.pluginRoot` field. It was causing Copilot CLI's marketplace install to concatenate `pluginRoot` + `source` and produce a duplicated `plugins/plugins/spec-flow` resolution path. `source` values are already resolved correctly relative to the marketplace.json directory, so both hosts work without the explicit root hint.

### Notes for upgraders

- **No maintainer setup required.** There is no mirror branch to push, no post-commit hook to install, no bootstrap script to run. Pull, commit, push as normal — both hosts get the updates.
- **No dual-extension trick.** Agent files are plain `.md`. Copilot CLI's custom-agent loader scans both `*.md` and `*.agent.md` and deduplicates by basename per its Custom agents configuration reference, so no symlinks, extension aliases, or content translation are required. The same files Claude Code reads are the files Copilot CLI reads.
- **Early adopters — refresh your marketplace cache.** If you added the `shared-plugins` marketplace on Copilot CLI before v2.1.0 and now hit `Plugin source directory not found: .../plugins/plugins/spec-flow` when installing spec-flow, your local marketplace cache has the pre-fix manifest. Run `/plugin marketplace remove jmontanari/ai-plugins` then `/plugin marketplace add jmontanari/ai-plugins` before retrying `/plugin install spec-flow@shared-plugins`. See the README's install section for the full sequence.
- **Minimum Copilot CLI version: v1.0.34** (check `copilot --version`). Earlier Copilot CLI builds may lack the `/plugin` command family.
- **Copilot CLI limitation:** Copilot CLI does not support branch-pinning in `/plugin install` (tracked at `github/copilot-cli#1296`). Copilot users always install from the default branch. Nested subagents under `agents/reflection/` and `agents/review-board/` are not discovered by Copilot CLI's flat-glob agent discovery; skills that dispatch those nested agents work only on Claude Code. Top-level agents work on both. **Resolved in v2.2.0** — the nested agents were flattened.
- **Historical note:** Two earlier PI-007 designs were explored on 2026-04-21 before landing on the current dual-path pattern. A morning design shipped a `master-copilot` mirror branch + POSIX-bash post-commit hook + setup script; Phase-7 smoketest revealed Copilot CLI lacks branch-pinning, so the mirror branch couldn't be consumed. A mid-day revision added `.agent.md` symlinks alongside the `.md` files; the `/agents` smoketest plus GitHub's Custom agents configuration reference together showed the symlinks were redundant (Copilot scans both extensions and deduplicates). Both design detours were removed; the commits remain in the feature branch's history.

## [2.0.0] — 2026-04-20

First major release. Introduces the **charter stage** — a pre-PRD Socratic
flow producing binding project-wide constraints (architecture, non-negotiables,
tools, processes, flows, coding rules) that every downstream artifact and
agent inherits. Also codifies the `docs/` folder layout, splits non-negotiables
into two citable namespaces, and introduces `CR-xxx` coding-rule IDs for
per-rule traceability.

### Added

#### Charter stage (new pipeline stage before `prd`)
- **`/spec-flow:charter` skill** at `skills/charter/SKILL.md`. Three modes:
  - **Bootstrap** — first-run Socratic for fresh projects (seven phases: auto-detect signals → user-supplied sources → confirm summary → Socratic by file → write → QA → commit per file → doctrine-wiring reminder)
  - **Update** — scoped re-run of Socratic for specific file(s); retirement UX prompts retire-vs-delete; per-file commits; post-commit divergence awareness
  - **Retrofit** — nine-step commit-per-step migration pipeline for pre-charter projects (v1.5.x and earlier) with `--dry-run` preview and `--decline` opt-out
- **`qa-charter` adversarial review agent** at `agents/qa-charter.md`. Opus. Read-only. Per-file + cross-file + scope/meta checks; retrofit-mode additions for re-keying completeness and spec back-reference integrity. Reuses `fix-doc.md` via the standard iter-1-full / iter-2+-focused / 3-iter-circuit-breaker loop.
- **Six focused charter templates** in `templates/charter/`:
  - `architecture.md` — layers, dependency direction, component ownership
  - `non-negotiables.md` — `NN-C-xxx` structured schema (Type: Rule / Reference)
  - `tools.md` — language, framework, test runner, linter, CI, approved/banned libraries
  - `processes.md` — branching, review, release, CI gates, incident response
  - `flows.md` — request / auth / data-write and other critical flows
  - `coding-rules.md` — `CR-xxx` structured schema (same Rule/Reference types as NN-C)
- **`Type: Rule` vs `Type: Reference` entry schema** for numbered-entry files. `Reference` entries defer to external content (URL or local file path); `Rule` entries are inline and self-contained. Both are citable.

#### Two non-negotiables namespaces
- **`NN-C-xxx`** (Charter) — project-wide binding rules. Live in `<docs_root>/charter/non-negotiables.md`. Rarely change.
- **`NN-P-xxx`** (Product) — product-specific binding rules. Live in the PRD's `## Non-Negotiables (Product)` section. Grow with each PRD import.
- **`CR-xxx`** (Coding Rules) — numbered, citable coding conventions. Live in `<docs_root>/charter/coding-rules.md`.
- **Write-once IDs** — NN-C, NN-P, CR IDs never renumber. Retired entries stay as tombstones (`RETIRED YYYY-MM-DD` markers). Specs citing retired IDs are must-fix by QA.

#### Folder layout codified
- New top-level structure in `<docs_root>/`:
  - `charter/` — six project-wide binding files
  - `prd/` — `prd.md` + `manifest.yaml` (moved from flat)
  - `specs/<piece>/` — per-piece `spec.md`, `plan.md`, `learnings.md`, and local `research/` subfolder
  - `research/<topic>/` — scaffolded (standalone cross-piece research; not wired in v1, roadmap item)
  - `backlog/backlog.md` — reflection output (was `improvement-backlog.md`)
  - `archive/` — legacy artifacts preserved

#### Template updates
- **`templates/prd.md`** — NN section renamed to `## Non-Negotiables (Product)` with NN-P structured schema. Charter reference line added.
- **`templates/spec.md`** — `charter_snapshot:` front-matter captures per-file `last_updated` dates at spec write time. NN section split into Project (NN-C) + Product (NN-P). New `### Coding Rules Honored` section for CR-xxx citations. Charter reference line.
- **`templates/plan.md`** — `charter_snapshot:` front-matter. Charter reference line. Each phase gains a "Charter constraints honored in this phase" slot citing NN-C/NN-P/CR entries.

#### Pipeline config + doctrine
- **`charter:` config block** in `templates/pipeline-config.yaml`:
  - `required` (default `false`; piece 6 retrofit flips to `true` after migration) — downstream skills fail fast when missing
  - `doctrine_load` (default `[non-negotiables, architecture]`) — list of charter files auto-injected into every agent's session via the SessionStart hook
- **SessionStart hook charter doctrine load** — `hooks/session-start` now conditionally reads charter files listed in `doctrine_load` and injects them into `additionalContext` alongside the TDD doctrine. Silent no-op when charter absent or list empty.

#### Downstream skill charter wiring
- **`prd` skill** — Step 0.5 charter prerequisite check (halts when `charter.required: true` and charter missing). NN classification during import: user decides project-wide (NN-C) vs product-specific (NN-P). New-layout writes to `<docs_root>/prd/`. Legacy-layout detection points users at `/spec-flow:charter --retrofit`.
- **`spec` skill** — Phase 1 reads `<docs_root>/charter/` (all six) with fallback to legacy `<docs_root>/architecture/`. Phase 1 scans NN-C, NN-P, CR namespaces. Phase 2 new step 1a identifies charter constraints touched. Phase 3 writes spec with `charter_snapshot` front-matter. Phase 4 QA prompt interpolates charter.
- **`plan` skill** — Phase 1 exploration reads charter as priors. Phase 2 allocates every spec-cited NN-C/NN-P/CR into exactly one phase's "Charter constraints honored" slot. Plan written with `charter_snapshot`. QA prompt includes charter; allocation completeness checked.
- **`execute` skill** — `qa-phase` prompt sources `## Non-negotiables` from NN-C + NN-P; new `## Coding rules cited by this phase` block attaches CR entries. Review-board architecture reviewer gets full charter. Spec-compliance reviewer gets NN-C/NN-P/CR for claim verification.
- **`status` skill** — top-line `Charter: present (last_updated YYYY-MM-DD)` indicator. Per-piece `⚠ Charter diverged` flag when any current `last_updated` > piece's snapshot. New `--resolve <piece>` flag walks divergence resolution (re-spec / re-plan / accept).

#### Agent updates
- **`implementer`** Rule 4 binds to `<docs_root>/charter/` (six files) with legacy fallback; explicitly names NN-C / NN-P / CR as plan-citable binding references.
- **`qa-spec`** checks citation integrity (no hallucinated IDs; retired citations must-fix), honoring specificity (vague phrasing fails), scope coverage (overlapping-scope entries must be cited).
- **`qa-plan`** checks per-phase allocation (no drops, no duplicates), per-phase honoring specificity, `charter_snapshot` front-matter presence.
- **`qa-phase`** checks charter citation honoring (cited entries must be demonstrably honored in phase diff).
- **`qa-prd-review`** audits NN-C and NN-P coverage across done pieces, retired-entry citation scan, CR drift spot-check.
- **`review-board/architecture`** expanded to cover CR-xxx compliance and `flows.md` honoring. Full charter is primary context.
- **`review-board/spec-compliance`** verifies every NN/CR claim is backed by the diff.
- **`review-board/prd-alignment`** verifies NN-P preservation across piece implementation.

### Changed

- **Folder layout** — `docs/prd.md` → `docs/prd/prd.md`, `docs/manifest.yaml` → `docs/prd/manifest.yaml`, `docs/improvement-backlog.md` → `docs/backlog/backlog.md`. Per-piece artifacts stay co-located under `docs/specs/<piece>/`. Retrofit mode migrates via `git mv` to preserve history.
- **PRD NN section** renamed from `## Non-Negotiables` to `## Non-Negotiables (Product)` using structured schema. Pre-charter projects retain the legacy flat section until they retrofit.
- **Spec NN section** — `### Non-Negotiables (from PRD)` renamed to `### Non-Negotiables Honored` and split into Project (NN-C) + Product (NN-P) subsections.
- **All downstream skills read both new and legacy layouts.** Charter takes precedence when present; fallback to legacy is automatic and silent.

### Migration from v1.5.x

Three paths for existing projects:

1. **Run `/spec-flow:charter --retrofit`.** Nine-step commit-per-step pipeline:
   - Snapshots pre-state to `docs/archive/pre-charter-migration-<date>/`
   - Socratic per existing NN: classify as C (charter) / P (product) / R (retire)
   - Runs bootstrap Socratic for the other five charter files
   - `git mv` layout migration (preserves history)
   - Rewrites PRD with NN-P namespace + Charter reference
   - Dispatches `fix-doc` per piece to rewrite NN citations
   - Full QA sweep (qa-charter + qa-spec + qa-plan on every rewritten artifact)
   - `--dry-run` available for preview before committing
2. **Opt out via `/spec-flow:charter --decline`.** Writes `charter.required: false` and creates `docs/.charter-declined` marker. Downstream skills skip all charter checks. Existing v1.5.x behavior preserved verbatim. Reversible.
3. **Do nothing.** `charter.required` defaults to `false`. Skills read and write legacy paths unchanged. Charter adoption happens only when the user invokes `/spec-flow:charter`.

Rollback from retrofit: every step is `git revert`-able; pre-state snapshot is the nuclear-option backstop (`git reset --hard <snapshot-sha>`). No destructive commands anywhere in the pipeline.

**Run `/reload-plugins` after upgrading** to pick up all skill, agent, template, hook, and config changes.

### Deferred (backlog)

- Validate charter structure against a mature existing product
- Fetch-and-summarize external URLs for `Type: Reference` entries
- Auto-generated architecture/flow diagrams from code
- `docs/research/<topic>/` wiring beyond scaffolding
- Automated divergence-resolution runners (currently human-gated via `/spec-flow:status --resolve`)
- Cross-piece retirement impact analysis
- Charter version tags and git-tag integration
- Automated retry on QA failures during retrofit
- Step-specific rollback tooling (currently `git revert` + manual reapply)
- Stale-reference detector (external URL changed outside our control)

## [1.5.0] — 2026-04-19

### Added
- **End-of-piece reflection stage (Step 4.5).** Two new Sonnet read-only agents — `agents/reflection/process-retro.md` and `agents/reflection/future-opportunities.md` — fire concurrently after Final Review's Human Sign-Off and before Capture Learnings. Process retro examines session metrics + escalation log + cumulative diff for orchestration improvements. Future opportunities examines spec/plan/diff/manifest for forward-looking work to consider in future pieces.
- **Project-level improvement backlog.** Reflection findings get appended to `<docs_root>/improvement-backlog.md` (committed, accumulates across pieces). The `spec` skill reads this file at brainstorm start to surface relevant past findings as candidate considerations for new pieces.
- **`reflection` config key** (`auto | off`, default `auto`) in `.spec-flow.yaml`. Disables Step 4.5 if needed.
- **Spec skill backlog integration.** Phase 1 step 6 (new) reads the backlog and surfaces ~5 most-relevant items during brainstorm. Phase 5 step 4 (new) prunes addressed/obsolete items after spec sign-off.

### Changed
- **Step 5 (Capture Learnings) restructured.** Now synthesizes `learnings.md` from the two reflection reports + cumulative diff, instead of free-form authoring. Falls back to pre-v1.5 behavior when `reflection: off`.
- **API encapsulation callout** in `skills/execute/SKILL.md` updated to include the two new reflection agents alongside the v1.4.0 phase-level agent list.

### Fixed
- **Agent identifier doubling** (regression from v1.4.0). Frontmatter `name:` fields had the `spec-flow-` prefix, causing agents to register as `spec-flow:spec-flow-<name>` instead of `spec-flow:<name>`. Stripped the prefix from all internal agents (implementer, tdd-red, verify, refactor, qa-phase, qa-phase-lite, fix-code) so legacy short-form callers (`spec-flow:tdd-red`, etc.) work again. Reflection agents use `name: reflection-<x>` to keep the directory-grouping signal in the identifier (`spec-flow:reflection-process-retro`).

### Notes for upgraders
- Plans authored before v1.5.0 work unchanged.
- New projects get `<docs_root>/improvement-backlog.md` created on first end-of-piece reflection. Existing projects can let it accumulate naturally.
- Set `reflection: off` to disable the new stage if you prefer the pre-v1.5 single-shot `learnings.md` flow.
- Run `/reload-plugins` after upgrading to pick up the agent identifier fix.

## [1.4.0] — 2026-04-19

### Added
- **Phase Groups with parallel sub-phase execution.** New plan-level hierarchy (`## Phase Group <letter>:` containing `#### Sub-Phase <letter>.<n> [P]:` sub-units) lets authors decompose parallelizable work (adapter patterns, independent endpoints, per-table migrations) into concurrently-dispatched sub-phases. Opt-in per plan — flat phases still work unchanged.
- **Phase Scheduler in `skills/execute/SKILL.md`.** Detects Phase Group headings, validates sub-phase scope disjointness, dispatches concurrent sub-phase pipelines (each runs its own Red → Build → Verify → QA-lite), waits at a barrier, then runs group-level Refactor and Opus QA on the cumulative diff.
- **`agents/qa-phase-lite.md`** — new Sonnet narrow review template for per-sub-phase QA. Complements the deep Opus QA that now runs at group level. Tiered QA drops net Opus cost as concurrency rises.
- **Autonomous triage decision matrix** for sub-phase failures. 12 failure signatures mapped to recovery actions (fix-code / Refactor / reset-and-re-dispatch / inline autofix / immediate escalation). Pass-1 recovery then pass-2 focused re-check. Hard cap: 2 passes then human escalation. Batched failure report covers the whole group in one review session.
- **`phase_groups` config key** (`auto | always | off`, default `auto`) in `.spec-flow.yaml`. Controls whether the Phase Scheduler is active.
- **Agent API encapsulation** across all internal agents (`implementer`, `tdd-red`, `verify`, `refactor`, `qa-phase`, `qa-phase-lite`, `fix-code`). Frontmatter descriptions now signal "do not call directly", and each agent has a Rule 0 first-turn entrypoint check that BLOCKs when called without the orchestrator-injected invariants (Mode flag, pre-flight snapshot, oracle anchors, AC matrix). Prevents direct-dispatch contamination.

### Changed
- **`skills/plan/SKILL.md` rule 8** introduces Phase Group authoring guidance with structure template, when-to-use / when-not-to-use criteria, scope discipline requirement, and Phase 0 Scaffold interaction.
- **`templates/plan.md`** gains a Phase Group example alongside the existing flat-phase examples.
- **`skills/execute/SKILL.md`** opens with an API-encapsulation doctrine callout reinforcing that this skill is the sole entrypoint for internal phase agents.
- **`agents/refactor.md` Rule 1** clarifies that when dispatched at Phase Group level (Step G7), "phase files" means the union of all sub-phase `**Scope:**` declarations. Orchestrator passes the union as the authoritative file list.

### Notes for upgraders
- Plans authored before v1.4.0 using only flat phases are fully backward-compatible.
- To pilot Phase Groups on an adapter-pattern piece, decompose in `plan` and let `phase_groups: auto` pick up the scheduler.
- Set `phase_groups: off` to disable the scheduler entirely if you hit issues during early rollout.

## [1.3.1] — 2026-04-19

### Added
- **Checkpoint-commit guidance in agent templates.** `agents/implementer.md`, `agents/tdd-red.md`, and `agents/refactor.md` now explicitly tell agents to commit at logical checkpoints during a dispatch (e.g. after each finished file, public-API surface, or plan bullet) and do a final commit when done. Each commit runs hooks; intermediate commits must be lint/type-clean, only the final commit must satisfy the mode's oracle. Benefits: faster error surfacing on small diffs, usable bisect-within-phase git history, natural recovery checkpoints.
- **Plan authoring guidance for checkpoint-friendly bullet ordering.** `skills/plan/SKILL.md` step 5 and `templates/plan.md` both now ask plan authors to order bullets inside `[Build]` / `[Implement]` blocks in a checkpoint-progression sequence (types → constructors → public API → internals → error paths). This gives the implementer agent natural checkpoint boundaries without needing prescriptive structure.

### Changed
- QA remains explicitly per-phase (unchanged design intent): adding more intermediate commits inside a single Build dispatch does NOT multiply QA/Verify/Refactor cost, since those agents consume the cumulative `git diff $phase_start_sha..HEAD` regardless of commit granularity.

## [1.3.0] — 2026-04-19

### Added
- **Mandatory AC Coverage Matrix in Build output.** `agents/implementer.md` requires a structured `## AC Coverage Matrix` table (`| AC ID | Test file:line / Verify assertion | Status |`) with either a concrete pointer per `covered` row or a specific reason + forward pointer per `NOT COVERED` row. The orchestrator validates the table at Step 3 before advancing.
- **Step 3 validation gate.** `skills/execute/SKILL.md` Step 3 item 7 parses the Build report's AC matrix and rejects + re-dispatches (within the 2-attempt oracle budget) when the section is missing, incomplete, or vague. A clean matrix unlocks Verify Audit mode (3 min) instead of Full mode (15 min).
- **Structured QA prompt composition.** `skills/execute/SKILL.md` Step 6 hands the iter-1 QA agent a pre-digested surface map (`## Files changed`, `## Public symbols`, `## Integration callers`, scoped `## Diff`, Build's `## AC Coverage Matrix`, `## Phase ACs`, `## Non-negotiables`) instead of dumping the raw diff + full spec + PRD sections. Opus does adversarial review rather than rediscovery.
- **QA iter-2 hard cap.** `agents/qa-phase.md` Focused re-review rule: reading any file outside the fix delta is a contract violation; return `BLOCKED — needs full re-review` instead of fetching.
- **`refactor` config key** (`auto | always | never`, default `auto`) in `.spec-flow.yaml`. In `auto`, Step 5 skips Refactor when Build reported oracle clean on first attempt + no plan deviations + clean AC matrix. Reclaims ~10–15 min per clean phase.
- **`qa_iter2` config key** (`auto | always`, default `auto`). In `auto`, Step 6 skips iter-M+1 QA re-dispatch when the fix diff is < 50 LOC + fix-code reported all resolved + oracle green — the fix-code agent's self-verification is the gate. Rationale: observed iter-2 hit rate was ~1 in 6, and the class of finding that hits tends to get caught by Final Review anyway.
- **Known pitfalls section in `agents/implementer.md`.** Descriptor binding in `patch.object`, relative-path `parents[N]` fixture paths, formula-vs-test-fit drift, mock-signature drift after contract changes, overly-broad `except` clauses. Python/pytest examples; the patterns generalize.
- **`CHANGELOG.md`** (this file).

### Changed
- **Reverted `--no-verify` intermediate commit cadence** (v1.2's P7). Every intermediate phase commit (Red, Build, Refactor, fix-code, final review) now runs pre-commit hooks normally. The one exception is Red for projects whose pre-commit config includes a test-running hook (would block the intentionally-failing tests) — Red's template uses a scoped `--no-verify` authorized by the orchestrator's pre-flight hook inventory. This revert presupposes the project moves expensive checks (test suites, whole-repo type checks) to `pre-push` or explicit orchestrator gates; see README.
- **Step 6b simplified** from a multi-counter consolidation loop to a single defensive sweep. Per-commit hooks catch issues at the commit that introduced them, so there is no accumulated lint/type debt for Step 6b to unwind. Step 6b runs pre-commit once over the phase's cumulative diff; one autofix re-run and one fix-code dispatch are allowed before escalation.
- **README pre-commit guidance.** Recommends pre-commit be lint + format + type-check only; test suites belong at `pre-push` stage or as explicit orchestrator gates. Tests run three times in the v1.3 flow: Step 3's oracle gate, Step 6b's sanity sweep, and CI — a fourth run on every commit is redundant.
- **Session-end summary fields** in `skills/execute/SKILL.md` Measurement section updated: adds `Refactor skipped`, `QA iter-2 skipped`, and `Step 6b outcome` alongside the existing Build duration / token count / Verify mode fields.

### Removed
- Step 6b's multi-round consolidation loop with `autofix_iter` / `error_fix_iter` counters.
- Per-iteration `(intermediate commit — pre-commit runs at phase consolidation)` commit-message tag.
- "Inline ruff --fix" shortcut branch in Step 6b (no longer needed without the consolidation loop).
- "Red lint pre-check" rule in `agents/tdd-red.md` (redundant with per-commit hooks catching lint at commit time).

## [1.2.1] — 2026-04-18

### Changed
- Version bump (patch, no functional changes recorded in git history).

## [1.2.0] — 2026-04-17

### Added
- **Conditional Verify (Audit/Full modes).** `skills/execute/SKILL.md` Step 4 picks Audit when Build reported oracle clean + no deviations + clean AC matrix; otherwise Full. Audit is ~3 min (AC matrix sanity check, no test re-run); Full is ~10–15 min (full oracle re-verification). Not yet reliably reached pre-1.3.0 because Builds inconsistently emitted a clean AC matrix — addressed in 1.3.0.
- **Race-safe `git add` by literal file paths.** `agents/tdd-red.md` and `agents/implementer.md` require staging by exact paths from the agent's own output section (never `git add .`, `git add tests/`, or any glob). Orchestrator reconciles the committed file list against the agent's reported paths. Prevents cross-agent contamination when two agents share the same worktree.
- **Single-commit-per-phase cadence via `--no-verify` intermediates.** *(Reverted in 1.3.0.)* Intermediate phase commits used `--no-verify`; pre-commit ran once at Step 6b against the full phase diff. Intended to save per-step hook cost when hooks ran slow test suites. In practice, surfaced lint debt late and created multi-round consolidation cycles — 1.3.0 reverts this in favor of cheap per-commit hooks and tests-at-pre-push.

### Changed
- Session-end summary tracks Verify mode chosen (Audit vs Full) and consolidation outcome counters.

## [1.1.1] — 2026-04-16

### Added
- **Orchestrator pre-flight snapshot.** `skills/execute/SKILL.md` Step 1b: the orchestrator collects read-only facts (LOC per file, schema samples for config families, symbol presence via `git grep`, pre-commit hook inventory) before dispatching Red and Build. Attached as `## Pre-flight snapshot` to both agents; replaces 5–15 agent-side rediscovery tool calls per dispatch.
- **Orchestrator plan-conditional resolution.** Pre-flight resolves two specific conditional phrasings in the plan — "extract ... if ... exceeds <N>" and "if <file/symbol> exists, reuse; otherwise create ..." — into binding `## Orchestrator pre-decisions` attached to the Build prompt. Agents treat pre-decisions as binding; re-deliberation is a contract violation.
- **Oracle block splicing from Red to Build.** Red's output includes a fenced `## Oracle block` (failing test identifiers + one-line causes). The orchestrator splices this verbatim into the Build prompt's `## Oracle` section. Build's oracle of done is exactly the tests Red wrote failing; no paraphrase.
- **Pre-commit self-check ban in agent templates.** Agents no longer run `pre-commit run` inside their turn — the commit itself triggers the hook. Avoids doubled hook wall time.
- **QA focused re-review mode.** `agents/qa-phase.md`: iteration 2+ receives only the fix agent's delta + prior must-fix findings, not the full phase diff/spec/plan. Narrows iter-2 scope to "verify the fix resolves the finding + scan for regressions on the touched surface."

## [1.0.0] — earlier baseline

### Added
- Initial release: two-track execution (TDD + Implement modes), unified implementer agent, phased orchestration (Red → Build → Verify → Refactor → QA → Progress), 5-agent final review board, worktree-per-piece workflow, PRD/manifest/spec/plan artifact hierarchy.
