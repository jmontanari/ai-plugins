---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
tdd: false
fast: false
review_board_variant: doc-as-code
---

# Plan: discovery-triage

**Spec:** docs/prds/exec-ready/specs/discovery-triage/spec.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** draft

## Overview

Extract execute's Step 6c synchronous-discovery triage into a standalone `spec-flow:triage` skill (review-board sibling pattern), backed by a single shared `reference/triage-contract.md` that BOTH the new skill and execute's Step 6c cite. Plus the FR-023 fold-in: rewire execute's FR-008 admission `y`-path to source its classify→disposition decision from the shared contract, and harden the FR-008 change-signal detection set.

**Mode — non-TDD / doc-as-code.** `tdd: false`: every deliverable is markdown (a skill, a reference doc) or YAML/JSON (manifest schema, version files). The spec's Testing Strategy is explicit: *there is no runtime unit suite.* "Tests" are (a) the machine-checkable greps named in the ACs, run as inline `[Verify]` oracles per phase, and (b) the durable **pipeline-e2e static-assertion suite** (`tests/e2e/lib/static.sh`, FR-013 — the merged regression net). Per the **Scaffold-first coordination-file rule** (plan SKILL.md §7), all durable `static.sh` assertions are authored once in **Phase 5** rather than fragmented across phases 1–4, so `static.sh` is edited in exactly one phase. Phases 1–4 are therefore Implement-track (`[Implement]` → `[Verify]`); Phase 5 carries the consolidated `[Write-Tests]` (the regression-net extension) per non-TDD structure. The AC Coverage Matrix is included for traceability though not required in non-TDD mode; per-phase QA and the end-of-piece Final Review board remain fully intact.

**Approach anchor (deliberation, normal-confidence).** `[DELIBERATION-CONSUMED]` — build `spec-flow:triage` standalone on the review-board sibling pattern; `reference/triage-contract.md` is the single source of truth (5-disposition→target map, provenance/recorded-row convention, no-silent-write + operator-gate rules, spike-scope-mode pointer); positional-arg input; bounded spike scope-mode is the only sub-dispatch; red-first forward-record on bug-classified fixes; intake Q4 route. The deliberation **was** adversarially reviewed (HOLDS verdicts) → normal-confidence anchor.

> **DRIFT (followed spec over deliberation).** The deliberation predates the FR-023 fold-in and states execute's Step 6c touch is "additive-citation only (no refactor)." The **spec supersedes this**: FR-T10/FR-T11 + AC-12/13/14 make execute a real behavior change (consume the contract + harden detection). Phase 3 implements the spec, not the stale deliberation note. See ADR-1.

**Already landed (NOT re-done by this plan).** The In-Scope "add FR-023 + annotate FR-019 AC-4 as extended" PRD touch is **already committed** on this branch (`d1c1b49 docs(prd): add FR-023`, authored at spec stage per the FR-009 precedent). `prd.md:486` carries `### FR-023`; `prd.md:414` carries the AC-4 EXTENDED annotation. No phase re-authors the PRD. See ADR-4.

**Phase dependency order:** Phase 1 (contract — foundation) → Phase 2 (skill, cites contract) + Phase 3 (execute, cites contract) + Phase 4 (intake, independent) → Phase 5 (version bump + consolidated regression net, asserts all prior outputs). Phases run serially (`Why serial:` on Phases 2–3); the wall-clock gain from parallelizing 3 doc-authoring phases is marginal and serial execution preserves per-phase Opus QA and lets each phase's QA verify its citation against the now-existing contract.

## Architectural Decisions

### ADR-1: Follow the spec (execute is a behavior change) over the stale deliberation note
**Context:** The deliberation `## Recommendation` + `## Adversarial Review` (Backward-compat lens) assert execute's Step 6c touch is "additive-citation only — execute-bound mechanics stay inline, behavior unchanged (AC-4)." The deliberation was written before the 2026-06-12 operator decision that folded FR-023 into this piece. The spec (FR-T10/FR-T11, AC-12/13/14) and the PRD (FR-023, which explicitly *supersedes* FR-019 AC-4's "execute unchanged") both make execute a real behavior change.
**Decision:** Phase 3 implements the **spec**: execute's FR-008 admission `y`-path sources its classify→disposition decision from `triage-contract.md` (a behavior change), and the FR-008 detection heuristic is hardened. The deliberation's "additive-citation only" line is treated as a superseded lower-fidelity prior.
**Alternatives considered:** (a) Honor the deliberation literally (citation-only execute touch) — rejected: contradicts the signed-off spec and PRD FR-023, would fail AC-12/AC-13. (b) Re-open deliberation to reconcile — rejected: unnecessary; the spec is the authoritative downstream artifact and already resolved this in its Open Questions section ("the FR-023 fold-in was explicitly accepted by the operator").
**Consequences:** Larger blast radius on the ~2,100-line execute file (accepted by operator per spec Open Questions); `pipeline-e2e` is the named regression net (Phase 5 extends it). Future readers must treat the deliberation's backward-compat verdict as scoped to the pre-fold-in design.
**Charter alignment:** Honors NN-C-003 (execute internal routing changes; externally-observable discipline preserved/expanded per AC-14) and NN-P-002.

