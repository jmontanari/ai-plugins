## Investigation Summary

Resolved depth: **full**. Investigation-first deliberation for `discovery-triage` (FR-019 / US-019 / SC-011 / G-7) — extract execute Step 6c synchronous-discovery triage into a standalone `spec-flow:triage` skill invocable from any session. Grounding: research.md digest, prd.md FR-019 + 5 ACs + failure mode, manifest entry (deps: spike-agent merged; downstream outcome-campaign/pipeline-economics consume this), execute Step 6c body (lines 1015–1338), spike-agent.md, review-board (canonical out-of-band sibling), intake Q4.

Key finding: the disposition set DIVERGES from Step 6c (5 named dispositions vs 3 execute analogs). The execute-bound machinery (`$piece_start_sha`, cumulative-diff ratio, amendment-budget counters, per-phase loop) cannot survive extraction. The standalone skill is a **thin orchestrator** (CR-008): parse → classify → at most one spike scope-mode dispatch → route into existing skills (`small-change`/`defer`) or author manifest/backlog → record provenance. No web research fired: every decision unit is a codebase-internal design question (single-source-of-truth, additive manifest field, out-of-band context resolution) answerable from charter conventions and existing prior art.

Decision units confirmed from the prompt (DU-1..DU-7), all refined below; none dropped.

## Viability Analysis

### DU-1 — Shared contract mechanism (CR-008/NN-C-008)

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| New `reference/triage-contract.md`; BOTH execute Step 6c and the skill cite it (disposition vocabulary, provenance row, no-silent-write rule, spike-scope contract pointer) | VIABLE | Single-source-of-truth per CR-008/NN-C-008; mirrors spike-agent.md / flywheel.md precedent. Coherence linter keeps anchors resolvable. | Yes — extracts the context-free half of Step 6c | — |
| Skill cites execute Step 6c prose directly (no new doc) | NON-VIABLE | Step 6c prose is execute-bound (interleaved with `$piece_start_sha`, budget counters, per-phase loop); a sibling skill citing it inherits execute coupling it cannot satisfy. | Partial | Cited prose mixes context-free contract with execute-only mechanics; no clean anchor exists to cite without pulling in execute state |
| Duplicate the contract into the skill | NON-VIABLE | Violates CR-008/NN-C-008 single-source-of-truth; two copies drift. | No | Charter NN-C-008 forbids restating definitions |

**Refinement:** the new doc holds ONLY the context-free contract (disposition→target-skill map, provenance/`.discovery-log.md` row convention, no-silent-write + operator-gate rules, the spike-scope-mode pointer). Execute Step 6c keeps its execute-bound mechanics inline and ADDS a citation to the shared doc for the context-free parts it already does — a light, additive touch, not a refactor of the 1,986-line file. pipeline-e2e (merged) is the execute regression net.

