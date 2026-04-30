# `depends_on:` precondition

This document factors the `depends_on:` precondition rules — reference resolution, status interpretation, refusal contracts, and the spec/plan-time triage prompt — out of `plugins/spec-flow/skills/execute/SKILL.md` Phase 1c so that `/spec-flow:spec`, `/spec-flow:plan`, and `/spec-flow:execute` can all cite a single source of truth. The execute-time enforcement at Phase 1c remains the ultimate refusal point; spec-time and plan-time checks are early-warning gates that surface the same unmet preconditions earlier in the pipeline and offer the operator three triage options before authoring continues.

## Purpose

Today, only `/spec-flow:execute` reads `depends_on:` (per `plugins/spec-flow/skills/execute/SKILL.md` Phase 1c). A piece can be specced and planned with prerequisites still `open` — operators only discover the gap at execute time, after spec and plan effort is already invested. This reference defines the rules so spec and plan can run the same check earlier and offer the operator a triage choice (pull-deps-in / fork / proceed) at the moment authoring begins.

The doc is read-only for `/spec-flow:execute` Phase 1c (Phase 1c continues to enforce the precondition as today). `/spec-flow:spec` Phase 1 and `/spec-flow:plan` Phase 1 cite this doc to run the same resolution + status logic and to render the operator triage prompt.

## Reference resolution

Resolve each entry in the current piece's `depends_on:` list to a target piece:

- **Qualified ref** `<dep-prd-slug>/<dep-piece-slug>` — look up the entry in `docs/prds/<dep-prd-slug>/manifest.yaml`.
- **Bare ref** `<dep-piece-slug>` — resolve against the current PRD's manifest (i.e. `docs/prds/<prd-slug>/manifest.yaml`).

Slug rules and the v3 layout that grounds these paths are specified in [`plugins/spec-flow/reference/v3-path-conventions.md`](v3-path-conventions.md).

## Status interpretation

For each resolved dependency, read its `status:` field. Per the piece-status state machine, statuses fall into three classes:

- **Passes (precondition satisfied):** `merged`, `done` (the backward-compatible alias of `merged`). Only these two statuses permit a downstream piece to start `execute`, and only these two satisfy the spec-time / plan-time precondition cleanly.
- **Transient (bypassable via `--ignore-deps`):** `open`, `specced`, `planned`, `in-progress`. The dependency is still progressing toward `merged`; the operator may choose to proceed anyway (operator override) at their own risk.
- **Structural failure (NEVER bypassable):** `superseded`, `blocked`. These signal the dependency will not reach `merged` along its current path:
  - `superseded` — the dep was abandoned and replaced by another piece. It will never reach `merged`. Running against a superseded dep almost always indicates the operator is looking at a stale `depends_on:` entry that should be rewritten or removed.
  - `blocked` — the dep has external blockers preventing progress. Running against a blocked dep risks compounding the blocker downstream.

The `--ignore-deps` flag (FR-021) bypasses transient-status refusals only. Structural-failure statuses refuse even when `--ignore-deps` is passed.

## Refusal contracts

The exact refusal strings (verbatim across spec, plan, and execute):

**Resolution-failure refusals** (fire BEFORE the status-based check; NOT bypassable via `--ignore-deps`):

- Malformed qualified ref (e.g. `auth/`, `/login`, `auth//login`):
  `malformed depends_on ref '<ref>' — expected <prd-slug>/<piece-slug> or bare <piece-slug>. Fix the manifest entry.`
- Qualified ref names a PRD that doesn't exist:
  `unmet depends_on — PRD '<prd-slug>' not found at docs/prds/<prd-slug>/. Check spelling.`
- Qualified or bare ref names a piece that isn't in the resolved manifest:
  `unmet depends_on — '<ref>' does not resolve to any known piece. Check spelling.`
