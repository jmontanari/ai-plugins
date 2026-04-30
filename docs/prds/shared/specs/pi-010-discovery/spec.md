---
charter_snapshot:
  architecture: 2026-04-21
  non-negotiables: 2026-04-21
  tools: 2026-04-21
  processes: 2026-04-21
  flows: 2026-04-21
  coding-rules: 2026-04-21
---

# Spec: pi-010-discovery

**PRD Sections:** FR-004, NFR-003, NFR-004, NN-P-002
**Charter:** docs/charter/ (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** pi-009-hardening (done 2026-04-25)

## Goal

Eliminate silent backlog deferrals in the spec-flow pipeline. Today, four discovery moments (deferred QA findings, "NOT COVERED — deferred" AC matrix rows, reflection-future-opportunities, reflection-process-retro) write findings to backlog files at end-of-piece — operators only learn about deferred prerequisite work at the *next* piece's spec brainstorm, by which point downstream pieces may already be in flight against an undone foundation.

Restructure discovery → resolution as a synchronous flow with operator triage at discovery time. Establish the binding operator principle: **the execution that found the work also fixes it**. Inline plan amendment is the default response to discovery, not a separate skill — the orchestrator that found the gap dispatches a `plan-amend` agent, commits a `chore(plan): amend — <reason>` commit on the worktree branch, and resumes from the affected phase. Discoveries that cannot be absorbed within the piece's stated goals fork to a new manifest piece with `depends_on:` chains; only operator-confirmed non-blocking findings flow to backlog files.

Ship as `spec-flow` v3.2.0 — a backwards-compatible minor bump per NN-C-003. Existing pre-amendment pipeline behavior is preserved through one release cycle via opt-in legacy flags; v3.3.0 will retire those flags. Five sub-areas (one user-visible new skill, four orchestrator behavior changes) bundle into a single piece because they share the discovery → triage → resolution flow they collectively implement: splitting them produces five releases that each only land a partial slice of the same flow, multiplying release ceremony without isolating risk.

## In Scope

**Capability item (user-visible):**

- **CAP-F: `/spec-flow:defer` operator skill.** New skill — sole supported path for writing to backlog files (PRD-local `<docs_root>/prds/<prd-slug>/backlog.md` and global `<docs_root>/improvement-backlog.md`). Records source piece, source phase, finding text, operator's rationale for non-blocking, and capture date. After this skill lands, every other skill's automatic backlog-write code path is removed. The skill accepts a structured invocation from the orchestrator's triage flow (the operator chooses defer; orchestrator invokes `/spec-flow:defer` with a pre-populated finding context) and a manual operator invocation (`/spec-flow:defer "<finding>" --rationale "<text>"`).

**Orchestrator items (no new user-facing surface change):**

- **CAP-A: depends_on enforcement at spec and plan time.** `/spec-flow:spec` and `/spec-flow:plan` gain a precondition check that surfaces unmet `depends_on:` to the operator. Today only `/spec-flow:execute` reads `depends_on:` (per `plugins/spec-flow/skills/execute/SKILL.md` Phase 1c), so a piece can be specced and planned with prerequisites still `open` — operators discover the gap only at execute time. The new check offers three triage options at spec/plan time: pull-deps-in as Phase 0 of the current piece, fork to write the prerequisite piece first, or proceed with `--ignore-deps` (operator-asserted override). The choice is recorded as a `## Dependency Triage` section in the spec.md or plan.md so future readers and review-board agents can audit the decision.

- **CAP-B: AC matrix deferred-row rejection at Verify gate.** The verify agent and execute Step 4 (AC Coverage Matrix validation gate) reject any AC matrix row whose status is `NOT COVERED — deferred to <pointer>` unless the row carries a new required field `Reason:` with one of three values: `does-not-block-goal`, `requires-amendment`, or `requires-fork`. `does-not-block-goal` requires inline operator confirmation before the phase completes; the other two trigger the CAP-D triage flow. A `legacy_deferred_rows: true` flag in the plan's front-matter preserves pre-3.2.0 behavior (silent acceptance of bare deferral rows) for one release cycle; v3.3.0 will retire the flag.

- **CAP-D: Discovery triage + inline plan amendment.** Load-bearing sub-area. New step in `plugins/spec-flow/skills/execute/SKILL.md` between phase-complete and next-phase-start: **Discovery Triage**. Aggregates discoveries from the just-finished phase's QA review and AC matrix gate. For each discovery, the orchestrator presents a triage prompt to the operator with three options: **amend**, **fork**, **defer**. The amend path dispatches a new `plan-amend` Sonnet agent (`plugins/spec-flow/agents/plan-amend.md`) with the current plan, the structured discovery report, and the diff+neighborhood scope; the agent emits a unified diff that inserts suffix-named amendment phases (`phase_<N>_amend_<K>` where N is the originating phase and K is the amendment counter starting at 1) before the next original phase; the orchestrator commits `chore(plan): amend — <reason>` on the worktree branch, dispatches `qa-plan` for diff+neighborhood re-review (iter-until-clean per `plugins/spec-flow/reference/qa-iteration-loop.md`), and on green resumes execution from the first amendment phase. The fork path writes a new piece into the manifest with `depends_on:` chains pointing back at the current piece, marks the current piece blocked, and halts execute. The defer path invokes `/spec-flow:defer` (CAP-F) to write a backlog entry with operator-recorded rationale; no orchestrator state changes; execute continues. Per-piece amendment budget is 2 (counting both plan and spec amendments together; spec amendments are bounded at 1 within that 2). Hitting the budget escalates to "scope was wrong; abandon and re-spec from scratch." A new per-piece artifact `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md` (committed on the worktree branch) records every discovery and its triage outcome — provides the audit trail operators have today only via grep-against-backlog. Final-Review-board misses (where the 4-reviewer board flags missing scope at end-of-piece) route through the same triage flow: amend re-opens the piece for additional phases that run before merge, fork writes a follow-up piece, defer requires explicit non-blocking rationale.

- **CAP-E: Reflection agents emit triage reports, not backlog writes.** `plugins/spec-flow/agents/reflection-future-opportunities.md` and `plugins/spec-flow/agents/reflection-process-retro.md` stop writing directly to backlog files. They emit structured findings to the orchestrator at execute Step 4.5; the orchestrator dispatches the same triage UX from CAP-D for each finding. `reflection-future-opportunities` findings each get a per-finding triage prompt (amend / fork / defer). `reflection-process-retro` findings get a single batched triage prompt at end-of-piece (cross-PRD process learnings rarely block the current piece's goals; per-finding triage would produce friction without insight). Operator's defer choice invokes `/spec-flow:defer` per CAP-F; only that path writes to backlog files.

**Release ceremony:**

- Single release commit bumps `plugins/spec-flow/.claude-plugin/plugin.json` `version` 3.1.3 → 3.2.0, updates `.claude-plugin/marketplace.json`'s spec-flow entry to 3.2.0, prepends a `## [3.2.0] — YYYY-MM-DD` section to `plugins/spec-flow/CHANGELOG.md` per Keep a Changelog with all five sub-area items grouped under Added / Changed and Migration notes for upgraders. (NN-C-009 three-place bump.)

## Out of Scope / Non-Goals

- **One-time backlog triage pass.** Existing entries in `<docs_root>/prds/<prd-slug>/backlog.md` and `<docs_root>/improvement-backlog.md` are grandfathered. A `--triage-existing-backlog` mode of `/spec-flow:defer` is captured for future work but not built in v3.2.0.
- **Auto-fork without operator confirmation.** Auto-mode (`--auto`) defaults to *amend* when absorption < 50% of cumulative diff and *escalate* otherwise; auto-mode never auto-forks or auto-defers — both are scope decisions that require operator judgment.
- **`/spec-flow:execute --resume-after-amendment` UX polish.** v3.2.0 ships the resume-from-affected-phase logic; v3.3.0 may add session-resume affordances if operators ask for them.
- **Cross-PRD discovery triage.** A discovery in piece X that names piece Y in another PRD as the prerequisite still triggers triage, but the fork path writes the new piece into the *current PRD's* manifest unless the operator explicitly directs otherwise. Cross-PRD orchestration is captured in v4.0 scope (see `docs/prds/shared/backlog.md`).
- **Plan-amend agent multi-language Verify steps.** Plan-amend inherits ORC-6's LLM-native [Verify] convention from pi-009; no language-runtime expansion in v3.2.0.
- **Spec-amend full-flow for breaking changes.** Spec amendments in v3.2.0 are bounded to additions/clarifications within the piece's stated goals (FR-12a). PRD-impacting spec changes (new goals, removed goals) escalate; no automated PRD-amendment path. Spec-amend full-flow including PRD impact is captured for future work.

## Requirements

### Functional Requirements

#### Capability (user-visible)

- **FR-1 (CAP-F):** `plugins/spec-flow/skills/defer/SKILL.md` exists as a new skill. The skill accepts two invocation forms:
  - **Orchestrator-driven (structured):** invoked from execute's triage flow with a pre-populated context block containing source piece slug, source phase id, source agent name, finding text (verbatim), and operator-supplied rationale.
  - **Operator-driven (manual):** `/spec-flow:defer "<finding>" --rationale "<text>" [--global] [--source-piece <slug>] [--source-phase <id>]`. When `--global` is passed, the entry is written to `<docs_root>/improvement-backlog.md`; otherwise to the PRD-local `<docs_root>/prds/<prd-slug>/backlog.md` of the active piece (resolved via `git worktree list` + `docs/prds/<prd-slug>/manifest.yaml` cross-reference).

- **FR-2 (CAP-F):** Every defer skill write produces a structured entry under a `## Recent findings` H2 section in the target backlog file, formatted as:
  ```markdown
  ### [Deferred via /spec-flow:defer] <finding-summary> — YYYY-MM-DD

  **Source:** `<prd-slug>/<piece-slug>` phase `<phase-id>` (agent: `<agent-name>`)
  **Finding (verbatim):** <finding-text>
  **Why this does not block <piece-slug>'s goals:** <operator-rationale>
  **Captured:** YYYY-MM-DD
  ```
  Required fields: source piece, source phase, agent (or `manual` for operator-driven invocations), finding text, rationale, date. Missing rationale refuses the write with: `REFUSED — defer requires --rationale; explain why this finding does not block the current piece's goals.`

- **FR-3 (CAP-F):** The defer skill is the sole code path that appends to backlog files. After CAP-A/B/D/E land:
  - `plugins/spec-flow/skills/execute/SKILL.md` Step 6a's "Append a stub to backlog" prose is rewritten to invoke `/spec-flow:defer` only after operator chose defer in the CAP-D triage flow.
  - `plugins/spec-flow/agents/reflection-future-opportunities.md` and `reflection-process-retro.md` no longer prescribe direct file appends (their `Findings append under...` prose is replaced with `Findings emitted to orchestrator for triage; the orchestrator may invoke /spec-flow:defer per operator choice`).

#### Orchestrator (no user-visible surface change)

- **FR-4 (CAP-A):** `plugins/spec-flow/skills/spec/SKILL.md` Phase 1 gains a new step (between current step 6 and step 7 charter-drift) titled "**Dependency precondition check**" that reads the target piece's `depends_on:` list from `docs/prds/<prd-slug>/manifest.yaml`, resolves each ref per the existing rules in `plugins/spec-flow/skills/execute/SKILL.md` Phase 1c, and on any unmet dep (status not `merged`/`done`) presents the operator with three options: pull-deps-in, fork, proceed with `--ignore-deps`. The check is informational on `proceed`; the user's choice is recorded for Phase 3 (write to spec.md).

- **FR-5 (CAP-A):** `plugins/spec-flow/skills/plan/SKILL.md` Phase 1 gains the same precondition check (reads the same `depends_on:` from the same manifest path). Same three options. Plan's choice is recorded for write to plan.md.

- **FR-6 (CAP-A):** When the operator chose `pull-deps-in` at spec time, the spec.md gains a `## Dependency Triage` section listing each unmet dep, its current status, and the operator's resolution ("Phase 0 will re-implement / verify"). When the operator chose `fork`, the skill halts spec authoring and emits `Refused — fork chosen; spec the prerequisite piece <ref> first.` When `proceed --ignore-deps` is chosen, the section records "Operator override; deps remain unmet at spec time." The same shape applies in plan.md when choices are made at plan time. The `## Dependency Triage` section is required (not skip-on-empty) when any dep was unmet at the moment of authoring; if all deps were already merged, the section is omitted.

- **FR-7 (CAP-B):** `plugins/spec-flow/reference/ac-matrix-contract.md` and `plugins/spec-flow/skills/execute/SKILL.md` Step 4 are updated. The AC matrix row schema gains an optional `Reason:` column. Any row with status `NOT COVERED — deferred to <pointer>` MUST carry a `Reason:` value of exactly one of: `does-not-block-goal`, `requires-amendment`, `requires-fork`. The verify agent rejects any deferral row that lacks a `Reason:` value with: `REFUSED — deferred row missing Reason; specify does-not-block-goal | requires-amendment | requires-fork.`

- **FR-8 (CAP-B):** A `Reason: does-not-block-goal` row pauses Step 4 and presents the operator with: `Phase claims AC <id> can defer without blocking <piece>'s goals — confirm? (y/n)`. On `y`, the row is accepted and the phase proceeds; on `n`, the phase Build is re-dispatched per the existing 2-attempt budget. A `Reason: requires-amendment` row triggers the CAP-D triage flow with `amend` as the default (operator may override to fork or defer). A `Reason: requires-fork` row triggers the CAP-D fork flow (skill halts, new piece written into manifest).

- **FR-9 (CAP-B):** `plugins/spec-flow/templates/plan.md` gains a `legacy_deferred_rows: false` key in the plan's front-matter (defaulting to `false`). Setting `legacy_deferred_rows: true` in a plan's front-matter restores pre-3.2.0 acceptance behavior: deferral rows are accepted regardless of `Reason:` content. The CHANGELOG flags the flag for retirement in v3.3.0.

- **FR-10 (CAP-D):** `plugins/spec-flow/skills/execute/SKILL.md` gains a new step **6c: Discovery Triage** between current Step 6 (QA gate) and Step 7 (phase commit). Step 6c aggregates discoveries from this phase: AC matrix `requires-amendment` / `requires-fork` rows from Step 4 (per FR-8), QA findings flagged as `Deferred to reflection:` from Step 6 (rerouted from today's auto-write to surfacing here), and Build escalations citing missing prerequisites from oracle iteration exhaustion. Each discovery is presented to the operator with the three triage options. The operator's choice is recorded in `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md` per FR-15. **Step 6c is the triage flow** — it is *invoked* from the inter-phase position described above and is *also invoked* from the post-Final-Review step described in FR-16. Both invocations dispatch the same triage UX, the same plan-amend / fork / defer paths, and write to the same `.discovery-log.md`.

- **FR-11 (CAP-D):** `plugins/spec-flow/agents/plan-amend.md` exists as a new Sonnet agent. The agent's input contract: a context block containing the current plan.md (full), the structured discovery report (type / why-blocks / proposed-amendment-scope / estimated-absorption-size), and the diff+neighborhood scope (the existing phase plus any phase that scopes the same SKILL.md / file). The agent's output: a unified diff that inserts new phases under suffix names (`phase_<N>_amend_<K>` per FR-13). The agent does NOT commit; it ends its report with `## Diff of changes` containing the unified diff. The orchestrator stages and commits per FR-12. (Mirror of `plugins/spec-flow/agents/fix-doc.md`'s contract pattern.) The unified diff format is the standard `git diff` format (with `--- a/<path>` and `+++ b/<path>` headers, hunk headers `@@ ... @@`, and standard context lines). The orchestrator extracts the diff by reading the agent's report, isolating the `## Diff of changes` section, and parsing everything between that heading and the next `##`-or-EOF boundary as the diff payload. The orchestrator applies the diff using `git apply --check <tmpfile>` (validation) followed by `git apply <tmpfile>` (application) against the worktree. On conflict (`git apply --check` exits non-zero), the orchestrator halts the amend flow with `Refused — plan-amend diff did not apply cleanly: <git apply stderr>` and routes the discovery back to the operator with the option to re-dispatch plan-amend (counts as a fresh amendment dispatch within the same triage event, but does NOT consume an additional budget slot for the same discovery). The orchestrator computes the neighborhood by enumerating phases whose `[Implement]` blocks touch any file the amendment touches by exact file path (not by shared directory).

- **FR-12 (CAP-D):** When the operator chooses `amend` in Step 6c, the orchestrator: (a) dispatches `plan-amend` per FR-11 with diff+neighborhood scope, (b) extracts the unified diff from the agent's report, (c) applies the diff to plan.md on the worktree branch, (d) dispatches `qa-plan` with `Input Mode: Focused re-review` and the diff (iter-until-clean per `plugins/spec-flow/reference/qa-iteration-loop.md`), (e) on `qa-plan` clean, commits `chore(plan): amend — <reason — discovery summary>` on the worktree branch, and (f) resumes execute starting at the first amendment phase (`phase_<N>_amend_1`). The amendment phases run through the standard TDD/Implement track including their own per-phase QA gate and AC matrix validation; they count toward the per-piece amendment budget (FR-14) but each amendment phase's internal phase QA does NOT count as a discovery moment that opens new amendment phases (amendments cannot recursively amend within the same triage event — but a *separate* later discovery in a subsequent phase may dispatch amendment, subject to the budget). When an amendment phase's own per-phase QA gate (Step 6) surfaces a new discovery, that discovery flows through Step 6c per the standard rules and counts as a separate amendment event against the budget (FR-14). Amendment phases are not exempt from generating discoveries; they are exempt only from being amended within the same triage event that created them.

- **FR-12a (CAP-D, spec amendments):** When a discovery's nature implies the spec was wrong (not just the plan) — concretely: the discovery names a missing FR, a missing AC, or an FR/AC whose statement is contradicted by what was actually built — the operator may choose `amend-spec` instead of `amend` (plan) at the Step 6c triage prompt. The orchestrator dispatches a `spec-amend` agent (analog of plan-amend at `plugins/spec-flow/agents/spec-amend.md`) with the current spec, the structured discovery report, and the affected sections. The agent emits a unified diff against spec.md. The orchestrator applies the diff per FR-11's apply contract, dispatches `qa-spec` with `Input Mode: Focused re-review` (iter-until-clean), and on green commits `chore(spec): amend — <reason>` on the worktree branch. Spec amendments are bounded to additions and clarifications within the piece's stated goals (added FRs / ACs / NFRs / NN honored entries / AC matrix rows); changes that introduce or remove a Goal-section entry are out of scope for v3.2.0 and escalate.

- **FR-13 (CAP-D):** Amendment phase IDs use suffix form: `phase_<N>_amend_<K>` where `<N>` is the originating phase id (the phase whose end-of-phase review surfaced the discovery) and `<K>` is a 1-indexed counter scoped to the originating phase (a single amendment dispatch may insert multiple phases — `phase_3_amend_1`, `phase_3_amend_2`, etc.). The orchestrator persists state keyed by these IDs (e.g., `phase_3_amend_1_ac_matrix`) per existing `execute/SKILL.md:410` patterns. The amendment counter resets on each originating phase but increments across separate amendment events from the same originating phase.

- **FR-14 (CAP-D):** Per-piece amendment budget: **2 amendments total per piece**, of which **at most 1 may be a spec amendment**. The 3rd amendment of any kind triggers escalation. Hitting the budget triggers the orchestrator escalation: `Amendment budget exhausted — piece scope was inadequate. Escalating: abandon and re-spec from scratch is recommended. Continue anyway? (y/n)`. On `y`, the orchestrator continues with no further amendments allowed (subsequent discoveries can only fork or defer); on `n`, the orchestrator halts execute and the piece status flips to `blocked` in the manifest with a notes-line citing budget exhaustion.

- **FR-15 (CAP-D):** A new per-piece artifact `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md` (committed on the worktree branch) records every discovery and its triage outcome. Format (markdown table):
  ```markdown
  # Discovery log — <prd-slug>/<piece-slug>

  | Phase | Discovery type | Source agent | Finding (1-line) | Triage choice | Resolution commit |
  |---|---|---|---|---|---|
  | phase_3 | requires-amendment | qa-phase | Auth helper missing X | amend | abc1234 chore(plan): amend — ... |
  | phase_4 | does-not-block-goal | verify | AC-7 deferral confirmed | defer | def5678 chore: defer ... |
  ```
  The orchestrator appends one row per discovery at Step 6c immediately after the operator's triage choice. The commit is committed alongside the resolution commit (or alongside the next phase commit if the resolution is deferral, since defer makes its own commit via `/spec-flow:defer`). Each row append is committed alongside its corresponding resolution commit (the amend commit, the fork manifest-update commit, or the /spec-flow:defer commit) — i.e., the `.discovery-log.md` row and the resolution commit land as a single coherent commit. This produces a per-discovery audit trail in `git log`.

- **FR-16 (CAP-D):** Final-Review-board (the 4-reviewer end-of-piece board: blind, spec-compliance, architecture, edge-case) findings flagged as `requires-amendment` route through Step 6c's triage flow (operator: amend / fork / defer). On `amend`, the piece re-opens for amendment phases that run before merge; on `fork`, a follow-up piece is written and the current piece merges as-is with the discovery deferred to the new piece; on `defer`, `/spec-flow:defer` writes to backlog with non-blocking rationale. The `## Deferred QA findings` section in execute/SKILL.md Step 6a (PRD-local backlog stub append at deferral time, FR-10 from pi-009) is replaced with this triage flow — Final Review no longer auto-writes deferred findings.

- **FR-16a (CAP-D):** When Final Review (the 4-reviewer end-of-piece board) returns must-fix findings, the orchestrator invokes Step 6c's triage flow once per finding before any merge action. Specifically, Step 6c is invoked from a new orchestrator step **Step 8: Final Review Triage** (positioned in execute SKILL.md between today's Final Review iter-loop and the merge gate). Each finding's triage choice records to `.discovery-log.md` per FR-15 with the source-phase column set to `final-review`. Amend phases inserted via Step 8 use suffix-form IDs `phase_final_amend_<K>` (where the originating phase is the literal token `final` since there is no specific upstream phase).

- **FR-17 (CAP-D):** Auto-mode (`--auto`) Step 6c default behavior: each discovery is auto-resolved as `amend` if `<estimated-absorption-size> / <cumulative-diff-size>` < 0.5 (the discovery report's `Estimated absorption size` field divided by the running cumulative diff size of the piece so far, both measured in LOC). Otherwise auto-mode escalates to operator with: `Discovery in <phase> would expand piece by <X>% — exceeding 50% auto-amend threshold. Operator triage required.` Auto-mode never auto-forks or auto-defers — both are scope decisions requiring operator judgment per the principle that the execution that found the work also fixes it. The 50% threshold is computed per-discovery against the cumulative diff size at the moment the discovery surfaces; threshold breaches do not lock the piece into operator-required mode for subsequent discoveries — each discovery is evaluated independently against the current cumulative diff size.

- **FR-18 (CAP-E):** `plugins/spec-flow/agents/reflection-future-opportunities.md` and `plugins/spec-flow/agents/reflection-process-retro.md` are updated. The "Findings append under..." prose in both is replaced with: emit findings as a structured report to the orchestrator (one finding per `### Finding-N` block, with type / rationale / dependencies / candidate-piece-sketch fields). The orchestrator at Step 4.5 receives the report and dispatches the CAP-D triage flow per finding (future-opportunities) or as a single batched prompt (process-retro). Direct file-append code in both agent prompts is removed.

- **FR-19 (CAP-E):** `plugins/spec-flow/skills/execute/SKILL.md` Step 4.5 prose is updated. The current "reflection commits append findings to backlogs" prose is rewritten to: "reflection agents emit findings to the orchestrator; the orchestrator dispatches CAP-D triage per finding (future-opportunities) or as a single batched prompt (process-retro). Findings the operator chooses to defer are written via `/spec-flow:defer` (which produces its own commit). Findings the operator chooses to amend dispatch the plan-amend flow per FR-12. The `git add backlog.md && git commit -m "reflection: ..."` step from today's flow is removed — the reflection step itself produces no commits." The Step 5 learnings.md commit remains unchanged (learnings.md is the synthesized doc, separate from raw findings).

#### Release ceremony

- **FR-20:** `plugins/spec-flow/.claude-plugin/plugin.json` `version` is bumped 3.1.3 → 3.2.0, `.claude-plugin/marketplace.json`'s spec-flow entry is bumped to 3.2.0, and `plugins/spec-flow/CHANGELOG.md` gains a new `## [3.2.0] — YYYY-MM-DD` section at the top with all five CAP items grouped per Keep a Changelog (Added / Changed / Removed / Migration notes for upgraders). The CHANGELOG entry calls out (a) new `/spec-flow:defer` skill, (b) `legacy_deferred_rows: true` opt-in flag for one-release legacy AC-matrix behavior, (c) per-piece amendment budget (2 amendments per piece, with at most 1 being a spec amendment), and (d) Step 4.5 reflection no longer auto-writes to backlog files. (NN-C-009 three-place bump.)

- **FR-21:** A `## Migration notes for upgraders` subsection in CHANGELOG 3.2.0 documents: existing backlog entries are grandfathered (no automatic triage); plans authored under v3.1.x continue to work — bare `NOT COVERED — deferred` rows are still accepted for one release if the plan sets `legacy_deferred_rows: true`; the `qa_iter2: auto` config key (already deprecated in v3.1.0) is unchanged in v3.2.0.

- **FR-22 (FR-004 honored):** `plugins/spec-flow/README.md` is updated in v3.2.0 to document Step 6c discovery triage, the plan-amend / spec-amend agents, and the `/spec-flow:defer` skill in the pipeline overview. The pipeline diagram (charter → prd → spec → plan → execute) gains a notation that execute now includes synchronous discovery triage at end-of-phase. The 'Agent inventory' section gains entries for `plan-amend` and `spec-amend`. The 'Skills' section gains an entry for `defer`.

### Non-Functional Requirements

- **NFR-1:** No new runtime dependencies under `plugins/spec-flow/` (NN-C-002). `plan-amend` and `defer` are both markdown-only artifacts: `plan-amend` is an LLM agent prompt, `defer` is a SKILL.md operating on local files via the LLM agent's native file-edit capabilities.

- **NFR-2:** All v3.2.0 changes are backwards-compatible additions or behavior-equivalent improvements (NN-C-003). The `legacy_deferred_rows: true` opt-in flag preserves pre-3.2.0 AC matrix behavior for one release; v3.3.0 will retire it. Existing pieces' backlog files are not modified at release time. The reflection-step backlog-append commit is removed in v3.2.0; user projects that grep for `reflection: <piece> — append findings to backlogs` commit messages will no longer find new occurrences after v3.2.0 — this is documented as a release note (FR-21) but not as a public-surface removal (the commit message pattern was emergent, not contractual).

- **NFR-3:** Every spec-flow-produced artifact this piece touches under `docs/` (specs, plans, learnings, the new `.discovery-log.md` per piece, backlog edits via /spec-flow:defer) is plain markdown / YAML (NN-P-001).

- **NFR-4:** Hooks and skills no-op silently on missing optional inputs (NN-C-005). The `/spec-flow:defer` skill returns "no active piece detected — pass --source-piece explicitly or invoke from within a piece worktree" rather than failing when invoked outside a worktree without `--source-piece`. The plan-amend agent emits "no diff produced — discovery does not require plan changes" rather than producing an empty commit when the discovery turns out to need only a phase-internal fix.

- **NFR-5:** Two-gate human sign-off is preserved (NN-P-002). The CAP-D triage step adds an additional decision point at end-of-phase (where today the orchestrator silently auto-defers); this is not a new sign-off gate at the merge boundary, but an additional triage moment within execute. The two existing gates (per-phase QA completion, end-of-piece review-board) are unchanged.

- **NFR-6:** Step 6c discovery triage budget on operator interruptions: in non-auto mode, the orchestrator should aggregate same-phase discoveries into a single triage prompt rather than firing one prompt per discovery. (E.g., if QA finds 3 discoveries in phase_3, the operator sees one prompt enumerating all 3 with checkboxes per choice, not 3 separate prompts.) Auto-mode applies its threshold logic (FR-17) per discovery independently.

- **NFR-7 (NFR-004 honored):** Both new artifacts (`/spec-flow:defer` skill and `plan-amend` / `spec-amend` agents) ship with documented `## Environment preconditions` sections (in their SKILL.md / agent.md respectively) listing host expectations: file-reading + inline-parsing capability via the LLM agent's runtime, `git` ≥ 2.5 for amendment commits, POSIX shell. No external runtime dependencies. Mirrors pi-009 CAP-4's path-1 precedent (LLM-native, no jq/yq/python3).

### Non-Negotiables Honored

**Project (NN-C — from `docs/charter/non-negotiables.md`):**

- **NN-C-001 (plugin/marketplace version sync):** FR-20's release commit updates `plugins/spec-flow/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` in the same commit. AC-26 verifies the two files agree on `version: 3.2.0` after the release commit lands.

- **NN-C-002 (no runtime deps):** This piece adds two new artifacts (`plugins/spec-flow/agents/plan-amend.md`, `plugins/spec-flow/skills/defer/SKILL.md`) — both are markdown-only LLM-agent specifications that operate in the LLM agent's runtime (file reading, file editing, git operations via the agent's host shell). No `package.json`, `requirements.txt`, `Dockerfile`, or compiled binary is added under `plugins/spec-flow/`.

- **NN-C-003 (backwards-compat within major):** v3.2.0 adds optional behavior (`/spec-flow:defer` skill, `legacy_deferred_rows: true` opt-in flag, AC matrix `Reason:` field, `.discovery-log.md` artifact, plan-amend agent). No public-surface item is removed. The reflection-step auto-write code path is removed but the reflection commit message pattern was emergent (not part of the documented public contract); release notes call it out per FR-21.

- **NN-C-004 (agent frontmatter `name:` is bare):** The new `plan-amend.md` agent's frontmatter `name:` is `plan-amend`, not `spec-flow:plan-amend`.

- **NN-C-005 (hooks no-op silently on missing optional inputs):** The defer skill's "active piece detection" falls back gracefully (NFR-4); the plan-amend agent's no-diff-needed case emits an inline note rather than producing an empty commit.

- **NN-C-006 (no destructive ops without confirmation):** The amend flow rewrites plan.md (a non-destructive edit producing a normal commit). The fork flow writes a new manifest entry (additive). The escalation path (FR-14) requires explicit `(y/n)` operator confirmation before continuing past budget exhaustion.

- **NN-C-007 (CHANGELOG in Keep a Changelog format):** FR-20 prepends a new `## [3.2.0] — YYYY-MM-DD` section per the standard.

- **NN-C-008 (agent prompts self-contained):** The `plan-amend` agent's prompt is composed by the orchestrator and includes the full plan.md, the discovery report, and the diff+neighborhood scope explicitly. The `/spec-flow:defer` skill's structured-invocation form receives all required fields from the orchestrator. Neither relies on conversation history.

- **NN-C-009 (always bump plugin version):** FR-20 specifies the three-place bump (plugin.json + marketplace.json + CHANGELOG); this piece is a minor bump (3.1.3 → 3.2.0) per the Semver scope guidance because all changes are additive or opt-in stricter behavior.

- **NFR-004 (documentation as source of truth):** The new `/spec-flow:defer` skill, `plan-amend` agent, and `spec-amend` agent each ship with a `## Environment preconditions` section in their respective SKILL.md/agent.md files. The amendment + defer flow is documented in `plugins/spec-flow/skills/execute/SKILL.md` Step 6c, FR-12, FR-12a, and Step 8 — operators have one reading path through the new flow without needing to grep for emergent behavior.

**Product (NN-P — from `docs/prds/shared/prd.md`):**

- **NN-P-001 (artifacts human-readable):** Every artifact this piece writes (defer entries, plan-amend diffs, .discovery-log.md, CHANGELOG) is plain markdown or YAML.

- **NN-P-002 (no auto-merge to main without two human gates):** The CAP-D triage step adds an end-of-phase decision moment but does NOT bypass the two existing gates (per-phase QA, end-of-piece review-board). Auto-mode's amend-when-small-enough behavior (FR-17) is constrained to absorption-size threshold and never auto-merges; auto-mode still requires human sign-off at the two existing gates per NN-P-002.

- **NN-P-003 (dog-food before recommend):** v3.2.0's release commit ships only after this piece itself runs through the new flow on this repo. The piece's plan-amend / defer / triage flow is exercised end-to-end in this piece's own execute run before user-facing release.

### Coding Rules Honored

- **CR-001 (agent frontmatter schema):** `plan-amend.md` ships with `name: plan-amend`, `description: ...` (one-line trigger + dispatch contract), `model: sonnet`. No `tools:` restriction.

- **CR-002 (skill frontmatter schema):** `skills/defer/SKILL.md` ships with `name: defer`, `description: ...` written in third-person ("Use when...") with concrete trigger phrases.

- **CR-004 (conventional-commits format):** Amendment commits use `chore(plan): amend — <reason>` (chore type per CR-004's enumeration); defer commits use `chore(<piece-slug>): defer <finding-summary>`.

- **CR-005 (repo-relative paths):** All paths in spec.md, plan.md, plan-amend agent prompt, and CHANGELOG use repo-root-relative paths.

- **CR-008 (thin orchestrator / narrow agent):** `plan-amend` is a narrow agent — its only task is "read plan + discovery → emit unified diff." The orchestrator (execute SKILL.md) handles all dispatch, commit, and resume logic. `/spec-flow:defer` is similarly narrow — it reads a structured invocation context, formats the entry, appends to the target backlog file. No agent dispatches another agent; all dispatches originate from execute or one of the other top-level skills.

- **CR-009 (markdown semantic hierarchy):** spec.md, plan.md, the new .discovery-log.md, and CHANGELOG entries use one H1, H2 for top sections, H3 for subsections. The plan-amend agent's emitted diff respects existing plan.md heading hierarchy.

## Acceptance Criteria

### CAP-F — defer skill

- **AC-1:** Given a plan committed on a piece worktree branch with the active piece resolvable from `git worktree list`, when the operator runs `/spec-flow:defer "Need rate-limit middleware" --rationale "Out of scope; tracked in v3.3 backlog"`, then `<docs_root>/prds/<prd-slug>/backlog.md` gains a new entry under `## Recent findings` with all six required fields populated and `git status` shows the file as the only change.
  - *Independent test:* Invoke the skill in a fresh worktree on a sample piece, inspect the resulting backlog.md, confirm the entry's six fields and the absence of any other modified files.

- **AC-2:** Given the operator omits `--rationale`, when `/spec-flow:defer "<finding>"` is invoked, then the skill refuses with `REFUSED — defer requires --rationale; explain why this finding does not block the current piece's goals.` and writes nothing.
  - *Independent test:* Invoke without `--rationale`, confirm exit message and no file change.

- **AC-3:** Given the operator passes `--global`, when the skill is invoked, then the entry is written to `<docs_root>/improvement-backlog.md` (not the PRD-local backlog) and the entry's `**Source:**` line uses the qualified `<prd-slug>/<piece-slug>` form.
  - *Independent test:* Invoke with `--global`, confirm the global file received the entry and the PRD-local file is untouched.

- **AC-4:** Given a structured orchestrator-driven invocation (with all six fields supplied as named arguments), when the skill executes, then it skips the operator-prompt code path entirely and produces the entry without any interactive prompt.
  - *Independent test:* Invoke programmatically with all fields, confirm no operator prompts surfaced.

### CAP-A — depends_on at spec/plan time

- **AC-5:** Given piece `pi-X` has `depends_on: [pi-Y]` where `pi-Y` status is `open`, when the operator invokes `/spec-flow:spec shared/pi-X`, then the spec skill enumerates the unmet dep and presents the three triage options (pull-deps-in / fork / proceed) before any worktree is created or spec.md is written.
  - *Independent test:* Set up two manifest pieces, invoke spec, confirm the prompt fires before any branch creation.

- **AC-6:** Given the operator chose `pull-deps-in` at spec time, when the spec skill writes spec.md, then spec.md contains a `## Dependency Triage` section listing the unmet dep, its current status, and the resolution ("Phase 0 will re-implement / verify").
  - *Independent test:* Walk through the prompt, choose pull-deps-in, inspect the resulting spec.md.

- **AC-7:** Given the operator chose `fork` at spec time, when the spec skill executes, then it halts with `Refused — fork chosen; spec the prerequisite piece <ref> first.` and writes no spec.md.
  - *Independent test:* Choose fork, confirm halt and absence of spec.md.

- **AC-8:** Given the operator chose `proceed --ignore-deps`, when the spec skill writes spec.md, then spec.md's `## Dependency Triage` section records "Operator override; deps remain unmet at spec time."
  - *Independent test:* Choose proceed, inspect spec.md.

- **AC-9:** Given the same precondition gate fires in `/spec-flow:plan`, when an operator invokes plan on a specced piece with unmet deps, then plan presents the same three options and records the choice in plan.md's own `## Dependency Triage` section.
  - *Independent test:* Spec a piece that bypassed deps, then invoke plan, confirm the prompt re-fires and plan.md records the resolution.

### CAP-B — AC matrix deferred-row rejection

- **AC-10:** Given a phase's Build report includes an AC matrix row `AC-7 | NOT COVERED — deferred to phase_5 | (no Reason)`, when the verify agent processes the matrix in execute Step 4, then verify rejects with `REFUSED — deferred row missing Reason; specify does-not-block-goal | requires-amendment | requires-fork.` and the orchestrator re-dispatches Build per the existing 2-attempt budget.
  - *Independent test:* Inject a bare deferral row in a Build report, run Step 4, confirm rejection.

- **AC-11:** Given a row with `Reason: does-not-block-goal`, when Step 4 processes it, then the orchestrator pauses with the inline confirmation prompt; on `y` the phase proceeds, on `n` Build is re-dispatched.
  - *Independent test:* Confirm the prompt fires and behaves correctly for both inputs.

- **AC-12:** Given a row with `Reason: requires-amendment`, when Step 4 processes it, then the orchestrator routes the row to Step 6c with `amend` as the default triage option.
  - *Independent test:* Inject a `requires-amendment` row, confirm it surfaces at Step 6c with amend pre-selected.

- **AC-13:** Given a plan.md with `legacy_deferred_rows: true` in front-matter, when Step 4 processes a bare deferral row, then verify accepts the row without requiring a `Reason:` field (legacy behavior preserved).
  - *Independent test:* Set the flag in plan.md front-matter, inject a bare row, confirm acceptance.

- **AC-13a:** Given a plan.md with `legacy_deferred_rows: true` AND a Build report contains a row with `Reason: requires-amendment`, when Step 4 processes the matrix, then verify accepts the row format (legacy flag silences the format check) AND the orchestrator routes the row to Step 6c with `amend` as default (legacy flag does NOT silence triage routing).
  - *Independent test:* Set the flag, inject a `requires-amendment` row, confirm both behaviors fire.

### CAP-D — discovery triage + inline plan amendment

- **AC-14:** Given a phase completes its QA gate (Step 6) with one or more discoveries (a `requires-amendment` AC row, a `Deferred to reflection:` QA finding, or a Build oracle escalation citing missing prerequisite), when Step 6c executes, then the orchestrator presents an aggregated triage prompt enumerating all same-phase discoveries with the three options per discovery; on `amend` for any discovery the orchestrator dispatches `plan-amend` per FR-12.
  - *Independent test:* Construct a phase with three discoveries — one of each source: an AC matrix `requires-amendment` row produced by Step 4, a QA finding flagged `Deferred to reflection:` produced by Step 6, and a Build oracle escalation citing missing prerequisite produced by Step 2/3 — and verify Step 6c presents all three in the aggregated prompt with their source agents named correctly (verify, qa-phase, implementer respectively).

- **AC-15:** Given the operator chose `amend` for a discovery, when `plan-amend` returns its unified diff and `qa-plan` re-review returns clean, then the orchestrator produces a commit with subject `chore(plan): amend — <reason>` on the worktree branch and the plan.md diff matches what `plan-amend` emitted.
  - *Independent test:* Walk through one amend cycle end-to-end, inspect the commit message and the plan.md diff.

- **AC-16:** Given an amendment inserts new phases, when execute resumes, then it runs the first amendment phase (`phase_<N>_amend_1`) before any phase whose id sorts after `phase_<N+1>` would have run, and the amendment phases each go through their own full TDD/Implement track.
  - *Independent test:* Amend phase_3 with two new phases, observe execution order is `..., phase_3, phase_3_amend_1, phase_3_amend_2, phase_4, ...`.

- **AC-17:** Given a piece has used 2 plan amendments and the operator triggers a 3rd amendment (or 1 plan amendment + 1 spec amendment + 1 more of either), when Step 6c presents the prompt, then the orchestrator emits the budget-exhaustion escalation prompt; on `n`, the piece status is set to `blocked` in the manifest with a notes line citing budget exhaustion.
  - *Independent test:* Manually exhaust the budget, observe the escalation prompt and the manifest update on `n`.

- **AC-18:** Given Step 6c executes, when the operator chooses any of the three options for any discovery, then `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md` gains a new row recording phase, type, source agent, finding summary, choice, and the resolution commit SHA.
  - *Independent test:* Observe the .discovery-log.md after each triage choice; verify all rows have all six columns populated.

- **AC-19:** Given Final Review (the 4-reviewer end-of-piece board) returns a finding flagged as `requires-amendment`, when the orchestrator processes the finding, then it routes through the same Step 6c triage flow via Step 8 (Final Review Triage) per FR-16a; on `amend`, the piece re-opens for amendment phases (using `phase_final_amend_<K>` IDs) that run before the merge gate.
  - *Independent test:* Inject a `requires-amendment` Final Review finding, observe Step 8 dispatches Step 6c, the piece does not advance to merge until amendment phases complete, and the `.discovery-log.md` row records source-phase as `final-review`.

- **AC-20:** Given auto-mode is active and a discovery's estimated absorption size is < 50% of cumulative diff so far, when Step 6c executes, then the orchestrator auto-amends without operator prompting (still produces the `chore(plan): amend — <reason>` commit and resumes from the amendment phase).
  - *Independent test:* Run with `--auto`, inject a small discovery, verify no operator prompt fires and the amendment commit lands.

- **AC-21:** Given auto-mode is active and a discovery's estimated absorption size is ≥ 50% of cumulative diff, when Step 6c executes, then the orchestrator escalates to operator with the threshold message; auto-mode never auto-forks or auto-defers regardless of discovery size.
  - *Independent test:* Run with `--auto`, inject a large discovery, verify the escalation prompt fires.

- **AC-21a (NN-P-002 preservation):** Given an amendment phase has been inserted and run via FR-12, when the amendment phase completes its [Implement] block, then the orchestrator runs the standard per-phase QA gate (Step 6) before advancing — no auto-bypass of QA.
  - *Independent test:* Run an amendment cycle end-to-end with `--auto`; confirm `git log` shows a per-phase QA commit (or QA dispatch in orchestrator state) for the amendment phase.

- **AC-21b:** Given a discovery names a missing AC, when the operator chooses `amend-spec`, then the orchestrator dispatches `spec-amend`, applies the resulting diff to spec.md, and the affected AC appears in spec.md after qa-spec returns clean.
  - *Independent test:* Run a spec-amend cycle end-to-end against a sample spec; confirm spec.md gains the new AC and the commit message is `chore(spec): amend — <reason>`.

- **AC-21c:** Given the spec-amend budget is 1 per piece (within the 2-total budget), when the operator attempts a 2nd spec-amend in the same piece, then the orchestrator refuses with `Refused — spec-amend budget exhausted (1/1); choose plan-amend, fork, or defer.`
  - *Independent test:* Use one spec-amend, attempt a second; confirm refusal.

### CAP-E — reflection rerouting

- **AC-22:** Given Step 4.5 reflection runs and `reflection-future-opportunities` produces 3 findings, when the orchestrator processes the agent's report, then it dispatches the Step 6c triage flow once per finding (3 separate triage prompts in operator mode; auto-mode applies the threshold per finding).
  - *Independent test:* Observe per-finding triage with 3 findings; confirm 3 prompts fire (or 3 auto-decisions in auto-mode).

- **AC-23:** Given `reflection-process-retro` produces N findings, when the orchestrator processes the report, then it presents a single batched prompt enumerating all N findings with one defer-batch action.
  - *Independent test:* Observe one prompt for N findings.

- **AC-24:** Given the operator chose defer for a reflection finding, when the orchestrator routes through `/spec-flow:defer`, then the resulting backlog entry's `**Source:**` line names the originating phase as `step-4.5-reflection` and the agent as either `reflection-future-opportunities` or `reflection-process-retro`.
  - *Independent test:* Defer one finding from each agent, inspect the backlog entries' source lines.

- **AC-25:** Given Step 4.5 reflection completes, when the orchestrator advances to Step 5, then no `reflection: <piece> — append findings to backlogs` commit exists on the worktree branch (the previous auto-write commit pattern is gone).
  - *Independent test:* Run a piece end-to-end, grep `git log` for the old commit message pattern, confirm zero matches in v3.2.0+.

### Release ceremony

- **AC-26:** Given the release commit lands, when an operator verifies the version sync (NN-C-001 sync rule), then `plugins/spec-flow/.claude-plugin/plugin.json`'s `version` field equals `.claude-plugin/marketplace.json`'s spec-flow plugin entry's `version` field.
  - *Independent test:* Read both `plugins/spec-flow/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` with the LLM agent's file-reading tool; parse each as JSON inline; confirm `plugin.json.version === marketplace.json.plugins[name=spec-flow].version`. Per pi-009 ORC-6 / FR-13 (LLM-native [Verify] convention), do NOT shell out to `jq` — the test must run with no host runtime dependencies.

- **AC-27:** Given the release commit lands, when an operator inspects `plugins/spec-flow/CHANGELOG.md`, then it has a new `## [3.2.0] — YYYY-MM-DD` section at the top with at least Added (defer skill, .discovery-log.md, plan-amend agent, AC matrix Reason field) and Migration notes for upgraders subsections populated.
  - *Independent test:* Read CHANGELOG.md, confirm the section exists and has populated subsections.

- **AC-27a (NFR-004 / NFR-7):** Given the release commit lands, when an operator opens `plugins/spec-flow/skills/defer/SKILL.md`, `plugins/spec-flow/agents/plan-amend.md`, and `plugins/spec-flow/agents/spec-amend.md`, then each contains a `## Environment preconditions` section enumerating LLM-runtime + git + POSIX shell expectations and explicitly stating no external-tool runtime dependencies.
  - *Independent test:* grep for `## Environment preconditions` in all three files; confirm each is present and the prose mentions "LLM agent's runtime" and "no external-tool" pattern.

- **AC-27b (FR-22):** Given the release commit lands, when an operator reads `plugins/spec-flow/README.md`, then it documents Step 6c, the plan-amend agent, the spec-amend agent, and the /spec-flow:defer skill, AND the pipeline overview reflects the new flow.
  - *Independent test:* grep README.md for `Step 6c`, `plan-amend`, `spec-amend`, `defer`; confirm all four appear with concrete prose around them.

## Technical Approach

The piece is structured as **Phase Groups** to keep per-area QA focused (lessons from pi-009: per-phase QA Opus skip on shared-block phases caused B.1 → B.4 collateral damage; this piece's phase grouping segregates by sub-area to minimize cross-area shared-block touches):

- **Phase 1 — CAP-F (defer skill).** Land the new skill standalone. It has no orchestrator-side dependents at this point — it can be tested end-to-end via direct operator invocation. Test: invoke against a sample backlog file, confirm structured entry shape per FR-2.

- **Phase Group A (CAP-A) — depends_on at spec/plan time.** Two parallel sub-phases: A.1 modifies `skills/spec/SKILL.md` Phase 1, A.2 modifies `skills/plan/SKILL.md` Phase 1. Both consume the same `depends_on:` resolution pattern from `skills/execute/SKILL.md` Phase 1c (lifted into a new shared reference doc to avoid copy-paste — `plugins/spec-flow/reference/depends-on-precondition.md`).

- **Phase Group B (CAP-B) — AC matrix deferred-row rejection.** Two parallel sub-phases: B.1 modifies `reference/ac-matrix-contract.md` schema, B.2 modifies `skills/execute/SKILL.md` Step 4 to consume the new schema. The `legacy_deferred_rows: true` flag (FR-9) is added in B.2 with template update in `templates/plan.md`.

- **Phase 4 — plan-amend agent (CAP-D, prerequisite for the new triage step).** Land the new agent under `plugins/spec-flow/agents/plan-amend.md`. Standalone — test by invoking it against a sample plan.md + sample discovery report; confirm it emits a parseable unified diff. Phase 4 also lands the new `spec-amend` agent under `plugins/spec-flow/agents/spec-amend.md` (mirror of plan-amend with qa-spec re-dispatch instead of qa-plan).

- **Phase 5 — Step 6c discovery triage + amendment flow (CAP-D, load-bearing).** Modify `skills/execute/SKILL.md` to add Step 6c, the FR-12 amendment commit flow, FR-13 phase naming, FR-14 budget tracking, FR-15 .discovery-log.md authoring, FR-16 Final Review routing, and FR-17 auto-mode threshold. This is the largest single phase by LOC; per pi-009's >150-LOC phase-sizing rule, plan stage will likely split this further into a Phase Group with 3 sub-phases (orchestrator state + commit flow / Final Review routing / auto-mode threshold).

- **Phase Group C (CAP-E) — reflection rerouting.** Three parallel sub-phases: C.1 updates `agents/reflection-future-opportunities.md`, C.2 updates `agents/reflection-process-retro.md`, C.3 updates `skills/execute/SKILL.md` Step 4.5 to dispatch the triage flow on agent reports.

- **Phase 9 — Release ceremony (FR-20, FR-21).** plugin.json + marketplace.json + CHANGELOG.md. Single commit per NN-C-009 exception.

**Cross-phase content-dependency annotations.** Following pi-009's must-improve item ("plan.md must carry an explicit 'shared concern' annotation listing content blocks that no single phase may delete unilaterally"), the plan stage of this piece will annotate three shared concerns: (a) `skills/execute/SKILL.md` is touched by Phase 5 and Phase Group C — both touch Step 4.5 and Step 6 prose; (b) `templates/plan.md` is touched by Phase Group B and Phase 5 — both add front-matter keys; (c) `agents/reflection-*.md` files (the two reflection agents) share structural skeleton — Phase Group C must keep both agents' output schemas in sync.

**Plan-amend agent's diff+neighborhood scope.** Inherits from pi-009's collateral-damage lesson: the `qa-plan` re-review on amendment diffs must include any plan phase that scopes the same SKILL.md / file as an amended phase, not just the amended phases themselves. The agent's input contract (FR-11) requires the orchestrator to compute the neighborhood by enumerating phases whose `[Implement]` blocks touch any file the amendment touches.

## Testing Strategy

- **Unit-test focus areas:**
  - `/spec-flow:defer` skill: argument parsing (manual vs structured invocation), backlog file resolution (PRD-local vs `--global`), entry-format generation, refusal contracts (missing rationale).
  - AC matrix parser: `Reason:` field extraction, refusal on missing field, `legacy_deferred_rows: true` opt-out.
  - plan-amend agent: empty-diff case (NFR-4), suffix-form phase ID generation, neighborhood scope calculation.
  - Discovery aggregator (Step 6c): same-phase aggregation, source tagging (qa-phase / verify / build-escalation / final-review).

- **Integration-test boundaries:**
  - End-to-end amendment cycle: phase completes → discovery surfaces → operator chooses amend → plan-amend runs → qa-plan iter-until-clean → commit lands → resume from amendment phase → amendment phase's own QA → next original phase.
  - End-to-end fork cycle: discovery surfaces → operator chooses fork → manifest entry written → current piece status flips to `blocked` → execute halts.
  - End-to-end defer cycle: discovery surfaces → operator chooses defer → /spec-flow:defer writes entry → execute continues.
  - Final Review routing: 4-reviewer board returns a `requires-amendment` finding → triage flow re-opens piece → amendment phases run → merge gate fires after amendment phases pass.
  - Auto-mode threshold: small discovery auto-amends without prompt; large discovery escalates.

- **Edge cases to cover:**
  - Amendment budget exhaustion: 3rd amendment triggers escalation prompt; on `n`, manifest reflects `blocked` status.
  - Spec amendment vs plan amendment counting: 1 spec + 1 plan = 2 (budget reached); 2 plan = 2 (budget reached, no spec amendment used); 0 spec + 2 plan = 2 (budget reached); 1 spec + 0 plan = 1 (budget remaining: 1 plan amendment allowed).
  - Empty plan-amend diff (the agent decides the discovery doesn't actually need a plan change): orchestrator does not produce an empty `chore(plan): amend` commit; instead surfaces "no diff produced" and routes the discovery as a Build re-dispatch.
  - Defer skill invoked outside any worktree without `--source-piece`: graceful refusal per NFR-4.
  - Reflection agent emits zero findings: orchestrator advances to Step 5 without dispatching any triage prompts (Step 4.5 effectively no-ops).
  - `legacy_deferred_rows: true` interaction with `requires-amendment` rows: legacy flag silences the format check but does NOT silence triage routing — a `requires-amendment` row with the legacy flag set still routes through Step 6c.