### ADR-2: Execute reuses the shared 5-disposition vocabulary only on the FR-008 admission path; agent-discovered rows keep inline routing
**Context:** Execute Step 6c today routes via 3 inline dispositions (`amend`/`fork`/`defer`, + conditional `amend-spec`). The shared contract names 5 (`small-change`/`plan-amend`/`new-piece`/`note-on-scheduled`/`explicit-defer-with-rationale`). FR-T10 unifies the vocabulary; AC-12 scopes the rewire to "a confirmed operator-initiated mid-execution change (the FR-008 admission `y` path)."
**Decision:** Only the **operator-initiated change admission `y`-path** (execute/SKILL.md §"Operator-initiated change admission (FR-008)") sources its disposition from the shared contract — so a mid-execution operator change can land on the fuller 5-disposition set. The four **agent-discovered** aggregation sources (Step 6c §Aggregation 1–4) keep their existing inline `default_triage` (`amend`/`fork`/`defer`) routing unchanged. Execute-bound mechanics (50% ratio→scope-spike, amendment-budget counters, block-aware placement, WIP-preemption) stay inline for the `plan-amend` disposition.
**Alternatives considered:** (a) Rewire ALL of Step 6c to the 5-disposition vocabulary — rejected: out of AC-12 scope, would re-plumb the agent-discovery aggregation and its budget/placement machinery (large, unrequested blast radius). (b) Map the contract's 5 to execute's 3 only (no small-change/note reachable mid-execution) — rejected: the spec Technical Approach explicitly says "a mid-execution change can land on the fuller, unified disposition set."
**Consequences:** The execute diff is bounded to the FR-008 admission block + the triage-prompt vocabulary citation; the aggregation/budget/placement machinery is untouched (lower regression risk). New mid-execution dispatch reachability: `small-change` handoff + `note-on-scheduled` write (enumerated in Phase 3 P3).
**Charter alignment:** NN-C-003 (additive to execute's externally-observable behavior), NN-P-002 (scope→amend→execute preserved, no mid-stream patch).

### ADR-3: `note-on-scheduled` writes an additive per-piece manifest `notes:` field via direct-YAML authoring (no new query verb)
**Context:** `note-on-scheduled` is a named FR-019 disposition distinct from `explicit-defer`; it attaches a note to an already-scheduled/queued manifest piece. No per-piece `notes:` field exists today (only manifest-level `coverage.notes`). VOQ-3 asked: manifest field vs backlog, and whether a `manifest-query add-note` verb is warranted.
**Decision:** Add an **optional per-piece `notes:` list** (`{source, date, finding}` per entry), documented authoritatively in `triage-contract.md` and written by the skill via fork's direct-YAML-edit idiom — **no new `manifest-query` verb**. A piece entry lacking `notes:` parses unchanged (YAML optional field). The manifest template needs no edit (the field is additive/optional).
**Alternatives considered:** (a) Reuse the flat backlog — rejected: a per-piece note that surfaces at the piece's next stage is not served by a flat backlog (deliberation Scope lens). (b) New `manifest-query add-note` verb — rejected: NN-C-002/NN-C-003, reuse the existing YAML-authoring idiom; no runtime surface.
**Consequences:** Minimal additive manifest surface (NN-C-003). The `manifest-query` Python tool is untouched; `notes:` is read by humans/skills, not the query tool.
**Charter alignment:** NN-C-002 (no runtime dep), NN-C-003 (additive/optional).

### ADR-4: The PRD FR-023 touch is treated as already-satisfied (committed at spec stage)
**Context:** The spec In-Scope lists "add FR-023 + annotate FR-019 AC-4." Git shows commit `d1c1b49 docs(prd): add FR-023` already landed both edits on this branch at spec stage (the FR-009 `spec-preresearch` precedent: the spec skill commits the PRD touch).
**Decision:** No phase re-authors the PRD. Phase 5's CHANGELOG entry references FR-023 as the user-facing change; the plan records the PRD touch as done.
**Alternatives considered:** (a) Re-author the PRD in a phase — rejected: would duplicate/conflict with the committed edit. (b) Revert and re-do under the plan — rejected: pointless churn.
**Consequences:** One fewer deliverable; Phase 5 verifies (not re-authors) the FR-023 PRD state.
**Charter alignment:** CR-004 (the existing PRD commit already follows conventional-commits).

## Integration-Test Registry (M1)

Doc-as-code piece: each "integration" is a citation/handoff boundary verified by a static grep in the consolidated pipeline-e2e suite (`tests/e2e/lib/static.sh`). All complete in Phase 5 (the single regression-net phase); the per-phase `[Verify]` oracles confirm the boundary inline at authoring time.

| ID | Path | Boundary (inside) | Doubled externals (contract test) | AC | registered_in_phase | completes_in_phase | skeleton_sha256 | completed_sha256 |
|----|------|-------------------|-----------------------------------|----|--------------------|---------------------|-----------------|------------------|
| INT-1 | tests/e2e/lib/static.sh (contract-parity asserts) | execute/SKILL.md Step 6c ↔ reference/triage-contract.md ↔ skills/triage/SKILL.md | none | AC-7, AC-12 | 5 | 5 | — | — |
| INT-2 | tests/e2e/lib/static.sh (skill+disposition asserts) | skills/triage/SKILL.md → small-change / plan-amend / defer / manifest `notes:` | none (in-repo handoffs) | AC-6, AC-10, AC-11 | 5 | 5 | — | — |
| INT-3 | tests/e2e/lib/static.sh (intake-route assert) | skills/intake/SKILL.md Q4 → spec-flow:triage | none | AC-9 | 5 | 5 | — | — |
| INT-4 | tests/e2e/lib/static.sh (hardened-detection assert) | execute/SKILL.md FR-008 admission ↔ documented phrasing set | none | AC-13, AC-14 | 5 | 5 | — | — |

## Phases

### Phase 1: Shared triage contract (`reference/triage-contract.md`)
**Exit Gate:** `reference/triage-contract.md` exists; contains the 5-disposition→target map, the provenance/`.discovery-log.md` recorded-row convention, the no-silent-write + operator-gate rules, the manifest `notes:` schema, the NN-P-006 red-first three-surface stamp convention, the FR-008 hardened change-signal phrasing set, and a `spike-agent.md` scope-mode pointer; per-`[Verify]` greps pass.
**ACs Covered:** AC-7 (contract exists — single source of truth), AC-8 (`notes:` schema), AC-6 (red-first three-surface stamp convention), AC-13 (hardened phrasing set documented in ONE place)
**In scope:** CREATE `plugins/spec-flow/reference/triage-contract.md` only.
**NOT in scope:** the skill that cites it (Phase 2); execute's citation (Phase 3); intake (Phase 4); version/CHANGELOG (Phase 5). The contract is *context-free* — it carries NO execute-bound mechanics (ratio, budget, placement, WIP-preemption stay inline in execute per Phase 3).
**Charter constraints honored in this phase:**
- NN-C-008 (definitions in one place): the contract IS the single source of truth; both consumers cite it and neither restates the 5-disposition vocabulary.
- NN-P-006 (bug-fix red-first): the contract defines the three-surface red-first stamp convention (forward-record only; no dependency on the unmerged `bugfix-redfirst` machinery).
- CR-005 (absolute file paths in docs): cross-references use repo-root-relative/absolute paths.
- CR-009 (semantic heading hierarchy): standard `##`/`###` nesting.

- [ ] **[Implement]** Author the context-free triage contract
  - Order: front-matter/intro → disposition→target map → spike-scope-mode pointer → provenance/recorded-row convention → operator-gate + batch rule → manifest `notes:` schema → red-first stamp convention → FR-008 hardened phrasing set → "consumed by" pointer.
  - Architecture constraints: markdown only (NN-C-002); context-free (no `$piece_start_sha`, no ratio, no budget — those stay inline in execute); model the doc on `reference/spike-agent.md` ("Single source of truth … Definitions live here and nowhere else.").

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/reference/triage-contract.md`**
  - Anchor: new file.
  - Structure outline (sections, in order):
    1. `# Triage contract` + one-paragraph intro: "Single source of truth for the *context-free* discovery-triage contract. Both `spec-flow:triage` (`skills/triage/SKILL.md`) and execute's Step 6c (`skills/execute/SKILL.md`) cite this doc and neither restates the disposition vocabulary (CR-008 / NN-C-008). Execute-bound mechanics (cumulative-diff ratio, amendment-budget counters, block-aware placement, WIP-preemption) are NOT here — they stay inline in execute."
    2. `## Dispositions → target surface` — a table mapping each of the **exactly five** dispositions to its target. Verbatim rows (the disposition→target map; this is the AC-10 oracle):

       ```
       | Disposition                   | Target surface                                                              |
       |-------------------------------|-----------------------------------------------------------------------------|
       | small-change                  | seeded handoff into /spec-flow:small-change (digest = authoritative reqs)    |
       | plan-amend                    | agents/plan-amend.md against the CURRENT working piece's plan.md (only when a current working piece resolves) |
       | new-piece                     | new manifest.yaml entry (fork's direct-YAML idiom, minus the block-current-piece coupling) |
       | note-on-scheduled             | additive per-piece manifest `notes:` field on the target scheduled/queued piece |
       | explicit-defer-with-rationale | /spec-flow:defer structured form (--rationale / operator_rationale required) |
       ```
    3. `## Exactly-one-disposition rule` — prose: every classification yields exactly one disposition — never zero, never two (AC-1).
    4. `## Spike scope-mode (the only sanctioned Opus dispatch)` — prose + pointer: "When a change needs design, dispatch `agents/spike.md` in scope mode (Opus, isolated, ≤2K return, `STATUS: OK|BLOCKED`) per `plugins/spec-flow/reference/spike-agent.md` `## Threshold reuse`. Out of band the cumulative-diff ratio is undefined ⇒ scope-spike (the spike-agent.md undefined-ratio branch). On `STATUS: BLOCKED`: record an **open needs-scoping item** carrying the blocker and surface it; never fabricate a disposition." (AC-2, AC-3.) Do NOT restate spike-agent.md internals (NN-C-008).
    5. `## Provenance & recorded-row convention` — prose: every disposition writes a recorded, provenance-bearing entry; provenance = `{source session/finding, date}`; the recorded row follows execute's `.discovery-log.md` one-row-per-discovery format (cite `skills/execute/SKILL.md` `.discovery-log.md authoring`). No disposition is a silent mid-stream patch (NN-P-002); no defer is silent (NN-P-004). (AC-4.)
    6. `## Operator gate (no auto-apply)` — prose: **every** disposition requires explicit operator confirmation of the proposal before any write/handoff — there is NO auto-apply path (NN-P-004 "nothing is auto-applied"). When multiple findings are supplied at once (FR-020 campaign batch), present them in a **single aggregated confirm prompt** (execute's existing Step 6c aggregated-prompt pattern) — one confirmation event, not one keystroke per finding. (AC-5.)
    7. `## Manifest `notes:` schema` — verbatim schema (AC-8):

       ```yaml
       # Optional, additive, per-piece. A piece entry lacking `notes:` parses unchanged.
       notes:
         - source: <source session / finding ref>
           date: <YYYY-MM-DD>
           finding: <one-line finding text>
       ```
    8. `## Red-first obligation (NN-P-006 forward-record)` — prose: bug-signal keyword set = `fix` / `bug` / `broken` / `regression` / `patch` (small-change's existing set). On a bug-classified discovery routed to a **fix** disposition (`small-change` / `plan-amend` / `new-piece`), stamp the red-first reproduce→fail→fix→pass obligation onto **all three** provenance surfaces: (1) the downstream handoff digest, (2) the recorded `.discovery-log.md`-style row, (3) the manifest/backlog entry. Forward-record only — NO dependency on the unmerged `bugfix-redfirst` machinery. (AC-6.) Cite PRD NN-P-006 / FR-022; do not restate the red-first cycle mechanics.
    9. `## FR-008 mid-execution change-signal phrasing set (the documented trigger set — ONE place)` — verbatim, the hardened set (AC-13). Lists the change-signal phrasings execute's FR-008 admission matches, expanded beyond today's `add… / change… / we should…`:

       ```
       Imperative / change-request signals (case-insensitive, leading-phrase match):
         add…, change…, remove…, delete…, rename…, replace…, update…, refactor…,
         we should…, what if we…, can you also…, let's also…, also need…, it should…,
         instead of…, make it…, switch to…, drop…, get rid of…, handle…(when phrased as a new requirement)
       Suppression rule (PRESERVED): free-form input is treated as a structured ANSWER — never a change-signal —
         whenever the coordinator is awaiting a constrained response (a y/n triage choice, a model-policy
         confirmation, a QA sign-off, a BLOCKED-escalation response, or any active prompt expecting a constrained reply).
       A false positive is a harmless, cancellable confirmation prompt (operator answers n).
       ```
    10. `## Consumed by` — prose pointer: "`skills/triage/SKILL.md` (the standalone skill) and `skills/execute/SKILL.md` Step 6c (the FR-008 admission `y`-path) both classify through this contract."
  - Pattern (single-source-of-truth header idiom, from `reference/spike-agent.md`):
    ```
    Single source of truth for the spike agent ... Definitions live here and nowhere else.
    Skills cite anchors and explicitly say "do NOT restate."
    ```
  - Done: file exists with all 10 sections; the disposition→target table has exactly 5 rows; the `notes:` schema and phrasing set are present verbatim; no execute-bound mechanic (ratio/budget/placement/WIP) appears.
  - Verify: `grep -c "^| " plugins/spec-flow/reference/triage-contract.md` includes the 5 disposition rows; `grep -n "amendment_budget\|piece_start_sha\|50%\|cumulative-diff" plugins/spec-flow/reference/triage-contract.md` returns no match (context-free invariant).

- [ ] **[Verify]** Confirm the contract is sound
  **Per-change checks:**
  - T-1 (exists): `test -f plugins/spec-flow/reference/triage-contract.md` — Expected: exit 0.
  - T-1 (5 dispositions): `grep -E "small-change|plan-amend|new-piece|note-on-scheduled|explicit-defer-with-rationale" plugins/spec-flow/reference/triage-contract.md | wc -l` — Expected: ≥5 (each disposition named in the map).
  - T-1 (notes schema, AC-8): LLM-agent-step: read `plugins/spec-flow/reference/triage-contract.md` and confirm the `## Manifest `notes:` schema` section shows a `notes:` list whose entries carry the three keys `source`, `date`, `finding` — Expected: all three keys present.
  - T-1 (red-first three surfaces, AC-6): LLM-agent-step: read the `## Red-first obligation` section and confirm it names all three stamp surfaces (handoff digest, recorded row, manifest/backlog entry) and the bug-signal keyword set `fix/bug/broken/regression/patch` — Expected: three surfaces + keyword set present.
  - T-1 (context-free invariant): `grep -nE "amendment_budget|piece_start_sha|50%|cumulative-diff" plugins/spec-flow/reference/triage-contract.md` — Expected: no output (exit 1).
  **Phase-level check:**
  - LLM-agent-step: read the full file and confirm it parses as well-formed markdown with the 10 sections in order and a single fenced `notes:` YAML block that is valid YAML — Expected: well-formed; no malformed fences.
  - Failure: any missing section, fewer than 5 disposition rows, an execute-bound mechanic present, or a malformed `notes:` YAML block.

- [ ] **[QA]** Phase review
  - Review against: AC-7 (contract-exists half), AC-8 (schema), AC-6 (stamp convention), AC-13 (phrasing-set location)
  - Diff baseline: git diff phase_1_start..HEAD

---

### Phase 2: Standalone `spec-flow:triage` skill (`skills/triage/SKILL.md`)
**Exit Gate:** `skills/triage/SKILL.md` exists with valid CR-002 frontmatter; cites `triage-contract.md` and does NOT restate the 5-disposition vocabulary inline; classifies to exactly one disposition; dispatches `agents/spike.md` scope-mode (the only sub-dispatch) with a BLOCKED branch that records an open needs-scoping item; every disposition is operator-confirmed and writes a provenance-bearing entry; `plan-amend` is gated on a resolvable current working piece; bug-classified fixes stamp red-first on three surfaces; per-`[Verify]` greps pass.
**ACs Covered:** AC-1 (exactly one disposition), AC-2 (spike scope-mode dispatch, isolated), AC-3 (BLOCKED → open needs-scoping item, no fabrication), AC-4 (provenance every disposition, no patch path), AC-5 (operator-confirm, batch-aggregated, no auto-apply), AC-6 (red-first three stamp sites — skill wiring), AC-7 (skill-cites-contract half), AC-8 (`note-on-scheduled` writes the `notes:` field), AC-10 (disposition→target routing parity), AC-11 (`plan-amend` menu gating + refuse-with-record)
**In scope:** CREATE `plugins/spec-flow/skills/triage/SKILL.md` only.
**NOT in scope:** execute's Step 6c citation/rewire (Phase 3); intake Q4 (Phase 4); version/CHANGELOG/regression assertions (Phase 5); building the NN-P-006 red-first GATE (owned by `bugfix-redfirst`, open — this skill only forward-records the obligation). No new `manifest-query` verb (direct-YAML authoring per ADR-3).
**Why serial:** Phase 2 cites `reference/triage-contract.md`; it cannot be authored or QA'd until Phase 1's contract exists on disk (the citation + no-restatement invariant is verified against the live contract).
**Charter constraints honored in this phase:**
- NN-C-002 (markdown + config only): the skill is markdown; the only dispatch is the existing spike agent; no runtime dependency.
- NN-C-006 (no destructive ops without confirmation): every disposition (single or campaign batch) requires operator confirmation before any manifest/backlog write.
- NN-P-001 (human gate preserved): interactive triage requires an operator keystroke per disposition; no sign-off gate is removed.
- NN-P-002 (no silent / mid-stream change): every disposition is a recorded, routed action; the skill never patches code.
- NN-P-004 (operator-gated, no silent defer, nothing auto-applied): no auto-apply path; campaign batch gets one aggregated confirm prompt; `explicit-defer` requires a rationale.
- NN-P-005 (thinking on Opus, mechanics on Sonnet): the only thinking dispatch is the bounded spike scope-mode (Opus, isolated); the skill body is Sonnet-runnable.
- CR-002 (skill frontmatter schema): `SKILL.md` carries `name`, `description`, `argument-hint` (review-board precedent).
- CR-008 (thin-orchestrator skills): triage orchestrates parse → classify → ≤1 spike dispatch → route → record; it embeds no design/impl logic.

- [ ] **[Implement]** Author the standalone triage skill
  - Order: frontmatter → standalone declaration + Step 0 config load → input parsing (positional + structured) → bug-signal scan → classify (cite contract, exactly one) → operator-confirm (single + batch-aggregated) → spike scope-mode (OK / BLOCKED) → per-disposition routing → provenance recording (+ red-first stamp) → `## Boundaries` → return digest.
  - Architecture constraints: review-board sibling pattern (standalone, no active piece required, routes into other skills, never patches); cite `triage-contract.md` for the disposition vocabulary and gate rules — do NOT restate them (NN-C-008); the ONLY sub-agent dispatch is `agents/spike.md` scope-mode (CR-008 thin orchestrator); `${CLAUDE_PLUGIN_ROOT}` for the agent path.

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/skills/triage/SKILL.md`**
  - Anchor: new file.
  - Frontmatter (CR-002 — model on review-board/SKILL.md:1-13):
    ```
    ---
    name: triage
    description: >-
      Classify a discovery — agent-found or operator-stated — to exactly one disposition and route it
      to a recorded, provenance-bearing manifest/backlog entry, out of band from any session. Five
      dispositions: fix-now via small-change / amend the current working piece's plan / new manifest
      piece / note on a scheduled piece / explicit defer with rationale. Dispatches the spike agent in
      scope mode when a change needs design; never patches code, merges, or auto-applies. Use when the
      user says "triage this", "what should we do with this finding", "route this discovery", or an
      FR-020 campaign hands off findings.
    argument-hint: "<discovery-text | finding-ref> [--source <s>] [--rationale <r>] [--piece <slug>]"
    ---
    ```
  - Structure outline (sections, in order):
    1. Intro + **standalone declaration** (verbatim model from review-board:20): "This skill is **standalone** — it does NOT require an active piece, a manifest, or even a running execute loop. It requires only a spec-flow project layout (a git repo with `docs_root`)."
    2. `## Step 0: Load config (best-effort)` — read `.spec-flow.yaml` if present (`docs_root` default `docs`); confirm git repo via `git rev-parse --is-inside-work-tree`, STOP if not (review-board Step 0 idiom).
    3. `## Step 1: Parse input` — positional `<discovery-text | finding-ref>` + flags `--source`, `--rationale`, `--piece`. ALSO accept the `defer`-style **structured field set** (`source_piece`, `source_phase`, `source_agent`, `finding_text`, `operator_rationale`, `target?`, `discovery_type?`) and a **batch** of findings (FR-020 campaign). All forms map to one internal classification. (FR-T3.)
    4. `## Step 2: Bug-signal scan` — scan the discovery text for the keyword set `fix`/`bug`/`broken`/`regression`/`patch` (cite the contract's red-first section); set a `bug_classified` flag. Forward-record only (intake's `small_change_signals_detected` precedent). (FR-T7.)
    5. `## Step 3: Classify (exactly one disposition)` — classify to exactly one of the five dispositions **per `plugins/spec-flow/reference/triage-contract.md` `## Dispositions → target surface`** (cite; do NOT restate the vocabulary). State the exactly-one rule (never zero, never two). For `plan-amend`: offered ONLY when `--piece` is supplied AND a current working piece resolves (worktree via defer's reverse-lookup); otherwise it is NOT in the presented menu (AC-11). (FR-T1, AC-1, AC-11.)
    6. `## Step 4: Operator confirm (no auto-apply)` — present the proposed disposition(s) and require explicit operator confirmation before ANY write/handoff (cite contract `## Operator gate`). A multi-finding batch is presented as ONE aggregated confirm prompt. No auto-apply path. (AC-5, NN-P-004.)
    7. `## Step 5: Spike scope-mode (when the change needs design)` — the single sanctioned dispatch:
       ```
       Agent({
         description: "Scope discovery for triage: <one-line>",
         prompt: "<inject: mode:scope + the discovery text (+ the current piece's plan.md when --piece resolves) + WORKTREE preamble>",
         model: "opus"
       })
       ```
       Out of band the ratio is undefined ⇒ scope-spike (cite `reference/spike-agent.md` `## Threshold reuse`). On `STATUS: OK`: consume the scoping artifact. On `STATUS: BLOCKED`: record an **open needs-scoping item** carrying the blocker and surface it to the operator; write **no** fabricated disposition. (FR-T5, AC-2, AC-3.)
    8. `## Step 6: Route to target surface` — per the contract's disposition→target map (cite):
       - `small-change` → seed `/spec-flow:small-change` with the discovery as the change-brief (small-change Step 6 "Seeded input"; record a `## Source` provenance line).
       - `plan-amend` → resolve the current working piece (defer reverse-lookup); dispatch `agents/plan-amend.md` against that `plan.md` (scope-spike first when design is needed). Refused with a recorded message when no current working piece resolves (AC-11).
       - `new-piece` → author a new `manifest.yaml` entry via fork's direct-YAML idiom (`status: open`, `depends_on` operator-specified), WITHOUT fork's "set current piece blocked" coupling.
       - `note-on-scheduled` → append `{source, date, finding}` to the target piece's additive manifest `notes:` list (contract schema; ADR-3). (AC-8.)
       - `explicit-defer-with-rationale` → `/spec-flow:defer` structured form; `--rationale`/`operator_rationale` mandatory (refuse if missing). (AC-10, AC-4.)
    9. `## Step 7: Record provenance (+ red-first stamp)` — every disposition writes a recorded provenance-bearing entry (source session/finding + date). When `bug_classified` AND the disposition is a fix (`small-change`/`plan-amend`/`new-piece`), stamp the red-first obligation onto **all three** surfaces — handoff digest, recorded row, manifest/backlog entry (cite contract `## Red-first obligation`). (AC-4, AC-6.)
    10. `## Step 8: Return digest` — return a ≤2K disposition summary.
    11. `## Boundaries — what this skill does NOT do` (review-board model): no merge; no code patch / mid-stream edit; no preempt of in-progress work; no silent write (every disposition operator-confirmed + recorded); no sign-off-gate removal; no new `manifest-query` verb.
  - Pattern (review-board → small-change seeded handoff, from introspection Pattern Catalog):
    ```
    Hand off to /spec-flow:small-change, passing the digest as the change description.
    small-change treats the digest as authoritative requirements (confirms scope rather than
    re-brainstorming). Record provenance in brief.md (## Source line).
    ```
  - Pattern (defer structured form, the explicit-defer wire):
    ```
    Structured fields: source_piece, source_phase, source_agent, finding_text,
      operator_rationale, target (optional), discovery_type (optional).
    Structured invocation skips the operator-confirmation prompt; refuses if rationale missing.
    ```
  - Done: file exists; frontmatter has `name`+`description`+`argument-hint`; Step 3 cites `triage-contract.md` and the 5-disposition vocabulary is NOT restated inline; exactly one `agents/spike.md` dispatch with a BLOCKED branch; `plan-amend` gated on a resolvable current working piece with a refuse-with-record branch; bug-classified branch stamps three surfaces; `## Boundaries` present; no code-edit/patch path anywhere.
  - Verify: see [Verify] below.

- [ ] **[Verify]** Confirm the skill is sound
  **Per-change checks:**
  - T-1 (exists + frontmatter, CR-002): `test -f plugins/spec-flow/skills/triage/SKILL.md` and `grep -E "^name:|^description:|^argument-hint:" plugins/spec-flow/skills/triage/SKILL.md | wc -l` — Expected: file exists; ≥3 frontmatter keys.
  - T-1 (cites contract, no restatement — AC-7 skill half): `grep -c "triage-contract.md" plugins/spec-flow/skills/triage/SKILL.md` — Expected: ≥1; AND LLM-agent-step: confirm the 5-disposition→target *table* from the contract is NOT reproduced inline (the skill cites the contract for the vocabulary) — Expected: no duplicated map.
  - T-1 (single isolated spike dispatch — AC-2): `grep -c "agents/spike.md" plugins/spec-flow/skills/triage/SKILL.md` — Expected: exactly 1; AND LLM-agent-step: confirm there is no main-window design-resolution step (all design goes through the spike) — Expected: none.
  - T-1 (BLOCKED branch — AC-3): LLM-agent-step: read Step 5 and confirm the `STATUS: BLOCKED` branch records an open needs-scoping item with the blocker and has no disposition-fabrication fallthrough — Expected: present, no fabrication.
  - T-1 (exactly one disposition — AC-1): LLM-agent-step: read Step 3 and confirm the output contract is a single disposition (never zero, never two) — Expected: single-disposition contract.
  - T-1 (no patch path — AC-4): `grep -nE "Edit\(|Write\(|git apply|patch the|edit the code|modify .*\.py|modify .*\.ts" plugins/spec-flow/skills/triage/SKILL.md` — Expected: no code-edit/patch path (no match).
  - T-1 (operator-confirm + batch — AC-5): LLM-agent-step: read Step 4 and confirm no auto-apply path exists and a multi-finding batch aggregates into a single confirm prompt — Expected: confirm-only + aggregated batch.
  - T-1 (red-first three sites — AC-6): LLM-agent-step: read Step 2 + Step 7 and confirm the bug-classified branch stamps red-first onto handoff digest, recorded row, AND manifest/backlog entry — Expected: three stamp sites.
  - T-1 (note write — AC-8): LLM-agent-step: read the `note-on-scheduled` routing in Step 6 and confirm it appends `{source, date, finding}` to the target piece's manifest `notes:` list — Expected: three-key note write.
  - T-1 (plan-amend gating — AC-11): LLM-agent-step: read Step 3/Step 6 and confirm `plan-amend` is offered only when a current working piece resolves and an explicit `plan-amend` request with no active piece is refused with a recorded message — Expected: gated + refuse-with-record.
  - T-1 (disposition→target parity — AC-10): LLM-agent-step: compare Step 6's five routing targets against `triage-contract.md` `## Dispositions → target surface` — Expected: each disposition routes to the contract's named target; no orphan/mismatch.
  **Phase-level check:**
  - Run: `grep -rn "triage-contract.md" plugins/spec-flow/skills/triage/SKILL.md` — Expected: at least one resolvable citation (the file exists from Phase 1).
  - Failure: missing frontmatter key, >1 or 0 spike dispatches, a code-patch path present, the disposition map restated inline, or any missing AC branch above.

- [ ] **[Refactor]** (optional) Clean up — scope: `skills/triage/SKILL.md` only
  - Check for: duplicated prose that should be a contract citation; inconsistent section naming.
  - Constraint: only modify the file created in this phase.

- [ ] **[QA]** Phase review
  - Review against: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7 (skill half), AC-8, AC-10, AC-11
  - Diff baseline: git diff phase_2_start..HEAD

---

### Phase 3: Execute Step 6c — consume the shared contract + harden FR-008 detection (`skills/execute/SKILL.md`)
**Exit Gate:** execute's Step 6c FR-008 admission `y`-path sources its classify→disposition decision from `triage-contract.md` (the 5-disposition vocabulary), the inline bespoke amend/fork/defer-only vocabulary copy on that path is removed in favor of the citation, execute-bound mechanics (ratio, budget, placement, WIP-preemption) remain inline and unchanged, the FR-008 detection phrasing set cites the contract's hardened set, the suppression-during-active-prompt rule is preserved, and the externally-observable scope→amend→execute discipline is preserved/expanded (never reduced); per-`[Verify]` greps pass.
**ACs Covered:** AC-12 (execute sources disposition from the shared contract; inline duplicated-vocabulary copy removed; execute-bound mechanics remain inline), AC-13 (hardened detection cites the documented phrasing set; suppression preserved), AC-14 (unified path preserves NN-P-002 — scope→amend→execute, no mid-stream patch), AC-7 (execute-cites-contract half)
**In scope:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md` — only the `### Step 6c: Discovery Triage` region: the `#### Operator-initiated change admission (FR-008)` block (detection phrasing + the `y`-path classification) and the `#### Triage prompt` block (cite the contract for the operator-change disposition vocabulary).
**NOT in scope:** the four agent-discovered aggregation sources' inline routing (Step 6c §Aggregation 1–4 keep `default_triage` amend/fork/defer — ADR-2); the 50% ratio computation, amendment-budget counters, block-aware placement, WIP-preemption, scope-spike pre-step, `.discovery-log.md` authoring (all stay inline, unchanged); the triage skill (Phase 2); intake (Phase 4); version/regression (Phase 5).
**Why serial:** Phase 3 cites `reference/triage-contract.md` (Phase 1) and must not run before it exists; high blast radius on the ~2,100-line execute file warrants per-phase Opus QA in isolation (operator accepted the blast radius per spec Open Questions).
**Steps traversed (P2):** `execute/SKILL.md` is a multi-step orchestration file (≥3 `### Step` headings). The FR-T10 change introduces a new path through the existing Step 6c loop: it traverses (1) `#### Operator-initiated change admission (FR-008)` (the `y`-path that appends the operator change), then (2) `#### Triage prompt` (where the disposition is chosen — now sourced from the contract vocabulary), then (3) the existing `#### Auto-mode threshold` → `#### Amend dispatch` (scope-spike pre-step + plan-amend) / `#### Fork dispatch` / `#### Defer dispatch` mechanics, which remain inline and are NOT re-plumbed. The new reachable dispositions (`small-change`, `note-on-scheduled`) traverse to handoff/manifest-write rather than the amend/fork/defer dispatchers. The `#### Amendment budget tracking`, `#### `.discovery-log.md` authoring`, `#### Recursion semantics`, and `#### NN-P-002 preservation` steps are traversed unchanged.
**Dispatch sites (P3):** The affected agent-dispatch contract is the operator-initiated-change routing. Pre-existing dispatch sites on this path: `agents/spike.md` (scope-mode pre-step, unchanged), `agents/plan-amend.md` (unchanged), `agents/spec-amend.md` (unchanged), `/spec-flow:defer` (unchanged). NEW reachability added by sourcing the fuller disposition set on the FR-008 `y`-path: `/spec-flow:small-change` seeded handoff and the manifest `notes:` write (`note-on-scheduled`) — both already exist as surfaces (Phase 2 / contract); execute now routes to them on the operator-change path. No agent prompt contract is altered; only which disposition the operator-change can select expands.
**Charter constraints honored in this phase:**
- NN-C-003 (backward compat within major): the rewire changes execute's INTERNAL routing on the FR-008 `y`-path only; the four agent-discovery sources, mechanics, and externally-observable discipline are preserved or expanded, never reduced (NFR-003 / AC-14).

- [ ] **[Implement]** Rewire the FR-008 admission `y`-path to the shared contract + harden detection
  - Order: (1) harden the detection phrasing (cite contract's documented set) → (2) preserve suppression rule → (3) on `y`, source the disposition vocabulary from the contract → (4) cite the contract in the Triage prompt block for the operator-change disposition set → (5) confirm mechanics untouched.
  - Architecture constraints: cite `triage-contract.md` — do NOT restate the 5-disposition vocabulary inline (NN-C-008); keep ALL execute-bound mechanics inline and unchanged (ADR-2); preserve the suppression-during-active-prompt rule verbatim in intent.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`**
  - Anchor: `#### Operator-initiated change admission (FR-008)` (lines 1046–1064).
  - Current:
    ```
    1046  #### Operator-initiated change admission (FR-008)
    1047
    1048  When a free-form operator turn (NOT a structured answer to an active execute prompt — triage choice, QA sign-off, BLOCKED escalation response, etc.) reads as a behavior or scope change — imperative phrasing such as "add…", "change…", "we should…", "what if we…", "can you also…" — the coordinator emits ONE confirmation prompt:
    ...
    1054  - **On `y`:** append the change to the Step 6c discovery list with:
    1055    - `source_agent: operator`
    1056    - `default_triage: amend`
    1057    - `row_text` = the operator's change text verbatim (used as input to the scope spike if threshold exceeded)
    1058    Proceed through the normal triage + amend flow for that discovery.
    1062  **Detection is SUPPRESSED while the coordinator is awaiting a structured answer** ...
    ```
  - Target:
    (a) Replace the inline phrasing enumeration in the L1048 sentence (`imperative phrasing such as "add…", "change…", "we should…", "what if we…", "can you also…"`) with a citation: `imperative / change-request phrasing per the documented change-signal set in `plugins/spec-flow/reference/triage-contract.md` `## FR-008 mid-execution change-signal phrasing set` (the single documented trigger set — do NOT restate it here, NN-C-008)`. (AC-13: hardened set documented in one place.)
    (b) Keep the **suppression** sentence (L1062) intact — preserve the rule that free-form input is treated as a structured answer whenever the coordinator awaits a constrained response. (AC-13.)
    (c) Rewrite the `On y` block (L1054–1058) so the admitted operator change's **classification is sourced from the shared contract's 5-disposition vocabulary** rather than hard-coding `default_triage: amend`: append the change with `source_agent: operator` and `row_text` = verbatim change text, then classify the disposition through `plugins/spec-flow/reference/triage-contract.md` `## Dispositions → target surface` (the SAME vocabulary `spec-flow:triage` uses) — so the operator change may land on `small-change` / `plan-amend` / `new-piece` / `note-on-scheduled` / `explicit-defer-with-rationale`, not only `amend`. Add an explicit note: "Execute-bound mechanics — the 50% ratio→scope-spike pre-step, amendment-budget counters, block-aware placement, and WIP-preemption — stay inline and apply unchanged to the `plan-amend` disposition (see the blocks below); only the classify→disposition→target decision is sourced from the shared contract (FR-T10 / AC-12)." (AC-12, AC-14.)
  - Pattern (existing contract-citation idiom already used in execute Step 6c, L1094):
    ```
    For all mechanics ... see `plugins/spec-flow/reference/flywheel.md` ... Do NOT restate those rules here (CR-008 / NN-C-008).
    ```
  - Done: the FR-008 phrasing enumeration is replaced by a contract citation; the suppression sentence is intact; the `On y` path sources its disposition from `triage-contract.md`'s 5-disposition vocabulary; an explicit "mechanics stay inline" note is present; no ratio/budget/placement/WIP text was deleted or altered.
  - Verify: `grep -n "triage-contract.md" plugins/spec-flow/skills/execute/SKILL.md` returns ≥1 match in the Step 6c region; the suppression sentence still present.

  **T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`**
  - Anchor: `#### Triage prompt` (lines 1068–1088).
  - Current:
    ```
    1072  <N> discoveries surfaced in <phase-id>:
    1075        Options: (a) amend  (f) fork  (d) defer
    ...
    1084  A fourth option, `(s) amend-spec`, is offered ONLY for discoveries whose finding text names a missing FR/AC ...
    ```
  - Target: Leave the agent-discovered triage prompt (the `(a) amend (f) fork (d) defer [(s) amend-spec]` menu for the four aggregation sources) UNCHANGED (ADR-2). Add ONE clarifying paragraph immediately after the triage-prompt block: "For an **operator-initiated change** admitted via the FR-008 `y`-path, the disposition is drawn from the unified 5-disposition vocabulary in `plugins/spec-flow/reference/triage-contract.md` `## Dispositions → target surface` (the same set `spec-flow:triage` uses) — not from this agent-discovery `(a)/(f)/(d)` menu, which governs the four agent-discovered aggregation sources only. Execute-bound mechanics (ratio, budget, placement, WIP-preemption) apply unchanged when the operator change is dispositioned to `plan-amend`." Do NOT restate the 5-disposition vocabulary inline — cite it. (AC-12, AC-7 execute half.)
  - Pattern: same contract-citation idiom as T-1.
  - Done: a clarifying paragraph distinguishes the operator-change disposition source (contract) from the agent-discovery `(a)/(f)/(d)` menu; the agent-discovery menu prose is unchanged; the 5-disposition vocabulary is cited not restated.
  - Verify: LLM-agent-step confirms the agent-discovery menu is intact AND the operator-change paragraph cites the contract.
  <!-- The .discovery-log.md row format, amendment budget, scope-spike pre-step, and NN-P-002 preservation blocks are intentionally NOT in this change set — they stay inline and unchanged (ADR-2). -->

- [ ] **[Verify]** Confirm execute conforms to the contract without regressing mechanics
  **Per-change checks:**
  - T-1 (cites contract — AC-7/AC-12): `grep -n "triage-contract.md" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1 match within lines 1046–1090.
  - T-1 (hardened detection sourced from one place — AC-13): LLM-agent-step: read the FR-008 admission block and confirm the change-signal phrasing is sourced by citation from `triage-contract.md` `## FR-008 mid-execution change-signal phrasing set` (not a fresh inline list) — Expected: citation present.
  - T-1 (suppression preserved — AC-13): `grep -n "SUPPRESSED while the coordinator is awaiting a structured answer" plugins/spec-flow/skills/execute/SKILL.md` — Expected: 1 match (rule intact).
  - T-1 (no inline 5-disposition restatement — AC-12): LLM-agent-step: confirm execute does NOT reproduce the contract's 5-disposition→target table inline; it cites the contract — Expected: cited, not restated.
  - T-1/T-2 (mechanics intact — AC-12/AC-14): `grep -cE "amendment_budget|piece_amendment_count|cumulative-diff|blocking-on-current|blocking-on-later|additive: <after-phase-id>|No amendment phase preempts" plugins/spec-flow/skills/execute/SKILL.md` — Expected: unchanged count vs phase_3_start (the ratio/budget/placement/WIP blocks were not deleted). Compare: `git diff phase_3_start..HEAD -- plugins/spec-flow/skills/execute/SKILL.md` touches ONLY lines within the Step 6c FR-008 admission + Triage-prompt region.
  - T-2 (agent-discovery menu intact — ADR-2): `grep -n "(a) amend  (f) fork  (d) defer" plugins/spec-flow/skills/execute/SKILL.md` — Expected: still present.
  **Phase-level check:**
  - Run: `git diff phase_3_start..HEAD -- plugins/spec-flow/skills/execute/SKILL.md | grep -E "^[-+]" | grep -vE "^(---|\+\+\+)"` then LLM-agent-step: confirm every changed line falls in the FR-008 admission or Triage-prompt blocks and no ratio/budget/placement/WIP line was removed — Expected: scoped diff; mechanics untouched.
  - Failure: a deleted mechanics block, the suppression rule removed, the 5-disposition vocabulary restated inline, or the agent-discovery `(a)/(f)/(d)` menu altered.

- [ ] **[QA]** Phase review
  - Review against: AC-12, AC-13, AC-14, AC-7 (execute half); confirm NN-C-003 backward-compat (externally-observable discipline preserved/expanded).
  - Diff baseline: git diff phase_3_start..HEAD

---

### Phase 4: intake Q4 route to `spec-flow:triage` (`skills/intake/SKILL.md`)
**Exit Gate:** intake's Q4 offers an "Investigation / discovery to triage" choice that routes to `spec-flow:triage`, operator-selected (no silent routing); the existing four choices and the read-only `exploratory` branch are unchanged; per-`[Verify]` grep passes.
**ACs Covered:** AC-9 (intake Q4 choice → `spec-flow:triage`, operator-selected)
**In scope:** MODIFY `plugins/spec-flow/skills/intake/SKILL.md` — only the `### Q4 — Standalone type` block (add one choice + its routing line).
**NOT in scope:** Step 2 auto-classification (unchanged — the new route is operator-selected, NOT auto-routed); the `exploratory` read-only branch (the triage route is distinct from it); any other Q-tree node; the triage skill itself (Phase 2).
**Charter constraints honored in this phase:**
- (No additional charter NN/CR slot — the spec's enumerated entries are allocated across Phases 1/2/3/5; this phase's backward-compat is covered by NFR-T2 in prose: the added choice removes none and the `exploratory` branch is untouched.)

- [ ] **[Implement]** Add the operator-selected triage route to Q4
  - Order: add the choice to the Q4 choice list → add its routing line.
  - Architecture constraints: operator-selected only (no auto-routing — intake AC-IN-5 "no silent routing" precedent); the route points at `spec-flow:triage` and is distinct from the read-only `exploratory` branch.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/intake/SKILL.md`**
  - Anchor: `### Q4 — Standalone type` (lines 196–208).
  - Current:
    ```
    200  Choices:
    201  - "Hotfix / regression / CI failure"
    202  - "Infrastructure or tooling change"
    203  - "Charter or documentation update"
    204  - "Exploration — read-only, no changes"
    205
    206  - **Hotfix / regression / CI / infra** → `type: hotfix` → Q5
    207  - **Charter / docs** → `type: charter` → skip to Step 4
    208  - **Exploration** → `type: exploratory` → skip to Step 4
    ```
  - Target: Add a fifth choice `- "Investigation / discovery to triage"` to the choice list (after L204), and add the routing line `- **Investigation / discovery to triage** → route to `/spec-flow:triage` (operator-selected; do NOT auto-route) → exit intake` after L208. The route is explicitly operator-selected and distinct from the `exploratory` read-only branch.
  - Pattern (existing Q4 routing-line idiom, from the Current block above):
    ```
    - **Charter / docs** → `type: charter` → skip to Step 4
    ```
  - Done: Q4 has five choices including "Investigation / discovery to triage"; a routing line maps it to `/spec-flow:triage`, operator-selected; the four existing choices and the `exploratory` branch are unchanged.
  - Verify: `grep -n "Investigation / discovery to triage" plugins/spec-flow/skills/intake/SKILL.md` returns 2 matches (choice + routing line); `grep -n "spec-flow:triage" plugins/spec-flow/skills/intake/SKILL.md` returns ≥1.

- [ ] **[Verify]** Confirm the route is present and operator-selected
  **Per-change checks:**
  - T-1 (choice + route — AC-9): `grep -c "Investigation / discovery to triage" plugins/spec-flow/skills/intake/SKILL.md` — Expected: 2 (choice line + routing line).
  - T-1 (routes to triage — AC-9): `grep -n "spec-flow:triage" plugins/spec-flow/skills/intake/SKILL.md` — Expected: ≥1 match in the Q4 region.
  - T-1 (operator-selected, no silent routing — AC-9): LLM-agent-step: read the Q4 routing line and confirm it is operator-selected (appears in the Q4 choice menu, not in Step 2 auto-classification) — Expected: operator-selected.
  **Phase-level check:**
  - LLM-agent-step: confirm the four original Q4 choices and the `exploratory` branch are unchanged — Expected: only an additive choice + route.
  - Failure: the route placed in Step 2 auto-classification, the `exploratory` branch altered, or a removed existing choice.

- [ ] **[QA]** Phase review
  - Review against: AC-9
  - Diff baseline: git diff phase_4_start..HEAD

---

### Phase 5: Version bump + consolidated pipeline-e2e regression net (version files + `static.sh` + CHANGELOG)
**Exit Gate:** plugin version is `5.18.0` across `plugin.json` + `marketplace.json`; CHANGELOG has a `## [5.18.0]` section describing the piece (incl. the FR-023 fold-in); the pipeline-e2e static suite (`tests/e2e/lib/static.sh`) is extended with the cross-phase citation-parity + skill + intake-route + hardened-detection assertions and its version assertions are bumped; the full static suite passes; no stray `5.17.0` remains in `plugin.json`/`marketplace.json`.
**ACs Covered:** AC-7 (cross-phase: contract exists AND both execute + skill cite it AND neither restates the vocabulary — the durable assertion), AC-9/AC-12/AC-13 (durable regression assertions for the intake route, execute citation, and hardened detection). (Per-AC mechanism was verified inline in Phases 1–4; Phase 5 makes the checks durable in the regression net per the spec Testing Strategy.)
**In scope:** MODIFY `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `plugins/spec-flow/CHANGELOG.md`, `plugins/spec-flow/tests/e2e/lib/static.sh`.
**NOT in scope:** the PRD (FR-023 already committed — ADR-4; Phase 5 only references it in the CHANGELOG); the deliverable docs/skills (Phases 1–4); any historical CHANGELOG section (`[5.17.0]`, `[5.16.1]` stay); the `static.sh` historical version-section assertions (lines 216/218 referencing `[5.16.1]` / `(c) continue` stay unchanged).
**Charter constraints honored in this phase:**
- NN-C-007 (CHANGELOG accompanies version bump): a `## [5.18.0]` CHANGELOG entry lands with the version bump.
- NN-C-009 (version bump on changes): `5.17.0 → 5.18.0` across all version-bearing files + the `static.sh` version assertions.
- CR-004 (conventional commits with plugin scope): the version/regression commit uses a `feat(...)`/`chore(...)` scoped message.

- [ ] **[Implement]** Bump the version and author the durable regression assertions
  - Order: bump `plugin.json` → bump `marketplace.json` → add `## [5.18.0]` CHANGELOG section → bump `static.sh` version assertions → append the unified-path / citation-parity / skill / intake-route / hardened-detection assertions to `static.sh`.
  - Architecture constraints: bump the LATEST version only — preserve historical CHANGELOG sections; `static.sh` assertions follow the existing `assert_grep '<ERE>' "$file" "<message>"` idiom and append to the artifact-contract anchors section.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json`**
  - Anchor: `"version"` (line 4).
  - Current:
    ```
    4    "version": "5.17.0",
    ```
  - Target: `"version": "5.18.0",`.
  - Done: plugin.json version is `5.18.0`.
  - Verify: `grep '"version": "5.18.0"' plugins/spec-flow/.claude-plugin/plugin.json` — match.

  **T-2: MODIFY `.claude-plugin/marketplace.json`**
  - Anchor: spec-flow entry `"version"` (line 15).
  - Current:
    ```
    15        "version": "5.17.0",
    ```
  - Target: `"version": "5.18.0",`.
  - Done: marketplace.json spec-flow entry version is `5.18.0`.
  - Verify: `grep '"version": "5.18.0"' .claude-plugin/marketplace.json` — match.

  **T-3: MODIFY `plugins/spec-flow/CHANGELOG.md`**
  - Anchor: `## [Unreleased]` (line 5) / top of changelog (above `## [5.17.0]` at line 7).
  - Current:
    ```
    5    ## [Unreleased]
    6
    7    ## [5.17.0] — 2026-06-12
    ```
  - Target: Insert a new `## [5.18.0] — 2026-06-12` section between `## [Unreleased]` and `## [5.17.0]`, with an `### Added` block summarizing: the standalone `spec-flow:triage` skill (FR-019); the shared `reference/triage-contract.md` (single source of truth both execute Step 6c and the skill cite); execute Step 6c consumes the shared contract on the FR-008 admission path + hardened mid-execution change-signal detection (FR-023, extends FR-019 AC-4); additive per-piece manifest `notes:` field; intake Q4 "Investigation / discovery to triage" route. Keep `## [5.17.0]` and all older sections unchanged.
  - Pattern (existing CHANGELOG section shape, from CHANGELOG.md:7-12):
    ```
    ## [5.17.0] — 2026-06-12
    ### Added
    - **FR-018: Outcome & negative-space acceptance criteria.** ...
    ```
  - Done: a `## [5.18.0] — 2026-06-12` section exists with an `### Added` block naming the skill, the contract, the FR-023 execute fold-in, the `notes:` field, and the intake route; historical sections intact.
  - Verify: `grep -n "## \[5.18.0\]" plugins/spec-flow/CHANGELOG.md` — match; `grep -c "## \[5.17.0\]" plugins/spec-flow/CHANGELOG.md` — still 1.

  **T-4: MODIFY `plugins/spec-flow/tests/e2e/lib/static.sh`**
  - Anchor: version-sync assertions (lines 209–212).
  - Current:
    ```
    209    assert_grep '"version": "5\.17\.0"' "$pluginjson" \
    210      "AC-11: plugin.json version is 5.17.0"
    211    assert_grep '"version": "5\.17\.0"' "$marketplace" \
    212      "AC-11: marketplace.json spec-flow entry is 5.17.0"
    ```
  - Target: bump both regex to `'"version": "5\.18\.0"'` and both message strings to `... is 5.18.0`. Leave the CHANGELOG `[5.16.1]` / `(c) continue` assertions (lines 216–219) UNCHANGED (historical-specific checks).
  - Done: the two version-sync assertions check `5.18.0`.
  - Verify: `grep -n '5\\.18\\.0' plugins/spec-flow/tests/e2e/lib/static.sh` — 2 matches (the two version assertions).

  **T-5: MODIFY `plugins/spec-flow/tests/e2e/lib/static.sh`**
  - Anchor: artifact-contract anchors section (after line 70, which asserts `'### Step 6c: Discovery Triage'`).
  - Current:
    ```
    63    # --- artifact-contract anchors (7 checks) ---
    ...
    69      '### Step 6c: Discovery Triage'
    70      '### Step G9b: Barrier work-commit'
    ```
  - Target: Append a new delimited block `# --- discovery-triage unified-path contract (FR-019/FR-023) ---` with these assertions (one `assert_grep`/`assert_file` per line, following the file's idiom; bind paths the way the function already binds `$pluginjson`/`$changelog`):
    1. Contract file exists (AC-7): `assert_file "${PLUGIN_ROOT}/reference/triage-contract.md" "FR-019: triage-contract.md exists"` (use the file's existing existence-assert helper; if none, `assert_grep "Dispositions" "${PLUGIN_ROOT}/reference/triage-contract.md" "FR-019: triage-contract.md has disposition map"`).
    2. Triage skill exists + cites the contract (AC-7 skill half): `assert_grep "triage-contract.md" "${PLUGIN_ROOT}/skills/triage/SKILL.md" "FR-019: triage skill cites the shared contract"`.
    3. Execute Step 6c cites the contract (AC-7/AC-12 execute half): `assert_grep "triage-contract.md" "${PLUGIN_ROOT}/skills/execute/SKILL.md" "FR-023: execute Step 6c cites the shared contract"`.
    4. Hardened FR-008 detection sourced from one place (AC-13): `assert_grep "FR-008 mid-execution change-signal phrasing set" "${PLUGIN_ROOT}/reference/triage-contract.md" "FR-023: hardened change-signal phrasing set documented in the contract"`.
    5. Suppression rule preserved in execute (AC-13): `assert_grep "SUPPRESSED while the coordinator is awaiting a structured answer" "${PLUGIN_ROOT}/skills/execute/SKILL.md" "FR-023: FR-008 suppression-during-active-prompt rule preserved"`.
    6. Intake Q4 route present (AC-9): `assert_grep "spec-flow:triage" "${PLUGIN_ROOT}/skills/intake/SKILL.md" "FR-019: intake Q4 routes to spec-flow:triage"`.
    7. Red-first three-surface stamp documented (AC-6): `assert_grep "red-first" "${PLUGIN_ROOT}/reference/triage-contract.md" "FR-019: contract documents the NN-P-006 red-first forward-record"`.
  - Pattern (existing assert idiom, static.sh:209/216):
    ```
    assert_grep '"version": "5\.17\.0"' "$pluginjson" \
      "AC-11: plugin.json version is 5.17.0"
    ```
  - Done: a new delimited assertion block with the 7 checks above is appended; it uses the file's `assert_grep`/`assert_file` helpers and `${PLUGIN_ROOT}` paths.
  - Verify: `grep -c "FR-019\|FR-023" plugins/spec-flow/tests/e2e/lib/static.sh` — ≥7 new assertion messages.

- [ ] **[Write-Tests]** The durable pipeline-e2e regression net (this IS the test authorship for the piece)
  - The Phase-5 `static.sh` additions (T-4 + T-5) constitute the regression-net extension the spec's Testing Strategy requires ("the execute surgery is covered by extending `pipeline-e2e`"). No separate runtime suite exists (doc-as-code). Stage `static.sh` via `git add` so `[Verify]` can run it.
  - **Test Data (one case per behavior-under-test; cases are the static-suite assertions):**
    - TD-1 (AC-7 contract single source): input = repo after Phases 1–4 → expect `triage-contract.md` exists AND both `skills/triage/SKILL.md` and `skills/execute/SKILL.md` grep-match `triage-contract.md` AND neither restates the 5-disposition table (asserted by T-5 checks 1–3 passing).
    - TD-2 (AC-12 execute sources from contract): input = `skills/execute/SKILL.md` Step 6c → expect a `triage-contract.md` citation in the FR-008 region (T-5 check 3 passes).
    - TD-3 (AC-13 hardened detection + suppression): input = contract + execute → expect the phrasing-set section present in the contract AND the suppression sentence present in execute (T-5 checks 4–5 pass).
    - TD-4 (AC-9 intake route): input = `skills/intake/SKILL.md` → expect a `spec-flow:triage` route (T-5 check 6 passes).
    - TD-5 (AC-6 red-first documented): input = contract → expect a `red-first` forward-record reference (T-5 check 7 passes).
    - TD-6 (NN-C-009 version sync): input = `plugin.json` + `marketplace.json` → expect `5.18.0` in both (T-4 passes).

- [ ] **[Integration-Test]** (completing-phase) Green the doc-as-code integration boundaries (INT-1..INT-4)
  - **Boundary:** the union of the spec's six Integration Coverage boundaries — all complete here because every boundary is a citation/handoff verified by the consolidated static suite: (1) `execute` Step 6c ↔ `triage-contract.md` ↔ `triage/SKILL.md` (INT-1); (2) `triage` → small-change / plan-amend / defer / manifest `notes:` (INT-2); (3) `intake` Q4 → `spec-flow:triage` (INT-3); (4) `execute` FR-008 admission ↔ documented phrasing set (INT-4). All components are inside the boundary (in-repo skills/reference docs); **no true external is doubled** (these are markdown-citation handoffs, not networked/SDK calls).
  - **completes_in_phase: 5**
  - **Contract tests:** none — there are no doubled true externals (every boundary is an in-repo doc/skill citation; the contract IS the grep-checkable citation parity, asserted by T-5 checks 1–7).
  - **Run:** `bash plugins/spec-flow/tests/e2e/self/test-core.sh` (drives `lib/static.sh`; fall back to `bash plugins/spec-flow/tests/e2e/run-e2e.sh` static mode if the runner name differs) — **Expected:** 0 failed assertions; the 7 new FR-019/FR-023 boundary assertions (T-5) and the bumped version assertions (T-4) all green.
  - Note: doc-as-code piece — there is no runtime integration harness (spec Testing Strategy: "no runtime unit suite"); the real-path verification of every boundary is the static-suite citation-parity grep, which exercises the actual on-disk artifacts produced by Phases 1–4.

- [ ] **[Verify]** Run the static suite + cross-phase consistency + anti-drift sweep
  **Per-change checks:**
  - T-1/T-2 (version bumped): `grep -c '"version": "5.18.0"' plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json` — Expected: 1 match in each file.
  - T-3 (CHANGELOG): `grep -n "## \[5.18.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: 1 match; `grep -c "## \[5.17.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: 1 (historical intact).
  - **Cross-phase schema-consistency oracle (AC-7, plan §2d) — `triage-contract.md` is the schema-bearing file referenced by Phases 1/2/3:** the contract exists AND `skills/triage/SKILL.md` cites it AND `skills/execute/SKILL.md` cites it AND neither restates the 5-disposition vocabulary inline:
    - `test -f plugins/spec-flow/reference/triage-contract.md && grep -lq triage-contract.md plugins/spec-flow/skills/triage/SKILL.md plugins/spec-flow/skills/execute/SKILL.md && echo PARITY-OK` — Expected: `PARITY-OK`.
    - LLM-agent-step: confirm neither `skills/triage/SKILL.md` nor `skills/execute/SKILL.md` reproduces the contract's `## Dispositions → target surface` 5-row table inline — Expected: cited in both, restated in neither.
  - **Superseded-ordinal anti-drift sweep (plan §2e) — version 5.17.0 → 5.18.0:**
    - Sweep superseded version in bump targets: `grep -rn "5\.17\.0" plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json` — Expected: 0 hits (no prior version remains in the two version files).
    - Sweep superseded version assertions in static.sh: `grep -n '5\.17\.0' plugins/spec-flow/tests/e2e/lib/static.sh` — Expected: 0 hits (both version assertions bumped). (Note: CHANGELOG.md KEEPS its historical `## [5.17.0]` section — it is intentionally excluded from this sweep.)
    - Sweep new target: `grep -rn "5\.18\.0" plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/spec-flow/tests/e2e/lib/static.sh` — Expected: ≥1 in each (4 total: plugin.json, marketplace.json, two static.sh assertions).
  **Phase-level check:**
  - Run the static-assertion suite: `bash plugins/spec-flow/tests/e2e/self/test-core.sh` (the runner that drives `lib/static.sh`) — Expected: PASS / 0 failed assertions (the bumped version asserts + the 7 new FR-019/FR-023 asserts all green). If the runner name differs, run `bash plugins/spec-flow/tests/e2e/run-e2e.sh` static mode.
  - Failure: any failed assertion, a stray `5.17.0` in a version file or static.sh version assertion, a missing CHANGELOG `[5.18.0]` section, or the parity oracle not returning `PARITY-OK`.

- [ ] **[QA]** Phase review
  - Review against: AC-7 (durable), AC-9/AC-12/AC-13 (durable regression), NN-C-007, NN-C-009
  - Diff baseline: git diff phase_5_start..HEAD

## AC Coverage Matrix

(Included for traceability; not required in non-TDD mode. Per-AC verification is in Executable AC Binding below.)

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1  | Classifies to exactly one of five dispositions | COVERED | Phase 2 |
| AC-2  | Dispatches spike.md scope-mode (bounded, isolated); no main-window design | COVERED | Phase 2 |
| AC-3  | Spike BLOCKED → open needs-scoping item w/ blocker; no fabricated disposition | COVERED | Phase 2 |
| AC-4  | Every disposition writes provenance-bearing entry; no silent patch path | COVERED | Phase 2 |
| AC-5  | No auto-apply; operator confirm; batch → one aggregated prompt | COVERED | Phase 2 |
| AC-6  | Bug-classified fix stamps red-first on all three surfaces | COVERED | Phase 1 (convention) + Phase 2 (wiring) |
| AC-7  | Contract defined once; both execute & skill cite it; no inline restatement | COVERED | Phase 1 (contract) + Phase 2 (skill cites) + Phase 3 (execute cites) + Phase 5 (durable parity oracle) |
| AC-8  | note-on-scheduled appends `{source,date,finding}`; absent field parses | COVERED | Phase 1 (schema) + Phase 2 (write) |
| AC-9  | Intake Q4 route to spec-flow:triage, operator-selected | COVERED | Phase 4 |
| AC-10 | Each disposition routes to the contract's named target surface | COVERED | Phase 2 |
| AC-11 | plan-amend gated on resolvable current piece; refuse-with-record otherwise | COVERED | Phase 2 |
| AC-12 | Execute Step 6c sources disposition from shared contract; mechanics inline | COVERED | Phase 3 |
| AC-13 | Hardened detection set documented once; suppression preserved | COVERED | Phase 1 (phrasing set) + Phase 3 (execute cites + suppression) |
| AC-14 | Unified path preserves NN-P-002 (scope→amend→execute, no mid-stream patch) | COVERED | Phase 3 |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1  | agent-step | Read `skills/triage/SKILL.md` Step 3; confirm single-disposition output contract (never 0, never 2) | Single-disposition contract |
| AC-2  | shell | `grep -c "agents/spike.md" plugins/spec-flow/skills/triage/SKILL.md` | `1` (exactly one isolated dispatch) |
| AC-3  | agent-step | Read Step 5 BLOCKED branch; confirm open needs-scoping item w/ blocker, no fabrication fallthrough | Present; no fabrication |
| AC-4  | shell | `grep -nE "Edit\(|Write\(|git apply|patch the code" plugins/spec-flow/skills/triage/SKILL.md` | No match (no patch path) |
| AC-5  | agent-step | Read Step 4; confirm no auto-apply path + batch aggregates to one prompt | Confirm-only + aggregated |
| AC-6  | agent-step | Read `triage-contract.md` red-first section + skill Step 7; confirm 3 stamp surfaces | Three surfaces named |
| AC-7  | shell | `test -f plugins/spec-flow/reference/triage-contract.md && grep -lq triage-contract.md plugins/spec-flow/skills/triage/SKILL.md plugins/spec-flow/skills/execute/SKILL.md && echo PARITY-OK` | `PARITY-OK` |
| AC-8  | agent-step | Read contract `## Manifest notes: schema`; confirm `source`+`date`+`finding` keys; absent field parses | Three keys; optional |
| AC-9  | shell | `grep -c "spec-flow:triage" plugins/spec-flow/skills/intake/SKILL.md` | ≥1 (Q4 route) |
| AC-10 | agent-step | Compare skill Step 6 targets vs contract disposition→target map | Each routes to named target; no mismatch |
| AC-11 | agent-step | Read skill Step 3/6; confirm plan-amend gated on resolvable piece + refuse-with-record branch | Gated + refuse-with-record |
| AC-12 | shell | `grep -n "triage-contract.md" plugins/spec-flow/skills/execute/SKILL.md` | ≥1 in lines 1046–1090 |
| AC-13 | shell | `grep -c "SUPPRESSED while the coordinator is awaiting a structured answer" plugins/spec-flow/skills/execute/SKILL.md` | `1` (suppression intact) + contract phrasing-set section present |
| AC-14 | agent-step | Read execute Step 6c FR-008 path; confirm scope→amend→execute + operator gate, no mid-stream-patch path | Discipline intact |

## Contracts

No TDD-track phases in this plan (all phases are Implement / Non-TDD doc-as-code) — section present for forward compatibility. `tdd-red` agents will not be dispatched; no contract injection occurs. The boundary-crossing surfaces this piece introduces (the disposition→target map, the manifest `notes:` schema, the FR-008 change-signal phrasing set) are captured authoritatively in `reference/triage-contract.md` (Phase 1) rather than as code-level contracts.

## Parallel Execution Notes

All phases run **serially** — no `[P]` sub-phases. Phase 1 (contract) is the foundation that Phases 2 and 3 cite (the citation + no-restatement invariant is verified against the live contract). Phase 5 asserts the outputs of Phases 1–4. `Why serial:` is declared on Phases 2 and 3 (cite the Phase-1 contract; execute's high blast radius warrants isolated per-phase Opus QA). `tests/e2e/lib/static.sh` is edited only in Phase 5 (Scaffold-first coordination-file consolidation — the per-phase machine-checkable greps run as inline `[Verify]` oracles in Phases 1–4; the durable assertions land once in Phase 5), so no phase contends on it.

## Agent Context Summary
| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, plan `[Implement]` tasks (self-contained Change Specification Blocks), spec ACs, plan `[Verify]` commands, arch constraints (ADR-1..4), pattern blocks, codebase context from `introspection.md` (File Inventory + Pattern Catalog for the phase scope) | Spec rationale, brainstorming history, the deliberation's superseded backward-compat note |
| Write-Tests (Phase 5) | Phase 5 `[Write-Tests]` Test Data, the `static.sh` assertion idiom, `${PLUGIN_ROOT}` path bindings | Other phases' diffs, prior agent conversations |
| Verify | The phase `[Verify]` greps/LLM-agent-steps + the static-suite command, spec ACs | Implementation reasoning |
| QA | Phase diff, spec, plan, PRD sections (FR-019/FR-023), charter skills | Any agent conversation history |