- Self-reference (the current piece's own slug appears in its own `depends_on:`):
  `self-referential depends_on — '<ref>' is the piece you're trying to execute. Remove the entry.`

**Status-based refusal** (the unmet-deps blocker; bypassable for transient statuses via `--ignore-deps`, never bypassable for structural-failure statuses):

```
REFUSED — unmet depends_on preconditions:
  - auth/login-flow   status: planned   (needs: merged or done)
  - billing/invoices  status: blocked   (needs: merged or done)
Re-run once these dependencies are merged, or pass --ignore-deps to proceed anyway (see FR-021).
```

**Structural-failure refusal** (fires even when `--ignore-deps` is passed):

`dep <ref> status: <superseded|blocked> — --ignore-deps does not apply to structural-failure statuses; update depends_on or unblock the dependency before re-running.`

These refusal strings are identical across spec, plan, and execute. The phrase "before re-running" applies symmetrically — at spec time it means re-running `/spec-flow:spec`; at plan time, `/spec-flow:plan`; at execute time, `/spec-flow:execute`.

## Triage options at spec/plan time

At spec time and plan time, an unmet `depends_on:` is not necessarily a blocker — the operator may have a coherent reason to author against an unmerged prerequisite (e.g. they intend to land both in this piece). When the resolution succeeds and the status check finds at least one transient or structural-failure status, the skill presents the operator with a triage prompt naming each unmet dep and its status:

```
Piece <piece-slug> has unmet depends_on:
  - <ref> (status: <status>)
Choose:
  (1) pull-deps-in  — add Phase 0 entries to this piece that re-implement / verify the prerequisite
  (2) fork          — block this piece; spec the prerequisite first
  (3) proceed       — operator override (equivalent to --ignore-deps); deps remain unmet
```

Triage option semantics:

- **(1) pull-deps-in.** The operator absorbs the prerequisite work into the current piece. At spec time, this means the spec's Goal/Scope/FR/AC sections are authored to also cover the dep's behavior. At plan time, this means the plan inserts a Phase 0 (or earlier phases) that re-implements / verifies the prerequisite before the piece's own work begins. The unmet-dep entry is removed from `depends_on:` only after the prerequisite is actually covered in the artifact being authored.
- **(2) fork.** The operator declines to author this piece until the prerequisite is itself specced/planned/merged. The skill halts with `Refused — fork chosen; spec the prerequisite piece <ref> first.` (or the plan-time analog `Refused — fork chosen; plan the prerequisite piece <ref> first.`). The operator's next action is to switch to the prerequisite piece and run `/spec-flow:spec` (or `/spec-flow:plan`) on it.
- **(3) proceed.** The operator overrides the precondition and continues authoring. This is the spec/plan-time equivalent of execute's `--ignore-deps` flag. Deps remain unmet at the moment of authoring; the operator accepts that the piece will refuse at execute time unless the deps reach `merged` first or the operator passes `--ignore-deps` again at execute time. **Structural-failure statuses (`superseded`, `blocked`) refuse this option** — the same rule that makes `--ignore-deps` non-bypassable at execute time applies symmetrically to the proceed option at spec/plan time.

The triage prompt is rendered exactly as shown above (literal `(1) pull-deps-in`, `(2) fork`, `(3) proceed` markers; one bullet per unmet dep).

## Recording the choice — `## Dependency Triage` section format

When the operator's choice is recorded, spec and plan write a `## Dependency Triage` section into the artifact being authored (spec.md or plan.md). The section is required (not skip-on-empty) when any dep was unmet at the moment of authoring; if all deps were already `merged` or `done`, the section is omitted.

Format:

```
## Dependency Triage

<one bullet per unmet dep>:
- `<ref>` (status: `<status>` at <YYYY-MM-DD>) — <resolution>
```

Resolution values per triage option:

- **pull-deps-in:** `Operator chose pull-deps-in; <Phase 0 will re-implement / verify | spec covers prerequisite behavior in §<section>>.`
- **proceed:** `Operator override; deps remain unmet at <spec|plan> time.`

The fork path does not produce a `## Dependency Triage` section because the skill halts before authoring the artifact — the refusal message is the audit trail.

The `## Dependency Triage` section gives future readers and review-board agents a verbatim record of why the piece was authored against an unmerged dep. It is auditable evidence that the operator made a deliberate choice rather than missing the gap.

## See also

- [`plugins/spec-flow/skills/execute/SKILL.md`](../skills/execute/SKILL.md) Phase 1c — the execute-time enforcement that already exists. The rules in this reference are the verbatim factoring of Phase 1c's resolution + status + refusal-contract logic; spec/plan/execute all run the same logic.
- [`plugins/spec-flow/reference/v3-path-conventions.md`](v3-path-conventions.md) — slug rules, manifest layout, and path resolution that ground the qualified/bare ref forms.
