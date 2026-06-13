---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
piece_class: behavior-bearing
---

# Spec: discovery-triage

**PRD Sections:** FR-019, FR-023, SC-011, G-7
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** spike-agent (merged)

## Goal

Extract execute's Step 6c synchronous-discovery triage — the discipline that classifies a discovered change and routes it without ever silently patching code, deferring, or guessing — into a standalone `spec-flow:triage` skill invocable from **any** session, built on the `review-board` out-of-band sibling pattern. Given a discovery (operator-stated or programmatically handed off by a future FR-020 campaign), the skill classifies it to **exactly one** of five dispositions, dispatches the FR-005 spike agent in scope mode as a bounded isolated Opus dispatch when the change needs design (never main-window thinking), and writes a recorded, provenance-bearing manifest/backlog entry. It preserves NN-P-002 (no silent mid-stream change), NN-P-004 (no silent defer), and forward-records the NN-P-006 red-first obligation for bug-classified fixes. Per operator decision (2026-06-12, adding **FR-023**), this piece also **unifies** execute with the standalone path: execute's Step 6c is rewired to **consume** the shared contract — so mid-execution operator-change triage uses the same disposition set as the standalone skill — and the FR-008 mid-execution detection heuristic is **hardened** to catch change-requests more reliably. The extraction stays additive for every other consumer; execute's externally-observable triage discipline (scope→amend→execute, no mid-stream patch) is preserved.

## In Scope

- A new standalone skill `plugins/spec-flow/skills/triage/SKILL.md` (`spec-flow:triage`), out-of-band, requiring no active piece/manifest beyond a spec-flow project layout.
- A new `plugins/spec-flow/reference/triage-contract.md` holding the **context-free** triage contract (the five dispositions, their target surfaces, the provenance/recording convention, the no-silent-write + operator-gate rules, and the spike-scope-mode pointer).
- **Rewiring execute's Step 6c to consume `triage-contract.md`** (FR-023): a confirmed operator-initiated mid-execution change is classified through the same shared contract the standalone skill uses, unifying the disposition vocabulary in and out of execute. Execute-bound mechanics stay inline (see Out of Scope).
- **Hardening the FR-008 admission detection heuristic** (FR-023): an expanded, documented set of change-signal phrasings so mid-execution change-requests are caught more reliably, preserving the suppression-during-structured-answer rule.
- A PRD touch on the piece branch: **add FR-023** to the exec-ready PRD and annotate FR-019 AC-4 as extended (the `spec-preresearch`/FR-009 precedent — the piece adds its new FR at merge).
- An additive, optional per-piece `notes:` field on `docs/prds/<prd-slug>/manifest.yaml` entries (the `note-on-scheduled` write target), with a defined provenance schema.
- An additive intake route: a Q4 "Investigation / discovery to triage" choice that points to `spec-flow:triage` (operator-selected, no silent routing).
- Forward-recording of the NN-P-006 red-first obligation on bug-classified fix dispositions (provenance stamp only — no dependency on the unmerged `bugfix-redfirst` machinery).
- Plugin version bump (5.17.0 → next minor) across all version-bearing files + CHANGELOG entry.

## Out of Scope / Non-Goals

- **Execute's execute-bound mechanics.** The unification (FR-023) rewires only execute's Step 6c *classification/disposition* decision to consume the shared contract; the execute-bound machinery (`$piece_start_sha`, the 50% cumulative-diff ratio, amendment-budget counters, block-aware placement, per-phase loop, WIP-preemption) stays inline and is NOT moved into the shared contract or changed.
- **NLU / ML-based change detection.** The FR-008 detection hardening expands the documented change-signal phrasing/keyword set and tightens the suppression rule — it adds NO model, classifier, or runtime NLU dependency (NN-C-002).
- **Cross-piece plan amendment.** `plan-amend` targets only the **current working piece's** plan — there is no "amend an arbitrary named piece's plan" path (operator decision, this brainstorm). When no current working piece is resolvable, `plan-amend` is simply not offered.
- **Building the NN-P-006 red-first gate.** That gate is owned by the `bugfix-redfirst` piece (FR-022, open). This piece only forward-records the obligation in provenance.
- **A `manifest-query add-note` verb.** The `notes:` field is authored via the same direct-YAML-edit idiom execute's fork dispatch uses; no new query verb.
- **Triage patching code, merging, or preempting in-progress work.** Triage classifies, routes, and records; the downstream skills (`small-change`, `plan-amend`, `defer`) carry the TDD/QA discipline.

