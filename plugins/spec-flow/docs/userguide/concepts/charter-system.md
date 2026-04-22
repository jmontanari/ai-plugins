# The charter system

The charter is the set of binding project-wide constraints that every spec-flow artifact inherits from. Six files, each addressing a distinct concern, sitting in `docs/charter/`:

```
docs/charter/
├── architecture.md        layer boundaries, dependency direction, module ownership
├── non-negotiables.md     NN-C-xxx entries — project-wide hard rules
├── coding-rules.md        CR-xxx entries — code conventions
├── tools.md               tool inventory + version pins
├── processes.md           branching, commit, release, review workflow
└── flows.md               standard end-to-end workflows
```

Together they answer the question: *"What does every piece in this project have to honor, no matter what?"*

## Why a charter

Without a charter, every spec starts from scratch. Every reviewer asks "should this respect convention X?" and answers with an opinion. Non-negotiables live in one person's head and die when that person moves on.

With a charter:

- Binding constraints are **enumerated with stable IDs** (`NN-C-001`, `CR-006`, etc.).
- Every spec's `Non-Negotiables Honored` section cites the IDs it respects and explains *how* it respects them.
- Every reviewer verifies those citations are accurate and complete.
- Drift is visible — the charter is versioned; amendments are tracked.

## The three citable namespaces

spec-flow distinguishes three classes of binding rules, each with its own ID prefix:

### NN-C-xxx — project non-negotiables (charter-level)

Rules that apply **project-wide, to every plugin and every piece**. Examples:

- `NN-C-001` — marketplace.json version must match each plugin's plugin.json version (no drift)
- `NN-C-002` — POSIX-only tooling, no rsync
- `NN-C-009` — three-place version bump on plugin version change (plugin.json + marketplace.json + CHANGELOG)

Written once in `docs/charter/non-negotiables.md`. Retired entries are tombstoned (marked `RETIRED`) rather than deleted — the ID never gets reused.

### NN-P-xxx — product non-negotiables (PRD-level)

Rules specific to **this product's PRD**. Live in the PRD's `## Non-Negotiables (Product)` section. Examples might be:

- `NN-P-001` — every public API endpoint must have contract tests
- `NN-P-003` — dog-food before recommend (don't ship an install path you haven't personally run)

Scoped to the PRD that introduces them. A different product's PRD has different NN-P entries.

### CR-xxx — coding rules

Conventions about **how code is written**: naming, imports, formatting, module layout, YAML frontmatter shape, CHANGELOG format, heading hierarchy. Live in `docs/charter/coding-rules.md`. Examples:

- `CR-001` — agent Markdown files must declare `name:` and `description:` frontmatter
- `CR-005` — paths in docs are repo-root-relative
- `CR-006` — CHANGELOG follows Keep a Changelog format
- `CR-009` — heading hierarchy (no skipped levels)

CR-xxx is the "style guide with teeth" set — violations are caught by reviewers and fixed before merge.

## How citations flow through the pipeline

Every artifact that derives work from the charter cites the applicable entries **by ID**:

- **Spec** → has a `### Non-Negotiables Honored` section and a `### Coding Rules Honored` section. Each line names an NN-C / NN-P / CR ID and describes *how this piece honors it*. Vague phrasing ("the piece respects the rule") fails review; concrete phrasing ("uses structured logging via the shared logger; no PII fields written per CR-015") passes.
- **Plan** → allocates each cited constraint to exactly one phase's "Charter constraints honored in this phase" slot. Drops (spec cites it, no phase claims it) and duplicates (two phases both claim it) are must-fix findings.
- **Implementation** → the implementer agent has an explicit rule: "Follow the project's charter, architecture designs, and non-negotiables. Binding sources, in order of precedence: `<docs_root>/charter/`, legacy architecture docs if charter is absent, PRD non-negotiables section, and any binding rules the plan explicitly cites by ID."
- **Reviewers** → qa-spec, qa-plan, qa-phase, and the review board all verify citation integrity: every cited ID exists in its source file (no hallucinations), no retired entry is cited, and the "honored by this piece" explanation is concrete.

## Citation integrity — the anti-drift

Reviewers catch three specific citation failures:

1. **Hallucinated ID** — the spec cites `NN-C-047` but no such entry exists in the charter. Must-fix.
2. **Retired entry cited** — the spec cites an entry whose tombstone says `RETIRED`. Must-fix — either drop the citation or upgrade to the superseding entry.
3. **Vague honoring** — the "how this piece honors it" line is wall-paper phrasing. Must-fix — rewrite to cite the specific mechanism.

These checks prevent the slow drift where citations accumulate but become ceremonial. If an ID is cited, a reviewer will verify the citation is real, current, and concrete.

## When the charter doesn't exist yet

Not every project starts with a charter. spec-flow supports two modes:

- **v2.0.0+ projects (charter-first):** charter exists. `charter → prd → spec → plan → execute` is the full flow.
- **Pre-charter / legacy projects:** charter is absent. Legacy `docs/architecture/` docs and unprefixed `NN-xxx` entries in the PRD's `## Non-Negotiables` section take the place of `docs/charter/`. Reviewers apply the same citation-integrity rules.

Run `/spec-flow:charter` to author or retrofit a charter for an existing project. The skill supports three modes:

- **Bootstrap** — greenfield, no prior architecture docs. Socratic brainstorm produces the six files from scratch.
- **Update** — charter exists; evolve specific entries. Divergence detection flags when updates conflict with already-shipped pieces.
- **Retrofit** — legacy architecture docs exist; migrate them into charter form. Preserves original intent; produces a migration trace.

## The charter snapshot

Plans authored against a charter include a `charter_snapshot:` front-matter block that records the charter-entry IDs the plan relies on. This serves two purposes:

1. At QA time, reviewers confirm every snapshot ID exists and is current.
2. At merge time, if the charter has changed since the plan was authored, the pipeline surfaces a divergence that must be resolved (re-author the plan, or confirm the change doesn't affect the piece).

Snapshots prevent the class of bug where a piece is specced against an old charter, the charter evolves mid-flight, and the piece ships honoring rules that no longer exist.

## Where to go next

- [Pipeline](./pipeline.md) — how charter flows into every downstream stage.
- [commands/charter.md](../commands/charter.md) — the full charter command walkthrough.
- [QA loop](./qa-loop.md) — how citation integrity is verified at every review.
