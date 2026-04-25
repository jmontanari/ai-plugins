---
charter_snapshot:
  architecture: 2026-04-21
  non-negotiables: 2026-04-21
  tools: 2026-04-21
  processes: 2026-04-21
  flows: 2026-04-21
  coding-rules: 2026-04-21
---

# Spec: PI-008-multi-prd-v3.0.0 — Multi-PRD Support (spec-flow v3.0.0)

**PRD Sections:** G-2, FR-004, NFR-003, NN-P-001, NN-P-003, NN-C-003
**Charter:** docs/charter/ (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** none
**Target release:** spec-flow v3.0.0 (major — breaking layout change)

## Goal

Let a single spec-flow project hold multiple PRDs in flight — sequentially or in parallel — under one shared charter, with each PRD living in a self-contained folder that carries its own requirements, manifest, specs, plans, and local backlog. Enable multi-developer/multi-capability workflows without forcing every piece of work through a single global manifest, while preserving charter as the singular source of project-wide rules. Provide a lossless migration path from the existing v1.x (flat) and v2.x (single `docs/prd/`) layouts.

## In Scope

- **Directory layout:** new `docs/prds/<prd-slug>/` namespace holding `prd.md`, `manifest.yaml`, `specs/<piece-slug>/`, `backlog.md`, and optional `README.md` per PRD.
- **Charter stays singular:** `docs/charter/` continues to be the one source of project-wide non-negotiables (NN-C), coding rules (CR), architecture, tools, processes, and flows. Every PRD references it.
- **PRD lifecycle states:** `status:` front-matter on each PRD (`drafting | active | shipped | archived`) with rules for when each state applies.
- **Short-slug naming:** human-set `slug:` fields on PRDs and pieces, used to build worktree directories (`worktrees/prd-<prd-slug>/piece-<piece-slug>/`) and branch names (`spec/<prd-slug>-<piece-slug>`, `plan/…`, `execute/…`). Folders keep long human-readable names; branches stay short and slash-free.
- **Dual backlog:** per-PRD `docs/prds/<slug>/backlog.md` for capability-scoped deferred work + global `docs/improvement-backlog.md` for cross-PRD learnings and spec-flow process findings. Reflection agents route by scope: `reflection-future-opportunities` → PRD-local, `reflection-process-retro` → global.
- **Automatic charter-drift detection:** every skill's Phase-1 "Load Context" step compares current `docs/charter/*.md` `last_updated:` values against each relevant spec's `charter_snapshot:`. Drift resolution happens inline via a focused-mode re-review of the existing `qa-spec` agent — no new user-facing skill surface.
- **Cross-PRD piece dependencies (declarative only):** manifest entries accept qualified refs like `depends_on: auth/token-refresh`. `execute` reads them to warn/block when prerequisite pieces are unmerged; no cross-PRD orchestration scheduler.
- **Migration skill `/spec-flow:migrate`:** one-shot upgrade from v1.x or v2.x layouts to v3 using `git mv` to preserve history. Prompts for a PRD slug, renames folders, injects required front-matter, updates `.spec-flow.yaml`.
- **Config key `layout_version: 3`** in `.spec-flow.yaml` — skills read it to choose path-resolution strategy; absence or `<3` triggers a non-blocking SessionStart warning recommending migration.
- **Status skill updates:** `/spec-flow:status` defaults to an all-PRDs condensed view; `/spec-flow:status <prd-slug>` drills in. Charter drift surfaces as a passive finding (action happens when the user enters a spec/plan/execute skill).
- **Template and agent updates:** `spec.md` and `plan.md` templates get path tokens that resolve under `docs/prds/<slug>/specs/<piece>/`; every agent prompt with hard-coded paths is updated.

## Out of Scope / Non-Goals

- **Ad-hoc "task" work** (lightweight spec→plan→execute for out-of-band bug fixes and small improvements). Captured in `docs/improvement-backlog.md` as a future PRD — will build on top of this layout.
- **Backlog-item promotion flow.** Manual copy during brainstorm continues to be the pattern.
- **Cross-PRD dependency orchestration** (scheduling, automatic cross-PRD build graph). v3 only records the declaration; execution decisions remain human.
- **Program-level dashboards** beyond the condensed all-PRD view in `/status`. No burn-down, no roll-up metrics, no cross-PRD timelines.
- **Charter-per-PRD or PRD-local non-negotiables.** Charter is and stays singular. NN-P entries continue to live inside each PRD's `prd.md`, distinct from NN-C (charter) and CR (charter).
- **v1.x/v2.x runtime coexistence.** v3.0.0 is a breaking major bump. Users either migrate or stay on v2.x. No dual-layout support.
- **Automatic migration on skill invocation.** Migration is explicit (`/spec-flow:migrate`) so users can review the rename plan before it runs.
- **Existing spec cross-reference rewriting.** The migration skill moves files but does not rewrite path mentions inside spec/plan content. Internal references may become stale; migration skill emits a summary of known-stale references for manual review.
- **`improvement-backlog.md` per-PRD split during migration.** All existing backlog items stay in the global file. Authors may copy forward into a PRD-local backlog manually if desired.

## Requirements

### PRD Coverage Mapping

This subsection traces each PRD section this piece claims to address (per the manifest's `prd_sections: [G-2, FR-004, NFR-003, NN-P-001, NN-P-003, NN-C-003]`) to the FR(s)/AC(s) below that satisfy it.

| PRD section | Spec requirements / acceptance criteria addressing it | Justification |
|---|---|---|
| **G-2** (flagship pipeline charter→prd→spec→plan→execute→merge) | FR-001, FR-007, FR-008, FR-019; AC-1, AC-2 | Multi-PRD support keeps G-2's flagship-pipeline promise valid as projects grow beyond a single PRD — without it, G-2 caps at one-capability-per-project. The pipeline still runs end-to-end; it now scales horizontally across PRDs. |
| **FR-004** (PRD's FR-004 — *the spec-flow plugin implements the full pipeline per `plugins/spec-flow/README.md`*) | All FRs (entire spec) | The PRD's FR-004 number is coincidentally identical to this spec's FR-004; they are unrelated. PRD-FR-004 asserts the pipeline exists. This spec keeps it intact and unbroken — no skill is removed; the layout is the only thing that changes. README is updated end-to-end per NFR-005. |
| **NFR-003** (backward compat within major) | FR-016, NFR-003 (this spec); AC-3, AC-4, AC-12, AC-15 | This piece is the major bump itself (v2.x → v3.0.0). Within-major compat continues from v3.0.0 forward; the migration skill plus SessionStart warning give v2.x users a clean upgrade path. |
| **NN-P-001** (human-readable artifacts) | FR-002, FR-019; NFR-005 | All v3 artifacts remain plain markdown + YAML. PRD front-matter and manifest piece entries are hand-auditable. |
| **NN-P-003** (dog-food before recommend) | AC-15, AC-18; "Migration of this repo (dog-food plan)" subsection | Repo migrates to v3 layout before v3.0.0 ships externally. AC-18 binds the release commit message to the dog-food run SHA. |
| **NN-C-003** (backward compat within major) | (See NFR-003 row above.) | v3.0.0 is the major bump that authorizes the breaking layout change. |

Note on FR-004 collision: this spec's FR-004 (worktree path) and the PRD's FR-004 (pipeline existence) share a number purely by coincidence. They do not reference each other.

### Piece-status state machine

Every manifest piece carries one of the following statuses. FR-011's `depends_on:` precondition refuses to start `execute` unless every named dependency is in `merged` or `done`.

| Status | Meaning |
|---|---|
| `open` | Listed in manifest; no spec yet. |
| `specced` | `spec.md` written and signed off; no plan yet. |
| `planned` | `plan.md` written and signed off; ready for execute. |
| `in-progress` | `execute` is running on the piece (one or more phases complete or under way). |
| `merged` | Piece's branch has merged to `main` / `master`. Final state for happy-path. |
| `done` | Backward-compatible alias for `merged` — pre-v3 manifests use `done`; v3+ may use either. |
| `superseded` | Piece was abandoned and replaced by another piece. Listed for history; not a valid dependency target. |
| `blocked` | External dependency or unresolved decision halts progress. Not a valid dependency target. |

`in-progress`, `superseded`, `blocked`, `open`, `specced`, and `planned` all fail the `depends_on:` precondition. Only `merged` and `done` allow a downstream piece to start `execute`.

### Functional Requirements

- **FR-001:** New layout is produced by the `prd` skill on a greenfield project: running `/spec-flow:prd <prd-slug>` creates `docs/prds/<slug>/prd.md` + `docs/prds/<slug>/manifest.yaml` + `docs/prds/<slug>/backlog.md`.
- **FR-002:** Every PRD front-matter carries `slug: <short-id>` (required), `status: drafting | active | shipped | archived` (required), `version: <int>` (required).
- **FR-003:** Every manifest piece entry accepts `slug:` (optional — falls back to `name` kebab-cased). When present, the piece's worktree and branches use the slug.
- **FR-004:** Worktree creation in `spec`, `plan`, and `execute` skills produces `worktrees/prd-<prd-slug>/piece-<piece-slug>/` paths.
- **FR-005:** Branch naming for piece work is `{spec,plan,execute}/<prd-slug>-<piece-slug>`. Slug validator rules (enforced by every skill that creates a worktree or branch — `prd`, `spec`, `plan`, `execute`, `migrate`):
  - Each slug: max 10 characters, charset `[a-z0-9-]`, must not start or end with `-`.
  - No reserved words at this time (placeholder for future expansion).
  - Total branch length must remain ≤ 50 characters.
  - On overflow or charset violation: the skill creating the branch refuses with an explicit error naming which slug is offending and what the limit is. No silent truncation.
- **FR-006:** The `prd` skill's update mode accepts either a PRD slug argument or no argument; no-arg defaults to "the only active PRD" and errors if there are multiple active PRDs without a slug.
- **FR-007:** `/spec-flow:status` default invocation lists every PRD folder under `docs/prds/` with its lifecycle state, piece counts by status, and any charter-drift warnings. `/spec-flow:status <prd-slug>` narrows to one PRD with full piece detail.
- **FR-008:** Every spec-flow skill touching a piece (spec, plan, execute, reflection) checks charter drift during Phase 1: if any charter file's `last_updated:` is newer than the piece's `charter_snapshot:` value for that file, drift is flagged.
- **FR-009:** Drift resolution: the skill dispatches `qa-spec` in `Input Mode: Focused charter re-review`, passing the full self-contained input bundle required by NN-C-008:
  (a) the full body of the piece's `spec.md`,
  (b) the full body of every charter file whose `last_updated:` advanced past the snapshot,
  (c) the piece's previous `charter_snapshot:` values for those files,
  (d) the piece's manifest entry (so the agent sees `prd_sections` and dependencies),
  (e) the PRD's `## Non-Negotiables (Product)` section (so the agent can cross-check NN-P drift),
  (f) the spec's existing `### Non-Negotiables Honored` and `### Coding Rules Honored` blocks (so the agent can detect a newly-added NN-C/NN-P/CR entry that the spec violates and confirm the citation list is still complete).
  The agent must be able to detect both compliance violations against existing entries and newly-added NN-C/NN-P/CR entries that the spec does not yet honor. If the agent returns `clean`, the snapshot is auto-advanced and a log line is appended to the spec ("charter_snapshot updated YYYY-MM-DD — no content changes required"). If the agent returns `must-fix`, the skill halts and surfaces the findings; the only forward path is amending the spec (or, explicitly out of band, reverting the charter change). There is no "accept the violation" escape hatch.
- **FR-010:** `reflection-future-opportunities` agent writes findings to `docs/prds/<slug>/backlog.md` (the PRD the piece belongs to). `reflection-process-retro` agent writes to `docs/improvement-backlog.md` (global).
- **FR-011:** Manifest piece entries accept `depends_on:` as a list of qualified references `<prd-slug>/<piece-slug>` (cross-PRD) or bare `<piece-slug>` (same-PRD). `execute` reads the precondition during Phase 1 and refuses to *start* the piece if any named dependency's `status` is not `merged` or `done` (per the piece-status state machine above), printing which deps are blocking and their current statuses. This precondition is a *blocker*, not an auto-advancer — it never bypasses the per-phase QA gate or the end-of-piece review-board sign-off mandated by NN-P-002. `execute` honors an explicit `--ignore-deps` flag (see FR-021) for deliberate deviations per NN-C-006.
- **FR-012:** New skill `/spec-flow:migrate` detects existing layout (v1 flat, v2 `docs/prd/`, or already-v3) and performs the appropriate `git mv` sequence: v1 → intermediate → v3, or v2 → v3, preserving every file's git history. v1 is canonically defined as `docs/prd.md` (flat) + `docs/manifest.yaml` (flat) + `docs/specs/<piece>/` (flat). If a v1-shaped repo lacks `docs/manifest.yaml` (very early adopters predating manifest-driven pipelines), migration treats that as a v0 case and refuses, pointing the user at `/spec-flow:charter` retrofit mode to first seed a charter and a manifest.
- **FR-013:** Migration prompts the user for the target PRD slug (unless passed as argument). Default suggestion is derived from the existing PRD's top-level title or project name.
- **FR-014:** Migration updates `.spec-flow.yaml` to add `layout_version: 3`. If the key already exists at a lower value, it's replaced.
- **FR-015:** Migration writes a `MIGRATION_NOTES.md` at the repo root summarizing: files moved, known stale internal references (detected via grep on moved paths in unmoved files), and recommended follow-ups. User can delete the file once reviewed.
- **FR-016:** SessionStart hook (`plugins/spec-flow/hooks/session-start.sh`) detects `layout_version` in `.spec-flow.yaml` and emits a non-blocking yellow warning when the value is absent or `<3`: "Layout is pre-v3. Run `/spec-flow:migrate` to adopt multi-PRD." Per NN-C-005, the hook is silent when `.spec-flow.yaml` is absent altogether and silent when `layout_version >= 3`; in every branch (warning emitted, silent, or genuine error) the hook exits 0 with valid JSON on stdout. No other behavior changes.
- **FR-017:** Charter reference paths remain unchanged across migration: `docs/charter/` is not moved. Charter is a prerequisite for v3 layout — migration refuses when `docs/charter/` is absent and prints a friendly message pointing at `/spec-flow:charter` (retrofit mode). Migration does not auto-create a charter; the user must run charter retrofit first.
- **FR-018:** Global backlog `docs/improvement-backlog.md` is not moved or duplicated during migration. If absent, migration creates an empty one with a header.
- **FR-019:** A piece's `docs/prds/<slug>/specs/<piece>/` folder is self-contained: `spec.md`, `plan.md`, `research/` (if present), `learnings.md`, `ac-matrix.md`. No piece artifact lives outside its piece folder except worktrees.
- **FR-020:** A PRD is archived by setting `status: archived` in its `docs/prds/<slug>/prd.md` front-matter — the folder stays in place. There is no physical move to `docs/archive/`. Archived PRDs do not appear in `/spec-flow:status`'s default view; `/spec-flow:status --include-archived` shows them. This behavior is reversible by editing the front-matter back to a live state.
- **FR-021:** `/spec-flow:execute` accepts `--ignore-deps` to proceed despite unmerged `depends_on:` entries (see FR-011). When set, execute prints a loud multi-line warning naming each ignored dependency and its current status before continuing. Aligns with NN-C-006's "explicit confirmation" posture for deliberate deviations. The flag does not bypass any other gate (per-phase QA, end-of-piece review-board) — those remain mandatory per NN-P-002.
- **FR-022:** `/spec-flow:migrate` accepts `--inspect` (alias for dry-run) which prints the full migration plan (every `git mv`, every front-matter mutation, every newly-created file) and exits 0 without prompting and without making any changes. Useful for scripted audits.
- **FR-023:** `/spec-flow:prd` validates slug uniqueness across `docs/prds/*/prd.md` front-matter `slug:` fields before writing a new PRD. On collision, the skill refuses with an error listing the colliding PRD path. When invoked greenfield with no slug argument, the skill prompts interactively for the slug — no implicit default.

### Non-Functional Requirements

- **NFR-001:** Migration completes on a repo with up to 20 pieces in under 30 seconds, excluding user confirmation time. No network calls.
- **NFR-002:** Charter-drift check during Phase-1 context load adds no more than one agent dispatch per skill invocation in the worst case (drift present). Zero dispatches when snapshots match.
- **NFR-003:** Every skill that resolved paths under `docs/specs/<piece>/` in v2 resolves paths under `docs/prds/<prd-slug>/specs/<piece>/` in v3, with identical semantic behavior when there is exactly one PRD.
- **NFR-004:** No runtime code dependencies introduced (NN-C-002). Migration skill is markdown-driven orchestration plus existing git CLI — no bash utilities beyond what charter/tools.md already lists.
- **NFR-005:** Documentation updated end-to-end: README, CHANGELOG (per Keep a Changelog — CR-006), every skill's SKILL.md, every agent's prompt mentioning path conventions, and the top-level spec-flow README migration section.
- **NFR-006:** Branch names must not contain `/` between slugs (only the single `spec/` / `plan/` / `execute/` prefix slash), keeping CI and hook pattern-matching simple.

### Non-Negotiables Honored

**Project (NN-C — from `docs/charter/non-negotiables.md`):**

- **NN-C-001** (version-marketplace sync): v3.0.0 bump updates `plugins/spec-flow/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` in the same commit. QA verification per NN-C-001's "How QA verifies" — `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json)` must produce no output post-release.
- **NN-C-002** (markdown + config only): migration is markdown + yaml edits + `git mv` shell calls. No runtime code dependencies added.
- **NN-C-003** (backward compat within major): v2.x → v3.0.0 is a major bump — breaking the layout is permitted. v3.x users are covered by future patch/minor compat guarantees.
- **NN-C-005** (hooks silent on missing optional deps): `plugins/spec-flow/hooks/session-start.sh` is silent when `.spec-flow.yaml` is absent or when `layout_version >= 3`; emits a non-blocking yellow notice when the file exists with `layout_version` absent or `<3`. In all three branches the hook exits 0 with valid JSON on stdout — meeting NN-C-005's three-scenario smoke test.
- **NN-C-006** (no destructive ops without confirmation): migration prints a dry-run plan and asks for confirmation before executing `git mv`. Refuses to run on a dirty working tree or in-flight worktrees without explicit `--force`. `/spec-flow:execute --ignore-deps` (FR-021) likewise requires the explicit flag and emits a loud warning per NN-C-006.
- **NN-C-007** (CHANGELOG in Keep a Changelog format): v3.0.0 CHANGELOG entry documents layout migration, new skill, config key, SessionStart warning, and breaking-change notes.
- **NN-C-008** (self-contained agent prompts): drift-mode `qa-spec` dispatch includes the full self-contained input bundle enumerated in FR-009 (full spec, moved charter file bodies, prior snapshot, manifest entry, PRD's NN-P section, spec's NN/CR honoring blocks). No conversation history assumed.
- **NN-C-009** (three-place version bump): v3.0.0 bump touches the NN-C-009 three places in one commit: `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and `plugins/spec-flow/CHANGELOG.md`.

**Product (NN-P — from `docs/prd/prd.md`):**

- **NN-P-001** (human-readable artifacts): all v3 artifacts remain plain markdown + YAML. Manifest, backlog, prd, spec, plan files stay hand-auditable.
- **NN-P-002** (no auto-merge — two human gates): the new `depends_on:` precondition added to `skills/execute/SKILL.md` (FR-011) only *blocks* `execute` from starting when an unmerged dependency exists. It never auto-advances past either of NN-P-002's two human sign-off gates (per-phase QA completion; end-of-piece review-board completion). Both remain mandatory and uneditable in v3.0.0.
- **NN-P-003** (dog-food before recommend): this repo itself migrates to v3 layout as part of the rollout. The migration skill runs end-to-end on `/mnt/c/ai-plugins` before v3.0.0 is documented for external users. Existing in-flight worktrees are preserved or cleanly aborted before migration. The v3.0.0 release commit message references the dog-food run by commit SHA and target-layout path (see AC-18).

### Coding Rules Honored

- **CR-001** (agent frontmatter): any new or modified agent keeps the `name` + `description` YAML schema intact.
- **CR-002** (skill frontmatter): new `/spec-flow:migrate` skill has full frontmatter (`name`, `description`, triggers per existing convention).
- **CR-003** (template placeholder syntax): path tokens in updated templates use the existing `{{placeholder}}` convention.
- **CR-004** (conventional-commits with plugin scope): every migration-related commit uses `feat(spec-flow):`, `chore(spec-flow):`, or `docs(spec-flow):` scope.
- **CR-005** (absolute file paths in docs): README/CHANGELOG/skill-doc updates mentioning files use repo-relative absolute paths.
- **CR-006** (CHANGELOG format): v3.0.0 CHANGELOG block follows Keep a Changelog structure.
- **CR-007** (config keys documented inline): `.spec-flow.yaml` template and example get inline comments for `layout_version:`.
- **CR-008** (thin-orchestrator skills / narrow-executor agents): the `migrate` skill is an orchestrator that dispatches to git (external) and optionally a narrow agent for dry-run-report generation. Drift check is a single-purpose focused-mode on existing `qa-spec`.
- **CR-009** (semantic heading hierarchy): all new docs follow H1/H2/H3 nesting rules.

## Acceptance Criteria

- **AC-1:** Given a greenfield project with `docs/charter/` and no existing PRD, When the user runs `/spec-flow:prd billing` (providing a slug), Then `docs/prds/billing/{prd.md, manifest.yaml, backlog.md}` exist with correct front-matter and `billing` PRD is in `drafting` status.
  Independent Test: initialize fresh repo → run prd skill → verify directory + file presence + front-matter fields.

- **AC-2:** Given a project with two active PRDs (`auth`, `billing`), When the user runs `/spec-flow:spec` on an `auth` piece and `/spec-flow:spec` on a `billing` piece in separate sessions, Then both pieces get distinct worktrees (`worktrees/prd-auth/piece-*/` and `worktrees/prd-billing/piece-*/`) and distinct branches (`spec/auth-*`, `spec/billing-*`), with no filesystem or git collisions.
  Independent Test: create two PRDs, open a piece under each, verify `git worktree list` + `git branch` output.

- **AC-3:** Given a v2.x project with `docs/prd/prd.md` + `docs/prd/manifest.yaml` + `docs/specs/`, When the user runs `/spec-flow:migrate auth`, Then the layout becomes `docs/prds/auth/prd.md`, `docs/prds/auth/manifest.yaml`, `docs/prds/auth/specs/*`, and `git log --follow` on any migrated file still shows the pre-migration history.
  Independent Test: take a known v2.x snapshot → run migrate → check `git log --follow` on three arbitrary files + verify content identical.

- **AC-4:** Given a v1.x project with `docs/prd.md` + `docs/manifest.yaml` + `docs/specs/`, When the user runs `/spec-flow:migrate core`, Then migration succeeds with the same history-preservation guarantee as v2.x.
  Independent Test: seed v1.x fixture → migrate → verify.

- **AC-5:** Given a project where a charter file's `last_updated:` is 2026-05-01 and a piece's `charter_snapshot:` for that file is 2026-04-15, When the user runs `/spec-flow:plan <piece>` or any downstream skill on that piece, Then the skill halts at Phase 1 with a drift finding surfaced for that file.
  Independent Test: artificially bump a charter file's `last_updated:` on a repo with existing specs → run `/spec-flow:plan <piece>` → verify drift-finding output.

- **AC-6:** Given drift exists but the new charter does not require spec changes, When the drift-mode `qa-spec` agent completes with a clean finding, Then the spec's `charter_snapshot:` values for the drifted file(s) are auto-advanced to the current charter dates, and a log line is appended to the spec.
  Independent Test: construct a no-conflict drift case → run skill → verify snapshot updated + log line present.

- **AC-7:** Given drift exists and the new charter does conflict with the existing spec, When the drift-mode agent reports must-fix findings, Then the skill halts and reports the findings to the user without auto-advancing the snapshot.
  Independent Test: construct a conflicting drift case (e.g., charter gains a new NN-C the spec violates) → run skill → verify halt + findings output.

- **AC-8:** Given a project with four PRDs (`auth` active, `billing` drafting, `reports` shipped, `legacy` with `status: archived`), When the user runs `/spec-flow:status`, Then output shows the three non-archived PRDs with their lifecycle states and piece counts, default-hiding any PRD whose `prd.md` front-matter has `status: archived`. Running `/spec-flow:status --include-archived` shows all four.
  Independent Test: seed fixture with four PRDs (one with `status: archived`) → run status with and without `--include-archived` → verify the archived PRD is hidden in the default view and shown with the flag.

- **AC-9:** Given the same project, When the user runs `/spec-flow:status billing`, Then output narrows to the `billing` PRD with piece-by-piece detail.
  Independent Test: run drill-in command → verify narrowed output.

- **AC-10:** Given a piece has `reflection-future-opportunities` and `reflection-process-retro` run at end-of-piece, When the agents complete, Then `docs/prds/<slug>/backlog.md` contains the future-opportunities findings and `docs/improvement-backlog.md` contains the process-retro findings, each appended (not overwritten).
  Independent Test: trigger a reflection run → inspect both files for new entries.

- **AC-11:** Given a piece declares `depends_on: [auth/login-flow]` and the `auth/login-flow` piece has `status: planned` (i.e., not yet merged), When the user runs `/spec-flow:execute <piece>`, Then execute refuses to start and prints which dependency is blocking and its current `status:` value. The same piece runs successfully once `auth/login-flow` reaches `status: merged` (or `status: done`).
  Independent Test: seed unmerged dependency at `status: planned` → run execute → verify refusal message names `auth/login-flow` and prints `planned`. Then advance to `status: merged` → re-run execute → verify it now starts.

- **AC-12:** Given a pre-v3 project's `.spec-flow.yaml` exists but lacks `layout_version: 3`, When any spec-flow session starts, Then SessionStart output contains the warning string "Layout is pre-v3. Run `/spec-flow:migrate` to adopt multi-PRD." and the hook exits 0. Subsequently running `/spec-flow:status`, `/spec-flow:prd`, and `/spec-flow:spec` each completes without error after the warning is emitted.
  Independent Test: open fresh session on pre-v3 repo → assert the warning string is present in the SessionStart hook stdout and exit code is 0 → run `/spec-flow:status`, then `/spec-flow:prd` (with a slug arg), then `/spec-flow:spec` → assert each invocation completes without error.

- **AC-13:** Given migration is run on a repo with uncommitted changes, or with any worktree under `worktrees/` other than the migration session's own, When the user confirms the migration plan, Then migration refuses and prints "working tree dirty — commit or stash first" (for uncommitted changes) or "in-flight worktree present — abort or `--force`" (for a sibling worktree). Migration only runs on a clean tree with no other in-flight worktrees (or explicit `--force`). "Active worktree" here means: any entry in `git worktree list` whose path is under `worktrees/` and is not the current session's own worktree.
  Independent Test: create dirty state → attempt migration → verify refusal with dirty-tree message. Add a sibling worktree → attempt migration → verify refusal with worktree message.

- **AC-14:** Given migration has run, When the user inspects `MIGRATION_NOTES.md`, Then the file lists every file moved, every grep-detected stale path reference in unmoved files, and a "what to do next" block.
  Independent Test: run migration → open notes file → verify structure.

- **AC-15:** Given this repo at HEAD with v2.x layout (`docs/prd/prd.md` + `docs/prd/manifest.yaml` + `docs/specs/`), When `/spec-flow:migrate shared-plugins` runs on a clean clone, Then the resulting target layout is `docs/prds/shared-plugins/{prd.md, manifest.yaml, specs/PI-008-multi-prd-v3.0.0/}` and `git log --follow docs/prds/shared-plugins/prd.md` shows commits predating the migration. Verifiable pre-release on a throwaway clone.
  Independent Test: clone this repo at the release-candidate SHA → run `/spec-flow:migrate shared-plugins` on the clone → assert `docs/prds/shared-plugins/prd.md`, `docs/prds/shared-plugins/manifest.yaml`, and `docs/prds/shared-plugins/specs/PI-008-multi-prd-v3.0.0/` exist → assert `git log --follow docs/prds/shared-plugins/prd.md` includes commits predating the migration commit.

- **AC-16:** Given a branch `spec/auth-token-refresh` is created, When the user inspects it, Then the total length is ≤ 50 characters and the path contains exactly one `/` separator.
  Independent Test: inspect created branch name.

- **AC-17:** Given a piece slug or PRD slug whose composition would produce a branch name longer than 50 characters or contain a character outside `[a-z0-9-]`, When the user runs `/spec-flow:spec`, `/spec-flow:plan`, or `/spec-flow:execute` on that piece, Then the skill refuses with an explicit error naming the offending slug, its current length, and the maximum allowed.
  Independent Test: seed a manifest with a piece-slug 12 chars long under a PRD-slug 9 chars long (combined branch length > 50) → run `/spec-flow:spec` → verify the skill refuses with an error naming the over-long slug.

- **AC-18:** Given v3.0.0 is being released, When the release commit is created, Then the commit message body references the dog-food migration run by both the dog-food-run commit SHA and the target layout path (`docs/prds/shared-plugins/`).
  Independent Test: `git log -1 --pretty=%B <release-tag>` and `grep` the output for the dog-food-run commit SHA and the literal string `docs/prds/shared-plugins`.

- **AC-19:** Given a project with at least one v2.x or v3.x layout, When the user runs `/spec-flow:migrate --inspect` (with or without a target slug argument), Then the skill prints the full migration plan to stdout (every `git mv`, every front-matter mutation, every newly-created file) and exits 0 without prompting and without making any filesystem changes.
  Independent Test: take a v2.x fixture → snapshot `git status` and the working tree → run `/spec-flow:migrate shared-plugins --inspect` → assert exit code 0, plan printed to stdout, post-run `git status` and tree hash identical to the snapshot (no files moved, no files created).

- **AC-20:** Given a project that already has a PRD with `slug: auth` at `docs/prds/authentication/prd.md`, When the user runs `/spec-flow:prd auth` to create a second PRD with the same slug, Then `/spec-flow:prd` refuses with an error naming the colliding PRD path and exits without creating any files.
  Independent Test: seed `docs/prds/authentication/prd.md` with `slug: auth` in front-matter → run `/spec-flow:prd auth` → assert refusal message names `docs/prds/authentication/prd.md` → assert no new directory under `docs/prds/` was created.

## Technical Approach

### Layout transition

```
# v2.x (today)
docs/
├── charter/
│   ├── architecture.md
│   ├── non-negotiables.md
│   ├── coding-rules.md
│   ├── tools.md
│   ├── processes.md
│   └── flows.md
├── prd/
│   ├── prd.md
│   └── manifest.yaml
├── specs/
│   └── <piece>/
│       ├── spec.md
│       ├── plan.md
│       └── learnings.md
├── improvement-backlog.md   # may be absent
└── archive/                 # optional

# v3.0.0 (target)
docs/
├── charter/                 # unchanged — singular across all PRDs
│   └── …
├── prds/
│   └── <prd-slug>/
│       ├── prd.md           # front-matter: slug, status, version
│       ├── manifest.yaml    # pieces with optional slug + qualified depends_on
│       ├── backlog.md       # PRD-local deferred work
│       ├── README.md        # optional: PRD elevator pitch
│       └── specs/
│           └── <piece-slug>/
│               ├── spec.md
│               ├── plan.md
│               ├── research/
│               ├── learnings.md
│               └── ac-matrix.md
└── improvement-backlog.md   # global — cross-PRD + process retros
```

A PRD is archived in place by setting `status: archived` in its `prd.md` front-matter. There is no `docs/archive/` directory in the v3 layout — `/spec-flow:status` filters archived PRDs out of the default view (see FR-020 / AC-8).

### PRD front-matter contract

```yaml
---
name: Authentication and session management
slug: auth
status: active          # drafting | active | shipped | archived
version: 1
---
```

### Manifest piece contract

```yaml
pieces:
  - name: token-refresh
    slug: tokref              # optional; defaults to kebab-cased name
    description: …
    prd_sections: [FR-010]
    dependencies: []           # legacy/same-PRD; bare piece names ok
    depends_on: []             # v3+ preferred: qualified refs list
    status: open
```

### Worktree and branch naming

- Worktree root: `worktrees/prd-<prd-slug>/piece-<piece-slug>/`
- Branches:
  - `spec/<prd-slug>-<piece-slug>`
  - `plan/<prd-slug>-<piece-slug>`
  - `execute/<prd-slug>-<piece-slug>`
- Slug length target: ≤ 10 chars each to keep branch length manageable. Validated by `spec` skill at worktree-creation time.

### Charter-drift mechanism

- Phase-1 check in `spec` (re-run on existing piece), `plan`, `execute`, and `prd` (update mode on active pieces) — plus passive surfacing in `status`.
- Algorithm:
  1. Load `docs/charter/*.md` front-matter `last_updated:` values into `charter_now`.
  2. Load piece spec's `charter_snapshot:` values into `snapshot`.
  3. For each charter file where `charter_now[file] > snapshot[file]`: mark drifted.
  4. If any drifted: dispatch `qa-spec` with `Input Mode: Focused charter re-review`, passing the full self-contained input bundle from FR-009 (full spec body, drifted charter file bodies, snapshot values, manifest entry, PRD's NN-P section, spec's NN/CR honoring blocks).
  5. Agent returns either `clean` or `must-fix`.
  6. If clean: orchestrator rewrites the spec's `charter_snapshot:` values to `charter_now` and appends a log line inside the spec body.
  7. If must-fix: orchestrator halts the current skill and prints the findings. The only forward path is amending the spec to honor the new charter (or, explicitly out of band, reverting the charter change). There is no escape hatch to accept the violation — drift findings are blocking.
- No new agent file needed — `qa-spec` gains a third `Input Mode` alongside `Full` and `Focused re-review`.

### Migration skill `/spec-flow:migrate`

- Single-phase orchestrator. No QA gate — migration is a mechanical file move, not a behavior change.
- Phases:
  1. **Detect source layout:** inspect `docs/prd.md` (v1), `docs/prd/prd.md` (v2), or `docs/prds/` (already v3). Error if ambiguous or none.
  2. **Gather inputs:** ask user for target PRD slug (or use argument). Derive default from existing PRD title. Validate slug (kebab-case, ≤ 10 chars, no slashes).
  3. **Safety checks:** refuse if working tree dirty. Refuse if active worktrees under `worktrees/` point to pre-v3 branches. `--force` overrides but prints warnings.
  4. **Dry-run plan:** print every `git mv` that will be executed + every file that will get front-matter additions. Ask for confirmation.
  5. **Execute:**
     - `git mv docs/prd docs/prds/<slug>` (v2) or `git mv docs/prd.md docs/prds/<slug>/prd.md` (v1 — with mkdir).
     - For v1 also: `git mv docs/manifest.yaml docs/prds/<slug>/manifest.yaml`.
     - `git mv docs/specs docs/prds/<slug>/specs`.
     - Inject `slug: <slug>`, `status: active`, `version: 1` into `prd.md` front-matter if missing.
     - Create `docs/prds/<slug>/backlog.md` with a header (if absent).
     - Create `docs/improvement-backlog.md` with a header (if absent).
     - Update `.spec-flow.yaml` to set `layout_version: 3`.
  6. **Scan for stale internal refs:** grep unmoved files (`README.md`, `CLAUDE.md`, top-level docs) for moved path prefixes; list findings.
  7. **Write `MIGRATION_NOTES.md`:** summary of moves, stale refs, suggested follow-ups.
  8. **Commit:** conventional-commit `chore(spec-flow): migrate docs to v3.0.0 multi-PRD layout`.

### SessionStart layout-version warning

- `plugins/spec-flow/hooks/session-start.sh` (or equivalent) reads `.spec-flow.yaml`. If `layout_version` absent or `<3`, prints a one-line yellow notice. Non-blocking. Silent if already v3 or no `.spec-flow.yaml` exists.

### Skill / agent / template update matrix

High-level impact (every file needs one pass for path resolution):

| Surface | Change type |
|---|---|
| `skills/prd/SKILL.md` | Accept `<prd-slug>` arg; write under `docs/prds/<slug>/`; update mode resolves which PRD |
| `skills/spec/SKILL.md` | Phase-1 drift check; worktree/branch naming; path resolution |
| `skills/plan/SKILL.md` | Same |
| `skills/execute/SKILL.md` | Same + `depends_on:` precondition check |
| `skills/status/SKILL.md` | Default all-PRDs view; `<slug>` drill-in; drift surfacing |
| `skills/charter/SKILL.md` | Unchanged in scope; charter stays at `docs/charter/` |
| `skills/release/SKILL.md` | No path changes (operates on plugin tree, not docs/) |
| `skills/migrate/SKILL.md` | **New** |
| `agents/qa-spec.md` | Add `Input Mode: Focused charter re-review` |
| `agents/qa-plan.md` | Path token updates |
| `agents/reflection-future-opportunities.md` | Write to `docs/prds/<slug>/backlog.md` |
| `agents/reflection-process-retro.md` | Write to `docs/improvement-backlog.md` (unchanged target) |
| `templates/spec.md` | `{{piece_slug}}`, `{{prd_slug}}` tokens |
| `templates/plan.md` | Same |
| `templates/manifest.yaml` (new) | Per-PRD skeleton |
| `templates/prd.md` | Front-matter block (slug, status, version) |

### Migration of this repo (dog-food plan)

- Current state: v2.x layout with `docs/prd/prd.md` + `docs/prd/manifest.yaml` + `docs/specs/` + one stale worktree directory (`worktrees/PI-005-copilot-cli-parity-map`, the associated branch is preserved as historical reference but the worktree itself is unused).
- Steps:
  1. Remove the stale `worktrees/PI-005-copilot-cli-parity-map` directory before migration. The associated branch `spec/PI-005-copilot-cli-parity-map` is preserved in git for reference, but the working tree is unused. Run `git worktree remove worktrees/PI-005-copilot-cli-parity-map --force` if the directory is stale. This satisfies AC-13's "no in-flight worktree other than the migration session's own" precondition.
  2. Land this PI-008 piece's implementation on an execute branch.
  3. On a dogfood branch: run `/spec-flow:migrate shared-plugins` (inferred slug — the marketplace name).
  4. Verify AC-15 passes: `git log --follow` on sampled files shows full history.
  5. Merge dogfood branch → master. Capture the migration commit SHA for AC-18.
  6. Cut v3.0.0 release (plugin.json + marketplace.json + CHANGELOG in the same commit per NN-C-001/NN-C-009). The release commit message body references the migration commit SHA from step 5 and the target layout path `docs/prds/shared-plugins/` (per AC-18 and NN-P-003).

## Testing Strategy

- **Unit:** slug validator (length, charset, reserved words); path resolver (given layout version + slugs → file paths); drift-detector (snapshot vs current → drifted set); `depends_on:` qualifier parser.
- **Integration:** fresh greenfield → run `prd`/`spec`/`plan`/`execute` cycle on two PRDs in parallel → verify no filesystem collision, both pieces land.
- **Migration fixtures:** minimal v1 fixture (flat `docs/prd.md` + `docs/manifest.yaml` + `docs/specs/x/`), minimal v2 fixture (`docs/prd/` form), edge fixture (v2 + pre-existing `docs/improvement-backlog.md`) — run `/spec-flow:migrate` on each, assert target layout and history preservation.
- **Drift scenarios:**
  - No drift → all skills proceed silently.
  - Drift, no conflict → snapshot auto-advance.
  - Drift, conflict → skill halts with must-fix.
- **Dog-food:** run migration end-to-end on this repo (AC-15). Validate every downstream skill on a post-migration piece.
- **Edge cases:** empty PRD folder; PRD with zero pieces; PRD in `archived` status; migration attempted on an already-v3 repo (should no-op with informational message).

## Open Questions

None. All originally-open questions have been resolved inline in the requirements above:

- OQ-1 (migrate `--inspect` dry-run): resolved as FR-022.
- OQ-2 (greenfield `/prd` slug prompt): resolved as FR-023.
- OQ-3 (archive location): resolved as FR-020 (in-place via front-matter; no physical move).
- OQ-4 (`--ignore-deps` on execute): resolved as FR-021.
- OQ-5 (drift-mode checks newly-added NN/CR entries): resolved as expanded FR-009 input bundle.
- OQ-6 (v1 no-manifest shape): resolved as the v0 refusal in FR-012 — pointing the user at `/spec-flow:charter` retrofit.
- OQ-7 (slug collision check at `prd` creation): resolved as FR-023.
