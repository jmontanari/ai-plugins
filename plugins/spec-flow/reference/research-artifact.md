# Research Artifact (research.md) — Contract

This document is the single source of truth for the `research.md` artifact produced by the spec-flow research agent. It is cited by `plugins/spec-flow/agents/research.md` (production rules for the agent that writes `research.md`), `plugins/spec-flow/skills/spec/SKILL.md` (marker emission on dispatch and post-dispatch paths), and `plugins/spec-flow/skills/plan/SKILL.md` (Phase 1 consumption and seed logic). Any schema detail, marker definition, or return-contract rule lives here and nowhere else; the agent and both skills defer to this file for authoritative definitions.

## Location

`research.md` is written to and read from the following path within the piece worktree:

```
docs/prds/<prd-slug>/specs/<piece-slug>/research.md
```

`<prd-slug>` and `<piece-slug>` are the slugs of the current piece as defined in `docs/prds/<prd-slug>/manifest.yaml`. This path is the single authoritative location — the agent writes here, the spec skill commits here, and the plan skill looks here.

## research.md structure

The file uses an annotated two-part structure: two FIXED top-level headings followed by one heading per cluster.

**Fixed top-level headings (in this order, always present):**

The first two `## ` headings in every `research.md` are fixed and must appear in this order:

- `## Brainstorm Inference Digest` — piece purpose, design constraints, and open ambiguities inferred from the PRD, manifest, and charter.
- `## Codebase Conventions` — empirical conventions from peer-component scan: file structure, naming patterns, shared config idioms, and wrapper conventions confirmed present in the repository.

**Per-cluster headings:**

After the two fixed sections, the agent writes one `## ` heading per cluster of related files. The research agent clusters by functional cohesion of the files it explores, since it has no finalized spec target list yet. Each cluster heading contains the following four bold-labelled blocks in this exact order:

```markdown
## <Cluster Name>

### File Inventory
**File Inventory:** ...

### Dependency Map
**Dependency Map:** ...

### Test Landscape
**Test Landscape:** ...

### Pattern Catalog
**Pattern Catalog:** ... verbatim code blocks (3–10 lines) ...
```

This is the identical cluster-grouped layout that `introspection.md` uses today. The four block labels (`**File Inventory:**`, `**Dependency Map:**`, `**Test Landscape:**`, `**Pattern Catalog:**`), the H2/H3 heading nesting, and the verbatim code block convention are preserved exactly so that the plan skill's section-extraction logic remains stable across both artifacts.

### Full-file shape

A complete `research.md` has this shape (top to bottom):

1. The two fixed sections in order: the digest prose under the first fixed heading, then the conventions list under the second fixed heading.
2. One `## <Cluster Name>` section per cluster, each containing the four `### ` subsections (`File Inventory`, `Dependency Map`, `Test Landscape`, `Pattern Catalog`) with their bold-labelled blocks and verbatim code examples.

The number of cluster sections varies per piece; there is no fixed minimum.

## Marker contract

Three markers are defined for use across the spec and plan skills. Each marker has an exact trigger condition and a designated emitter; no other marker forms are valid.

### `[RESEARCH-UNAVAILABLE: <reason>]`

Emitted by the **spec** skill. Triggers when ANY of the following occur:

- The research agent returns `STATUS: BLOCKED` in its digest.
- The dispatch itself errors (agent process error, timeout, or other non-clean exit).
- `research.md` is missing or zero-length on the piece branch after a nominally successful dispatch.
- The `git add`/`git commit` of `research.md` fails — staging zero files (path not found) or a non-zero exit from `git commit`. In this case emit `[RESEARCH-UNAVAILABLE: research.md commit failed]`.

The marker is **non-blocking**: the spec skill logs it inline and continues with the L-10 fallback path. No `research.md` is committed on this path. `<reason>` is a short human-readable description of which trigger fired (e.g., `agent returned STATUS: BLOCKED`, `dispatch timed out`, `research.md empty after dispatch`).

### `[RESEARCH-CONSUMED: <N> files, <M> re-read]`

Emitted by the **plan** skill Phase 1 when `research.md` exists on the piece branch at the start of Phase 1. `N` is the count of covered files (files appearing in any cluster's `**File Inventory:**` block of `research.md`). `M` is the count of files re-read during Phase 1 — targeted top-ups consisting of non-covered spec targets (files the spec names that are not covered files) plus staleness re-reads (covered files whose content has changed since the research agent's commit, detected via `git diff`).

### `[RESEARCH-ABSENT: running full exploration]`

Emitted by the **plan** skill Phase 1 when `research.md` does not exist on the piece branch at the start of Phase 1. On this path the plan skill runs the full per-cluster exploration loop unchanged (no seeding from `research.md`).

### STATUS lines and marker placement

Each marker is emitted as a single bracketed line at the point in the plan skill's Phase 1 output where the branch decision is made. Markers are not placed in `introspection.md` or `research.md` — they appear in the orchestrator's Phase 1 progress output only.

## Return contract

The research agent returns a structured digest to the main thread at the end of its run. The digest is **≤ 2 000 tokens**. The on-disk `research.md` written to the piece branch may be richer (longer, more verbatim code, expanded cluster sections); the digest is a summary intended for the spec skill's in-context use and for the marker-emission decision.

The digest's FINAL line is exactly one of:

```
STATUS: OK
```

```
STATUS: BLOCKED
```

`STATUS: OK` means `research.md` was written successfully and the artifact is available on the piece branch. `STATUS: BLOCKED` means the agent could not complete the exploration (missing inputs, unresolvable dependencies, or an error that prevents a useful output). On `STATUS: BLOCKED` the agent must include a brief reason in the digest body before the status line; it must NOT write a partial `research.md`.

No other STATUS values are valid. The spec skill keys the `[RESEARCH-UNAVAILABLE]` / no-marker branch decision on whether this final line equals `STATUS: OK`.

## Covered file

A **covered file** is a file appearing in any cluster's `**File Inventory:**` block of `research.md`.

This definition is the input to the N/M counting used in the `[RESEARCH-CONSUMED: <N> files, <M> re-read]` marker: N is the total count of covered files across all clusters in `research.md`; M is the count of additional files the plan skill reads during Phase 1 beyond that set (non-covered spec targets and staleness re-reads of covered files whose content has changed).

**N=0 edge case.** When `research.md` exists at the canonical path but contains no cluster sections (the research agent found nothing relevant or only wrote the two fixed headings), N=0. The plan skill emits `[RESEARCH-CONSUMED: 0 files, <M> re-read]` and processes every spec target as non-covered (all through the targeted top-up in step 2). No special handling required — the algorithm naturally produces a correct `introspection.md` via pure targeted reads, equivalent in effect to the ABSENT path.

## See also

- `plugins/spec-flow/agents/research.md` — agent that produces `research.md` and the ≤2K digest.
- `plugins/spec-flow/skills/spec/SKILL.md` — emits `[RESEARCH-UNAVAILABLE]` or proceeds on `STATUS: OK`.
- `plugins/spec-flow/skills/plan/SKILL.md` — emits `[RESEARCH-CONSUMED]` or `[RESEARCH-ABSENT]` in Phase 1.
- `plugins/spec-flow/reference/brainstorm-procedure.md` — L-10 fallback path used when research is unavailable.
