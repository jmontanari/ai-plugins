---
charter_snapshot:
  architecture: "2026-06-09"
  non-negotiables: "2026-06-09"
  tools: "2026-06-09"
  processes: "2026-06-09"
  flows: "2026-06-09"
  coding-rules: "2026-06-09"
  integrations: ~
jira_key: ~
jira_url: ~
---

# Brief: manifest-ops — Manifest query + state tool

## Problem Statement

spec-flow's `manifest.yaml` grows one entry per piece, each with a multi-line
`description`, `prd_sections`, `dependencies`, and `status`. Past ~6 pieces
(exec-ready is already at 8) the file becomes hard to scan by eye: you cannot
quickly see which pieces are still open, what a given piece depends on, or — the
real question — which open pieces are *unblocked and workable next*. Today that
reasoning is done ad-hoc by reading the whole file. This change adds a
deterministic tool the skill layer can call to read the manifest, filter by
status, resolve dependencies, render a table, compute the ready-to-work set, and
safely mutate one entry's `status`.

## Functional Requirements

- FR-1 — Parse: read a `manifest.yaml`, extracting per piece `slug`, `name`,
  `status`, `dependencies`, `prd_sections`. Tolerate the real schema
  (`slug` / `dependencies` / `status`) — not the `id` / `depends_on` the `status`
  skill currently assumes.
- FR-2 — Open items: `open` subcommand lists pieces whose status is not a
  terminal-done state (`merged`).
- FR-3 — Dependencies: `deps <slug>` lists what `<slug>` depends on;
  `deps <slug> --reverse` lists pieces that depend on `<slug>`.
- FR-4 — Table: `table` renders all pieces as an aligned text table
  (`slug | status | deps | prd_sections`).
- FR-5 — Ready set: `ready` lists pieces workable next = status `open` AND every
  dependency is `merged` (or `done`, the backward-compatible terminal alias per
  spec-flow's piece-status state machine).
- FR-6 — Mutate state: `set-status <slug> <new-status>` updates exactly that
  piece's `status:` in place, validates `<new-status>` against the status
  vocabulary, and refuses unknown slugs.
- FR-7 — Dual implementation: a `python3` fast path AND a complete pure-bash (awk)
  fallback, auto-selected by a dispatcher (`python3` if present, else bash). Both
  produce identical output on the fixtures.
- FR-8 — Skill wrapper: a new `manifest` skill documents and invokes the tool.
- FR-9 — status-skill drift fix: update the `status` skill's manifest-read
  instructions to reference the real fields (`slug` / `name` / `dependencies` /
  `status`) instead of `id` / `depends_on`.

## Acceptance Criteria

1. AC-1: against `docs/prds/exec-ready/manifest.yaml`, `open` returns exactly
   `spec-preresearch`, `flywheel-repo`, `flywheel-global` (the non-`merged`
   pieces).
2. AC-2: `deps spike-agent` returns `plan-concrete`, `sonnet-coord`;
   `deps research-unify --reverse` includes `plan-concrete` and `spec-preresearch`.
3. AC-3: `ready` against `exec-ready` returns `flywheel-repo` (status `open`, dep
   `sonnet-coord` is `merged`) and excludes `flywheel-global` (dep `flywheel-repo`
   not merged) and `spec-preresearch` (status `specced`, not `open`). Dependencies
   are satisfied when their status is `merged` or `done` (the backward-compatible
   terminal alias per spec-flow's piece-status state machine).
4. AC-4: `table` output is column-aligned and lists all 8 pieces with their status.
5. AC-5: `set-status flywheel-repo specced` changes only that entry's `status:`
   line; a re-parse confirms the new value and every other piece is byte-unchanged.
   `set-status bogus-slug specced` exits non-zero with an "unknown slug" error and
   writes nothing.
6. AC-6: with `python3` on PATH the dispatcher uses the python path; with `python3`
   masked the bash fallback produces identical stdout for `open`, `deps`, `ready`,
   and `table` across the `exec-ready`, `shared`, and `prop_firm` manifests.
7. AC-7: `plugin.json` and `marketplace.json` both move `5.7.0` → `5.8.0`
   (NN-C-001 version sync).
8. AC-8: the `status` skill's SKILL.md no longer references `id:` or `depends_on:`
   for manifest reads; a grep for those tokens in the manifest-read section returns
   nothing, and the real fields (`slug` / `dependencies`) appear instead.

## Non-Negotiables Honored

- NN-C-001 (version sync): plugin + marketplace bumped to 5.8.0 in lockstep — AC-7.
- NN-C-005 (graceful optional-dep degradation): the bash fallback when `python3` is
  absent mirrors the hook no-op-on-missing-dep principle — AC-6.

## Non-Negotiable Override (owner-accepted)

- NN-C-002 (no runtime dependencies): **knowingly violated and accepted by the repo
  owner.** A `python3` fast-path script ships under `plugins/spec-flow/`, which
  NN-C-002 bans and whose `hooks/`-only exception does not cover. The charter text
  is left unchanged by operator decision. Mitigation: the pure-bash fallback is
  mandatory and complete, so zero-install (NN-C-002's rationale) is preserved in
  practice. The review-board architecture reviewer will flag this at the execute
  merge gate; the finding is expected and will be waved off by the owner.

## Coding Rules Honored

- The new `manifest` SKILL.md carries valid frontmatter (`name`, `description`) per
  charter-coding-rules; `name:` is the bare local name, not the plugin-prefixed
  form (NN-C-003 / NN-C-004).

## Scope Gate Override

- The operator chose to continue as a small-change after the scope gate fired. The
  gate triggered at 4+ phases (bash impl, python impl, dispatcher + skill, version
  sync + dual-fixture validation) and re-fired at 5 phases when the `status` drift
  fix was folded in. `scope_gate_override = true`.

## Out of Scope

- Editing NN-C-002's text or any charter file.
- Creating or parsing manifests for non-spec-flow YAML; multi-PRD aggregation; the
  `coverage:` block.
- Reordering pieces, editing dependencies, or any mutation beyond `status`.
