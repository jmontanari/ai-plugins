---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
  integrations: ~
jira_key: ~
jira_url: ~
---

# Brief: signoff-view — Operator-driven full-document view at spec & plan sign-off

## Problem Statement

At the spec sign-off (spec skill Phase 4) and plan sign-off (plan skill Phase 3), the skill only "presents for sign-off" — effectively a model-written summary. To review the full `spec.md` / `plan.md` at the approve point, the operator must either ask the model to re-print it (which costs output tokens on every gate) or hunt for the file path manually. The operator wants, at each gate, to see the full document *on their own terms* — open it in another window, print it to their terminal, or have the model print it on demand — and then decide before approving. The default gate must stay token-cheap: it should never auto-dump the full document into the conversation.

## Functional Requirements

- FR-1: At both sign-off gates, print a compact **review block** containing the artifact's repo-root-relative path, a one-line section index (line count + top-level section names), and explicit operator-driven view options.
- FR-2: The review block offers three host-neutral, user-initiated ways to view the full document: (a) open in a separate window — `!open <path>`; (b) print to the operator's terminal — `!cat <path>`; (c) ask the orchestrator to print the full document on demand (rendered in chat). The operator chooses one, several, or none.
- FR-3: The default gate prints **only** the compact review block — it does NOT auto-dump the full document into the conversation. The on-demand model print (FR-2c) fires only when the operator explicitly asks.
- FR-4: After the review block, the existing approve / request-changes confirmation is presented, unchanged in behavior.
- FR-5: Bump the plugin version per NN-C-009 and add a CHANGELOG entry.

## Acceptance Criteria

1. AC-1: spec skill Phase 4 step 4 prints the review block (path + section index + the three view options) followed by the approve / request-changes prompt, and does NOT auto-print the full spec.
2. AC-2: plan skill Phase 3 step 4 prints the review block (path + section index + the three view options) followed by the approve prompt, and does NOT auto-print the full plan.
3. AC-3: The review block offers at minimum all three view affordances — open-in-window (`!open <path>`), print-to-terminal (`!cat <path>`), and "ask the orchestrator to print it" — and its wording does not rely on clickable file-path links.
4. AC-4: The existing approve→continue and request-changes→QA-loop behavior at both gates is unchanged (the change is additive presentation only).
5. AC-5: No `### Phase N` heading-anchor lines are altered in either SKILL.md; edits are confined to the sign-off step prose (CR-009).
6. AC-6: The plugin version is bumped 5.12.2 → 5.12.3 across `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, and the `.claude-plugin/marketplace.json` spec-flow entry, with a matching `CHANGELOG.md` section; all version strings read identically.

## Non-Negotiables Honored

<!-- Product non-negotiables are not applicable for change-track briefs -->
- NN-C-003 (Backward compat within a major): the change is additive presentation only; no skill name, template header, config key, or hook contract is removed or renamed, and the approve / request-changes flow is preserved.
- NN-C-009 (Always bump version, all files): patch bump 5.12.2 → 5.12.3 across all version-bearing files with a non-empty CHANGELOG section.
- NN-C-001 (version ⇄ marketplace sync): the `.claude-plugin/marketplace.json` spec-flow entry is bumped in lockstep with `plugin.json`.

## Coding Rules Honored

- CR-009 (Heading hierarchy): the sign-off edits preserve the H2/H3/H4 hierarchy and alter no `### Phase N` detection anchors.
- CR-005 (Repo-root-relative paths in docs): the printed review block uses a repo-root-relative artifact path.

## Out of Scope

- Clickable file-path links — they do not work reliably in the operator's terminal.
- Auto rendered-echo of the full document at the gate by default — rejected for per-gate token cost; the model print is on-demand only (FR-2c).
- Plan-mode / `ExitPlanMode` integration — host-specific (Claude Code only, won't port to Copilot CLI), and its no-write mode conflicts with the sign-off's commits.
- Any sign-off gate other than spec (Phase 4) and plan (Phase 3) — charter, prd, and execute phase gates are untouched.
- A config key to toggle the behavior — display-only and cheap; no toggle needed.

## Source

Operator-initiated change via `/spec-flow:small-change`. Design converged through live testing of `!cat`, `!open`, and clickable-path affordances during the brainstorm session (2026-06-10).