## Requirements

### Functional Requirements

- **FR-T1 (skill exists, classifies to exactly one disposition):** `spec-flow:triage` is a standalone skill invocable outside execute. Given a supplied discovery, it classifies it to **exactly one** disposition: `small-change` / `plan-amend` / `new-piece` / `note-on-scheduled` / `explicit-defer-with-rationale`. (PRD AC-1)
- **FR-T2 (shared contract, single source of truth):** A new `reference/triage-contract.md` defines the context-free contract; both the new skill and execute's Step 6c route their classification through it, neither restates it (CR-008/NN-C-008). Execute **consumes** the contract for its classify→disposition decision (FR-T10) — the disposition vocabulary lives once in the shared doc, and execute-bound mechanics stay inline. (PRD FR-019 AC-4 as extended by FR-023)
- **FR-T3 (input form):** The skill takes a positional `<discovery-text | finding-ref>` plus flags (`--source`, `--rationale`, `--piece` to name the current working piece). It also accepts the `defer`-style structured field set, and a batch of findings, for programmatic FR-020 callers. All forms map to one internal classification and every disposition is operator-confirmed (batch-aggregated when multiple findings are supplied). (PRD AC-1, AC-5)
- **FR-T4 (disposition dispatch):** Each disposition routes to its target surface: `small-change` → seeded handoff into `/spec-flow:small-change`; `plan-amend` → `agents/plan-amend.md` against the **current working piece's** `plan.md` (offered only when a current working piece is resolvable); `new-piece` → a new `manifest.yaml` entry (fork's YAML-authoring idiom, without the block-current-piece coupling); `note-on-scheduled` → the additive per-piece `notes:` field; `explicit-defer-with-rationale` → `/spec-flow:defer` structured form (`--rationale` required). (PRD AC-1)
- **FR-T5 (bounded spike scope-mode):** When the change needs design, the skill dispatches `agents/spike.md` in scope mode as a bounded isolated Opus dispatch (≤2K return, `STATUS: OK|BLOCKED`) and consumes the scoping artifact — it never resolves the design in the main window. Out of band the diff-ratio is undefined, which is already `scope-spike` per `reference/spike-agent.md`; the "needs design" judgment selects. On `STATUS: BLOCKED`, the skill records an **open needs-scoping item** with the blocker and surfaces it — it never fabricates a disposition. (PRD AC-2, failure mode)
- **FR-T6 (recorded, provenance-bearing, operator-gated):** Every disposition writes a recorded manifest/backlog entry carrying provenance (source session/finding, date). No disposition is a silent mid-stream patch (NN-P-002); no defer is silent (NN-P-004). Gating: **every** disposition requires explicit operator confirmation of the proposal before any write/handoff — there is no auto-apply path (NN-P-004: "nothing is auto-applied"). When multiple findings are supplied at once (FR-020 campaign batch), they are presented in a single aggregated confirm prompt — execute's existing Step 6c batch pattern — so confirmation is one event, not one keystroke per finding. (PRD AC-3)
- **FR-T7 (NN-P-006 forward-record):** The skill detects bug-signal keywords (`fix`/`bug`/`broken`/`regression`/`patch` — small-change's existing set). On a bug-classified disposition routed to a fix (`small-change` / `plan-amend` / `new-piece`), it stamps the red-first obligation onto **all three** provenance surfaces: the downstream handoff digest, the `.discovery-log.md`-style recorded row, and the manifest/backlog entry. No dependency on the unmerged `bugfix-redfirst` machinery. (PRD FR-019/FR-022 edge-case row; NN-P-006)
- **FR-T8 (intake reachability):** intake's Q4 gains an "Investigation / discovery to triage" choice routing to `spec-flow:triage`, operator-selected (no silent routing). (PRD AC-5)
- **FR-T9 (additive manifest `notes:` field):** Manifest piece entries gain an optional `notes:` list; each note records `{source, date, finding}`. Registries without the field read unchanged (NN-C-003). (note-on-scheduled write target)
- **FR-T10 (execute consumes the shared contract):** Execute's Step 6c is rewired to classify a confirmed operator-initiated mid-execution change through the shared `triage-contract.md` — the same classification the standalone skill uses — so the disposition vocabulary is unified in and out of execute. Execute-bound mechanics (the 50% cumulative-diff ratio, amendment-budget counters, block-aware placement, WIP-preemption) stay inline; only the classify→disposition→target decision becomes shared. This is a behavior change to execute (not citation-only) and explicitly extends FR-019 AC-4; `pipeline-e2e` is the regression net and is extended to cover the unified path. (PRD FR-023 AC-1, AC-3)
- **FR-T11 (hardened mid-execution detection):** The FR-008 admission detection heuristic is hardened to catch an expanded, documented set of change-signal phrasings (beyond the current `add…`/`change…`/`we should…` set) so mid-execution change-requests are caught more reliably, while preserving the rule that free-form input is treated as a structured answer whenever the coordinator is awaiting one. The trigger set is documented in one place (the shared contract or a cited reference). No NLU/model dependency (NN-C-002). (PRD FR-023 AC-2)

### Non-Functional Requirements

- **NFR-T1 (isolation, ≤2K):** The spike scope-mode dispatch is the only sub-agent dispatch; it is isolated and returns ≤2K tokens (NFR-001, NN-C-008). The skill body is a thin orchestrator (CR-008) runnable on Sonnet — all design thinking is in the bounded Opus spike.
- **NFR-T2 (backward-compat):** Every surface touched is backward-compatible — execute Step 6c (internal routing rewired to consume the shared contract; externally-observable behavior preserved or expanded, never reduced), manifest (`notes:` optional), intake (one added choice). No existing behavior is retro-broken (NN-C-003 / NFR-003).
- **NFR-T3 (no runtime deps):** Markdown + YAML + POSIX-bash only (NN-C-002); manifest/note authoring reuses the existing direct-YAML-edit idiom — no new script or query verb.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-002 (markdown + config only): the skill, the contract doc, and the manifest-field edit are markdown/YAML/bash; the only dispatch is the existing spike agent. No runtime dependency added.
- NN-C-003 (backward compat within major): manifest `notes:` is optional; the execute Step 6c rewire (FR-T10/FR-T11) changes internal routing only — externally-observable execute behavior is preserved or expanded, never reduced (NFR-003); intake gains a choice — all backward-compatible.
- NN-C-006 (no destructive ops without confirmation): every disposition (single or campaign batch) requires operator confirmation before any manifest/backlog write; campaign batches get one aggregated confirm prompt; no path writes without confirmation.
- NN-C-007 / NN-C-008-doc parity (CHANGELOG): a CHANGELOG.md entry accompanies the version bump.
- NN-C-008 (self-contained agent prompts / definitions in one place): the spike dispatch prompt is self-contained; the triage contract lives only in `triage-contract.md` and is cited, never restated.
- NN-C-009 (version bump on changes): plugin version bumps from 5.17.0 across all version-bearing files.

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-002 (no silent or mid-stream change): every disposition is a recorded, routed action; the skill never patches code or applies a mid-stream fix. The spike-then-amend wiring mirrors execute's no-bypass rule for the `plan-amend` path.
- NN-P-004 (operator-gated, no silent defer, nothing auto-applied): every disposition is operator-confirmed before any write/handoff — no auto-apply path, even for FR-020 campaign callers (a batch gets one aggregated confirm prompt); `explicit-defer` requires a rationale via `/spec-flow:defer`; no disposition writes silently.
- NN-P-005 (thinking on Opus, mechanics on Sonnet): the only thinking dispatch is the spike in scope mode (Opus, isolated); the skill body is Sonnet-runnable.
- NN-P-006 (bug-fix/regression red-first): bug-classified fix dispositions forward-record the red-first obligation so it travels with the spawned fix (machinery owned by `bugfix-redfirst`).
- NN-P-001 (human gate preserved): interactive triage requires an operator keystroke per disposition; the skill never removes a sign-off gate.

### Coding Rules Honored

- CR-002 (skill frontmatter schema): `SKILL.md` carries `name`, `description`, and `argument-hint` (review-board precedent).
- CR-004 (conventional commits with plugin scope): recorded dispositions and the contract/skill commits use `chore(...)`/`feat(...)` scoped messages.
- CR-005 (absolute file paths in docs): the skill and contract doc cite repo files by absolute path.
- CR-008 (thin-orchestrator skills, narrow-executor agents): triage orchestrates (parse → classify → ≤1 spike dispatch → route → record); it embeds no design/impl logic.
- CR-009 (semantic heading hierarchy): the new docs follow the standard section nesting.

## Acceptance Criteria

AC-1: Given a supplied discovery (positional text or structured fields), When `spec-flow:triage` runs, Then it classifies the discovery to **exactly one** of the five named dispositions — never zero, never two. [outcome:result]
  Independent Test [judgment: qa-spec / spec-compliance reviewer]: inspect the skill's classification step — confirm a single-disposition output contract and that no path emits multiple or null dispositions.

AC-2: Given a discovery whose change needs design, When triage runs, Then it dispatches `agents/spike.md` in scope mode as a bounded isolated Opus dispatch and consumes the scoping artifact — and never resolves the design in the main window. [mechanism]
  Independent Test [machine: grep the skill for a single `agents/spike.md` scope-mode dispatch and the absence of any main-window design-resolution step]: the dispatch block is present and isolated.

AC-3: Given the spike scope-mode dispatch returns `STATUS: BLOCKED`, When triage handles it, Then it records an open needs-scoping item carrying the blocker and surfaces it to the operator, and writes **no** fabricated disposition. [outcome:result]
  Independent Test [judgment: spec-compliance reviewer]: confirm the BLOCKED branch records an open item with the blocker and has no disposition-fabrication fallthrough.

AC-4: Given any disposition is selected, When triage applies it, Then it writes a recorded manifest/backlog entry carrying provenance (source session/finding + date), and applies no disposition as a silent mid-stream patch. [outcome:result]
  Independent Test [judgment: spec-compliance reviewer]: trace each of the five dispositions to a recorded provenance-bearing write; confirm no code-edit/patch path exists in the skill.

AC-5: Given any invocation (a single discovery or an FR-020 campaign batch of findings), When triage proposes the disposition(s), Then no disposition is written or handed off without an explicit operator confirmation, and a multi-finding batch is presented as one aggregated confirm prompt rather than auto-applied. [mechanism]
  Independent Test [judgment: spec-compliance reviewer]: confirm there is no auto-apply path; every write/handoff is preceded by an operator-confirmation step, and the batch path aggregates into a single prompt.

AC-6: Given a bug-signal discovery (`fix`/`bug`/`broken`/`regression`/`patch`) routed to a fix disposition, When triage records it, Then the red-first obligation is stamped onto the handoff digest, the recorded row, and the manifest/backlog entry — all three. [outcome:result]
  Independent Test [machine: grep the skill + contract doc for the red-first-obligation stamp wired into all three provenance surfaces on the bug-classified branch]: three stamp sites present.

AC-7: Given execute's Step 6c and the standalone skill, When this piece ships, Then the context-free triage contract is defined once in `reference/triage-contract.md` and BOTH execute's Step 6c and the skill route their classification through it (single source of truth) — neither restates the five-disposition vocabulary inline. [outcome:integration]
  Independent Test [machine: `triage-contract.md` exists AND both `skills/execute/SKILL.md` and `skills/triage/SKILL.md` cite it AND neither restates the five-disposition vocabulary inline (grep)]: both citers resolve; no duplicated vocabulary.

AC-8: Given a `note-on-scheduled` disposition, When triage writes it, Then it appends to the target piece's additive manifest `notes:` list with `{source, date, finding}`, and a manifest entry lacking the field still parses unchanged. [mechanism]
  Independent Test [machine: schema check — the written note carries the three keys; a manifest without `notes:` loads without error]: both hold.

AC-9: Given intake's Q4 routing, When the operator selects "Investigation / discovery to triage", Then intake routes to `spec-flow:triage` without silent routing (the operator explicitly selects it). [mechanism]
  Independent Test [machine: grep intake's Q4 for the added choice mapping to `spec-flow:triage`]: choice present and operator-selected.

AC-10: Given each of the five dispositions, When triage routes it, Then it lands on the correct downstream surface (`small-change` handoff / `plan-amend` on the current working plan / new manifest piece / manifest `notes:` / `/spec-flow:defer`) and the routing matches the shared `triage-contract.md` disposition→target map. [outcome:integration]
  Independent Test [judgment: spec-compliance reviewer]: verify each disposition's dispatch target against the contract doc's disposition→target table; no orphan or mismatched route.

AC-11: Given no current working piece is resolvable, When triage presents the disposition menu, Then `plan-amend` is **not** offered (and an explicit `plan-amend` request with no active piece is refused with a recorded message), while the other four dispositions remain available. [mechanism]
  Independent Test [judgment: spec-compliance reviewer]: confirm the menu gates `plan-amend` on a resolvable current working piece and the refusal-with-record branch exists.

AC-12: Given a confirmed operator-initiated mid-execution change (the FR-008 admission `y` path), When execute's Step 6c classifies it, Then the disposition decision is sourced from the shared `triage-contract.md` (the unified vocabulary, not a bespoke inline amend/fork/defer-only copy), while execute-bound mechanics (ratio, budget, placement, WIP-preemption) remain inline. [outcome:integration]
  Independent Test [judgment: spec-compliance reviewer]: confirm execute's Step 6c classification is sourced from the shared contract, the inline duplicated-vocabulary copy is removed, and the execute-bound mechanics remain inline.

AC-13: Given a mid-execution free-form operator turn that is a change-request, When the coordinator is NOT awaiting a structured answer, Then the hardened FR-008 admission heuristic surfaces the confirmation prompt across the expanded documented phrasing set; and when the coordinator IS awaiting a structured answer, the same input is treated as that answer (suppression preserved). [mechanism]
  Independent Test [judgment: spec-compliance reviewer]: confirm the trigger phrasing set is expanded and documented in one place, and the suppression-during-active-prompt rule is preserved.

AC-14: Given the unified execute path (FR-T10/FR-T11), When a mid-execution change is admitted, Then it still routes scope→amend→execute under operator confirmation and is never applied as a silent mid-stream patch — execute's externally-observable triage discipline is preserved or expanded, never reduced. [outcome:result]
  Independent Test [judgment: spec-compliance reviewer]: confirm no mid-stream-patch path is introduced and the operator-confirmation gate + scope→amend→execute flow are intact on the unified path.

## Technical Approach

**Pattern.** `spec-flow:triage` is the out-of-band sibling of execute's Step 6c, modeled structurally on `skills/review-board/SKILL.md`: a `## Step 0` best-effort config load, an explicit "standalone — no active piece required" note, a `## Boundaries` section (no merge, no code patch, no preempt of in-progress work, no silent write, no sign-off removal), and routing into other skills rather than editing code.

**Shared contract (DU-1).** `reference/triage-contract.md` is the single source of truth for the *context-free* contract: the five dispositions, the disposition→target-surface map, the provenance/recorded-row convention, the no-silent-write + operator-gate rules, and a pointer to `spike-agent.md` for scope mode. Execute's Step 6c is rewired to **consume** this contract for its classify→disposition decision (FR-T10), so the disposition vocabulary is identical in and out of execute; its execute-bound mechanics (cumulative-diff ratio, amendment-budget counters, placement into a live plan, WIP-preemption) stay inline and out of the shared doc. This is a behavior change to execute (not citation-only); `pipeline-e2e` (merged) is the execute regression net and is extended to cover the unified path.

**Disposition mechanics.**
- `small-change` → seed `/spec-flow:small-change` with the discovery as the change-brief input (the `review-board --fix` handoff precedent).
- `plan-amend` → resolve the **current working piece** from context (active worktree / in-progress manifest entry); dispatch `agents/plan-amend.md` against that `plan.md`. When the change needs design, the scope spike runs first (undefined ratio ⇒ scope-spike). Offered only when a current working piece resolves (AC-11).
- `new-piece` → author a new `manifest.yaml` entry via fork's direct-YAML idiom, `status: open`, `depends_on` as the operator specifies — without fork's "set current piece blocked" coupling (there may be no current piece).
- `note-on-scheduled` → append to the target piece's additive `notes:` list (DU-3 / FR-T9).
- `explicit-defer-with-rationale` → `/spec-flow:defer` structured form; `--rationale` mandatory.

**Spike trigger (DU-2).** Out of band, the execute 50% cumulative-diff ratio has no `$piece_start_sha` baseline, so the ratio is always undefined — which `reference/spike-agent.md` already maps to `scope-spike`. The operator (or the calling skill) signals "needs design"; triage then dispatches scope mode with the discovery text (+ the current piece's `plan.md` when a working piece is resolved) as inputs. No new threshold constant.

**Gating.** Every disposition is propose-then-operator-confirm before any write/handoff — there is no auto-apply path (NN-P-004: "nothing is auto-applied"). An FR-020 campaign that hands triage a batch of findings gets ONE aggregated confirm prompt covering all of them (execute's existing Step 6c aggregated-prompt pattern), so a campaign run is gated by a single confirmation event rather than per-finding friction. This honors both halves of NN-P-004 — no silent defer AND nothing auto-applied — while keeping campaign throughput high.

**NN-P-006 forward-record (DU-6).** Bug-signal keyword detection (small-change's existing set) flags a bug classification; on a fix-bound disposition the red-first obligation is stamped on all three surfaces (handoff digest, recorded row, manifest/backlog entry). When `bugfix-redfirst` later lands, the obligation is already travelling with the fix. Precedent: intake's `small_change_signals_detected` forward-records a signal without acting on it.

**Execute unification + detection hardening (FR-023).** Mid-execution, only the live coordinator can tell a free-form change-request from an answer to an active prompt — so detection stays in execute's Step 6c FR-008 admission (a skill cannot auto-fire on a keystroke). Two changes: (1) the admission heuristic's change-signal phrasing set is expanded and documented in one place (the shared contract or a cited reference), catching more real change-requests, with the suppression-during-active-prompt rule preserved (a false positive stays a harmless prompt, cancellable with `n`); (2) on a confirmed change, Step 6c routes its classify→disposition decision through `triage-contract.md` instead of an inline bespoke amend/fork/defer copy — so a mid-execution change can land on the fuller, unified disposition set. Execute-bound mechanics (ratio, budget, placement, WIP-preemption) are unchanged. NN-P-002 holds: the path is still scope→amend→execute under confirmation, never a mid-stream patch.

**Data flow.** discovery in (positional text, structured fields, or a campaign batch) → bug-signal scan → classify (propose) → operator confirm (one aggregated prompt when a batch is supplied) → [needs design? → spike scope-mode (Opus, isolated) → OK: consume artifact | BLOCKED: record open needs-scoping item] → route to target surface → write recorded provenance entry (+ red-first stamp if bug-classified) → return a ≤2K disposition summary.

## Testing Strategy

This is a doc-as-code / skill-authoring piece (markdown + YAML); there is no runtime unit suite. "Tests" are the QA-gate inspections and the machine-checkable greps named in the ACs:
- **Machine-checkable (grep/diff/schema):** AC-2 (single isolated spike dispatch), AC-6 (three red-first stamp sites), AC-7 (`triage-contract.md` exists + both execute and skill cite it + no duplicated vocabulary), AC-8 (note schema + optional-field parse), AC-9 (intake Q4 choice).
- **Judgment (spec-compliance / qa reviewer):** AC-1 (exactly-one-disposition), AC-3 (BLOCKED → open item, no fabrication), AC-4 (provenance on every disposition, no patch path), AC-5 (confirm-only, batch-aggregated, no auto-apply), AC-10 (disposition→target map parity), AC-11 (plan-amend menu gating), AC-12 (execute sources disposition from the shared contract), AC-13 (hardened detection + suppression preserved), AC-14 (unified path preserves NN-P-002).
- **Execute regression (FR-T10/FR-T11):** the execute surgery is covered by extending `pipeline-e2e` (merged) to exercise the unified mid-execution path (admission → shared-contract classification → scope→amend→execute) so the rewire cannot regress execute's externally-observable behavior.
- **Edge cases to cover:** spike BLOCKED; no current working piece (plan-amend suppressed); a manifest entry without the `notes:` field; a programmatic call with no rationale routed to defer (must refuse); an ambiguous bug-vs-feature discovery (bug-signal scan); a mid-execution change-request across the expanded phrasing set; the same input arriving while the coordinator awaits a structured answer (suppression must hold).
- **Negative-space (must-NEVER) emphasis:** the outcome ACs (AC-1, AC-3, AC-4, AC-6) encode the guarantees that are the entire point of the piece — exactly one disposition, no fabricated disposition, no silent/unrecorded write, no dropped red-first obligation.

## Integration Coverage

- Integration: `triage` → `small-change` — inside:{triage skill}; doubled externals: none (in-repo skill handoff, contract-tested via the disposition→target map); AC-10; behavioral.
- Integration: `triage` → `plan-amend` agent (current working piece only) — inside:{triage skill}; doubled externals: the spike scope-mode dispatch (already contract-tested by spike-agent); AC-10, AC-11; behavioral.
- Integration: `triage` → `manifest.yaml` (`new-piece` + `note-on-scheduled` writes) and `triage` → `/spec-flow:defer` — inside:{triage skill}; doubled externals: none; AC-8, AC-10; behavioral.
- Integration: `execute` Step 6c ↔ `triage-contract.md` (shared contract — execute CONSUMES it, FR-T10) — inside:{execute skill, triage skill}; doubled externals: none; AC-7, AC-12; behavioral.
- Integration: `execute` FR-008 admission ↔ hardened detection (FR-T11) — inside:{execute coordinator}; doubled externals: none; AC-13, AC-14; behavioral.
- Integration: `intake` Q4 → `spec-flow:triage` — inside:{intake skill}; doubled externals: none; AC-9; behavioral.

## Open Questions

- **Scope (operator decision, 2026-06-12):** the execute-unification + FR-008 detection hardening were **folded into this piece** rather than split into a dependent follow-on. This adds **FR-023** to the PRD (extending FR-019 AC-4), plus FR-T10/FR-T11 and AC-12/13/14 here. The trade-offs flagged at brainstorm — larger blast radius on the ~2,100-line execute file and an AC count above the qa-prd ≤7 guideline — were explicitly accepted by the operator; `pipeline-e2e` (merged) is the execute regression net.
- None outstanding. The three brainstorm VOQs were resolved: VOQ-1 → red-first stamp on all three surfaces (AC-6); VOQ-2 → `plan-amend` targets only the current working piece, no cross-piece amend (AC-11, Non-Goals); VOQ-3 → additive manifest `notes:` field via direct-YAML authoring, no new query verb (AC-8, FR-T9). Gating resolved (qa-spec NN-P-004 reconciliation) → every disposition operator-confirmed, no auto-apply; FR-020 campaign batches use one aggregated confirm prompt (AC-5), honoring NN-P-004's "nothing auto-applied" clause.
