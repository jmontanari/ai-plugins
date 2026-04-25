# v2.0.0 Piece 2 — Template Updates + pipeline-config + Session-Start Doctrine Load

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire charter into the foundational templates (prd/spec/plan), add the `charter:` config block to pipeline-config.yaml with safe defaults, and teach the session-start hook to conditionally inject charter files into session context.

**Architecture:** Pure markdown + config + bash changes. Five files modified. `charter.required` defaults to `false` (so pre-charter projects don't break); the hook no-ops silently when `docs/charter/` is absent. Downstream skills (piece 3) will flip `required` handling to enforce on new projects.

**Tech stack:** Markdown, YAML, bash.

**Spec reference:** `docs/superpowers/specs/2026-04-20-charter-stage-and-docs-structure-design.md` §8

## Files

- Modify: `plugins/spec-flow/templates/prd.md`
- Modify: `plugins/spec-flow/templates/spec.md`
- Modify: `plugins/spec-flow/templates/plan.md`
- Modify: `plugins/spec-flow/templates/pipeline-config.yaml`
- Modify: `plugins/spec-flow/hooks/session-start`
- Modify: `plugins/spec-flow/CHANGELOG.md`

## Piece 2 scope fence (NOT in this plan)

- No changes to `prd`, `spec`, `plan`, `execute`, `status` SKILLs (piece 3)
- No changes to any agent files (piece 4)
- Charter skill (piece 1) unchanged
- No enforcement of `charter.required: true` anywhere yet — piece 3 does that

### Task 1 — Update `prd.md` template

Replace entire content with the new NN-P schema + Charter reference.

### Task 2 — Update `spec.md` template

Replace NN section with split Project (NN-C) + Product (NN-P) subsections. Add "Coding Rules Honored" section. Add `charter_snapshot` front-matter.

### Task 3 — Update `plan.md` template

Add `charter_snapshot` front-matter at top. Add `**Charter:** docs/charter/` reference line. Add "Charter constraints honored" slot to each of the two phase examples.

### Task 4 — Update `pipeline-config.yaml`

Append `charter:` block with `required: false` default (safe for existing projects; new projects get prompted to run `/spec-flow:charter`).

### Task 5 — Update `session-start` hook

Add conditional charter-file reading after doctrine load. Controlled by `charter.doctrine_load` config key. If `docs/charter/` exists and config key is set, concatenate those files into session_context.

### Task 6 — CHANGELOG piece 2 entry

Add `[2.0.0-piece.2]` section above piece 1's entry in CHANGELOG.md.

### Task 7 — Commit piece 2

Single commit covering all six file changes. Message summarizes the template + config + hook work.

## Self-review checklist (end of plan)

- Template changes are additive (no renaming of existing section anchors that specs from v1.5 already rely on, unless the change is explicitly documented in CHANGELOG migration notes)
- `charter.required: false` default preserves backward compat
- Hook changes no-op silently when charter is absent
- NN-C, NN-P, CR ID conventions consistent with piece 1 templates and qa-charter agent
