# /spec-flow:prd

Import or normalize a Product Requirements Document, then decompose it into implementable *pieces* tracked in a manifest.

## What it does

Produces two artifacts:

- `docs/prd/prd.md` — the normalized PRD with stable section IDs (`G-x` for goals, `FR-x` for functional requirements, `NFR-x` for non-functional requirements, `SC-x` for success criteria, `NN-P-x` for product non-negotiables).
- `docs/prd/manifest.yaml` — an enumeration of *pieces* (work units). Each piece maps to one or more PRD sections, declares its dependencies, and carries a status.

A piece is a unit of work that can be specced and shipped independently. Pieces are the things you'll later run `/spec-flow:spec` against.

## When to run it

- **After `/spec-flow:charter`** on a fresh project.
- **When the PRD amends** — add a new section, revise goals, add a new success criterion. The skill supports incremental updates, not just first-time import.
- **When you need to re-decompose** — pieces have turned out to be wrong and need re-slicing.

## The flow

1. **Import mode** — you paste or point at a source PRD (often a markdown doc, a Google Docs export, or freeform bullet points).
2. **Normalization** — the skill assigns stable IDs to every requirement section. Goals become `G-1`, `G-2`, ...; functional requirements become `FR-001`, `FR-002`, ...; non-negotiables become `NN-P-001`, `NN-P-002`, ...
3. **Decomposition brainstorm** — Socratic dialogue to break the PRD into pieces:
   - What's the smallest independently-shippable unit?
   - Which sections does each piece cover?
   - What's the dependency order?
   - What's deferred / out-of-scope?
4. **Manifest authoring** — produces `manifest.yaml` with one entry per piece.
5. **qa-prd-review** adversarially reviews the PRD + manifest for coverage: every requirement is either mapped to a piece, or explicitly marked as uncovered-intentional with a reason.
6. If findings emerge, fix-doc makes targeted fixes. Up to 3 iterations.
7. You sign off.
8. Both files commit to master.

## Loops

- **Decomposition brainstorm** — iterate on piece boundaries until the decomposition feels right. Pieces that are too big become unmanageable; too small and they thrash on dependencies.
- **QA loop** — up to 3 iterations of qa-prd-review ↔ fix-doc.

## What you get

**`docs/prd/prd.md`** — structured, ID'd, ready to be cited by every downstream artifact. Example shape:

```markdown
## Goals
- **G-1:** ... (user-facing goal)
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

**`docs/prd/manifest.yaml`** — the piece enumeration. Example:

```yaml
schema_version: 1
prd_source: "docs/prd/prd.md"

pieces:
  - name: PI-001-marketplace-version-sync
    description: Fix marketplace.json spec-flow version drift
    prd_sections: [FR-001, NN-C-001]
    dependencies: []
    status: done

  - name: PI-002-version-sync-ci
    description: CI job enforcing NN-C-001 across all plugins
    prd_sections: [FR-001, NFR-003, NN-C-001]
    dependencies: [PI-001-marketplace-version-sync]
    status: open

coverage:
  total_prd_sections: 15
  covered_sections: 8
  uncovered_sections: [G-3, SC-002, NN-P-003, ...]
  notes: |
    Uncovered-but-intentional: SC-001/SC-002 are measurement goals, not
    implementable pieces. NN-P-003 is a process rule.
```

## Handoff

Next: pick an `open` piece and run `/spec-flow:spec <piece-name>` — or run `/spec-flow:status` and let it tell you which piece to start with.

## Worked example

You import a draft PRD with four goals, nine functional requirements, and three success criteria. After brainstorming decomposition:

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

Manifest ends up with 5 pieces, clear dependencies, clean coverage notes. Every FR is either mapped to a piece or explicitly called out as intentionally uncovered.

## Common decomposition choices

- **Slice by user journey** when the PRD is user-facing (auth flow → export flow → admin flow).
- **Slice by layer** when the PRD is infrastructure-heavy (schema migration → API → client → observability).
- **Slice by risk** when part of the work is speculative — ship the known-good part first, defer the risky part.
- **Keep each piece under ~3 days of work**. Pieces larger than that tend to grow during spec authoring and should be split.

## Where to go next

- [/spec-flow:spec](./spec.md) — author a spec for one piece.
- [/spec-flow:status](./status.md) — see which pieces are ready to work on.
