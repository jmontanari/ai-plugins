---
charter_snapshot:
  architecture: "2026-06-01"
  non-negotiables: "2026-06-05"
  tools: "2026-06-01"
  processes: "2026-06-01"
  flows: "2026-06-01"
  coding-rules: "2026-06-01"
  integrations: ~
jira_key: ~
jira_url: ~
---

# Brief: dispatch-integrity — Dispatch integrity hardening

## Source

`docs/improvement-backlog.md` — four findings routed to `"dispatch-integrity" small-change`
(2026-06-10 cross-repo field sweep, source-verified against spec-flow 5.8.0):
worktree-path contract (HIGH), manifest.yaml ownership (HIGH), Step 5.5 merge-gate
precondition (MEDIUM), implementer truncation detection (MEDIUM). The findings ARE the
functional requirements; each finding's verbatim FIX seeds the acceptance criteria.

## Problem Statement

Four field-verified defects let the execute / review-board orchestration *dispatch* work or
*trust* returns without integrity guarantees. (1) No agent template or dispatch site requires a
`WORKTREE: <abs-path>` preamble, so agents infer paths from the plan and may resolve reads
against the MAIN repo — producing false gate verdicts, the worst failure class for a review
system (2 logged incidents: a false-FAIL on a clean phase, and a false FAIL + misleading PASS
from board reviewers reading main-repo files). (2) `manifest.yaml` ownership is implicit — an
agent set `status: merged` during a [QA] step before Final Review, requiring a manual revert and
risking premature piece closure. (3) The Step 5.5 manifest commit is ordered before Step 6 only
in advisory prose, so a retried Step 6 (or a push after a revert) can merge without it — a piece
reached main with `status: in-progress`. (4) Implementer output truncation on long-running gate
commands (~8-min mypy/test runs) is undetectable, so the orchestrator manually staged + committed
and silently bypassed the implementer's self-review checklist. All four are plugin-level guard
gaps with logged cross-repo incidents; none is blocked by an in-flight piece in this repo.

## Functional Requirements

- **FR-1 (worktree-path contract, HIGH):** Every dispatched agent prompt begins with a
  `WORKTREE: <absolute-path>` preamble plus "resolve every read/write from this root." Wire it
  into all execute + review-board dispatch sites; document the rule in
  `reference/coordinator-contract.md`; add the field to each dispatched agent's input contract
  with a `[WORKTREE-ABSENT]` marker escalation when the preamble is missing.
- **FR-2 (manifest ownership, HIGH):** Declare `manifest.yaml` orchestrator-owned. (a) Add an
  explicit "manifest.yaml is orchestrator-owned; agents MUST NOT modify it" line to the
  implementer / tdd-red / fix-code / refactor input contracts, and a manifest-ownership row to
  `reference/coordinator-contract.md`. (b) Extend the execute Step 6b sweep to flag any
  agent-produced diff that touches a `manifest.yaml` file as a blocking violation.
- **FR-3 (Step 5.5 precondition, MEDIUM):** Make "HEAD contains the Step 5.5 manifest commit" an
  explicit, checked precondition of Step 6 — for both `merge_strategy` values and every retry
  path — and add it to the push-ready / PR-open checklist line emitted to the operator.
- **FR-4 (implementer truncation, MEDIUM):** The implementer stages its work and emits a
  `READY-TO-COMMIT` marker (self-review complete) BEFORE invoking long-running gate commands. The
  orchestrator treats truncated output lacking the marker as a resumable failure and re-dispatches
  with prior context; the manual stage-and-commit bypass is prohibited.

## Acceptance Criteria

1. AC-1: `reference/coordinator-contract.md` contains a worktree dispatch-preamble rule (the
   `WORKTREE: <abs-path>` contract + "resolve every read/write from this root" + `[WORKTREE-ABSENT]`
   escalation) AND a manifest-ownership entry. (grep-verifiable)
2. AC-2: Every agent dispatched by execute or review-board carries a `WORKTREE:` input-contract
   field and a `[WORKTREE-ABSENT]` escalation instruction in every body file it ships: both twins
   when both have bodies; the single `.md` for the singletons `research.md` and `spike.md` (which
   have no `.agent.md`); and the `.md` only for `review-board-security`, whose `.agent.md` is a
   frontmatter-only stub with no body.
3. AC-3: The implementer, tdd-red, fix-code, and refactor input contracts each state
   "manifest.yaml is orchestrator-owned" with an explicit MUST-NOT-modify instruction (both twins).
