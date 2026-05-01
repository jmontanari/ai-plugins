# Changelog

All notable changes to the `spec-flow` plugin. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the plugin uses [Semantic Versioning](https://semver.org/).

## [3.7.2] — 2026-05-01

### Fixed

- **plan skill — per-file exit criteria in `[Implement]` blocks:** when a phase modifies multiple files of the same class (e.g., N playbooks each requiring FQCN + when guard + assert), the plan must enumerate per-file exit criteria rather than a class-level description. A class-level description alone causes the implementer to apply the constraint to the first file and skip it on the rest.
- **plan skill — wrapper/consumer test suites in `[Verify]` blocks:** when the modified component is consumed by a wrapper or sibling with its own test suite (e.g., an Ansible role consumed by a wrapper role with its own molecule suite), the `[Verify]` block must name ALL suites that must pass — not just the suite of the directly modified component. Failure to do so lets phases pass Verify while wrapper-role tests remain broken.
- **spec skill — codebase conventions section:** Phase 2 brainstorm now includes step 3a: scan 2-3 peer components to identify empirical conventions that differ from generic framework docs, confirm with user, and document in a `### Codebase Conventions` section. Prevents spec-compliance reviewers from flagging valid project-idiomatic patterns (e.g., galaxy_info wrapper in meta/main.yml used by 50+ peer roles) as violations.
- **execute skill — technology behavior preamble for fix-code dispatches:** per-phase QA loop (Step 6) and Final Review fix loop (Step 3) now inject a `## Platform behavior` block from the spec's `## Technology Notes` / `### Behavior Notes` section before the findings list in every fix-code prompt. Prevents regression cascades where the fix agent introduces new bugs on well-known platform idioms (e.g., Ansible: set_fact always returns ok; notify requires a task that reports changed; always: runs before rescue).

## [3.7.1] — 2026-05-01

### Fixed

- **plan skill:** `integrations.md` is now read during Phase 1 charter exploration whenever it exists. Any phase touching external services, APIs, SDKs, or third-party libraries must follow the principles defined there (naming conventions, hierarchy rules, status transitions, notes) — treated as non-negotiables for that scope. Previously the file was only loaded for issue-tracker config (Step 0 enabled gate); its broader design principles were silently skipped during plan authoring.
- **charter non-negotiables (NN-C-009):** updated "three places" rule to "all version-bearing files"; plugins that co-ship for multiple hosts must bump all host descriptors. Added pointer to `plugins/<plugin>/docs/releasing.md`.
- **spec-flow releasing.md (new):** authoritative 4-file checklist (`plugin.json`, `.claude-plugin/plugin.json`, `marketplace.json`, `CHANGELOG.md`) with quick-verify shell snippet and instructions for adding future version-bearing files.

## [3.7.0] — 2026-05-01

### Changed

- **Branch model: 3-verb-prefix branches → single `piece/<slug>` branch** (#pi-012). The `spec/<slug>`, `plan/<slug>`, and `execute/<slug>` per-phase branches are replaced by a single `piece/<prd-slug>-<piece-slug>` branch that persists for the full pipeline lifetime of a piece. The spec skill creates the branch and worktree once; plan and execute inherit both. One PR per piece, opened after execute completes. The `migrate/` branch convention is unchanged.
- **execute Step 5.5**: Now writes `merged_at: <YYYY-MM-DD>` alongside `status: merged` in the manifest. Commit message changed to `chore(manifest): mark <piece> as merged`. Step 5.5 is now explicitly marked as a mandatory gate — the piece branch must not be pushed or a PR opened before this commit is made.
- **status skill Step 1**: Worktree scan primary pattern updated to `piece/<slug>`. Legacy verb-prefixed branches (`spec/`, `plan/`, `execute/`) remain detected for backward compatibility and are shown with a `(legacy)` annotation.
- **status skill Step 4**: Added stale-in-progress guard — when a piece shows `in-progress` in the manifest but no active worktree is found, it is displayed as `⚠ stale-in-progress` with a remediation hint (`set status: merged, merged_at: <date>`). Passive surface only (NN-C-005).
- **status skill Step 7 drill-in**: Simplified display from three separate branch-presence columns (spec ✓/—, plan ✓/—, execute ✓/—) to a single `Branch: piece/<slug> (stage: …)` line.
- **slug-validator**: Updated branch format docs, worked examples (`spec/auth-tokref` → `piece/auth-tokref`, 17 chars), worst-case calc (`piece/<20>-<20>` = 47 chars), and Where Invoked list (plan and execute no longer create branches).
- **v3-path-conventions**: Branch row updated from `<verb>/<prd-slug>-<piece-slug>` to `piece/<prd-slug>-<piece-slug>` with a note that all pipeline stages share the branch.

### Migration notes for upgraders

- **Existing pieces mid-pipeline** (on a legacy verb-prefixed branch) continue to work — the status skill detects them with backward-compat pattern matching. To migrate, run `git branch -m spec/<slug> piece/<slug>` (or `plan/`, `execute/`) inside the worktree. New pieces automatically use `piece/<slug>`.
- **Step 5.5 now writes `merged_at:`** — projects that parse the manifest YAML for `status: merged` are unaffected. Projects that compare manifest fields may need to handle the new `merged_at` field.



### Added
- **`/spec-flow:defer` skill** — sole supported path for writing to backlog files. Records source piece, source phase, finding text, operator's rationale for non-blocking, and capture date. Invoked structured (from execute Step 6c after operator chooses defer) or manually (`/spec-flow:defer "<finding>" --rationale "<text>"`).
- **`plan-amend` agent** — Sonnet agent dispatched by execute Step 6c when operator chooses to amend the plan. Emits a unified diff inserting suffix-named amendment phases (`phase_<N>_amend_<K>`).
- **`spec-amend` agent** — Sonnet agent dispatched when a discovery implies the spec was wrong. Emits unified diffs adding FRs / ACs / NFRs within the piece's stated goals.
- **`Step 6c: Discovery Triage`** in execute/SKILL.md — synchronous discovery triage at end-of-phase. Aggregates discoveries from per-phase QA gate, AC matrix `requires-amendment` rows, Build oracle escalations. Each discovery gets operator triage: amend / fork / defer.
- **`Step 8: Final Review Triage`** in execute/SKILL.md — re-invokes Step 6c for end-of-piece Final Review must-fix findings. Amendment phases use `phase_final_amend_<K>` IDs.
- **`Step G9c: Group Discovery Triage`** in execute/SKILL.md — discovery triage step in the Phase Group Loop, between Group Deep QA and the group progress commit. Aggregates sub-phase discoveries and routes through Step 6c.
- **AC matrix `Reason:` field** for `NOT COVERED — deferred to ...` rows — required values: `does-not-block-goal`, `requires-amendment`, `requires-fork`. See `plugins/spec-flow/reference/ac-matrix-contract.md`.
- **`.discovery-log.md`** per-piece artifact — committed to `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md`. Records every discovery and its triage outcome.
- **`legacy_deferred_rows: true` opt-in flag** in plan front-matter — preserves pre-3.6.0 AC matrix behavior for one release. Deprecated; will be retired in v3.7.0.
- **`depends_on:` precondition checks** in `/spec-flow:spec` and `/spec-flow:plan` — surface unmet dependencies at spec/plan time. Three options: pull-deps-in / fork / proceed (operator override).
- **`plugins/spec-flow/reference/ac-matrix-contract.md`** — new reference doc factoring the AC matrix schema + parsing rules.
- **`plugins/spec-flow/reference/depends-on-precondition.md`** — new reference doc factoring the depends_on resolution + triage rules. Cited by spec, plan, and execute skills.

### Changed
- **execute Step 4.5 (reflection)** — reflection agents now emit findings to the orchestrator instead of writing directly to backlog files. The orchestrator dispatches Step 6c triage on receipt.
- **execute Step 6a** — Auto-write of `Deferred to reflection:` findings removed; those findings flow into Step 6c aggregation. Backlog writes go through `/spec-flow:defer` only after operator chooses defer.
- **per-piece amendment budget** — 2 amendments per piece, with at most 1 being a spec amendment. Hitting the budget triggers the orchestrator escalation.

### Removed
- The reflection-step commit message pattern `reflection: <piece> — append findings to backlogs` no longer occurs (the reflection step itself produces no commits in v3.6.0+).

### Migration notes for upgraders
- **Existing backlog entries are grandfathered.** No automatic triage; they remain in `<docs_root>/prds/<prd-slug>/backlog.md` and `<docs_root>/improvement-backlog.md` as-is.
- **Plans authored under v3.5.x continue to work.** Bare `NOT COVERED — deferred` rows are still accepted for one release if the plan sets `legacy_deferred_rows: true` in its front-matter. v3.7.0 will retire the flag.
- **Behavioral change in QA + reflection.** Discoveries that previously flowed silently to backlog files now surface as triage prompts at end-of-phase.

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

## [3.4.1] — 2026-04-30

### Added

- **`intake` skill — work intake and triage for spec-flow sessions.** A new skill that classifies incoming work at session start and routes it to the right pipeline stage, branch, and context layer before any file operations begin.

  **Problem it solves:** Sessions that start with ambiguous requests ("fix this test", "update X") had no mechanism to determine whether the work belonged to the active piece, a different PRD, a hotfix, or pure exploration. This caused agents to operate from the wrong branch, skip charter constraints, or jump into execution without the correct spec/plan context loaded.

  **Classification tree:** Intake walks a short decision tree (Q1–Q6, short-circuits at first clear signal) to determine one of five work types:

  | type | Charter | Spec/plan context | Worktree CWD |
  |---|---|---|---|
  | `plan-scoped` | All NNs + CRs | Spec ACs + current phase | Required |
  | `pipeline-entry` | All NNs + CRs | Being created | New (by target skill) |
  | `hotfix` | All NNs + CRs | None | Main or hotfix branch |
  | `charter` | All NNs + CRs | None | Main repo |
  | `exploratory` | None | None | No constraint |

  Charter NNs and CRs are loaded for every type except pure read-only exploration — they apply to all work in the repo, not just pipeline work.

  **Auto-classification:** Unambiguous message signals (piece name, branch reference, spec path, "hotfix", "explore") skip the question tree entirely.

  **Produces a `work_context` record** written to session state that subsequent turns can reference for consistent enforcement across a session.

  **Branch strategy for standalone work:** Hotfix and regression tracks ask which branch to target (current, new hotfix off main, or existing) and whether to create a Jira ticket.

- **`session-start` hook: active worktree detection.** The hook now runs `git worktree list --porcelain` at session start and injects an `⚡ ACTIVE SPEC-FLOW WORKTREE` block into the session context when a spec-flow branch (`spec|plan|execute/*`) is found. The injected block names the worktree path and branch, and states the required `cd` before any file operation. This surfaces the CWD requirement before the agent reads the first user message, closing the gap where agents continued operating from the main repo root despite an active worktree.

- **`session-start` hook: IMPORTANT message updated.** The session-start instruction now reads "invoke the `intake` skill" in place of "invoke the `status` skill". The `intake` skill calls `status` internally, so status remains the first step — but intake is the correct entry point when work is about to begin.

## [3.4.0] — 2026-04-29

### Added

- **Optional MCP-only issue tracker integration.** Adds flag-driven, zero-breaking-change integration with external issue trackers (Jira, Linear, GitHub Issues, Azure DevOps, or any custom provider) using MCP tools exclusively — no hardcoded API calls.

  **Config:** Add `integrations.issue_tracker.enabled: true` to `.spec-flow.yaml`. All other keys are optional with sensible defaults. See the commented schema block in the updated `templates/pipeline-config.yaml`.

  **MCP capability check:** Before every integration step, skills verify that the required MCP tools are available. Missing tools emit a named `⚠️ INTEGRATION WARNING` and skip the step — the pipeline never fails because of integration unavailability. See `plugins/spec-flow/reference/integration-capability-check.md` for the full algorithm and per-provider default tool names.

  **Skill integration points:**
  - `spec`: creates a "Write Spec" task before brainstorm (if `auto_create_tasks: true`); at sign-off transitions the spec task to Done and creates a "Write Plan" task.
  - `plan`: transitions the plan task to In Progress at authoring start; at sign-off creates per-phase tasks and records their keys as `jira_task:` inline in plan.md.
  - `execute`: at each phase start reads `jira_task:` from plan.md, transitions the task to In Progress, and injects the issue key into commit messages via `commit_tag_format`; after phase QA passes, transitions to In Review; after Final Review Board passes, transitions all phase tasks to Done before merge.
  - `status`: in drill-in and default views, fetches live issue status for in-progress pieces that have `jira_task:` keys in plan.md and displays them as `Issues: PROJ-42 [In Progress]`.

  **New files:**
  - `plugins/spec-flow/reference/integration-capability-check.md` — MCP check pattern, provider defaults, graceful-degradation modes.
  - `plugins/spec-flow/templates/charter/integrations.md` — fillable integration rules template (task naming, status transitions, commit format, issue hierarchy).

  **Zero breaking changes:** absent or disabled `integrations:` block = identical behavior to v3.3.x.

## [3.3.1] — 2026-04-28

### Fixed

- **`session-start` hook invalid JSON.** `session_context` contained `\${CLAUDE_PLUGIN_ROOT}` (a `\$` escape sequence that is invalid in JSON), causing Copilot CLI to silently discard the entire `additionalContext` payload — doctrine, charter content, and the "invoke status" reminder were never injected. Fix reduces `\\\$` to `\$` in the source so bash emits `${CLAUDE_PLUGIN_ROOT}` (no leading backslash) in the string value. Affects both Copilot CLI (`additionalContext`) and Claude Code (`hookSpecificOutput.additionalContext`) output branches.

## [3.2.0] — 2026-04-27

### Added

- **Dual-platform support for Copilot CLI.** The plugin now works with both Claude Code and GitHub Copilot CLI without code duplication.
  - Root `plugin.json` symlink → `.claude-plugin/plugin.json`: Copilot CLI requires `plugin.json` at the plugin root; Claude Code reads `.claude-plugin/`. One symlink, one source of truth.
  - `hooks/hooks.json` now contains both `SessionStart` (Claude Code) and `sessionStart` (Copilot CLI) hook blocks, coexisting on different JSON keys.
  - `hooks/session-start` outputs `Plugin root:` to session context in Copilot CLI so `${CLAUDE_PLUGIN_ROOT}` references in skills resolve correctly.
  - `skills/execute/SKILL.md` Pre-Loop now includes a platform note: use the built-in `sql` tool in Copilot CLI in place of `TaskCreate`/`TaskUpdate`/`TaskList`.

## [3.1.3] — 2026-04-25

### Changed

- **Plan SKILL rule 8 ("Phase Groups for parallelizable work") flips from recommendation to default.** When ≥2 units of work touch disjoint file scopes and have no symbol dependencies on each other, a Phase Group with `[P]`-marked sub-phases is now the default authoring pattern; a serial chain of flat phases for the same disjoint work requires explicit justification via a `Why serial: <reason>` preamble line on the affected phase(s). Reason: in practice, plan authors were defaulting to flat phases even for genuinely parallelizable work, leaving execute-time concurrency on the table because the orchestrator only dispatches what the plan declares as parallel.

### Added

- **qa-plan criterion 11 — missed parallelism (should-fix).** The plan QA agent now flags flat-phase plans where ≥2 phases declare disjoint file scopes (path-set intersection empty AND no symbol cross-references) without a `Why serial:` rationale on either of the disjoint-scope phases. **Should-fix**, not must-fix — plan authors retain judgment, but the check makes "did you consider parallel?" visible at QA gate time so the parallel-by-default rule actually shapes plans over time. Detection is static text analysis against the plan document only (per-pair path-set intersection + symbol-reference scan); no codebase access required.

### Migration notes for upgraders

- **No user action required for in-flight pieces.** Plans already approved through qa-plan continue to execute identically; the new criterion only fires on plans authored or re-reviewed under v3.1.3+.
- **Authoring impact:** plan authors who deliberately structure parallelizable work as serial flat phases (preserving per-phase Opus QA for regulatory reasons, anticipating later coupling, etc.) must now declare the rationale via `Why serial: <reason>` on the affected phase(s). One line per phase suffices; multiple distinct reasons → multiple lines on the affected phases.
- **Behavior change for execute-time concurrency:** plans authored under v3.1.3+ should converge toward more Phase Groups for genuinely parallelizable work. Execute-time wall-clock for those pieces drops by the parallel-fan-out factor (typically 2–4× for adapter/endpoint families). No execute-skill changes — this is purely upstream plan-authoring guidance + QA enforcement.

## [3.1.2] — 2026-04-25

### Fixed

- **Execute orchestrator now binding-creates a harness task list up front.** Prior wording said only "Track progress via plan.md checkboxes," which produced inconsistent behavior across runs — sometimes the full task list was created, sometimes only the first task, sometimes none. v3.1.2 adds an explicit **Pre-Loop: Build Task List** section to `plugins/spec-flow/skills/execute/SKILL.md` requiring one `TaskCreate` per dispatch unit (each `### Phase <N>` and each `#### Sub-Phase <letter>.<n>`, in plan order, all `pending`) before any phase dispatches. Group headings do NOT get their own task — sub-phases ARE the dispatched units. Status transitions are spelled out: `in_progress` at Step 1, `completed` at Step 7, escalation leaves `in_progress`. Resume case (`TaskList` already returns tasks for the piece) is reconciled against plan.md checkbox state, not rebuilt — plan-edited-mid-flight mismatches surface to human rather than silently auto-rebuilding.

### Migration notes for upgraders

- **No user action required.** This is a documentation-clarification change to the `execute` skill. The new wording codifies one of the two existing behaviors as canonical. No `.spec-flow.yaml` config changes; existing pieces in flight continue to execute identically (Step 7 commits, plan.md checkboxes, oracle gates, and review-board behavior are unchanged).
- **Visibility change for orchestrator runs:** if your runs were creating tasks lazily (one at a time) or skipping the task list when a piece had only one phase, those runs will now create the full list up front. End state is identical; intermediate visibility and resumability improve.

## [3.1.1] — 2026-04-25

### Fixed

- **Step 3.7b reconciliation gate now extends to Implement track** (was previously `Mode: TDD only`). Per pi-009-hardening's Phase Group A contamination event — A.2's commit silently swept in A.4's staged files because the gate didn't fire on Implement track. v3.1.1 makes the unified-commit-reconciliation check (b) a HARD FAIL on both modes; for Mode: Implement, strays in the commit (files outside Build's `## Files Created/Modified`) escalate immediately rather than retry.
- **Phase-sizing predicate filtering** — counting rule now excludes HTML comments (`^\s*<!--` through `-->`), fenced code blocks (everything between `` ``` `` or `~~~ `` fence pairs), markdown horizontal rules, and table separators. A plan section that quotes a 200-line shell example inside a fenced block no longer falsely trips the 150-line warning.
- **Deferred-finding parser boundary grammar** — Step 6a verbatim-finding extraction now uses formal indent-based termination: stops at the first blank line, OR a sibling/shallower list-item at the same-or-lesser indent, OR a markdown heading. Sub-bullets at greater indent are part of the finding. Worked example added.
- **Mid-piece QA pass resume guard now uses two-source check** — primary source is `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.orchestra-state.json` (survives interactive rebases / squash-merges that erase the marker commit); marker commit is the secondary fallback. Either source positive → skip dispatch.
- **Pre-commit-hook compatibility** for the empty `--allow-empty` marker commit — when a project's hook config rejects empty commits, the state-file source is mandatory; the orchestrator writes `.orchestra-state.json` BEFORE attempting the marker commit so the resume signal persists even if the marker fails.

### Changed

- **Plan-skill exit-gate semantics validator** gains an `exit_gate_override: <reason>` escape hatch (parallel to existing `phase_size_override`). Use ONLY for legitimate quoted prose — meta-plans whose `[Verify]` block describes the rejected pattern itself, or `[Verify]` steps that assert the absence of the pattern in some target file. Override is logged for posterity and surfaces in QA-loop input.
- **Step 0a phase-counting clarification** — `## Phase Group <letter>` headings count as 1 unit; `### Phase <num>` headings (even when titled `Group B.x` for AC-tracking) each count as 1 unit. Resolves the ambiguity flagged by pi-009-hardening's edge-case reviewer.
- **Step 0a odd-N timing documentation** — for odd N, K=⌈N/2⌉ produces ⌊N/2⌋ pre-half phases and ⌈N/2⌉ post-half phases. Asymmetry is intentional (earlier dispatch is safer). Worked example for N=7.

### Removed

- (none — all changes are bug fixes or backwards-compatible additions per NN-C-003.)

### Migration notes for upgraders

- **No user action required.** All v3.1.1 changes are bug fixes or escape-hatch additions to existing v3.1.0 surfaces. User `.spec-flow.yaml` configs continue to load without changes.
- **Behavior change for Implement-track phases:** the Step 3.7b reconciliation gate now fires on Implement track. If your plan's `[Implement]` Build agents have been writing files outside their declared `## Files Created/Modified` set (typically a sign of a staging-area race or a wildcard `git add -A`), v3.1.1 will reject those phases and escalate. Fix the agent's staging discipline (literal paths only) and re-run.
- **Phase Group sub-phase agents:** the reconciliation extension makes concurrent-staging races visible immediately rather than silently absorbing them. If you've been running 3+ parallel sub-phases that share file-staging conventions, v3.1.1 will surface contamination earlier — same root cause, faster failure mode.
- **`exit_gate_override` and `phase_size_override`** are plan-author escape hatches; use sparingly and only with stated reason. They appear in plan QA output for reviewer visibility.

## [3.1.0] — 2026-04-25

### Added

- Charter-drift deep scan via `/spec-flow:status --include-drift` — surfaces semantic drift in spec NN/CR citations against current charter content (CAP-2 / FR-2, FR-3).
- `{{worktree_root}}` template token resolved by orchestrator from active piece slug pair; replaces literal `worktrees/...` paths in Agent dispatch templates across spec/plan/execute/status/prd/migrate SKILL.md files (CAP-3 / FR-4, FR-5).
- `## Environment preconditions` section in `plugins/spec-flow/skills/migrate/SKILL.md` — documents host-side capabilities (LLM-agent runtime + git + POSIX shell) without mandating any specific language runtime (CAP-4 / FR-6).
- Mid-piece Opus QA pass for ≥6-phase pieces — orchestrator inserts one Opus QA dispatch at the half-way commit when prior phases auto-skipped (ORC-2 / FR-9).
- Deferred-finding tracking — orchestrator parses `Deferred to reflection:` markers in QA reports and writes structured stubs to PRD-local backlog at deferral time (ORC-3 / FR-10).
- `plugins/spec-flow/reference/qa-iteration-loop.md` — canonical reference doc for the iter-until-clean QA loop pattern; spec/plan/charter/execute SKILL.md cite it (ORC-7 / FR-14, FR-15).
- Plan-skill phase-sizing warning when a single phase exceeds 150 LOC of behavioral prose (ORC-4 / FR-11).
- Plan-skill exit-gate semantics validator rejecting "X is documented to run later" downgrades (ORC-5 / FR-12).

### Changed

- PI-008 spec FR-005 amended to single-branch model (`spec/<prd-slug>-<piece-slug>` from spec authoring through plan and execute) — matches shipped code; replaces the v3.0.0 spec text that prescribed three branches per piece (CAP-1 / FR-1).
- NFR-004 in `docs/prds/shared/prd.md` clarified that "Documentation is the source of truth" includes documenting environment preconditions for skills that operate on user repos (CAP-4 / FR-7).
- Sharpened Opus QA skip-predicate — skips only for additive markdown / YAML / pure config; routes to Opus when phase touches scripts with control-flow constructs or new skill bodies regardless of LOC (ORC-1 / FR-8).
- Plan template `[Verify]` examples for YAML/JSON validation use LLM-agent-step framing instead of `yq`/`jq` shell-outs (ORC-6 / FR-13).
- All QA gates (spec, plan, charter, execute per-phase, mid-piece Opus, Final Review fix-up) iterate until reviewer reports zero must-fix findings; iter-1 = full review, iter-2+ = focused re-review on the fix diff; 3-iter circuit breaker stays as escalation guard (ORC-7 / FR-14).

### Removed

- (none — no public-surface item removed; `qa_iter2` config key is retained as deprecated, see Migration notes below.)

### Migration notes for upgraders

- **`qa_iter2` config key is deprecated.** The orchestrator no longer reads this key. Users with `qa_iter2: auto` or `qa_iter2: always` in their `.spec-flow.yaml` continue to load without error or warning — the key syntax is preserved for backwards compatibility per NN-C-003. The behavior change: iter-2 QA re-dispatch is now the default for all gates (no more conditional skip on small fix diffs). Users who relied on the auto-skip for throughput should expect more iterations on phases where fix-code surfaces residual must-fix items.
- **`/spec-flow:status --include-drift` is opt-in.** Default `/spec-flow:status` invocation is unchanged. Run with `--include-drift` to surface citation drift across all specs.
- **Mid-piece Opus QA pass triggers on long pieces.** Pieces declaring ≥6 phases where the first ⌈N/2⌉ all auto-skip Opus will see one additional Opus dispatch at the half-way commit. No user action required; the dispatch is observable in the session summary as `mid_piece_opus_pass: dispatched`.
- **Dog-food evidence:** v3.1.0 was end-to-end dog-fooded on this repo as the `pi-009-hardening` piece. End-of-piece reflection is captured in `docs/prds/shared/specs/pi-009-hardening/learnings.md` — covering all 12 sub-phases (Group A.1–A.4, Group B.1–B.4, Group C.1–C.3, Phase D), with what-worked / what-didn't entries per sub-phase.

## [3.0.0] — 2026-04-25

### Added
- New `docs/prds/<prd-slug>/` layout supporting multiple PRDs per project under a singular `docs/charter/`.
- PRD lifecycle states (`drafting | active | shipped | archived`) via PRD front-matter.
- PRD-local backlog at `docs/prds/<prd-slug>/backlog.md` for capability-scoped deferred work; global `docs/improvement-backlog.md` reserved for cross-PRD learnings and spec-flow process retros.
- Cross-PRD piece dependencies via qualified `depends_on:` refs (`<prd-slug>/<piece-slug>`).
- New `/spec-flow:migrate` skill — one-shot v1.x/v2.x → v3.0.0 layout migration with `--inspect` (dry-run) and `--force` (override safety checks).
- New `.spec-flow.yaml` config key: `layout_version: 3` (controls path resolution; absence triggers SessionStart warning).
- Slug validator (≤20 chars, charset `[a-z0-9-]`, ≤50-char branch length) — see `plugins/spec-flow/reference/slug-validator.md`.
- `qa-spec` agent: third Input Mode `Focused charter re-review` for automatic charter-drift detection.
- `--ignore-deps` flag on `/spec-flow:execute` for deliberate deviations past unmerged dependencies.
- `--include-archived` flag on `/spec-flow:status` to show archived PRDs.

### Changed
- `docs/specs/<piece>/` → `docs/prds/<prd-slug>/specs/<piece-slug>/` (paths now PRD-scoped).
- `docs/prd/manifest.yaml` → `docs/prds/<prd-slug>/manifest.yaml` (manifest now per-PRD).
- Worktrees: `worktrees/prd-<prd-slug>/piece-<piece-slug>/`.
- Branches: `spec/<prd-slug>-<piece-slug>` (similarly for plan, execute, migrate).
- SessionStart hook now emits a non-blocking yellow warning when `layout_version` is absent or `<3`.
- `reflection-future-opportunities` writes findings to PRD-local backlog (was: global).
- `reflection-process-retro` writes findings to global backlog (target unchanged; routing rule now load-bearing).

### Removed
- Single-PRD-only assumption in skills (every skill now scans `docs/prds/*/` for active PRDs).
- `docs/archive/` directory convention — archived PRDs stay in place via `status: archived` front-matter.

### Migration notes
- v3.0.0 is a breaking major bump per NN-C-003. Run `/spec-flow:migrate <prd-slug>` to upgrade an existing v1.x or v2.x project. v0 (pre-charter) projects must run `/spec-flow:charter` retrofit first.
- The migration uses `git mv` to preserve file history. Verify with `git log --follow docs/prds/<prd-slug>/prd.md` post-migration.
- The migration writes a `MIGRATION_NOTES.md` at the repo root listing every move and any detected stale internal references.
- This repo dog-foods the migration on itself before v3.0.0 is documented for external users (NN-P-003).

## [2.7.1] — 2026-04-24

### Fixed

- **Hook scripts now have the git executable bit set.** `hooks/run-hook.cmd` and `hooks/session-start` were committed as `100644` (non-executable) in git's index. On install, Claude Code's marketplace unpack preserves git file modes, so users saw a SessionStart hook error: `/bin/sh: 1: /.../hooks/run-hook.cmd: Permission denied`. Fixed via `git update-index --chmod=+x` on both files; they are now tracked as `100755` and execute correctly on install. No content change — same shebangs (`#!/usr/bin/env bash`), same script bodies. This bug existed from the hooks' introduction and is unrelated to any v2.x change.

### Notes for upgraders

- **Reinstall to pick up the fix.** If you installed v2.7.0 or earlier and hit the SessionStart permission error, the file mode in your cached copy (`~/.claude/plugins/cache/shared-plugins/spec-flow/<version>/hooks/`) is still `644`. Re-run `/plugin install spec-flow@shared-plugins` (or your host's equivalent) to fetch v2.7.1 with the correct mode.
- **No doctrine or API change.** Every other v2.7.0 behavior is preserved.

## [2.7.0] — 2026-04-22

Architectural shift: **one commit per TDD cycle**. Red no longer commits — it stages its tests via `git add` and emits a SHA-256 content-hash manifest. The implementer creates a SINGLE unified commit containing Red's staged tests + Build's production code, so each TDD cycle lands as one commit in git history (one behavior addition, one commit) instead of two (tests, then code). The pre-commit hook runs once per cycle instead of twice; the old `git diff $red_sha..HEAD -- tests/` anti-cheat check is replaced by path-keyed SHA-256 re-hashing.

This is the third step of the commit-cadence optimization arc:
- **v2.6.0** — per-agent-step default (Red, Build, Refactor = 3 commits per phase)
- **v2.7.0** — per-cycle default (Build unified commit, Refactor = 1–2 commits per phase)

### Changed

- **`agents/tdd-red.md` — Red agent stages but does not commit.**
  - Rule 6 replaced: "Stage your tests, do NOT commit." Red runs `git add -- <literal paths>` after writing tests; any subsequent `git commit` on Red's turn is a contract violation.
  - Rule 9 added: emit `## Staged test manifest` listing every authored path with its SHA-256 content hash. The orchestrator snapshots this for the post-commit integrity check.
  - "Rule: committing failing tests" replaced with "Rule: no commit, no hook concern" — Red no longer triggers pre-commit hooks, so the `--no-verify` test-running-hook carve-out is obsolete.
  - "Rule: literal file list on commit" renamed to "Rule: literal file list when staging" with updated language.
  - Output format adds `## Staged test manifest` section.
  - Anti-patterns: "Commit your own changes" and "Omit the `## Staged test manifest`" added.

- **`agents/implementer.md` — Mode: TDD creates the unified commit.**
  - Rule 8 rewritten: ONE unified commit at the end containing Red's staged tests (already in staging area) + Build's production code. File list must equal (Red manifest paths ∪ Build reported paths). Content-hash integrity gate rejects any modification to Red's tests.
  - Mode descriptions updated: `Mode: TDD` now notes that the working tree starts with Red's tests staged; the unified commit captures both sets.
  - "TDD mode only" section updated: new bullet on the unified commit requirement; content-hash integrity cross-referenced.
  - Output format: `## Files Created/Modified` (TDD mode) now explicitly lists ONLY production/non-test files the implementer authored — Red's tests are tracked separately via the stage manifest and must not appear in this section.

- **`skills/execute/SKILL.md` — orchestrator workflow.**
  - Step 2 (Red): renamed "TDD-Red — Write Failing Tests (Stage, Don't Commit)"; dispatch prompt notes Red does NOT commit; the old `--no-verify` test-hook carve-out is removed.
  - Step 2.4 (Red validation): on-violation cleanup now uses `git restore --staged --worktree -- <failed paths>` to reset the staging area for the retry (no commit to revert).
  - Step 2.6 (new): capture `phase_N_red_stage_manifest` verbatim from Red's output; re-hash every file to detect manifest-vs-actual drift at capture time; persist a copy to `/tmp/spec-flow/phase-N-red-manifest.json` for resume resilience.
  - Step 3 (Implement): prompt template adds `## Red staged test manifest` (Mode: TDD) and `## Commit` instructions explaining the unified-commit requirement.
  - Step 3.7 (new): post-commit integrity and reconciliation gates — (a) content-hash integrity check re-hashes each test file in HEAD against the stage manifest, any drift rejects; (b) unified commit reconciliation verifies the commit's file list equals (Red manifest ∪ Build reported files), strays or missings reject.
  - Step 4.5 (test integrity): simplified — primary tampering check runs at Step 3.7a, so Step 4.5 only re-runs content-hash against HEAD if a Refactor commit intervenes.
  - Step 6b (hook sanity): language updated — Red no longer commits, so hooks only run on the implementer's unified commit (where Red's tests ride along), Refactor, and fix-code commits.
  - Step G4 (Phase Group sub-phase flow): notes shared-staging-area safety — scope disjointness (Step G2) + literal-path staging/commit discipline means parallel sub-phases don't cross-contaminate even though the git index is shared.
  - Stale prose in "Per-Phase Loop" setup and "Session Resumability" that claimed "phases do not commit internally" was genuinely wrong pre-v2.7.0 (Red, Build, Refactor all committed); it's now corrected and accurate under the unified-commit model.

- **`reference/spec-flow-doctrine.md` — Commit Cadence section rewritten.**
  - Table now shows Red = 0 commits (stages only), Build (Mode: TDD) = 1 unified commit, Build (Mode: Implement) = 1, Refactor (if run) = 1. Net 1–2 commits per TDD phase vs. 2–3 in v2.6.0 vs. 3–5+ pre-v2.6.0.
  - New "Why unified, not separate Red and Build commits" paragraph explains the narrative-coherence rationale — a TDD cycle is one complete behavior addition; splitting it into tests-then-code separated halves that were each individually incoherent.
  - New "Integrity preserved via SHA-256" paragraph explains why the anti-cheat check moved from `git diff` to path-keyed content hash.
  - Agent-Specific Safeguards row "No test modification to pass" updated from diff-based to hash-based enforcement.

- **`docs/userguide/concepts/tdd-loop.md` — user-facing Step 1 and Step 2 rewritten** to describe stage-then-unified-commit flow; the "Test integrity — the anti-cheat" section explains the new SHA-256 mechanism with a historical note about the pre-v2.7.0 diff-based approach.

- **`templates/plan.md` — Agent Context Summary table** updated with the new Red-stages-implementer-commits handoff, including what context each agent receives and produces.

### Notes for upgraders

- **No plan-file change required.** Plans authored for v2.6.0 (or earlier) work unchanged under v2.7.0 — the `[TDD-Red]` / `[QA-Red]` / `[Build]` / `[Verify]` / `[Refactor]` / `[QA]` checkbox structure is preserved. The commit model is an agent-behavior and orchestrator-gate change, not a plan-schema change.
- **Git history looks different.** Pre-v2.7.0, a TDD phase produced a Red commit (`tests for X`) followed by a Build commit (`implement X`). Post-v2.7.0, the same phase produces one commit (`phase N: X` containing both). `git log` becomes terser; each commit represents one complete working behavior. Bisect across the piece stays functional; intra-phase bisect (which was theoretical anyway for AI-driven TDD) is no longer available.
- **Anti-cheat strictness is unchanged.** The pre-v2.7.0 `git diff $red_sha..HEAD -- tests/` would flag any test-file edit. The v2.7.0 SHA-256 re-hash flags exactly the same set of violations (any content change to any path in the Red manifest). Detection power is equivalent; only the mechanism changed. Auto-format changes, whitespace fixes, and comment tweaks all trip both.
- **Red retry discipline.** When qa-tdd-red or Red validation rejects, the orchestrator now runs `git restore --staged --worktree -- <paths>` to unstage and revert before re-dispatching Red. Under pre-v2.7.0 the rejected Red commit had to be reset (`git reset HEAD~1`) or amended; the staging-area model is cleaner.
- **Resume behavior.** If a session is interrupted between Red's stage and Build's commit, resume detects Red's staged manifest via the `/tmp/spec-flow/phase-N-red-manifest.json` sidecar and the actual staged files in the index. If either is missing or drifted, the orchestrator escalates — it does not attempt automatic recovery because lost Red work must be re-authored, not guessed.
- **Parallel sub-phases (Phase Groups) share the staging area.** This is safe because (a) scope disjointness is validated at Step G2 and (b) each sub-phase stages and commits by literal path. Documented in Step G4.
- **The `--no-verify` carve-out is gone.** Pre-v2.7.0, projects with test-running pre-commit hooks had to let Red use `--no-verify` (since Red's tests were expected to fail and would block the commit). Under v2.7.0 there's no Red commit; by the time the unified commit runs, tests pass, so a test-running hook approves it normally. Projects that added custom handling for the Red `--no-verify` case can remove it.

## [2.6.0] — 2026-04-22

Optimizes commit cadence: each TDD cycle now produces 2–3 commits total (one per agent-step: Red, Build, optional Refactor) instead of one per file. Pre-commit hooks (lint / format / type-check) run 2–3× per phase instead of N×, saving ~10–25s of pure hook overhead per phase with no loss of orchestrator guarantees.

### Changed

- **`agents/tdd-red.md` Rule 6 — "ONE commit at the end of your Red step, containing all authored tests."** Previous phrasing encouraged "logical checkpoints, typically one commit per test file or per AC group" — agents over-interpreted as one-per-file. New default is the single batched commit; opt-out to AC-group checkpointing only for exceptionally large Red blocks (>200 LOC of tests).
- **`agents/implementer.md` Rule 8 — "ONE commit at the end of your Build/Implement step, when the oracle passes."** Previous phrasing allowed checkpointing "per file / per public-API surface / per sub-task." New default is the single batched commit; opt-out for exceptionally large phases (>200 LOC delta).
- **`agents/refactor.md` Rule 4 — "ONE commit at the end of your Refactor step."** Previous phrasing encouraged checkpointing per independent cleanup (dedup, rename, extraction). New default is the single batched commit; opt-out for exceptionally large refactors or multiple unrelated cleanups.
- **`reference/spec-flow-doctrine.md` — new "Commit Cadence" section** codifying the default across all three agents, documenting why the historical checkpointing rationale (faster error surfacing, bisect-within-phase, intermediate recovery) is weak for AI-driven TDD, and explaining the rare opt-out conditions.

### Notes for upgraders

- **No API change.** Skill commands and orchestrator entry points are unchanged. Orchestrator gates (contamination check after Red commit, test-integrity diff between Red and Verify, scoped re-runs) still operate on the same commit boundaries — they just see 2–3 commits per phase instead of many.
- **No agent-retry budget change.** Oracle retries, QA retries, and the 2-attempt circuit breaker are untouched.
- **Per-file commit is still allowed** as a documented opt-out for large phases. It is no longer the default; agents report the rationale when choosing it.
- **Expect quieter git history.** Commits per piece drop from ~3–5× (plan phases × files) to ~2–3× (plan phases × agent-steps). `git log` + `git blame` become more readable; intra-phase navigation was never the point.
- **Contamination discipline unchanged.** `Rule: literal file list on commit` still applies — stage files by literal path, never by pattern. The cadence change is about count-per-step, not staging shortcuts.

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
