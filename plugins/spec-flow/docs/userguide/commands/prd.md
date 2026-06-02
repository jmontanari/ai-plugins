# /spec-flow:prd

Import or normalize a Product Requirements Document, then decompose it into implementable *pieces* tracked in a manifest. A single project can host one or more PRDs — each lives in its own directory under `docs/prds/`.

## What it does

Produces two artifacts per PRD, placed under `docs/prds/<prd-slug>/`:

- `docs/prds/<prd-slug>/prd.md` — the normalized PRD with stable section IDs (`G-x` for goals, `FR-x` for functional requirements, `NFR-x` for non-functional requirements, `SC-x` for success criteria, `NN-P-x` for product non-negotiables). Includes YAML front-matter declaring the slug, status, and version.
- `docs/prds/<prd-slug>/manifest.yaml` — an enumeration of *pieces* (work units). Each piece maps to one or more PRD sections, declares its dependencies, carries a status, and points directly to its spec and plan files once they exist.

The `<prd-slug>` is a short, lowercase, hyphenated identifier you choose (e.g. `ddf-creator`, `platform-v2`, `shared`). It becomes part of every path, branch name, and worktree root for pieces in that PRD.

A piece is a unit of work that can be specced and shipped independently. Pieces are the things you'll later run `/spec-flow:spec` against.

## When to run it

- **After `/spec-flow:charter`** on a fresh project — to import or author the first PRD.
- **When adding a new PRD** — a new product domain, a major release, or a distinct capability area that belongs in a separate manifest. Each gets its own slug and directory.
- **When the PRD amends** — add a new section, revise goals, add a new success criterion. The skill supports incremental updates, not just first-time import.
- **When you need to re-decompose** — pieces have turned out to be wrong and need re-slicing.

## Three modes

The skill auto-detects mode from arguments and project state; if nothing disambiguates, it asks:

```
How would you like to start?
(a) Import — I have an existing PRD document (BMad output, Notion export, plain markdown, etc.)
(b) Create — I have an idea but no document yet; help me build the PRD from scratch
(c) Update — I have an existing PRD in this pipeline I want to amend
```

- **Import** — point at a source doc; the skill extracts and re-numbers content into the template.
- **Create** — a structured Socratic interview elicits problem, personas, user stories, success metrics, non-goals, constraints, risks, and open questions before writing the PRD.
- **Update** — amend an existing PRD (add pieces, reprioritize, revise goals); runs an impact assessment and offers to re-review affected pieces' specs.

(A fourth path, `--review`, is the end-of-pipeline fulfillment check — see "qa-prd vs qa-prd-review" below.)

## The flow

1. **Argument parsing → slug validation → slug uniqueness check** — before any greenfield write.
2. **Charter prerequisite check** — if `charter.required: true` and no charter exists, the skill halts and tells you to run `/spec-flow:charter` first.
3. **Normalization / interview** — the skill assigns stable IDs to every requirement section. Goals become `G-1`, `G-2`, …; functional requirements become `FR-001`, `FR-002`, …; success criteria `SC-001`, …; product non-negotiables `NN-P-001`, … (project-wide constraints are proposed for the charter as `NN-C-xxx` instead). During the Create interview, decisions the user explicitly defers are marked `[PENDING-DECISION: <area>]` inline — these are informational at PRD level; the spec brainstorm for the affected piece resolves them.
4. **Decomposition brainstorm** — Socratic dialogue to break the PRD into pieces: smallest shippable unit, which sections each piece covers, dependency order, what's deferred. The brainstorm also captures the **branching strategy** (step 4l).
5. **qa-prd gate** (Opus, PRD completeness) — runs *before* the manifest is created; must-fix findings block manifest creation.
6. **Manifest authoring** — produces `manifest.yaml` with one entry per piece, plus the branching fields.
7. If findings emerge, fix-doc makes targeted fixes. Up to 3 iterations.
8. You sign off.
9. PRD, manifest, and `backlog.md` commit to master.

## qa-prd vs qa-prd-review

Two distinct PRD review agents, at opposite ends of the pipeline:

- **qa-prd** (Opus) — the **pre-manifest completeness gate** during import/create. Checks the PRD itself is complete and falsifiable before pieces are enumerated. Must-fix findings block manifest creation.
- **qa-prd-review** (Opus) — the **end-of-pipeline fulfillment review**, run via `/spec-flow:prd --review <slug>` after all pieces ship. Reads the PRD, every completed spec, and the codebase, and validates that what was built actually fulfills the PRD.

## Branching strategy fields

The decomposition brainstorm asks how the PRD's pieces are branched, and writes three fields to the manifest front-matter that every downstream skill enforces automatically:

```yaml
feature_branch: <name or null>   # piece branches base off this and merge here after execute
merge_target: <name>             # where feature_branch merges when the full PRD ships (default: master)
pr_required: <true|false>        # piece branches merge via PR (default true) vs direct push
```

