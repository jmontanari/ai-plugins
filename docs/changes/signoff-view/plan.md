---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
legacy_deferred_rows: false
fast: false
tdd: false
---

# Plan: signoff-view — Operator-driven full-document view at spec & plan sign-off

**Brief:** docs/changes/signoff-view/brief.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/CR entries)
**Status:** merged

## Overview

Add an operator-driven full-document review block at the spec and plan sign-off gates. The block prints the artifact's repo-root-relative path, a one-line section index, and three host-neutral view affordances (`!open`, `!cat`, or ask-the-orchestrator-to-print), then the existing approve / request-changes prompt. The default gate prints only the compact block — no auto-dump. Two doc-as-code phases: (1) edit the two sign-off steps; (2) version bump + CHANGELOG. Both phases use the Implement track — this is markdown skill prose with no automated test harness (charter-tools: markdown/YAML only), so `tdd: false` and verification is by `grep`/inspection.

## Architectural Decisions

No significant architectural decisions for this piece. The change is additive presentation prose confined to two existing sign-off steps; it introduces no new config key, contract, or agent. (Mechanism selection — operator-driven view vs. auto-print vs. plan-mode — was resolved during the brainstorm and is recorded in the brief's Out of Scope section.)

## Phases

### Phase 1 (Implement track): Sign-off review blocks

**Exit Gate:** Both sign-off steps print the review block (path + section index + three view options) ahead of the approve prompt; `grep` confirms the new block text in both files and confirms no `### Phase` anchor line changed.
**ACs Covered:** AC-1, AC-2, AC-3, AC-4, AC-5
**In scope:** The single sign-off step in each of the spec and plan skills.
**NOT in scope:** Version bump + CHANGELOG (Phase 2); any other gate (charter/prd/execute).
**Steps traversed (P2):** spec/SKILL.md Phase 4 step 4 (line ~287); plan/SKILL.md Phase 3 step 4 (line ~649).
**Dispatch sites (P3):** none (no `Agent({…})` dispatch is added or changed).
**Charter constraints honored in this phase:**
- CR-009 (Heading hierarchy): edit only the sign-off step prose; do not touch any `### Phase N` / `#### Sub-Phase` anchor line.
- CR-005 (Repo-root-relative paths): the printed path token is repo-root-relative.
- NN-C-003 (Backward compat): preserve the approve→continue / request-changes→QA-loop wording and behavior; add presentation only.

- [x] **[Implement]** Edit the spec sign-off step
  - File: `plugins/spec-flow/skills/spec/SKILL.md`, Phase 4 step 4 (currently: `4. When QA returns clean: present spec to user for sign-off.`).
  - Replace with an instruction to, when QA returns clean, print a review block for sign-off containing: (a) a ✅ header line with the repo-root-relative `spec.md` path; (b) a one-line section index — `wc -l` line count plus the spec's top-level `##` section names; (c) three view affordances, verbatim intent: open in a window (`!open <path>`), print to terminal (`!cat <path>`), or ask the orchestrator to print the full spec on demand; (d) the explicit instruction that the orchestrator does NOT auto-print the full spec — the full document prints only on operator request. Then the existing approve / request-changes prompt (Phase 5 step 1 behavior) follows unchanged.
  - Keep the surrounding "**Limitation:**" note and the `### Phase 5: Finalize` heading intact.

- [x] **[Implement]** Edit the plan sign-off step
  - File: `plugins/spec-flow/skills/plan/SKILL.md`, Phase 3 step 4 (currently: `4. Present to user for sign-off.`).
  - Replace with the same review-block instruction, parameterized for `plan.md` (path, line count, the plan's top-level `##` section names — e.g. Overview / Architectural Decisions / Phases / Testing). Same three view affordances and the same no-auto-print rule. The existing `### Phase 4: Finalize` heading and its step 1 (`User approves → continue`) follow unchanged.

- [x] **[Write-Tests]** No automated tests (doc-as-code; charter-tools permits markdown/YAML only, no test harness). Verification is by inspection per the Verify step.

- [x] **[Verify]**
  - Command: `cd /Volumes/joeData/ai-plugins/worktrees/signoff-view && grep -n '!open' plugins/spec-flow/skills/spec/SKILL.md plugins/spec-flow/skills/plan/SKILL.md && grep -n '!cat' plugins/spec-flow/skills/spec/SKILL.md plugins/spec-flow/skills/plan/SKILL.md`
  - Expected: at least one matching line in EACH of the two files for both `!open` and `!cat` (4+ match lines total across the two greps), confirming both sign-off blocks carry both shell affordances.
  - Anchor check: `grep -c '^### Phase ' plugins/spec-flow/skills/spec/SKILL.md plugins/spec-flow/skills/plan/SKILL.md` — counts must be unchanged from pre-edit (`spec`: same as before, `plan`: same as before; a reviewer compares against `git show HEAD:<file> | grep -c '^### Phase '`).
  - Failure indicator: a grep returns no match for either file (block missing from one gate), or the `### Phase ` count differs from HEAD (an anchor line was disturbed).

### Phase 2 (Implement track): Version bump + CHANGELOG

**Exit Gate:** All version-bearing files read `5.12.3` identically and `CHANGELOG.md` carries a `## [5.12.3]` section with a non-empty entry; the `releasing.md` grep recipe passes.
**ACs Covered:** AC-6
**In scope:** The four version-bearing files + CHANGELOG.
**NOT in scope:** The sign-off edits (Phase 1).
**Steps traversed (P2):** n/a (no multi-step orchestration file edited).
**Dispatch sites (P3):** none.
**Charter constraints honored in this phase:**
- NN-C-009 (Always bump version, all files): patch bump across all version-bearing files with a non-empty CHANGELOG section.
- NN-C-001 (version ⇄ marketplace sync): the marketplace entry is bumped in lockstep.

- [x] **[Implement]** Bump version 5.12.2 → 5.12.3
  - `plugins/spec-flow/plugin.json` — `"version": "5.12.3"`.
  - `plugins/spec-flow/.claude-plugin/plugin.json` — `"version": "5.12.3"`.
  - `.claude-plugin/marketplace.json` — the spec-flow entry's `version` → `5.12.3`.
  - `plugins/spec-flow/CHANGELOG.md` — add a `## [5.12.3] — 2026-06-10` section describing: operator-driven full-document view block at spec and plan sign-off (`!open` / `!cat` / on-demand print), default gate stays token-cheap (no auto-dump).

- [x] **[Write-Tests]** No automated tests (doc-as-code).

- [x] **[Verify]**
  - Command: `cd /Volumes/joeData/ai-plugins/worktrees/signoff-view && grep -RhoE '"version": *"[0-9]+\.[0-9]+\.[0-9]+"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json | sort -u && head -5 plugins/spec-flow/CHANGELOG.md`
  - Expected: every printed `"version"` string reads `"5.12.3"` (the `sort -u` collapses to a single line `"version": "5.12.3"` if all agree); CHANGELOG top section is `## [5.12.3]`.
  - Failure indicator: more than one distinct version string appears (skew), or the CHANGELOG top section is not `## [5.12.3]`.

## Integration Coverage

None in scope. This is a doc-as-code change to skill prose; it adds no external boundary, no `Agent({…})` dispatch, and no integration seam.

## Testing Strategy

- No automated harness (markdown/YAML plugin; charter-tools). Verification is by `grep`/inspection per each phase's `[Verify]` step and by the end-of-piece review board reading the two edited sign-off steps for AC compliance.
- Inspectable invariants: AC-1/AC-2/AC-3 (block present with all three affordances in each gate), AC-5 (anchor counts unchanged), AC-6 (version strings identical) are all reviewer-checkable by diffing the edited prose and re-running the Verify greps.
- Edge cases: confirm the no-auto-print rule is stated in both gates (the gate must not dump the full document by default); confirm the approve / request-changes wording is preserved (AC-4).