4. AC-4: Every agent dispatch site in `skills/execute/SKILL.md` and `skills/review-board/SKILL.md`
   injects a `WORKTREE: <abs-path>` preamble into the agent prompt — no un-prefixed dispatch
   remains. (grep-verifiable: every dispatch composes the preamble)
5. AC-5: execute Step 6b (and the Step G9 group sweep) flags any agent-produced diff touching a
   `manifest.yaml` path as a blocking violation, with the check expressed as orchestrator
   prose / git-diff logic (no new binary or runtime dependency).
6. AC-6: execute Step 6 refuses to proceed unless HEAD contains the Step 5.5 manifest commit —
   stated as an explicit precondition for `squash_local` AND `pr`, on the first run and every
   retry path — and the operator checklist line names this precondition.
7. AC-7: The implementer contract defines a `READY-TO-COMMIT` marker emitted after self-review and
   before any long-running gate; execute Step 3 treats marker-absent truncation as a resumable
   failure (re-dispatch with prior context) and the manual stage-and-commit bypass is removed /
   prohibited.
8. AC-8: After all edits, the 22 agent twin pairs that were byte-identical before this change
   remain byte-identical (same git blob hash; verifiable: `git ls-files -s` blob equality per
   pair). The 4 pre-existing divergent pairs — plan-amend, qa-plan, tdd-red, and
   review-board-security — are not required to be unified by this piece.
9. AC-9: spec-flow version is bumped 5.9.0 → 5.10.0 in `plugins/spec-flow/.claude-plugin/plugin.json`
   and the spec-flow entry in `.claude-plugin/marketplace.json`; a `## [5.10.0]` CHANGELOG entry
   describes the four guards.

## Non-Negotiables Honored

- NN-C-008 (self-contained agent prompts): the `WORKTREE: <abs-path>` preamble is orchestrator-
  attached context — exactly the kind of load-bearing state NN-C-008 requires the prompt to carry
  rather than have the agent infer.
- NN-C-002 (markdown + config only, no runtime deps): the Step 6b manifest sweep (FR-2b) and the
  truncation-resume protocol (FR-4) are implemented as orchestrator prose / git-diff logic in
  SKILL.md — no new binary, hook dependency, or interpreter is introduced.
- NN-C-009 + NN-C-001 (version bump + plugin.json ↔ marketplace.json sync): Phase 7 bumps the
  version in both version-bearing files in one change.
- NN-C-003 (backward compatibility within a major): every change is additive (new contract fields,
  new preconditions, stricter guards on existing flows) — no existing invocation pattern breaks;
  the change stays within 5.x.
- NN-C-007 (CHANGELOG per plugin, Keep a Changelog): Phase 7 adds a `## [5.10.0]` entry.

## Coding Rules Honored

- CR-004 (conventional commits with plugin scope): commits use the `spec-flow` scope.
- CR-005 (absolute file paths in documentation): the new coordinator-contract rule and agent
  contract fields reference repo files by absolute path.
- CR-006 (CHANGELOG — Keep a Changelog format): Phase 7's entry follows the format.
- CR-008 (thin-orchestrator skills, narrow-executor agents): the manifest sweep and resume logic
  live in the execute orchestrator; agent contracts stay declarative (state ownership + emit a
  marker), not procedural.
- CR-009 (semantic heading hierarchy): new `coordinator-contract.md` sections nest correctly under
  existing `##` headings.

## Out of Scope

- fix-code sibling-file / call-site context enrichment (backlog → FR-018 qa-hardening).
- Opus QA cross-phase composition skip-predicate change (backlog → FR-018 qa-hardening).
- Execute pre-flight test-suite baseline / inherited-failure attribution (backlog → exec-guardrails FR-011).
- qa-phase-lite async-lifecycle checks / routing carve-out (backlog → FR-018 qa-hardening).
- Any change to upstream spec/plan authoring agents beyond adding the `WORKTREE:` field (their
  file-resolution behavior is otherwise untouched).
- Implementing the manifest sweep or truncation detection as a new hook binary or interpreter
  dependency (NN-C-002 forbids it; orchestrator prose only).

## Scope Gate Override

The scope gate fired at **6 implementation phases** (4 distinct findings, 2 of them — the Step 6b
manifest sweep and the truncation-resume protocol — net-new orchestration mechanisms rather than
pure documentation). The operator elected to continue as a small-change rather than route to the
full PRD → spec → plan pipeline. `scope_gate_override = true`. A 7th phase (version bump +
CHANGELOG) is mandatory release housekeeping, not a finding.
