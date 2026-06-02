# The charter system

The charter is the set of binding project-wide constraints that every spec-flow artifact inherits from. In v4 the charter is **not a docs directory** — it is published as a set of **skill files** the host can load on demand. Seven domains, one skill each, living under a single host-native skills root: either `.github/skills/charter-<domain>/SKILL.md` (GitHub / Copilot CLI convention) or `.claude/skills/charter-<domain>/SKILL.md` (Claude Code convention). A project uses **exactly one** root, written below as `<charter_root>` (`.github` or `.claude`). How that root is resolved for reading and chosen for writing is defined canonically in [reference/charter-location.md](../../../reference/charter-location.md):

```
<charter_root>/skills/        # <charter_root> = .github or .claude
├── charter-architecture/SKILL.md     layer boundaries, dependency direction, module ownership
├── charter-non-negotiables/SKILL.md  NN-C-xxx entries — project-wide hard rules
├── charter-coding-rules/SKILL.md     CR-xxx entries — code conventions
├── charter-tools/SKILL.md            tool inventory + version pins
├── charter-processes/SKILL.md        branching, commit, release, review workflow
├── charter-flows/SKILL.md            standard end-to-end workflows
└── charter-integrations/SKILL.md     external service constraints — Jira/MCP/CI/webhooks
```

Each file is a real skill with `name:` / `description:` frontmatter:

```yaml
---
name: charter-architecture
description: "Read before touching layer structure, module boundaries, or dependency direction in src/. Binds where business logic, HTTP handling, and data access may live and what may import what."
---
```

Together they answer the question: *"What does every piece in this project have to honor, no matter what?"*

## Why a charter

Without a charter, every spec starts from scratch. Every reviewer asks "should this respect convention X?" and answers with an opinion. Non-negotiables live in one person's head and die when that person moves on.

With a charter:

- Binding constraints are **enumerated with stable IDs** (`NN-C-001`, `CR-006`, etc.).
- Every spec's `Non-Negotiables Honored` section cites the IDs it respects and explains *how* it respects them.
- Every reviewer verifies those citations are accurate and complete.
- Drift is visible — the charter is committed, one file per domain, and amendments are tracked in `git log`.

## Where the charter lives — location resolution

The charter root is **resolved, not hardcoded**. The full rules live in [reference/charter-location.md](../../../reference/charter-location.md); the short version:

- **Reading.** Any skill that consumes charter (`status`, `intake`, `spec`, `plan`, `execute`, `review-board`, `charter --update`) detects the active root by existence — it globs for `charter-*/SKILL.md` under both `.claude/skills/` and `.github/skills/` — or honors the `charter_root:` key in `.spec-flow.yaml` when set. Resolution is read-only and never writes the key.
- **Writing (bootstrap).** When `/spec-flow:charter` creates a charter and no root is established yet, it **detects which host directory exists** and recommends that one: only `.github/` present → recommend `.github/skills/`; only `.claude/` present → recommend `.claude/skills/`. If **both** exist it asks you to pick (no auto-pick); if **neither** exists it asks (no default — it never assumes). After you confirm, it persists `charter_root: .github` (or `.claude`) to `.spec-flow.yaml` so every downstream skill resolves the same location without re-detecting or re-prompting.

There is no `<charter_root>` other than `.github` or `.claude`, and there is no pre-v4 docs-based layout.

## Two-tier loading

Loading all seven domains into every agent would bloat context for rules that don't apply to the work at hand. The charter uses a **two-tier loading model**:

| Tier | Mechanism | Default domains |
|---|---|---|
| **Always-on doctrine** | `charter.doctrine_load` in `.spec-flow.yaml`, injected by the SessionStart hook | `non-negotiables`, `architecture` |
| **On-demand** | Description-triggered invocation by the host | `tools`, `flows`, `processes`, `coding-rules`, `integrations` |

The SessionStart hook reads `charter.doctrine_load` and injects only those charter skills at startup — by default `non-negotiables` and `architecture`, the two domains that bind almost every change. The remaining five are loaded on demand: because each is a skill with a project-specific, trigger-accurate `description:`, the host pulls it in when a contributor is about to do work that domain governs (e.g. `charter-integrations` triggers when wiring a Jira or MCP step).

This is why charter skill descriptions matter so much. A generic description means a domain is never consulted; the `charter` skill runs each one through `skill-creator`'s description-optimization loop precisely so it triggers reliably.

After authoring or editing charter skills, run `/reload-plugins` (or start a new session) so the SessionStart doctrine load and on-demand triggers pick up the new content.

## The three citable namespaces

spec-flow distinguishes three classes of binding rules, each with its own ID prefix:

### NN-C-xxx — project non-negotiables (charter-level)

Rules that apply **project-wide, to every PRD and every piece**. Examples:

- `NN-C-001` — marketplace.json version must match each plugin's plugin.json version (no drift)
- `NN-C-002` — POSIX-only tooling, no rsync
- `NN-C-009` — three-place version bump on plugin version change (plugin.json + marketplace.json + CHANGELOG)

