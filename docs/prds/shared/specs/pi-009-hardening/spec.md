---
charter_snapshot:
  architecture: 2026-04-21
  non-negotiables: 2026-04-21
  tools: 2026-04-21
  processes: 2026-04-21
  flows: 2026-04-21
  coding-rules: 2026-04-21
---

# Spec: pi-009-hardening

**PRD Sections:** FR-004, NFR-003, NFR-004
**Charter:** docs/charter/ (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** PI-008-multi-prd-v3.0.0 (merged 2026-04-25)

## Goal

Land all v3.0.0-reflection-driven follow-up work as a single coherent v3.1.0 minor release of the spec-flow plugin. Resolve four capability gaps surfaced during PI-008 (FR-005 branch-design ambiguity, lack of semantic charter-drift detection, hard-coded worktree paths, undocumented migrate-skill environment preconditions) and harden seven distinct orchestrator behaviors (Opus-QA skip predicate, mid-piece QA pass, iter-until-clean QA loops, deferred-finding tracking, plan-skill phase-sizing rule, plan-skill exit-gate semantics rule, default Python-based [Verify] commands). Ship as `spec-flow` v3.1.0 — a backwards-compatible minor bump per NN-C-003.

The bundle is intentionally large because all 11 items address the same root cause (PI-008's reflection findings) and ship the same release ceremony. Splitting them into 3+ point releases would multiply spec/plan/release overhead without isolating risk.

The `qa_iter2` retirement is a behavior change rather than a public-surface change — the config key remains parseable for backwards compatibility, only its effect is neutralized. CHANGELOG migration notes call this out for users who relied on the auto-skip throughput.

## In Scope

**Capability items (user-visible behavior):**

- **CAP-1: FR-005 branch-design resolution.** v3.0.0 spec FR-005 prescribes three branches per piece (`spec/`, `plan/`, `execute/`). Shipped code uses one shared `spec/<prd>-<piece>` branch through plan and execute. Resolve by amending FR-005 to match the shipped single-branch reality and adding ACs that pin the contract.

  Rationale: PI-008's spec text proposed three branches (`spec/`, `plan/`, `execute/`) per piece for separation of concerns. The shipped code reuses a single `spec/<prd-slug>-<piece-slug>` branch through plan and execute. Single-branch wins because (a) it matches v2's proven behavior with no observed friction, (b) AC-16/AC-17 in PI-008 already test only the `spec/` form so test coverage tracks reality, (c) every Phase Group worktree operation in plan and execute reuses the same checkout — three-branch would force checkout dance between phases without isolating risk, and (d) the squash-merge release model makes per-stage branches cosmetic rather than load-bearing for traceability. The amendment makes spec text match shipped code rather than expanding code to match aspirational spec.
- **CAP-2: Charter-drift deep scan.** Extend `/spec-flow:status` with a `--include-drift` mode that opens each spec, parses NN/CR citations from `### Non-Negotiables Honored` and `### Coding Rules Honored` blocks, and grep-verifies the cited entry IDs still exist in the current charter files. Opt-in (does not run on default `/spec-flow:status` invocation).
- **CAP-3: Worktree-token sweep.** Add a `{{worktree_root}}` template token resolved by the orchestrator from the current PRD+piece slugs. Replace hard-coded `worktrees/` references in skill-side Agent dispatch templates and skill orchestration text — specifically the `plugins/spec-flow/skills/{execute,plan,spec,status,prd,migrate}/SKILL.md` files where the orchestrator composes paths for dispatched agents.
- **CAP-4: Migrate-skill environment precondition.** Document, in `plugins/spec-flow/skills/migrate/SKILL.md` and in NFR-004 of `docs/prds/shared/prd.md`, that the migrate skill assumes an LLM-driven execution context capable of reading files and parsing YAML/JSON inline (without external tool shell-outs), plus `git` ≥ 2.5 (for `git mv`) and a POSIX shell. Path 2 (shipping an embedded helper in any specific language) is explicitly deferred — needs a separate charter brainstorm on NN-C-002 scope.

**Orchestrator items (no user-visible surface change):**

- **ORC-1: Sharpen Opus QA skip-predicate.** Skip Opus QA only when the phase's deliverable is *additive markdown / YAML / pure config*. Default to Opus QA when the phase touches shell logic, branching control flow, or ships a new skill body — regardless of LOC.
- **ORC-2: Mid-piece Opus QA pass for ≥6-phase pieces.** When a piece has ≥6 phases that all auto-skip Opus, the orchestrator inserts one mid-piece Opus pass at the half-way commit. Reviewer reads the cumulative diff vs. the spec, not just one phase's diff.
- **ORC-3: Deferred-finding tracking.** When a QA gate produces a "deferred to reflection" finding, the orchestrator appends a stub item to the PRD-local `backlog.md` at deferral time, citing the deferring reviewer + commit + verbatim finding text.
- **ORC-4: Plan-skill phase-sizing rule.** When a single phase's deliverable exceeds ~150 LOC of new behavioral prose, the plan skill's authoring path warns and recommends splitting into a Phase Group with 2-3 sub-phases. The plan author may override with a stated rationale.
- **ORC-5: Plan-skill exit-gate semantics rule.** A phase's exit gate may not downgrade from "X ran successfully" to "X is documented to run later" silently. If pre-merge execution truly isn't possible, the plan author splits the piece into two pieces (e.g., PI-N + PI-Nb).
- **ORC-6: Default LLM-native validation for [Verify] YAML/JSON checks.** Plan templates default [Verify] YAML/JSON validation to LLM-agent-native parsing — the agent reads the file with its file-reading tool and validates content inline, without shelling out to language-specific runtimes or external parsing tools (`yq`, `jq`, etc.). Eliminates the recurring tool-availability failure mode from PI-008's Phases 1 and 6 by removing the dependency on a specific external parser being on the host.
- **ORC-7: Iter-until-clean QA loop, applied universally.** Every QA gate (spec, plan, charter, execute per-phase, mid-piece Opus, Final Review fix-up) keeps iterating as long as the reviewer reports must-fix findings. Iter-1 sees the full artifact; iter-2+ is focused re-review on the fix diff. The 3-iter circuit breaker remains as the escalation guard. The `qa_iter2: auto` skip predicate is retired; a single shared reference doc (`plugins/spec-flow/reference/qa-iteration-loop.md`) defines the pattern and every QA-running skill cites it.

## Out of Scope / Non-Goals

- **Migrate-skill path 2** (embedded Python helper script under `plugins/spec-flow/skills/migrate/`). Deferred — would require a charter brainstorm on whether NN-C-002's "no runtime dependencies" rule admits embedded helpers.
- **Phase Group parallelism timing measurement.** Captured in `docs/prds/shared/backlog.md` as a data-gathering item; no instrumentation work in v3.1.0.
- **Cross-PRD dependency auto-orchestration** (`/spec-flow:status --unblocked`). Captured as v4.0 scope.
- **NN-C-001 version-sync CI** (PI-002 in manifest). Pre-existing backlog item, independent of v3.1.0 scope.
- **Second-plugin pilot** (PI-004). Pre-existing manifest item, no relation to v3.1.0.
- **NN-C-002 charter amendment.** v3.1.0 stays inside the existing NN-C-002 contract by treating the migrate skill as documentation that runs in an LLM environment; it does not introduce repo-level runtime dependencies.

## Requirements

### Functional Requirements

#### Capability

- **FR-1 (CAP-1):** v3.1.0 amends spec PI-008 FR-005 to specify a single shared `spec/<prd-slug>-<piece-slug>` branch from spec authoring through plan and execute. Three new ACs in PI-008's spec verify single-branch behavior across all three phases. Hyperlink the amendment from `docs/prds/shared/specs/PI-008-multi-prd-v3.0.0/learnings.md` (under "Future opportunities — item 1").
- **FR-2 (CAP-2):** `/spec-flow:status --include-drift` opens every `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md`, parses the `### Non-Negotiables Honored` and `### Coding Rules Honored` sections, extracts cited IDs (`NN-C-xxx`, `NN-P-xxx`, `CR-xxx`), and verifies each ID exists as a heading in the current charter file (`docs/charter/non-negotiables.md`, `docs/prds/<prd-slug>/prd.md`, `docs/charter/coding-rules.md` respectively).
- **FR-3 (CAP-2):** When `--include-drift` finds a citation referencing an ID that no longer exists in the charter (or is marked retired), it surfaces a "**Citation drift**" line in the status output naming the spec, the cited ID, and the file the ID was expected in. Default `/spec-flow:status` (without the flag) is unchanged.
- **FR-4 (CAP-3):** A new template token `{{worktree_root}}` resolves to `worktrees/prd-<prd-slug>/piece-<piece-slug>` at orchestrator render time, derived from the current piece's PRD slug + piece slug per `plugins/spec-flow/reference/v3-path-conventions.md`.
- **FR-5 (CAP-3):** All orchestrator-side `Agent({...})` invocation templates and worktree-path documentation references in `plugins/spec-flow/skills/*/SKILL.md` use `{{worktree_root}}` instead of literal `worktrees/...` paths. The token resolves to `worktrees/prd-<prd-slug>/piece-<piece-slug>` per `plugins/spec-flow/reference/v3-path-conventions.md`. Skill `## Step 0: Load Config` preamble lines documenting the `worktrees_root` config-key resolution rule are exempt from the sweep — they document the config key, not a literal worktree path.
- **FR-6 (CAP-4):** `plugins/spec-flow/skills/migrate/SKILL.md` declares an "Environment preconditions" section listing: an LLM-driven execution context with file-reading + inline YAML/JSON parsing capability (no external-tool shell-outs required), `git` ≥ 2.5 (for `git mv`), and a POSIX shell. External validators or scripting runtimes (any specific language interpreter, `yq`, `jq`) are NOT preconditions — the migrate skill is authored so every read-and-rewrite step uses the LLM agent's native parsing rather than shell-outs to language-specific tools. The section explicitly states: "These capabilities live in the LLM agent's runtime, not in the user's installed plugin."
- **FR-7 (CAP-4):** `docs/prds/shared/prd.md` NFR-004 is amended to clarify that "Documentation is the source of truth" includes documenting environment preconditions for skills that operate on user repos. The migrate skill's environment preconditions are referenced from NFR-004 by file path.

#### Orchestrator

- **FR-8 (ORC-1):** `plugins/spec-flow/skills/execute/SKILL.md` defines an Opus-QA skip predicate that returns "skip" only when the phase's diff is composed of (a) added markdown sections, (b) added or modified YAML keys, or (c) added comments and whitespace. Any phase touching scripts in any procedural language, branching control-flow constructs (conditionals, loops, short-circuit operators — pattern set extensible per language), or new skill bodies (a new file under `plugins/*/skills/*/SKILL.md`) defaults to Opus QA regardless of LOC. The initial implementation's pattern set targets shell control-flow (since spec-flow's hooks are shell scripts); pattern coverage is extended only if spec-flow ever introduces hooks or generators in another language.
- **FR-9 (ORC-2):** When a piece's plan declares ≥6 phases and the first ⌈N/2⌉ all returned "skip" from the Opus skip predicate, the orchestrator inserts one mid-piece Opus QA pass at the commit immediately following phase ⌈N/2⌉. This pass reviews the cumulative diff against the full spec and every AC, not just the most recent phase.
- **FR-10 (ORC-3):** When a QA agent's report includes the literal string `Deferred to reflection:` (case-insensitive) followed by a finding, the orchestrator (a) appends a structured stub to `docs/prds/<prd-slug>/backlog.md`, (b) cites the deferring reviewer's name, the commit SHA at deferral time, and the verbatim finding text, and (c) commits the backlog edit on the piece branch with message `chore(<piece>): record deferred QA finding`.
- **FR-11 (ORC-4):** `plugins/spec-flow/skills/plan/SKILL.md` rejects, by default, any phase whose `[Implement]` block prescribes more than 150 added lines of behavioral prose (commands, assertions, scripts) — measured by counting non-comment, non-blank lines in the phase's `[Implement]` block. The plan author may override with a `phase_size_override: <reason>` declaration in the phase's preamble; otherwise the plan skill recommends a Phase Group split.
- **FR-12 (ORC-5):** `plugins/spec-flow/skills/plan/SKILL.md` rejects any phase whose `[Verify]` exit gate string matches the pattern "is documented to run" or "deferred to release" (case-insensitive). When such a downgrade is needed, the plan author splits the piece into PI-N (skill ships) and PI-Nb (skill is run on a real project).
- **FR-13 (ORC-6):** `plugins/spec-flow/templates/plan.md`'s `[Verify]` examples for YAML/JSON validation are authored as LLM-agent steps (e.g., `Read the file at <path> and confirm it parses as valid YAML/JSON; report any error inline`) rather than as shell-outs to a language-specific parser or external tool. Existing skill SKILL.md files that prescribe `yq`/`jq` shell commands in [Verify] blocks are updated to LLM-agent-step equivalents. No specific language runtime is mandated.
- **FR-14 (ORC-7):** A new reference document `plugins/spec-flow/reference/qa-iteration-loop.md` defines the iter-until-clean pattern: iter-1 dispatches with full-input mode and the full artifact; iter-2+ dispatches with focused re-review mode and only the prior iter's fix diff; iteration continues until the reviewer reports zero must-fix findings; the 3-iter circuit breaker triggers escalation to human (not auto-stop).

  Iteration numbering: iter-N denotes the Nth dispatch of the QA reviewer agent. Between iter-N and iter-(N+1), the orchestrator dispatches `fix-doc` (for spec/plan/charter QA) or `fix-code` (for execute per-phase QA) once. The 3-iter circuit breaker fires when iter-3 returns ≥1 must-fix finding — at that point the orchestrator escalates to the human and does NOT dispatch iter-4.
- **FR-15 (ORC-7):** Every QA-running skill (`plugins/spec-flow/skills/{spec,plan,charter,execute}/SKILL.md`) cites `qa-iteration-loop.md` in its QA Loop section and removes inline iter-2-skip prose. The `qa_iter2` config key in `plugins/spec-flow/templates/pipeline-config.yaml` is **not removed**; instead a `# DEPRECATED in 3.1.0 — see plugins/spec-flow/reference/qa-iteration-loop.md` inline comment block is added above the key. The orchestrator-side change is to delete the read-and-act-on logic that reads `qa_iter2`. A CHANGELOG entry documents the deprecation.

#### Release ceremony

- **FR-16:** A single release commit bumps `plugins/spec-flow/.claude-plugin/plugin.json` `version` 3.0.0 → 3.1.0, updates `.claude-plugin/marketplace.json`'s spec-flow entry to 3.1.0, and prepends a `## [3.1.0] — YYYY-MM-DD` section to `plugins/spec-flow/CHANGELOG.md` with all 11 items grouped under Added / Changed / Removed per Keep a Changelog. (NN-C-009 three-place bump.)
- **FR-17:** `plugins/spec-flow/CHANGELOG.md`'s 3.1.0 entry includes a "Migration notes for upgraders" subsection covering: `qa_iter2` config key retirement (no user action required — the key was inert when set to `auto`), behavioral change in QA loops (more iterations expected on phases with ambiguity), and the new `--include-drift` flag.

### Non-Functional Requirements

- **NFR-1:** No new runtime dependencies under `plugins/spec-flow/` (NN-C-002). The migrate skill's environment preconditions are documented as host expectations on the LLM agent's runtime + `git` + POSIX shell, not as new project dependencies under `plugins/`.
- **NFR-2:** All v3.1.0 changes are backwards-compatible additions or behavior-equivalent improvements (NN-C-003). User projects on v3.0.0 layouts continue to work without manual changes. The `qa_iter2` config key is retained in `pipeline-config.yaml` with a `# DEPRECATED in 3.1.0 — see plugins/spec-flow/reference/qa-iteration-loop.md` inline comment block. The orchestrator no longer reads the key; users with `qa_iter2: auto` or `qa_iter2: always` in `.spec-flow.yaml` continue to load without error or warning. The behavior change (always-iterate vs. conditional skip) is documented as a release note in CHANGELOG.md per FR-17 — this is an intentional behavior improvement, not a public-surface removal: the key syntax still parses, the field still exists, only its effect is now neutralized.
- **NFR-3:** Every spec-flow-produced artifact this piece touches under `docs/` (specs, learnings, the PRD edit, the PRD-local backlog) is plain markdown / YAML. NN-P-001 binds spec-flow-pipeline-produced artifacts under `docs/`; the plugin's own internal files (`plugins/spec-flow/CHANGELOG.md`, `plugin.json`, `marketplace.json`, the new `qa-iteration-loop.md`, SKILL.md edits) are governed by NN-C-007 (CHANGELOG format) and the plugin's own conventions, not NN-P-001.
- **NFR-4:** Hooks and skills no-op silently on missing optional inputs (NN-C-005). The charter-drift deep scan returns "no drift" when there are no specs to scan; the worktree-token resolver falls back to an empty string when no piece is active and emits a warning to stderr but exits 0.

### Non-Negotiables Honored

**Project (NN-C — from `docs/charter/non-negotiables.md`):**

- **NN-C-002 (no runtime deps):** NN-C-002 binds plugin-internal runtime dependencies — files committed under `plugins/<plugin>/` that the user's project must execute. The migrate skill ships only markdown text describing operations the LLM agent performs in its own host environment when the user invokes the skill. The user's project does not gain any external-tool or language-runtime dependency at install time; the migrating LLM agent's own native capabilities (file reading, inline parsing) are what the skill leans on. This piece adds no `package.json`, `requirements.txt`, `Dockerfile`, or compiled binary under `plugins/`. CAP-4's 'Environment preconditions' section in `skills/migrate/SKILL.md` documents this distinction explicitly: 'These capabilities live in the LLM agent's runtime, not in the user's installed plugin.'
- **NN-C-003 (backwards-compat within major):** v3.1.0 adds optional behavior (`--include-drift` flag, mid-piece QA pass triggered on ≥6-phase pieces, expanded iter-until-clean loop). No public-surface item is removed except the retired `qa_iter2` config key, which was opt-in and treated as inert in user configs (silent ignore on read).
- **NN-C-005 (hooks silently no-op on missing optionals):** The worktree-token resolver and charter-drift deep scan both return cleanly when their inputs are absent. No new hook is added by this piece.
- **NN-C-008 (agent prompts self-contained):** Every prompt template touched by ORC-1, ORC-2, and CAP-3 carries all context the dispatched agent needs (skip-predicate inputs are pre-computed by the orchestrator and inlined; the mid-piece reviewer receives the cumulative diff + spec text + AC matrix; `{{worktree_root}}` is interpolated to a literal path before dispatch). No prompt assumes prior conversation state.
- **NN-C-007 (CHANGELOG in Keep a Changelog format):** v3.1.0's CHANGELOG.md entry follows Keep a Changelog format with explicit Added / Changed / Removed groupings and a Migration notes for upgraders subsection (FR-17). The 3.1.0 heading uses the `## [3.1.0] — YYYY-MM-DD` format.
- **NN-C-009 (always bump version + 3 places):** Release ceremony (FR-16, FR-17) bumps `plugin.json`, `marketplace.json`, and `CHANGELOG.md` in a single commit. CHANGELOG.md includes Added / Changed / Removed groupings.

**Product (NN-P — from `docs/prds/shared/prd.md`):**

- **NN-P-001 (artifacts human-readable):** Every spec-flow-produced artifact this piece touches under `docs/` (this spec, the upcoming plan, learnings.md, the PRD edit at `docs/prds/shared/prd.md`, and the PRD-local `backlog.md` stub format from FR-10) is plain markdown / YAML. NN-P-001 binds spec-flow-pipeline-produced artifacts under `docs/`; plugin-internal files such as `plugins/spec-flow/CHANGELOG.md`, `plugin.json`, `marketplace.json`, the new `qa-iteration-loop.md`, and SKILL.md edits are governed by NN-C-007 and plugin conventions, not NN-P-001.
- **NN-P-002 (no auto-merge without human sign-off at two gates):** The mid-piece Opus QA pass (ORC-2) is *added* before the existing per-phase QA + Final Review gates — it does not replace either, and does not bypass human sign-off. The iter-until-clean policy (ORC-7) escalates to human at the 3-iter circuit breaker rather than auto-merging on stale findings.
- **NN-P-003 (dog-food before recommend):** v3.1.0 itself runs through the v3.0.0 pipeline (this spec, the upcoming plan, the upcoming execute) before any of v3.1.0's behaviors are advertised to external users in the README. NFR-004 (CAP-4) is the only piece change that documents required dog-food behavior; v3.1.0's release commit message must reference a successful end-to-end run on this repo.

### Coding Rules Honored

- **CR-002 (skill frontmatter schema):** All edited SKILL.md files retain `name:` and `description:` frontmatter; new reference doc `qa-iteration-loop.md` uses standard markdown without frontmatter (it is a reference, not a skill).
- **CR-005 (repo-root-relative paths in docs):** Every file path in this spec is relative to repo root. The new `{{worktree_root}}` token resolves to repo-root-relative paths.
- **CR-006 (CHANGELOG format — Keep a Changelog):** CHANGELOG.md edits follow Keep a Changelog 1.1.0 (the source CR-006 references).
- **CR-007 (config keys documented inline):** The `qa_iter2` config key remains in `plugins/spec-flow/templates/pipeline-config.yaml` with a `# DEPRECATED in 3.1.0 — see plugins/spec-flow/reference/qa-iteration-loop.md` inline comment block per CR-007's binding rule that 'config keys have inline comments explaining purpose, valid values, default, and rationale.' The deprecation comment cites the new reference doc and explains why the key's effect is neutralized.
- **CR-008 (skills orchestrate, agents execute):** All ORC-* changes preserve the orchestrator/executor split. The new mid-piece QA pass dispatches a fresh `qa-phase` Opus agent — it does not introduce skill-side QA logic. The deferred-finding tracking is orchestrator-side; agents only emit the `Deferred to reflection:` marker and the orchestrator does the bookkeeping.
- **CR-009 (heading hierarchy):** New reference doc and amended SKILL.md files preserve the existing H1 / H2 / H3 / H4 hierarchy. The Phase Scheduler's `### Phase N:` and `#### Sub-Phase N.m:` anchors in `templates/plan.md` are unchanged in level.

## Acceptance Criteria

### Capability

- **AC-1 (CAP-1, FR-1):** Given the v3.0.0 PI-008 spec is checked out from `master`, When a v3.1.0 amendment commit is applied, Then PI-008's spec.md FR-005 reads "single shared `spec/<prd-slug>-<piece-slug>` branch through spec, plan, and execute" and contains three new ACs (AC-21, AC-22, AC-23) that pin single-branch behavior at each pipeline stage.
  - *Independent test:* `grep -c "single shared" docs/prds/shared/specs/PI-008-multi-prd-v3.0.0/spec.md` returns ≥ 1; `grep -c "AC-2[123]" docs/prds/shared/specs/PI-008-multi-prd-v3.0.0/spec.md` returns 3.

- **AC-2 (CAP-2, FR-2, FR-3):** Given a `docs/prds/shared/specs/<piece>/spec.md` cites `NN-C-099` (a non-existent ID) in its `### Non-Negotiables Honored` section, When `/spec-flow:status --include-drift` runs, Then the output contains a "Citation drift" line naming the spec path, the offending ID, and the expected charter file.
  - *Independent test:* On a synthetic spec with a planted bad citation, the status skill's `--include-drift` invocation prints exactly one drift line and exits non-zero.

- **AC-3 (CAP-2):** Given no spec contains a stale citation, When `/spec-flow:status --include-drift` runs, Then the output reports "No citation drift detected across N specs" where N is the count of specs scanned, and exits 0.

- **AC-4 (CAP-3, FR-4, FR-5):** Given the worktree at `worktrees/prd-shared/piece-pi-009-hardening`, When the orchestrator dispatches an `implementer` agent, Then the agent prompt contains zero literal occurrences of `worktrees/prd-` and at least one `{{worktree_root}}` placeholder (or its rendered value `worktrees/prd-shared/piece-pi-009-hardening`).
  - *Independent test:* After the worktree-token sweep, `grep -E 'worktrees/(prd|<prd|prd-)' plugins/spec-flow/skills/{execute,plan,spec,status,prd,migrate}/SKILL.md` returns matches only on lines that (a) define the v3 convention itself with the explicit pattern `worktrees/prd-<prd-slug>/piece-<piece-slug>/`, (b) reference `plugins/spec-flow/reference/v3-path-conventions.md`, or (c) document the `worktrees_root` config-key resolution rule in the skill's `## Step 0: Load Config` preamble. All Agent({prompt: ...}) dispatch templates and per-piece path interpolations use `{{worktree_root}}`.

- **AC-5 (CAP-4, FR-6, FR-7):** Given `plugins/spec-flow/skills/migrate/SKILL.md` is open, Then it contains a section heading "## Environment preconditions" naming three host-side capabilities: (a) an LLM-driven execution context with file-reading and inline YAML/JSON parsing, (b) `git` ≥ 2.5 (for `git mv`), and (c) a POSIX shell. The section explicitly notes that no specific language runtime or external parsing tool is required.
  - *Independent test:* `grep -A 10 "Environment preconditions" plugins/spec-flow/skills/migrate/SKILL.md | grep -E "git|POSIX|LLM"` returns matches for all three anchors. `grep -A 10 "Environment preconditions" plugins/spec-flow/skills/migrate/SKILL.md | grep -E "no specific language runtime|no external"` returns ≥ 1 match confirming the agnostic framing is explicit.

- **AC-6 (CAP-4):** Given `docs/prds/shared/prd.md`, Then NFR-004 mentions `plugins/spec-flow/skills/migrate/SKILL.md` by file path and clarifies that documenting environment preconditions is part of "Documentation is the source of truth."
  - *Independent test:* `grep -A 3 "NFR-004" docs/prds/shared/prd.md | grep "skills/migrate/SKILL.md"` returns at least one match.

### Orchestrator

- **AC-7 (ORC-1, FR-8):** Given a phase whose diff contains a new shell-control-flow construct (conditional, loop, or short-circuit operator) in a hook script, or ships a new skill body file, When the orchestrator's skip-predicate is invoked, Then the predicate returns "do not skip" (route to Opus QA). The predicate's pattern set is currently scoped to shell-style constructs because spec-flow's hooks are shell scripts; the predicate is extensible if spec-flow ever adopts hooks in another language.
  - *Independent test:* Three synthetic diffs — (a) only added markdown headings, (b) a hook diff adding a control-flow construct (e.g., a conditional block), (c) a new `SKILL.md` file — produce skip-predicate outcomes [skip, do-not-skip, do-not-skip].

- **AC-8 (ORC-2, FR-9):** Given a plan with 6 phases whose first 3 all returned "skip" from the Opus skip-predicate, When phase 3 commits, Then the orchestrator dispatches a mid-piece Opus QA pass before phase 4 begins, with the cumulative diff (commits 1..3) and the full spec attached to the prompt.
  - *Independent test:* On a 6-phase plan where phases 1–3 all skip Opus, a mid-piece pass dispatch is recorded in the orchestrator's session log between phase 3 and phase 4. The dispatch's prompt contains both `git diff <merge-base>..HEAD` output and the spec.md text.

- **AC-9 (ORC-3, FR-10):** Given a QA agent report containing `Deferred to reflection: spec FR-005 single-branch ambiguity unresolved`, When the orchestrator parses the report, Then the orchestrator (a) appends a stub starting with `## [Deferred QA finding]` to `docs/prds/<prd-slug>/backlog.md`, (b) the stub cites the deferring reviewer's agent name and the current HEAD commit SHA, and (c) commits the backlog edit on the piece branch.
  - *Independent test:* On a synthetic agent-report file containing the marker string, the orchestrator's parsing routine produces a backlog file diff matching the expected stub format and a commit on the current branch.

- **AC-10 (ORC-4, FR-11):** Given a plan whose Phase 4 `[Implement]` block contains 250 non-blank lines of behavioral prose, When the plan skill's authoring path runs, Then the skill emits a warning naming Phase 4 and recommending a Phase Group split, and the warning includes the LOC count (250) and the threshold (150).
  - *Independent test:* On a synthetic plan.md draft with a 250-LOC Phase 4 [Implement] block, the plan-skill warning output contains the substring "Phase 4: 250 lines of behavioral prose exceeds 150-line threshold; recommend split."

- **AC-11 (ORC-5, FR-12):** Given a plan with a phase whose `[Verify]` block reads "AC-15 is documented to run at release time", When the plan skill validates the plan, Then validation fails with an error naming the phase and citing FR-12. Plan authoring cannot proceed until the phase is rewritten or the piece is split.
  - *Independent test:* On a synthetic plan.md with the offending [Verify] string, the plan-skill validator returns non-zero and the error message contains "exit-gate downgrade not allowed."

- **AC-12 (ORC-6, FR-13):** Given `plugins/spec-flow/templates/plan.md`, Then no `[Verify]` example block invokes `yq`, `jq`, or any other external parser/runtime as the YAML/JSON validator. Every YAML/JSON validation example is authored as an LLM-agent step (e.g., `Read the file at <path> and confirm it parses as valid YAML; report any error inline`).
  - *Independent test:* `grep -E "(yq|jq)( |$)" plugins/spec-flow/templates/plan.md` returns zero matches inside `[Verify]` blocks. Additionally `grep -E "Read the file at|parses as valid (YAML|JSON)" plugins/spec-flow/templates/plan.md` returns ≥ 1 match per `[Verify]` example block, demonstrating LLM-agent-step framing.

- **AC-13 (ORC-7, FR-14):** Given `plugins/spec-flow/reference/qa-iteration-loop.md` is open, Then it specifies (a) iter-1 input mode = "Full" with the full artifact, (b) iter-2+ input mode = "Focused re-review" with only the prior iter's fix diff, (c) iteration continues until reviewer reports zero must-fix findings, and (d) 3-iter circuit breaker escalates to human.
  - *Independent test:* `grep -E "iter-1|iter-2|circuit breaker|focused re-review|iter-N|fix-doc dispatch|iter-3|iteration numbering" plugins/spec-flow/reference/qa-iteration-loop.md` returns matches for all anchors including the iteration-numbering paragraph.

- **AC-14 (ORC-7, FR-15):** Given each of `plugins/spec-flow/skills/{spec,plan,charter,execute}/SKILL.md`, Then each cites `plugins/spec-flow/reference/qa-iteration-loop.md` by relative path in its QA Loop section. The phrase `qa_iter2: auto` does not appear in any SKILL.md.
  - *Independent test:* `grep -l "qa-iteration-loop.md" plugins/spec-flow/skills/{spec,plan,charter,execute}/SKILL.md` returns all four file paths; `grep -r "qa_iter2: auto" plugins/spec-flow/skills/` returns zero matches.

### Release ceremony

- **AC-15 (FR-16):** Given the merge commit for v3.1.0, When `git diff <merge-base>..HEAD -- plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/spec-flow/CHANGELOG.md` is run, Then exactly three files show diffs: `plugin.json` version 3.0.0 → 3.1.0, `marketplace.json` spec-flow entry version 3.0.0 → 3.1.0, and a new `## [3.1.0]` section at the top of `CHANGELOG.md`.
  - *Independent test:* The three diffs are present in a single commit (or coherent commit series) and the version strings match exactly.

- **AC-16 (FR-17):** Given the v3.1.0 CHANGELOG entry, Then it contains a "Migration notes for upgraders" subsection mentioning the `qa_iter2` retirement, the iter-until-clean behavioral change, and the `--include-drift` addition.
  - *Independent test:* `grep -A 30 "## \[3.1.0\]" plugins/spec-flow/CHANGELOG.md | grep -E "Migration|qa_iter2|include-drift"` returns matches for all three anchors.

- **AC-17 (NN-P-003):** Given the v3.1.0 release commit, When examined, Then (a) the release commit message references `docs/prds/shared/specs/pi-009-hardening/learnings.md` as the dog-food evidence artifact, and (b) `learnings.md` exists at that path with end-of-piece reflection content covering all 12 sub-phases (Group A.1–A.4, B.1–B.4, C.1–C.3, Phase D) — including for each sub-phase at minimum a heading naming the sub-phase and a "what worked / what didn't" entry. The squash-merge model collapses the 12 sub-phase commits into one release commit per CAP-1(d), so `learnings.md` is the squash-merge-stable artifact carrying the dog-food evidence.
  - *Independent test:* All four checks must pass: (1) `git show <release-commit> --format=%B` includes the literal substring `pi-009-hardening/learnings.md`. (2) `grep -cE "^#+ .*(Group [ABC]\.[0-9]+|Phase D)" docs/prds/shared/specs/pi-009-hardening/learnings.md` returns ≥ 12 — one Markdown heading per sub-phase, not running prose. (3) `grep -cE "what (worked|didn'?t)" docs/prds/shared/specs/pi-009-hardening/learnings.md` returns ≥ 12 — at minimum one what-worked-or-what-didn't entry per sub-phase (combined "What worked / What didn't" entries on a single line count as one match per the author's choice). (4) The file is non-empty and the byte count exceeds 1 KB, ruling out the degenerate "12 stub headings + nothing else" case.

## Technical Approach

### Phase decomposition (preview — refined in plan)

Three Phase Groups expected; per ORC-4, none of the items individually exceeds the 150-LOC threshold:

- **Group A — Capability (CAP-1, CAP-2, CAP-3, CAP-4):** Independent file targets; can run in parallel. Sub-phases:
  - A.1 PI-008 spec amendment (FR-1) — small markdown diff
  - A.2 status-skill `--include-drift` mode (FR-2, FR-3) — adds CLI flag handling + grep loop
  - A.3 worktree-token resolver + sweep (FR-4, FR-5) — orchestrator-side token + SKILL.md sweep across `plugins/spec-flow/skills/{execute,plan,spec,status,prd,migrate}/SKILL.md`
  - A.4 migrate-skill environment precondition section (FR-6, FR-7) — adds section to SKILL.md and amends NFR-004
- **Group B — Orchestrator behaviors (ORC-1, ORC-2, ORC-3, ORC-7):** All edit `skills/execute/SKILL.md` and the `qa-phase`/`qa-phase-lite` agent prompts. Sequential because they share the same files.
  - B.1 Skip-predicate sharpening (FR-8)
  - B.2 Mid-piece Opus QA pass (FR-9)
  - B.3 Deferred-finding tracking (FR-10)
  - B.4 Iter-until-clean reference doc + skill citations (FR-14, FR-15)
- **Group C — Plan-skill rules + LLM-native [Verify] default (ORC-4, ORC-5, ORC-6):** All edit `skills/plan/SKILL.md` + `templates/plan.md`. Sequential.
  - C.1 Phase-sizing rule (FR-11)
  - C.2 Exit-gate semantics rule (FR-12)
  - C.3 LLM-agent-step default in [Verify] examples (FR-13)
- **Phase D — Release ceremony (FR-16, FR-17):** Single phase; bumps version + marketplace + CHANGELOG; merges feature branch; tags. Run last.

### Data flow and key files touched

- **`plugins/spec-flow/skills/execute/SKILL.md`** — receives ORC-1/ORC-2/ORC-3/ORC-7 edits (~120 lines added).
- **`plugins/spec-flow/skills/plan/SKILL.md`** — receives ORC-4/ORC-5/ORC-6 edits (~80 lines added).
- **`plugins/spec-flow/skills/status/SKILL.md`** — adds `--include-drift` parsing + scan loop (~60 lines added).
- **`plugins/spec-flow/skills/{spec,plan,charter,execute}/SKILL.md`** — each adds 1-2 lines citing `qa-iteration-loop.md` and removes inline iter-2-skip prose.
- **`plugins/spec-flow/skills/migrate/SKILL.md`** — adds "Environment preconditions" section (~25 lines).
- **`plugins/spec-flow/reference/qa-iteration-loop.md`** — NEW, ~80 lines.
- **`plugins/spec-flow/templates/plan.md`** — replaces `yq`/`jq` shell-out examples with LLM-agent-step framing (~10 line edits).
- **`plugins/spec-flow/templates/pipeline-config.yaml`** — retains `qa_iter2` key with `# DEPRECATED in 3.1.0` comment block citing `qa-iteration-loop.md`; orchestrator-side read-and-act-on logic is removed (~6 line comment update + read-logic removal).
- **`plugins/spec-flow/skills/{execute,plan,spec,status,prd,migrate}/SKILL.md`** — `worktrees/` → `{{worktree_root}}` sweep across 6 SKILL.md files (orchestrator-side Agent dispatch templates + worktree-path documentation references).
- **`plugins/spec-flow/.claude-plugin/plugin.json`** — version 3.0.0 → 3.1.0.
- **`.claude-plugin/marketplace.json`** — spec-flow entry version 3.0.0 → 3.1.0.
- **`plugins/spec-flow/CHANGELOG.md`** — prepend `## [3.1.0]` section.
- **`docs/prds/shared/specs/PI-008-multi-prd-v3.0.0/spec.md`** — FR-005 amendment + AC-21/22/23 (CAP-1).
- **`docs/prds/shared/prd.md`** — NFR-004 amendment (CAP-4).

### Architectural constraints

- **CR-008 separation:** All "skill-side" changes are orchestration logic (config parsing, dispatch decisions, predicate evaluation). All "agent-side" changes are prompt-template content. Skills do not gain implementation logic; agents do not gain orchestration logic.
- **NN-C-008 self-contained prompts:** The mid-piece QA pass receives the cumulative diff + full spec text in its prompt. It does not assume access to per-phase QA reports or session history.
- **Backwards-compat for `qa_iter2`:** A user `.spec-flow.yaml` containing `qa_iter2: auto` after upgrade does not error — the orchestrator simply doesn't read the key. The CHANGELOG migration note explains this.

## Testing Strategy

### Unit / structural

- Skip-predicate (FR-8): three synthetic diffs covering markdown-only, shell-control-flow, and new SKILL.md → predicate outcomes verified.
- Plan-skill phase-sizing rule (FR-11): synthetic plan.md with 250-line `[Implement]` block → warning emitted with correct LOC counts.
- Plan-skill exit-gate validator (FR-12): synthetic plan.md with downgrade pattern → validator rejects.
- LLM-agent-step replacement (FR-13): grep on `templates/plan.md` proves no `yq`/`jq` (or other external-parser shell-outs) survive in `[Verify]` blocks; LLM-agent-step framing is present in every YAML/JSON validation example.
- QA-loop reference doc structure (FR-14): grep verifies the four required anchors.

### Integration

- `--include-drift` end-to-end (FR-2, FR-3): synthetic spec with planted bad citation → status output contains exactly one drift line, exit code non-zero. Synthetic spec with valid citations → "No citation drift" + exit 0.
- Mid-piece QA pass dispatch (FR-9): synthetic 6-phase plan where phases 1–3 skip Opus → orchestrator dispatch log shows a mid-piece pass between phase 3 commit and phase 4 dispatch.
- Deferred-finding tracking (FR-10): synthetic agent report with `Deferred to reflection:` marker → backlog file diff matches expected stub; commit message matches `chore(<piece>): record deferred QA finding`.
- Iter-until-clean loop (FR-14): synthetic QA agent that returns 2 must-fix findings on iter-1, 1 on iter-2, 0 on iter-3 → loop exits cleanly at iter-3, no auto-stop in between.

### End-to-end / dog-food

- This piece is itself the dog-food run for v3.1.0 (NN-P-003). The plan-execute cycle for pi-009-hardening exercises:
  - Iter-until-clean QA loops (every QA gate iterates to clean before advancing).
  - Sharpened skip-predicate (verify Phase B.1's hook control-flow edit triggers Opus QA, not skip).
  - Mid-piece Opus QA pass (this piece has 12 sub-phases (4+4+3+1) across 3 Phase Groups + 1 release phase; mid-piece pass triggers around sub-phase 6).
  - Worktree-token sweep (the agent prompts dispatched in Group B already use `{{worktree_root}}`).
  - Plan-skill rules (the plan for this piece must obey FR-11/FR-12/FR-13 itself).
- Release commit message (AC-17) cites this dog-food run.

### Edge cases to cover

- A spec citing a charter ID that exists but in a *different* charter file (e.g., NN-C-007 cited under "Coding Rules Honored" instead of "Non-Negotiables Honored"). Behavior: drift report flags the misplacement.
- A piece with exactly 5 phases that all auto-skip Opus → no mid-piece pass dispatched (threshold is ≥6).
- A piece with 6 phases where phases 1–3 skip but phase 4 routes to Opus → mid-piece pass still dispatches *after* phase 3, regardless of phase 4's predicate outcome.
- A `Deferred to reflection:` marker appearing in a non-QA agent report (e.g., implementer report) — orchestrator ignores it; only QA-agent reports trigger the stub.
- A user `.spec-flow.yaml` with `qa_iter2: always` (legacy override) — silently ignored after upgrade; no warning.
- The worktree-token resolver invoked outside a piece worktree (e.g., on master) — emits stderr warning, returns empty string, exits 0.
- A Phase Group whose sub-phases collectively exceed 150 LOC even though each is individually under — phase-sizing rule applies per sub-phase, not per group.

## Open Questions

(none — all path-picks resolved during scoping. Both the FR-005 single-branch decision and the migrate-skill path-1 decision are settled per the In Scope section above.)