If `feature_branch` is set, piece branches base off it (not master) and never commit PRD work directly to `merge_target` until the PRD ships.

## Loops

- **Decomposition brainstorm** — iterate on piece boundaries until the decomposition feels right. Pieces that are too big become unmanageable; too small and they thrash on dependencies.
- **QA loop** — up to 3 iterations of qa-prd-review ↔ fix-doc.

## What you get

**`docs/prds/<prd-slug>/prd.md`** — structured, ID'd, ready to be cited by every downstream artifact. Includes YAML front-matter and stable-ID requirement sections. Example shape:

```markdown
---
slug: ddf-creator
status: active
version: 3
---

# DDF Creator System

## Goals
- **G-1:** ...
- **G-2:** ...

## Functional Requirements
- **FR-001:** ...
- **FR-002:** ...

## Non-Functional Requirements
- **NFR-001:** ...

## Success Criteria
- **SC-001:** ...
- **SC-002:** ...

## Non-Negotiables (Product)
- **NN-P-001:** ...
- **NN-P-003:** dog-food before recommend — don't ship an install path you haven't personally run
```

**`docs/prds/<prd-slug>/manifest.yaml`** — the piece enumeration. Example:

```yaml
schema_version: 1
generated: 2026-04-27
last_updated: 2026-04-27
prd_source: "docs/prds/ddf-creator/prd.md"
feature_branch: feature/ddf-creator    # or null for direct-to-master
merge_target: master
pr_required: true

pieces:
  - name: pipeline-infra
    slug: pipeline-infra
    description: Core pipeline infrastructure shared by all protocols
    prd_sections: [FR-011, FR-012, FR-013, NFR-001, SC-006]
    depends_on: []
    status: planned
    spec: docs/prds/ddf-creator/specs/pipeline-infra/spec.md
    plan: docs/prds/ddf-creator/specs/pipeline-infra/plan.md

  - name: snmp-create-p1
    slug: snmp-create-p1
    description: Single SNMP device at 100% on all 9 scoring dimensions
    prd_sections: [FR-001, FR-005, FR-006, SC-001, SC-002]
    depends_on: [pipeline-infra]
    status: open

coverage:
  total_prd_sections: 24
  covered_sections: 24
  uncovered_sections: []
  percentage: 100
```

Note that `spec:` and `plan:` fields are added to a piece entry by the skill when those artifacts are created — they are not present for `open` pieces.

## Handoff

Next: pick an `open` piece and run `/spec-flow:spec <prd-slug>/<piece-slug>` — or run `/spec-flow:status` and let it tell you which piece to start with.

## Multiple PRDs in one project

A project can have more than one PRD. Each lives in its own `docs/prds/<prd-slug>/` directory with its own manifest, its own pieces, and its own lifecycle state. The charter at `<charter_root>/skills/charter-*/` (`.github` or `.claude`, resolved per [reference/charter-location.md](../../../reference/charter-location.md)) is shared — it applies to every PRD in the repo.

Common reasons to add a second PRD:
- A new major product area with distinct goals and success criteria (not just more pieces on the same capability).
- A major version boundary where v2 requirements are truly independent of v1.
- A contractually or organizationally separate deliverable.

Run `/spec-flow:prd` a second time and supply a new slug when prompted. The skill creates `docs/prds/<new-slug>/` alongside the existing one — nothing in the existing PRD changes.

## Worked example

You import a draft PRD with four goals, nine functional requirements, and three success criteria. After brainstorming decomposition with slug `my-product`:

```
G-1  (user authentication)    → split into PI-101, PI-102, PI-103
G-2  (data export)             → PI-104
G-3  (admin dashboard)         → deferred — out of scope for v1
G-4  (observability)           → PI-105

FR-001..FR-004 (auth)          → mapped to PI-101, PI-102, PI-103
FR-005..FR-007 (export)        → mapped to PI-104
FR-008, FR-009 (logging)       → mapped to PI-105

SC-001 (90% login success)     → uncovered-intentional (measurement goal)
SC-002 (p99 export < 5s)       → PI-104's acceptance criteria reference it
SC-003 (zero logging gaps)     → PI-105
```

Manifest ends up with 5 pieces at `docs/prds/my-product/manifest.yaml`, clear dependencies, clean coverage notes. Every FR is either mapped to a piece or explicitly called out as intentionally uncovered.

## Common decomposition choices

- **Slice by user journey** when the PRD is user-facing (auth flow → export flow → admin flow).
- **Slice by layer** when the PRD is infrastructure-heavy (schema migration → API → client → observability).
- **Slice by risk** when part of the work is speculative — ship the known-good part first, defer the risky part.
- **Keep each piece under ~3 days of work**. Pieces larger than that tend to grow during spec authoring and should be split.

## Where to go next

- [/spec-flow:spec](./spec.md) — author a spec for one piece.
- [/spec-flow:status](./status.md) — see which pieces are ready to work on.