Written once in `<charter_root>/skills/charter-non-negotiables/SKILL.md` (`<charter_root>` = `.github` or `.claude`, resolved per [reference/charter-location.md](../../../reference/charter-location.md)). Retired entries are tombstoned (marked `RETIRED`) rather than deleted — the ID never gets reused.

### NN-P-xxx — product non-negotiables (PRD-level)

Rules specific to **this product's PRD**. Live in the PRD's `## Non-Negotiables (Product)` section. Examples might be:

- `NN-P-001` — every public API endpoint must have contract tests
- `NN-P-003` — dog-food before recommend (don't ship an install path you haven't personally run)

Scoped to the PRD that introduces them. A different product's PRD has different NN-P entries.

### CR-xxx — coding rules

Conventions about **how code is written**: naming, imports, formatting, module layout, YAML frontmatter shape, CHANGELOG format, heading hierarchy. Live in `<charter_root>/skills/charter-coding-rules/SKILL.md`. Examples:

- `CR-001` — agent Markdown files must declare `name:` and `description:` frontmatter
- `CR-005` — paths in docs are repo-root-relative
- `CR-006` — CHANGELOG follows Keep a Changelog format
- `CR-009` — heading hierarchy (no skipped levels)

CR-xxx is the "style guide with teeth" set — violations are caught by reviewers and fixed before merge.

## How citations flow through the pipeline

Every artifact that derives work from the charter cites the applicable entries **by ID**:

- **Spec** → has a `### Non-Negotiables Honored` section and a `### Coding Rules Honored` section. Each line names an NN-C / NN-P / CR ID and describes *how this piece honors it*. Vague phrasing ("the piece respects the rule") fails review; concrete phrasing ("uses structured logging via the shared logger; no PII fields written per CR-015") passes.
- **Plan** → allocates each cited constraint to exactly one phase's "Charter constraints honored in this phase" slot. Drops (spec cites it, no phase claims it) and duplicates (two phases both claim it) are must-fix findings.
- **Implementation** → the implementer agent follows the charter as binding doctrine. The always-on charter skills (non-negotiables + architecture) are injected into its context; any other binding rule the plan cites by ID is supplied with the phase.
- **Reviewers** → qa-spec, qa-plan, qa-phase, and the review board all verify citation integrity: every cited ID exists in its source file (no hallucinations), no retired entry is cited, and the "honored by this piece" explanation is concrete. The board's `architecture` reviewer reads `charter-architecture` + `charter-coding-rules`.

## Citation integrity — the anti-drift

Reviewers catch three specific citation failures:

1. **Hallucinated ID** — the spec cites `NN-C-047` but no such entry exists in the charter. Must-fix.
2. **Retired entry cited** — the spec cites an entry whose tombstone says `RETIRED`. Must-fix — either drop the citation or upgrade to the superseding entry.
3. **Vague honoring** — the "how this piece honors it" line is wall-paper phrasing. Must-fix — rewrite to cite the specific mechanism.

These checks prevent the slow drift where citations accumulate but become ceremonial. If an ID is cited, a reviewer will verify the citation is real, current, and concrete.

## Authoring and amending the charter

`/spec-flow:charter` runs a Socratic brainstorm to produce the seven skill files, passing through the `qa-charter` agent before sign-off. It supports two modes:

- **Bootstrap** — greenfield. A repo-scan agent infers patterns, the Socratic dialogue resolves them section by section (one section per domain), the skill resolves the destination root (detect/recommend/prompt per [reference/charter-location.md](../../../reference/charter-location.md)), and writes seven `<charter_root>/skills/charter-*/SKILL.md` files, one commit each, then persists `charter_root` to `.spec-flow.yaml`.
- **Update** — charter exists; evolve specific entries. New NN-C/CR entries get the next sequential ID; retired entries are tombstoned (never deleted). Divergence detection flags when an update conflicts with already-shipped pieces.

Charter skills live on `main` — charter is project-global, not piece-scoped, so it is never authored inside a worktree.

`.spec-flow.yaml` records two charter keys: `charter.required: true` (prd/spec/plan/execute fail fast when no charter is found) and `charter.doctrine_load` (the always-on domains). Both are set by the charter skill alongside `layout_version: 4`.

## The charter snapshot

Specs and plans authored against a charter include a `charter_snapshot:` front-matter block that records the **commit date of each charter skill** the artifact relies on (read from `git log -1 --format=%ci <charter_root>/skills/charter-<domain>/SKILL.md`, where `<charter_root>` is resolved per [reference/charter-location.md](../../../reference/charter-location.md)). This serves two purposes:

1. At QA time, reviewers confirm every snapshot entry exists and is current.
2. At merge time, if a charter skill has changed since the artifact was authored, the pipeline surfaces a divergence that must be resolved (re-author the plan, or confirm the change doesn't affect the piece).

Snapshots prevent the class of bug where a piece is specced against an old charter, the charter evolves mid-flight, and the piece ships honoring rules that no longer exist.

## Where to go next

- [Pipeline](./pipeline.md) — how charter flows into every downstream stage.
- [commands/charter.md](../commands/charter.md) — the full charter command walkthrough.
- [QA loop](./qa-loop.md) — how citation integrity is verified at every review.
