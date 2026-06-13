---
charter_snapshot:
  architecture: "2026-06-13"
  non-negotiables: "2026-06-13"
  tools: "2026-06-13"
  processes: "2026-06-13"
  flows: "2026-06-13"
  coding-rules: "2026-06-13"
  integrations: ~
jira_key: ~
jira_url: ~
---

# Brief: preflight-read-cap — Cap execute pre-flight to bounded probes

## Source

Operator-observed during a live `spec-flow:execute` run on the `prop_firm`
project: at Phase 2 start the coordinator ran a series of `git grep` calls and
then `Read` four source files (`context.py`, `emitter.py`, a sample test, and
others) into its own context before dispatching the implementer. Diagnosed in
the preceding session as Step 1b pre-flight over-reach.

## Problem Statement

During `spec-flow:execute`, the orchestrator's Step 1b pre-flight is meant to
gather *cheap* facts (LOC counts, a schema sample, symbol presence, hook
inventory) and inject them into agent prompts so the agents don't rediscover
them. In practice the coordinator reads full source/test file **bodies** to
learn signatures and usage before dispatching the implementer. This is wasted
cost and a discipline violation: the coordinator's context is long-lived and is
the most expensive context in the pipeline (~73% of pipeline token cost per the
efficiency baseline), and the Coordinator Return Discipline already forbids
pasting raw file bodies into it for *agent returns* — but the same rule was
never stated for pre-flight *reads*. The implementer reads the files it edits
anyway, so coordinator full-file reads are redundant. The root cause is soft
wording: Step 1b's intro ("collects facts the agents would otherwise
rediscover") and the Orchestrator Role bullet ("cheap reads") are permissive
enough to invite full-file `Read`s, even though the enumerated probes
(items 1–8) only authorize `wc -l`, `head -N`, and `git grep -l`.

## Functional Requirements

- FR-1: Add an explicit **Probe budget** guardrail to Step 1b that enumerates
  the allowed read forms and forbids reading full source/test file bodies into
  coordinator context during pre-flight.
- FR-2: The allowed-form enumeration covers exactly: `wc -l`; bounded
  `head -N` / `tail -N` (the item-2 schema sample, N ≤ ~20); `git grep -l` /
  `git grep -n` / `grep -n` (paths and line numbers, never bodies); and reading
  the small structured config/doc files already named by the items
  (`.pre-commit-config.yaml`, `introspection.md`) plus `plan.md` / `spec.md`.
- FR-3: State the narrow escape hatch: a signature/usage detail the implementer
  genuinely needs up front belongs in the plan's Change Specification Block, not
  a coordinator file-body read. (A pointer to the existing plan mechanism — no
  new mechanism is introduced.)
- FR-4: Tighten the Orchestrator Role bullet (`SKILL.md:132`) to name the same
  cap and cross-reference the Step 1b Probe budget, so the two descriptions of
  "fact-gathering probes" do not contradict each other.
- FR-5: Bump the spec-flow plugin version `5.18.0 → 5.19.0` across all four
  version-bearing files and add a CHANGELOG entry.

## Acceptance Criteria

1. AC-1: Step 1b contains a **Probe budget** subsection that states the
   coordinator MUST NOT `Read` full source or test file bodies during pre-flight,
   and includes the narrow escape hatch from FR-3.
2. AC-2: The Probe budget subsection enumerates the allowed read forms from FR-2
   and is consistent with Step 1b items 1–8 (no item is contradicted; items 1–8
   themselves are unchanged in behavior).
3. AC-3: The Orchestrator Role bullet at `SKILL.md:132` names the bounded-probe
   cap and references Step 1b's Probe budget; the two sites do not contradict.
4. AC-4: `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`,
   and the spec-flow entry in `.claude-plugin/marketplace.json` all read `5.19.0`;
   the NN-C-001 sync diff produces no output.
5. AC-5: `plugins/spec-flow/CHANGELOG.md` has a new `## [5.19.0] — 2026-06-13`
   section with at least one non-empty **Changed** entry describing the guardrail.
6. AC-6: No behavioral change to Step 1b probe items 1–8 or to any other execute
   step — the diff is limited to the new guardrail prose, the line-132 bullet,
   and the four version-bearing files.

## Non-Negotiables Honored

- NN-C-001 (version/marketplace sync): both `plugin.json` descriptors and the
  root `marketplace.json` entry are bumped to `5.19.0` in the same change.
- NN-C-009 (always bump on plugin change, all version-bearing files): the change
  touches `plugins/spec-flow/`, so all four version-bearing files
  (root `plugin.json`, `.claude-plugin/plugin.json`, root `marketplace.json`,
  `CHANGELOG.md`) are updated to `5.19.0`.
- NN-C-003 (backward compat within a major): the guardrail is a tightening of
  existing orchestrator prose — no config key, plan format, or invocation
  pattern changes; existing plans and `.spec-flow.yaml` files still execute.

## Coding Rules Honored

- CR-002 (skill frontmatter schema): the execute SKILL.md `name`/`description`
  front-matter is left unchanged; edits are body-only.
- CR-006 (CHANGELOG — Keep a Changelog): the new section uses a `Changed`
  grouping under a `## [5.19.0] — YYYY-MM-DD` heading.
- CR-008 (thin-orchestrator skills): the change reinforces this rule directly —
  it keeps the orchestrator a conductor by forbidding it from absorbing source
  bodies that belong in executor agents.
- CR-009 (semantic heading hierarchy): the Probe budget guardrail is added as a
  bolded lead-in within Step 1b, not a new heading level that would disturb the
  `### Step 1b` → item hierarchy.

## Out of Scope

- Plan densification (making Change Specification Blocks carry more signatures so
  pre-flight has less to find) — that is the exec-ready PRD direction and is its
  own pipeline work.
- Any change to the `implementer` agent or to how it reads files.
- Any change to the Coordinator Return Discipline rules for *agent returns*
  (those already exist; this change only extends the spirit to pre-flight reads).
- Changing item 8 `introspection.md` reading — `introspection.md` is a bounded
  structured doc and remains an explicitly allowed read.