### DU-2 — plan-amend disposition out of band

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| (c) Offer `plan-amend` ONLY with an explicit `--piece <slug>` arg naming an active in-progress piece; resolve its worktree (`git worktree list` + manifest reverse-lookup, defer's pattern) and dispatch plan-amend against it | VIABLE | plan-amend needs plan.md + worktree + placement; with the piece named, all three resolve. Honors NN-P-002 (recorded, gated). | Yes — reuses defer's worktree/manifest reverse-lookup + spike scope-mode | — |
| (b) Refuse plan-amend out of band; down-route to new-piece/note | NON-VIABLE (as sole path) | FR-019 AC-1 names `plan-amend` as a reachable disposition; refusing it entirely fails AC-1. | n/a | AC-1 enumerates plan-amend; a skill that can never reach it is non-compliant |
| (a) Always resolve an active piece heuristically from manifest and dispatch | NON-VIABLE | Multiple `in-progress` pieces may exist; silent target-guessing violates NN-P-002 (operator must own the target) and risks amending the wrong plan. | Partial | No unambiguous "current piece" out of band; auto-pick is a silent mid-stream change |

**Refinement:** Path (c). The 50% diff-ratio is execute-bound (no `$piece_start_sha`) — see DU-3. Out of band, plan-amend is reachable only when the operator names the target piece; absent that arg the classifier offers new-piece / note / small-change / defer instead. This is a documented, intentional DIVERGENCE, not a regression.

### DU-3 — Spike-vs-direct trigger out of band

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Operator-choice "does this change need design?" → yes dispatches spike scope-mode; the undefined/zero-cumulative-diff branch already = "scope-spike" in spike-agent.md | VIABLE | spike-agent.md already treats undefined ratio as ratio→∞ ⇒ scope-spike. Out of band the ratio is ALWAYS undefined (no baseline), so the canonical rule already says "spike." Operator/heuristic judgment selects, not a fabricated number. | Yes — reuses spike-agent.md `## Threshold reuse` undefined-ratio branch verbatim | — |
| Size proxy (absorption LOC absolute threshold) | NON-VIABLE | Invents a new config key + a baseline that does not exist out of band; no corpus to set it; adds runtime-ish heuristic the charter discourages. | No | No cumulative-diff denominator exists; absolute LOC cutoff is an unjustified new constant |
| Always-spike every design-needing change unconditionally | VIABLE | Conservative; equals the undefined-ratio branch. Slight over-dispatch cost but never under-scopes. | Yes | — |

**Refinement:** the out-of-band rule = "undefined ratio ⇒ scope-spike" (already canonical in spike-agent.md). The operator (or the calling skill, e.g. FR-020 campaign per finding) signals "needs design"; triage then dispatches the spike in scope mode. AC-2's "above the size/complexity threshold" maps to this judgment gate — NOT to the execute 50% computation. Scope-mode inputs DIVERGE: with no active plan, "current plan + diff/neighborhood scope" becomes the discovery text + (when `--piece` given) that piece's plan.md, else just the discovery text.

### DU-4 — note-on-scheduled target

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| New optional per-piece `notes:` list on the manifest entry (additive, NN-C-003); each note carries provenance (source, date, finding) | VIABLE | The "scheduled piece" IS a manifest entry (open/specced/planned). Note travels with the piece, visible at its next spec/plan. Additive ⇒ registries without the field read unchanged (NN-C-003). | Yes — extends manifest schema additively; manifest-query reads it | — |
| Write to the target piece's `prds/<slug>/backlog.md` | VIABLE (secondary) | defer already owns backlog writes; a note IS a backlog-shaped record. Reuses defer's write path. | Yes — reuses defer | — |
| Write to the target piece's `spec.md` | NON-VIABLE | spec.md may not exist yet (open piece); spec is gated/QA'd, not a free-write surface; pollutes a budgeted artifact (artifact-budgets). | No | spec.md absent for `open` pieces; spec is a gated artifact, not a note sink |

**Refinement:** PRIMARY = additive per-piece manifest `notes:` field (the note belongs to the piece, surfaces at its next pipeline stage). The skill does NOT need a new `manifest-query add-note` verb — it can author the YAML the way fork authors a new entry (LLM-edits the file, commits), consistent with how new-piece works (DU below). Recorded + operator-gated ⇒ NN-P-004 honored. backlog.md remains the explicit-defer target (DU is distinct).

### DU-5 — Input/invocation form

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| review-board-style positional arg + flags: `<discovery text \| finding-ref> [--piece slug] [--source ...] [--rationale ...]` | VIABLE | review-board is the canonical out-of-band arg-taking skill (`argument-hint`, CR-002). Positional discovery text serves both operator-stated (AC-5 intake handoff) and programmatic per-finding (FR-020 campaign) callers. `--piece` gates DU-2; `--rationale` gates defer; `--source` records provenance. | Yes — copies review-board `argument-hint` + flag pattern | — |
| Structured block (defer's structured form) | VIABLE (complementary) | defer's structured form is the precedent for programmatic callers. Triage can accept the same field set when FR-020 hands off a finding. | Yes — reuses defer structured-field convention | — |

**Refinement:** positional-arg-plus-flags is PRIMARY (covers ad-hoc + intake). For programmatic FR-020 per-finding calls, accept the defer-style structured field set as an equivalent input. Both map to the same internal classification. CR-002 `argument-hint` declared.

### DU-6 — NN-P-006 honoring with bugfix-redfirst UNMERGED

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Forward-record the bug classification + red-first obligation in the disposition's provenance (small-change handoff digest `## Source`/`## Red-first-required`, and the manifest/backlog/`.discovery-log.md` entry) | VIABLE | Precedent: intake records `small_change_signals_detected` WITHOUT acting (forward-record a signal). When bugfix-redfirst merges, the obligation is already travelling with the fix. No hard dep on its machinery. | Yes — mirrors intake's forward-record-signal precedent | — |
| Wire the red-first gate directly in triage | NON-VIABLE | bugfix-redfirst (FR-022/NN-P-006) OWNS that gate and is `open`/unmerged; building it here duplicates/pre-empts another piece and creates a hard dependency the manifest forbids (this piece deps only spike-agent). | No | bugfix-redfirst unmerged; its small-change/hotfix/qa red-first wiring does not exist to call |

**Refinement:** detect bug-signal keywords (`fix`/`bug`/`broken`/`regression`/`patch` — small-change's existing set) and, on a bug-classified disposition routed to a fix path, STAMP the red-first obligation into provenance (handoff digest + recorded entry). This satisfies the FR-019/FR-022 edge-case row ("the spawned fix runs the red-first cycle — NN-P-006 follows the fix out of band") at the documentation+provenance level without depending on bugfix-redfirst's gate. Sufficient for AC-coverage: AC-3 requires a recorded provenance entry; the red-first stamp rides in it.

### DU-7 — intake routing entry (AC-5)

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Add an "Investigation / discovery to triage" choice to intake Q4 → routes to `spec-flow:triage` (no silent routing — operator explicitly selects, mirroring AC-IN-5) | VIABLE | Q4 already enumerates standalone types; adding one choice is additive. intake's "no silent routing" precedent makes the explicit-select requirement native. | Yes — extends intake Q4 branch list | — |
| Reuse the existing `exploratory` branch | NON-VIABLE | `exploratory` = read-only no-changes (`charter_constraints: none`, skip to Step 4). A discovery to triage IMPLIES a routing/write action — opposite semantics. | No | exploratory is explicitly read-only/no-write; triage writes a disposition |

**Refinement:** new Q4 choice → `spec-flow:triage`, operator-selected (AC-5 + intake's no-silent-routing invariant).

## Integration Check

Single integrated cluster (one skill, one shared contract doc, one spike reuse). Composition across units:

- DU-1 (shared doc) is the spine: DU-2/3/4/6's recorded-disposition + provenance + spike-pointer rules all live there once, cited by both execute and the skill. No conflict.
- DU-3's "undefined-ratio ⇒ scope-spike" reuses spike-agent.md verbatim; DU-2's plan-amend dispatch consumes that same spike's scoping artifact — identical to execute's Amend dispatch wiring, minus the budget counters. Composes cleanly.
- DU-5's input form feeds DU-6's keyword detection (parse → detect bug-signal → stamp). Composes.
- DU-4 (manifest `notes:`) and new-piece (fork-without-blocked-coupling) are both additive YAML authoring, same write idiom as fork — no new manifest-query verb required, so NN-C-002 (no runtime dep) holds.
- DU-7 (intake Q4) is a leaf: it only needs the skill to exist and take a positional discovery arg (DU-5). Composes.
- Version: NN-C-009 bump from 5.17.0 + CHANGELOG across version-bearing files; CR-002 frontmatter.

No cross-unit conflict requiring a VOQ. One coherence obligation: the new `reference/triage-contract.md` anchors must be linter-resolvable from both citers.

## Adversarial Review

| Lens | Verdict | Challenge & resolution |
|------|---------|------------------------|
| Architecture-integrity | HOLDS | Thin-orchestrator (CR-008): the skill dispatches at most one spike, routes into small-change/defer, authors manifest/backlog — no sub-agent fan-out, no impl logic. Shared doc respects single-source-of-truth. Mirrors review-board sibling shape. |
| Scope/simplicity (YAGNI) | HOLDS (with note) | Challenged: does DU-4 need a NEW manifest field vs reusing backlog? Resolved: note-on-scheduled is a NAMED FR-019 disposition distinct from explicit-defer; a per-piece note that surfaces at the piece's next stage is not served by a flat backlog. Field is additive/optional (NN-C-003) — minimal surface. No new manifest-query verb (reuse fork's YAML-authoring) keeps scope tight. |
| User-intent | HOLDS | US-019: "one disciplined command … so nothing dies in scrollback and I stop paying main-window Opus to hand-triage." Positional-arg form (DU-5) + intake reachability (DU-7) + bounded spike (DU-3, off the 180k main loop) directly serve this. |
| Backward-compat | HOLDS | Execute Step 6c behavior unchanged (AC-4): DU-1 only ADDS a citation; the execute-bound mechanics stay inline. Manifest `notes:` additive (NN-C-003). intake Q4 gains a choice, removes none. pipeline-e2e regression net intact. |
| Risk | HOLDS (with VOQ) | Spike BLOCKED → record open needs-scoping item with blocker, never fabricate (failure mode honored). NN-P-006 forward-record carries a real risk: if bugfix-redfirst's eventual provenance SHAPE differs from what triage stamps, the obligation may not be picked up. Folded into VOQ-1. plan-amend out-of-band worktree resolution edge (dirty/missing worktree) folded into VOQ-2. |

## Recommendation

Build `spec-flow:triage` as a standalone out-of-band skill on the **review-board sibling pattern**:

1. **DU-1:** create `reference/triage-contract.md` holding the context-free contract (5-disposition→target map, provenance/`.discovery-log.md` row, no-silent-write + operator-gate rules, spike-scope-mode pointer). Execute Step 6c ADDS a citation to it (additive, no refactor). Both cite; neither restates (CR-008/NN-C-008).
2. **DU-5:** input = positional `<discovery text | finding-ref> [--piece slug] [--source ...] [--rationale ...]` (review-board `argument-hint`, CR-002); also accept defer-style structured fields for programmatic FR-020 callers.
3. **Classify** to exactly one of: `small-change` (route to `/spec-flow:small-change` seeded-input handoff) / `plan-amend` (DU-2: ONLY with `--piece`, resolve worktree via defer's reverse-lookup, dispatch plan-amend against it) / `new-piece` (fork's YAML-authoring minus the blocked-coupling) / `note-on-scheduled` (DU-4: additive per-piece manifest `notes:` field) / `explicit-defer-with-rationale` (`/spec-flow:defer` structured form, `--rationale` required).
4. **DU-3:** when the change needs design, dispatch `agents/spike.md` scope-mode (Opus, isolated, ≤2K, STATUS) — out-of-band ratio is undefined ⇒ scope-spike per spike-agent.md; inputs = discovery text (+ piece plan.md when `--piece`). BLOCKED ⇒ recorded open needs-scoping item with blocker (failure mode).
5. **DU-6:** detect bug-signal keywords; on a bug-classified fix disposition, STAMP the red-first obligation into the handoff digest + recorded entry (forward-record, intake precedent) — no dep on unmerged bugfix-redfirst.
6. **DU-7:** add an "Investigation / discovery to triage" choice to intake Q4 → `spec-flow:triage`, operator-selected (no silent routing).
7. Every disposition writes a recorded, provenance-bearing entry (NN-P-002) and no defer is silent (NN-P-004). Markdown/bash/yaml only (NN-C-002); version bump from 5.17.0 + CHANGELOG (NN-C-009); explicit `## Boundaries` section (review-board model: no merge, no preempt, no silent write).

## Validated Open Questions

- **VOQ-1 (NN-P-006 forward-record shape):** What is the exact provenance field/shape triage stamps for the red-first obligation so bugfix-redfirst (unmerged) reliably picks it up when it lands — a named field in the small-change handoff digest, the `.discovery-log.md` row, the manifest/backlog entry, or all three? Forward-compat depends on a shape both pieces agree on; bugfix-redfirst's consumer side does not yet exist to constrain it. (Risk lens; DU-6.)
- **VOQ-2 (plan-amend out-of-band worktree resolution):** When `--piece` is given but the resolved worktree is dirty, missing, or the piece is not actually `in-progress`, does triage refuse with a recorded message, down-route to new-piece/note, or attempt resolution? defer resolves a target but does not dispatch into a live worktree; the dispatch-into-active-worktree case is new surface. (Architecture/risk lens; DU-2.)
- **VOQ-3 (note-on-scheduled write mechanism):** Confirm note-on-scheduled writes the additive manifest `notes:` field via fork-style direct YAML authoring (no new `manifest-query add-note` verb) rather than the target piece's backlog — and confirm the field schema (provenance: source, date, finding). Primary path is clear; the manifest-vs-backlog boundary and whether a query verb is warranted survived as a scope question. (Scope lens; DU-4.)

## Answered by Investigation

- **Shared contract mechanism (DU-1):** RESOLVED — new `reference/triage-contract.md`, both cite, neither restates; execute touch is additive-citation only (no refactor). CR-008/NN-C-008.
- **plan-amend reachability out of band (DU-2):** RESOLVED — reachable ONLY with explicit `--piece`; resolve worktree via defer's reverse-lookup; absent the arg, offer the other four dispositions. Documented divergence, not regression.
- **Spike-vs-direct trigger (DU-3):** RESOLVED — out-of-band ratio is undefined ⇒ scope-spike per spike-agent.md's existing undefined-ratio branch; operator/caller "needs design" judgment selects. No new threshold constant.
- **Input/invocation form (DU-5):** RESOLVED — positional arg + flags (review-board pattern) primary; defer-style structured fields for programmatic callers.
- **intake reachability (DU-7):** RESOLVED — new Q4 choice → `spec-flow:triage`, operator-selected (no silent routing); NOT the read-only `exploratory` branch.
- **NN-P-006 hard-dependency on bugfix-redfirst:** N/A as a blocker — honored via forward-record provenance (intake precedent); no machinery dependency. (Exact shape → VOQ-1.)
- **Backward-compat of execute Step 6c (AC-4):** RESOLVED — additive extraction; Step 6c behavior unchanged; pipeline-e2e regression net.
- **Runtime-dependency risk (NN-C-002):** N/A — markdown/bash/yaml only; manifest authoring reuses fork's LLM-edit idiom, no new script/verb required.
