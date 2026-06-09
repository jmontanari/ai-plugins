---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  coding-rules: 2026-06-01
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
---

# Spec: spec-preresearch — Investigation-First Design Protocol (Spec 2.0)

**PRD Sections:** FR-009 (new — this piece writes FR-009 into `docs/prds/exec-ready/prd.md`)
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** research-unify (merged)

## Goal

Replace the current reactive brainstorm model — where the spec/PRD/small-change skills ask questions before investigating — with an investigation-first protocol. Before the user sees a single design question, a multi-agent deliberation protocol runs a structured 5-phase investigation: a coordinator agent reads all available artifacts and fires targeted web research; parallel viability agents analyze every viable path per decision-unit cluster concurrently; a synthesis agent integrates findings across clusters; a parallel adversarial review board (five lenses: architecture integrity, scope/simplicity, user-intent, backward-compat, risk) stress-tests the emerging recommendation; and a convergence agent writes `deliberation.md`. The calling skill presents this investigation summary to the user first, then asks only the questions the protocol could not resolve itself. The deliberation artifact is also consumed by the plan skill (Phase 1) as the approach anchor, so design decisions made during spec survive into implementation without re-derivation. This is a shared primitive wired into four calling skills: `spec`, `prd`, `small-change`, and `charter`; and consumed by `plan`.

**The core invariant:** Every question the user is asked must trace to a specific, citable finding in `deliberation.md` — and that traceability is *artifact-verifiable*, not merely instructed: each validated open question carries a stable ID (VOQ-N), and any question presented in brainstorm cites either a VOQ-N or a named deliberation section. Questions the protocol could resolve are resolved and recorded in §Answered by Investigation; questions it could not resolve are the only ones surfaced.

**Depth scales to the work.** The protocol runs at full depth where deep investigation is rational (spec, prd, charter) and at reduced depth for lightweight work (small-change), governed by a configurable depth policy (`full` / `lite` / `off`). The research basis for every design choice below — Boris Cherny, Sean Grove / SDD, Harper Reed, Karpathy's LLM Council, Addy Osmani, AWS Kiro/EARS, SCoT — and the decisions/divergences are recorded in `design-basis.md` (committed alongside this spec).

## In Scope

- New `agents/deliberation-coordinator.md` — Opus; Phase A: reads all injected artifacts (PRD sections, research.md digest, charter constraints, piece description), fires web research on genuine unknowns; returns investigation seed to the calling skill
- New `agents/deliberation-viability.md` — Opus; Phase B (dispatched N times in parallel, one per decision-unit cluster): enumerates ALL viable paths for its cluster — INCLUDING reuse/extend-existing-code paths surfaced from research.md, not only greenfield paths — and assigns VIABLE/NON-VIABLE with explicit reasoning + a concrete blocker for any NON-VIABLE verdict (EARS-style: no "seems hard"); returns per-cluster viability findings
- New `agents/deliberation-synthesis.md` — Opus; Phase C: integrates all per-cluster viability findings, checks cross-cluster path composition, documents conflicts; returns integrated recommendation
- New `agents/deliberation-lens.md` — Opus; Phase D (dispatched 5 times in parallel, one per lens): adversarially challenges the Phase C recommendation from a single lens (architecture-integrity | scope/simplicity | user-intent | backward-compat | risk); returns HOLDS or CONTESTED with specific reasoning
- New `agents/deliberation-convergence.md` — Opus; Phase E: synthesizes adversarial lens verdicts, finalizes the recommendation that survived review, generates validated-open-questions and answered-by-investigation lists, writes `deliberation.md`
- New `reference/deliberation-artifact.md` — single source of truth for artifact structure, marker contract, return contract (parallel to `reference/research-artifact.md`)
- `skills/spec/SKILL.md` — wire deliberation dispatch in Phase 2 pre-brainstorm setup (after research commit); rewrite step 1b to read from `deliberation.md` recommendation; enforce question gate
- `skills/prd/SKILL.md` — wire deliberation dispatch before piece-decomposition brainstorm
- `skills/small-change/SKILL.md` — wire deliberation dispatch before the focused brainstorm
- `skills/charter/SKILL.md` — wire deliberation dispatch before each charter-domain brainstorm (architecture, non-negotiables, coding-rules, etc.); investigation covers existing codebase patterns, industry standards for the project type, and per-domain rule viability
- `skills/plan/SKILL.md` — wire deliberation.md consumption in Phase 1 (after research.md read); emit `[DELIBERATION-CONSUMED: <recommendation>]` or `[DELIBERATION-ABSENT: no deliberation artifact]`; plan agent uses the recommendation as approach anchor
- `reference/brainstorm-procedure.md` — add deliberation artifact consumption rules (mandatory-block auto-skip logic)
- `reference/deliberation-depth.md` — new; defines the depth policy (`full` / `lite` / `off`), per-skill defaults, the `lite` phase profile, and the operator override contract
- `.spec-flow.yaml` — new optional `deliberation.depth` config key (and optional `deliberation.lenses`); absent key → per-skill default (full for spec/prd/charter, lite for small-change), preserving backward compatibility (NN-C-003)
- `agents/qa-spec.md` — new criteria: (a) deliberation structure check; (b) deliberation-grounding provenance check (VOQ-ID traceability)
- `docs/prds/exec-ready/specs/spec-preresearch/design-basis.md` — research provenance + decision records (already committed)
- FR-009 section added to `docs/prds/exec-ready/prd.md`; manifest coverage updated
- Plugin version bump to 5.8.0 (NN-C-009)

## Out of Scope / Non-Goals

- **Cross-piece deliberation caching** — if the same decision unit appears in multiple pieces, this piece does NOT reuse a prior deliberation; each piece's deliberation is independent and fresh.
- **Per-unit (individual) agent dispatch** — Phase B dispatches one agent per decision-unit CLUSTER, not one per individual unit; single-unit granularity is a future performance optimization.
- **True multi-model council** (different model architectures cross-reviewing, per Karpathy's LLM Council) — **considered and rejected** for this piece: adversarial review is a thinking task and NN-P-005 mandates Opus for thinking, so a non-Opus reviewer would violate the charter. Phase D achieves diversity via five *lenses* on Opus (dimension diversity) instead of multiple *models*. Rationale recorded in `design-basis.md` §D-1; revisit only if a charter carve-out for non-thinking "cross-check" review is added.
- **Removing the human approval gate** — the investigation-first protocol reduces question count; it does not remove spec/plan/PRD sign-off (NN-P-001).

## Requirements

### Functional Requirements

- FR-009-A: A shared Opus deliberation protocol (5-phase multi-agent orchestration) runs before the first user-facing brainstorm question in any of the four calling skills (spec, prd, small-change, charter). The calling skill dispatches agents through five phases in strict order and writes `deliberation.md` (via Phase E convergence agent). Calling skills present the investigation summary first; questions come second.
- FR-009-B: Per-decision-unit viability analysis: for each **decision unit** in the piece, a viability agent enumerates ALL viable paths (not bounded to 2–3), evaluates each with explicit reasoning, and assigns a VIABLE or NON-VIABLE verdict — with a concrete identified blocker required for any NON-VIABLE verdict (EARS-style discipline: no ambiguous "seems hard"/"should"/"may"). The enumerated paths MUST include any **reuse/extend-existing-code** options surfaced from research.md, not only greenfield paths. A **decision unit** is the per-skill analysis granularity: an FR for `spec`, a candidate piece / decomposition boundary for `prd`, a domain rule or principle for `charter`, and the change itself for `small-change`.
- FR-009-C: Cross-unit integration check: after per-unit analysis, the synthesis agent verifies that the VIABLE paths across all decision units compose into a coherent whole. Conflicts are documented explicitly and narrowed to composable paths; unresolved conflicts become validated open questions.
- FR-009-D: Triggered web research: when the coordinator encounters a genuine unknown not resolvable from injected context (codebase, PRD, charter), it searches the web for prior art, methodology, and comparable solutions. Web research does not fire for unknowns the codebase or PRD resolves. A genuine unknown is a question whose answer cannot be derived by reading the injected inputs (PRD sections, research.md if available, charter constraints). Design choices that the PRD or charter already resolve are NOT genuine unknowns and do not trigger web research.
- FR-009-E: Convergence: Phase E synthesizes the Phase D adversarial board verdicts into a final recommendation. The finalized recommendation is the path that survived adversarial review (revised if the board's CONTESTED verdicts required it); every point the board left CONTESTED-and-unresolved becomes a validated open question (with a stable VOQ-N ID); everything the protocol resolved itself is recorded in §Answered by Investigation. (This is distinct from FR-009-I, which specifies the board itself; FR-009-E specifies how its output is folded.)
- FR-009-F: Mandatory-block auto-skip: when deliberation concludes N/A for a spec brainstorm block (C-1 assumption audit, C-2 security, H-4 NFR sub-block, M-7 migration check) with logged reasoning in `deliberation.md`, the calling skill skips that block in the brainstorm. When deliberation cannot conclude N/A, the block runs as confirmation, not discovery — the calling skill presents deliberation's partial answer as a prefacing statement before the confirmation question (e.g., "Deliberation found: [deliberation's conclusion for this dimension]. Please confirm: is this correct for your piece?") rather than asking the question from scratch.
- FR-009-G: Plan skill consumption: the plan skill reads `deliberation.md` §Recommendation and §Viability Analysis in Phase 1 (after research.md consumption). It emits `[DELIBERATION-CONSUMED: <recommendation>]` inline before proceeding; the plan agent uses the recommendation as the approach anchor for implementation decomposition. When `deliberation.md` is absent, the skill emits `[DELIBERATION-ABSENT: no deliberation artifact]` and continues with current plan behavior unchanged.
- FR-009-H: Grouped parallel FR-cluster viability analysis: the calling skill identifies FR clusters (related FRs grouped by functional similarity or dependency), dispatches one viability agent per cluster in parallel (Phase Group pattern), and dispatches a synthesis agent only after all cluster agents complete (barrier). A piece with a single FR dispatches one viability agent; no minimum cluster count is required.
- FR-009-I: Multi-lens adversarial review board: after Phase C synthesis, the calling skill dispatches parallel adversarial lens agents, each with a distinct lens — (1) architecture integrity: does the recommendation follow the project's architectural principles and charter constraints?; (2) scope/simplicity: is this the simplest solution? any scope creep or under-scope?; (3) user-intent alignment: does the recommendation serve the stated PRD user story?; (4) backward-compat: does the recommendation break any existing behavior or contract?; (5) risk: what are the key failure modes, hidden assumptions, and external dependencies? At `full` depth all five lenses run; at `lite` depth a configured subset runs (default: scope/simplicity + risk). All lens agents run on Opus — this is a single-model, multi-lens board, NOT a multi-model council (see Out of Scope and `design-basis.md` §D-1). Each agent returns HOLDS or CONTESTED with specific reasoning. Folding of verdicts into validated open questions is specified in FR-009-E.
- FR-009-J: Depth policy (complexity gate): the deliberation protocol runs at a depth determined by `.spec-flow.yaml` `deliberation.depth` (or per-skill default when absent): `full` (all 5 phases, all 5 lenses — default for spec/prd/charter), `lite` (Phase A + a single Phase B viability pass over the whole piece + a reduced Phase D of the configured lens subset + Phase E; Phase C auto-skipped when ≤1 cluster — default for small-change), or `off` (skip deliberation entirely; emit `[DELIBERATION-SKIPPED: depth=off]` and fall back to current brainstorm behavior). An operator may override the depth at invocation. The selected depth is recorded in `deliberation.md` §Investigation Summary (or, for `off`, in the emitted marker).

### Non-Functional Requirements

- NFR-009-1: Each deliberation agent (coordinator, viability, synthesis, lens, convergence) runs in a fresh, isolated context (no brainstorm history). Each agent's return to the calling skill is a structured digest ≤2K tokens; `deliberation.md` on disk (written by Phase E) may be richer (NN-C-008, mirrors NFR-001).
- NFR-009-2: If the deliberation protocol fails on any of the 5 fatal triggers enumerated in AC-12 (Phase A BLOCKED, Phase C BLOCKED, Phase E BLOCKED, deliberation.md missing/empty after Phase E, git commit fails), the calling skill emits `[DELIBERATION-UNAVAILABLE: <reason>]` non-blocking and falls back to current brainstorm behavior. Phase B and Phase D partial failures are non-fatal (AC-12) and do not emit UNAVAILABLE. The fallback is silent beyond the emitted marker (NN-C-003, mirrors NFR-001's UNAVAILABLE path).
- NFR-009-3: All changes are additive and backward-compatible (NN-C-003). Pieces whose skills do not dispatch the deliberation protocol run unchanged; the new `.spec-flow.yaml` `deliberation.depth` key is optional (absent → per-skill default); the `off` depth and the UNAVAILABLE fallback both reproduce pre-5.8.0 brainstorm behavior; no existing config keys or skill invocation patterns are broken.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-001 (version/marketplace sync): plugin.json and marketplace.json must reflect the same version (5.8.0) after this piece ships; enforced by AC-15's diff check.
- NN-C-002 (no runtime deps): All five deliberation agent files are `.md` files; `reference/deliberation-artifact.md` and `reference/deliberation-depth.md` are `.md` files; the `.spec-flow.yaml` `deliberation.depth` key is plain config. No binaries, no packages, no Docker.
- NN-C-003 (backward compat): All wiring is additive. `[DELIBERATION-UNAVAILABLE]` fallback preserves current behavior on any phase failure. Existing skill invocation patterns unchanged. NN-C-003 also governs the `[DELIBERATION-UNAVAILABLE]` fallback — calling skills fall back to current brainstorm behavior on any agent failure, preserving backward compatibility.
- NN-C-004 (bare agent name): All five deliberation agent files use bare names — `name: deliberation-coordinator`, `name: deliberation-viability`, `name: deliberation-synthesis`, `name: deliberation-lens`, `name: deliberation-convergence` — no plugin prefix.
- NN-C-006 (no destructive ops): git operations in this piece are additive commits to the piece branch, explicitly excluded from NN-C-006's destructive-operation definition. No git reset/rm/push --force/branch -D operations are performed.
- NN-C-007 (CHANGELOG format): CHANGELOG.md receives a new `## [5.8.0]` section in Keep a Changelog format before merge (enforced by AC-15).
- NN-C-008 (self-contained agent prompts): Each deliberation agent's prompt is assembled by the calling skill with all injected inputs for that phase. No deliberation agent assumes brainstorm history or prior session state.
- NN-C-009 (version bump): All version-bearing files bumped to 5.8.0 in the same piece commit series.

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-001 (human approval gate preserved): The investigation-first protocol reduces the question count and improves question quality; it does not remove spec/plan/PRD sign-off. The brainstorm still concludes with human review and sign-off.
- NN-P-003 (execute is operator-invoked only): No change to execute invocation. This piece touches spec/prd/small-change/charter/plan only.
- NN-P-005 (thinking on Opus): All five deliberation agent files (`deliberation-coordinator`, `deliberation-viability`, `deliberation-synthesis`, `deliberation-lens`, `deliberation-convergence`) run on Opus; calling skills (Sonnet-tier coordinators) dispatch each as an isolated Opus sub-agent per model placement policy. CR-001 enforces `model: opus` frontmatter on all five files.

### Coding Rules Honored

- CR-001 (agent frontmatter): All five deliberation agent files have YAML frontmatter with `name: deliberation-<role>`, `description:` (trigger criteria + dispatch contract for that phase), `model: opus`.
- CR-002 (skill frontmatter): No new skill files. Existing skill frontmatter is preserved.
- CR-008 (separation of concerns — thin orchestrators, narrow executors): Each deliberation agent executes one narrow task (its single phase). The calling skills orchestrate (dispatch phases, apply barriers, commit state). No deliberation agent dispatches sub-agents; no skill implements phase logic directly.
- CR-009 (markdown heading hierarchy): `deliberation.md` uses H2 for top-level sections, H3 for subsections. `reference/deliberation-artifact.md` uses the same structural convention as `reference/research-artifact.md`.

## Acceptance Criteria

AC-1: Given a spec/prd/small-change/charter skill is invoked for any piece, When the pre-brainstorm setup runs, Then all five deliberation agent files exist (`deliberation-coordinator.md`, `deliberation-viability.md`, `deliberation-synthesis.md`, `deliberation-lens.md`, `deliberation-convergence.md`) and the calling skill's Phase 2 pre-brainstorm setup contains a deliberation orchestration block that dispatches Phase A with all required injected inputs (PRD sections, piece description, research.md if available, charter constraints).
  Independent Test: `ls plugins/spec-flow/agents/deliberation-{coordinator,viability,synthesis,lens,convergence}.md` all exit 0; each frontmatter contains `model: opus` and a `name: deliberation-<role>` entry; `grep -n 'deliberation-coordinator' plugins/spec-flow/skills/spec/SKILL.md` returns a dispatch line in the Phase 2 pre-brainstorm section. (No live dispatch required — all checks are file-system and grep assertions.)

AC-2: Given the deliberation protocol is running at `full` depth, When the calling skill executes it, Then the skill dispatches five phases in strict order — Phase A (coordinator: read-all artifacts + web research) → Phase B (parallel: per-decision-unit-cluster viability, one agent per cluster, barrier) → Phase C (synthesis: cross-cluster integration) → Phase D (parallel: five adversarial lens agents, barrier) → Phase E (convergence: final recommendation + deliberation.md write) — and does not emit validated open questions until Phase E convergence. (Depth `lite`/`off` variants are specified in AC-19.)
  Independent Test: `grep -n 'Phase A\|Phase B\|barrier\|Phase C\|Phase D\|Phase E' plugins/spec-flow/skills/spec/SKILL.md` returns the deliberation orchestration block with Phase A → B (barrier) → C → D (barrier) → E sequencing in the pre-brainstorm setup section; `ls plugins/spec-flow/agents/deliberation-{coordinator,viability,synthesis,lens,convergence}.md` all exit 0. (No live run required — all checks are static file and grep assertions; deliberation.md structure is verified independently by AC-7.)

AC-3: Given Phase B viability runs for a piece with N decision units, When analysis completes, Then `deliberation.md` §Viability Analysis contains one entry per decision unit; each entry lists all viable paths the viability agent found (not bounded to 2–3) — including any reuse/extend-existing-code path surfaced from research.md — with VIABLE/NON-VIABLE verdict, explicit reasoning per path, and a concrete identified blocker for every NON-VIABLE verdict.
  Independent Test: For a test piece with 3 decision units, `deliberation.md` has 3 per-unit entries each containing ≥1 path with verdict + reasoning; any NON-VIABLE path names a concrete blocker (no bare "seems hard").

AC-4: Given Phase A runs, When the coordinator encounters a genuine unknown not resolvable from injected context, Then it invokes WebSearch/WebFetch to find prior art, methodology, or comparable solutions, and the findings are cited in the relevant per-unit entry or Investigation Summary.
  When the coordinator can resolve the unknown from injected context, Then web research does not fire.
  Independent Test: deliberation.md cites at least one external source when an unknown was encountered; no external sources cited when PRD + codebase fully resolve the piece.

AC-5: Given Phase C integration runs after Phase B analysis, When the per-unit VIABLE paths do not compose (conflict detected), Then `deliberation.md` §Integration Check documents the conflict explicitly and flags it as a validated open question.
  When per-unit paths compose cleanly, Then the section confirms coherence with brief reasoning.
  Independent Test: A test piece with a known cross-unit conflict produces a flagged entry in §Integration Check.

AC-6: Given Phase D adversarial review runs after Phase C synthesis, When the lens agents challenge the Phase C recommendation, Then any CONTESTED finding is documented in `deliberation.md` §Adversarial Review with the specific lens, the challenge, and whether it becomes a validated open question. When all lenses return HOLDS, Then the section records what was challenged and why it held.
  Independent Test: §Adversarial Review is non-empty in every deliberation.md; CONTESTED findings from Phase D that survive Phase E appear in §Validated Open Questions.

AC-7: Given Phase E convergence completes successfully, When it writes the artifact, Then `deliberation.md` is written to `docs/prds/<prd-slug>/specs/<piece-slug>/deliberation.md` on the piece branch with exactly 7 H2 sections in order: Investigation Summary, Viability Analysis, Integration Check, Adversarial Review, Recommendation, Validated Open Questions, Answered by Investigation; and `reference/deliberation-artifact.md` is the single source of truth for this structure (agents and skills cite it, never restate it).
  Independent Test: `ls worktrees/exec-ready-spec-preresearch/docs/prds/exec-ready/specs/spec-preresearch/deliberation.md` exits 0; grep for all 7 H2 headings passes; `ls plugins/spec-flow/reference/deliberation-artifact.md` exits 0.

AC-8: Given the spec skill is invoked for a piece and deliberation succeeds, When the brainstorm begins, Then the first user-facing message is the investigation presentation (Investigation Summary + Recommendation + count of validated open questions), NOT a design question; and brainstorm questions are restricted to the §Validated Open Questions list. Each question presented MUST carry a citation to its source — either a `VOQ-N` ID (for a listed validated open question) or a named deliberation section (for an emergent follow-up, e.g., "Following deliberation §Integration Check: ..."). The spec skill's Phase 2 instructions must encode this citation requirement.
  Independent Test: `skills/spec/SKILL.md` Phase 2 step 1b reads from deliberation.md recommendation field; `grep -n 'VOQ\|citation' plugins/spec-flow/skills/spec/SKILL.md` returns the VOQ-ID / named-section citation requirement in the Phase 2 question-gate instructions.

AC-9: Given the PRD skill is invoked to create or update a PRD, When the pre-brainstorm setup runs, Then the 5-phase deliberation protocol runs before piece-decomposition brainstorm starts; the PRD brainstorm first message includes the investigation summary.
  Independent Test: `skills/prd/SKILL.md` contains a deliberation orchestration block (grep `deliberation-coordinator` in the pre-brainstorm section).

AC-10: Given the small-change skill is invoked, When the pre-brainstorm setup runs, Then the 5-phase deliberation protocol runs before the 5–8 question focused brainstorm; the first message includes the investigation summary.
  Independent Test: `skills/small-change/SKILL.md` contains a deliberation orchestration block (grep `deliberation-coordinator`).

AC-10b: Given the charter skill is invoked to author or update a charter domain (any of: architecture, non-negotiables, coding-rules, tools, processes, flows), When the pre-brainstorm setup runs, Then the 5-phase deliberation protocol runs with context including: existing codebase patterns (from research or L-10 scan), the domain being chartered, and any related industry-standard rules the coordinator agent can find via web research. The first charter brainstorm message includes the investigation summary.
  Independent Test: `skills/charter/SKILL.md` contains a deliberation orchestration block (grep `deliberation-coordinator`); a manual smoke test of `/spec-flow:charter` on a test project shows the investigation summary before the first Socratic question.

AC-11: Given deliberation concludes a mandatory spec block is N/A with logged reasoning (e.g., "security: doc-as-code piece, no external data handling"), When the spec brainstorm reaches that block (C-1, C-2, H-4 NFR sub-block, M-7 migration check), Then the block is auto-skipped in the brainstorm; the auto-skip is non-silent: the calling skill emits a one-line note to the user stating the block name and N/A rationale; the auto-skip rationale is also visible in deliberation.md §Answered by Investigation.
  When deliberation cannot conclude N/A for a block, Then the block runs as confirmation, not open discovery — the calling skill presents deliberation's partial answer as a prefacing statement before the confirmation question (e.g., "Deliberation found: [deliberation's conclusion for this dimension]. Please confirm: is this correct for your piece?") rather than asking the question from scratch.
  Independent Test: A doc-as-code test piece's deliberation.md §Answered by Investigation contains an entry for each auto-skipped block with N/A rationale; the skill emits a one-line note for each auto-skipped block visible in the brainstorm output.

AC-12: Given the deliberation protocol fails at any phase, When the calling skill detects failure, Then behavior is:
  Fatal (5 triggers — skill emits `[DELIBERATION-UNAVAILABLE: <phase>-<reason>]` and falls back to current brainstorm behavior): (a) Phase A STATUS: BLOCKED; (b) Phase C STATUS: BLOCKED; (c) Phase E STATUS: BLOCKED; (d) deliberation.md missing or zero-length after Phase E completes; (e) git commit of deliberation.md fails.
  Non-fatal (2 partial cases — skill proceeds with available findings): (f) Phase B some-cluster BLOCKED: skill proceeds to Phase C with remaining cluster outputs; (g) Phase D any/all lens BLOCKED: skill proceeds to Phase E with available verdicts; Phase E notes "adversarial review unavailable" in §Adversarial Review; no UNAVAILABLE marker emitted.
  The fallback on fatal triggers is indistinguishable from pre-5.8.0 spec behavior.
  Independent Test: Simulate each of the 5 fatal triggers; verify `[DELIBERATION-UNAVAILABLE]` is emitted and brainstorm proceeds normally. Simulate Phase B partial failure (one cluster blocked); verify Phase C proceeds with remaining findings. Simulate Phase D all-BLOCKED; verify Phase E runs and §Adversarial Review notes unavailability.

AC-13: Given `qa-spec` reviews a spec, When `deliberation.md` is present on the piece branch, Then qa-spec checks: (a) `deliberation.md` contains all 7 required H2 sections in order; (b) every §Validated Open Questions entry carries a stable `VOQ-N` ID; (c) `[DELIBERATION-UNAVAILABLE]`/`[DELIBERATION-SKIPPED]` if present in the spec artifact is treated as informational (not must-fix). When `deliberation.md` is absent (UNAVAILABLE/SKIPPED path), qa-spec notes this as informational only and does not add a must-fix finding. qa-spec does NOT add a transcript-behavior check (brainstorm transcripts are not reviewable from the spec artifact).
  Independent Test: `agents/qa-spec.md` contains a criterion entry that verifies `deliberation.md` structure (all 7 H2 sections) AND that §Validated Open Questions entries are VOQ-ID-tagged — not transcript behavior.

AC-14: Given the spec is approved and the piece ships, When the plan skill runs, Then `docs/prds/exec-ready/prd.md` contains an FR-009 section with Statement, Priority, User Stories, and Acceptance Criteria consistent with this spec; and `manifest.yaml` coverage block reflects the new FR-009.
  Independent Test: `grep "FR-009" docs/prds/exec-ready/prd.md` returns the FR-009 section heading; coverage percentage in manifest is updated.

AC-15: Given any file under `plugins/spec-flow/` is modified by this piece, When the piece is committed, Then `plugins/spec-flow/.claude-plugin/plugin.json`, root `plugin.json` (if present), `.claude-plugin/marketplace.json`, and `plugins/spec-flow/CHANGELOG.md` all reflect version `5.8.0`.
  Independent Test: `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json)` produces no output; CHANGELOG has `## [5.8.0]` heading.

AC-16: Given the plan skill is invoked for a piece, When Phase 1 loads context, Then the plan skill reads `deliberation.md` §Recommendation and §Viability Analysis (if the artifact exists on the piece branch); emits `[DELIBERATION-CONSUMED: <recommendation>]` inline before proceeding; and the plan prompt uses the recommendation as the approach anchor. When `deliberation.md` is absent, the skill emits `[DELIBERATION-ABSENT: no deliberation artifact]` and continues with current plan behavior unchanged.
  Independent Test: `grep -n 'DELIBERATION-CONSUMED\|DELIBERATION-ABSENT' plugins/spec-flow/skills/plan/SKILL.md` returns at least two lines; those line numbers fall within the Phase 1 / context-load section of the file (not in a comment block or later phase). Implementer: mark the insertion point in SKILL.md with a `## Phase 1` or equivalent heading that the grep line-number check can bound against.

AC-17: Given the pre-brainstorm deliberation protocol runs for a piece with N decision units, When the calling skill identifies decision-unit clusters, Then it dispatches Phase B viability agents in parallel (one per cluster); the Phase C synthesis agent dispatches only after all Phase B agents complete (barrier); the coordinator (Phase A) and convergence agent (Phase E) run sequentially before and after the parallel phases. When the piece has a single decision unit, exactly one viability agent is dispatched (no minimum cluster count).
  Independent Test: `ls plugins/spec-flow/agents/deliberation-viability.md` exits 0; frontmatter contains `name: deliberation-viability`, `model: opus`; the calling skill's deliberation orchestration section shows Phase B as a parallel dispatch block with a barrier before Phase C.

AC-18: Given Phase C synthesis completes and depth is `full`, When the adversarial review board (Phase D) runs, Then the calling skill dispatches exactly five parallel adversarial lens agents (architecture-integrity, scope/simplicity, user-intent, backward-compat, risk), all on Opus; each agent returns HOLDS or CONTESTED with specific reasoning; the Phase E convergence agent synthesizes all five verdicts per FR-009-E; any CONTESTED verdict not resolved in Phase E becomes a VOQ-tagged validated open question in `deliberation.md`. (At `lite` depth the configured lens subset runs — default 2; see AC-19.)
  Independent Test: `ls plugins/spec-flow/agents/deliberation-lens.md` exits 0; frontmatter contains `name: deliberation-lens`, `model: opus`; the body contains a lens parameter slot (e.g., `{lens}` or equivalent injection pattern); the calling skill's Phase D orchestration block lists exactly 5 lens labels for full depth.

AC-19: Given the depth policy governs protocol cost, When a calling skill resolves depth, Then it reads `.spec-flow.yaml` `deliberation.depth` (or applies the per-skill default when the key is absent: `full` for spec/prd/charter, `lite` for small-change); and:
  `full` → all 5 phases, all 5 lenses (AC-2).
  `lite` → Phase A + a single Phase B viability pass over the whole piece + Phase C auto-skipped when ≤1 cluster + a reduced Phase D running only the configured lens subset (default: scope/simplicity + risk) + Phase E.
  `off` → no deliberation; the skill emits `[DELIBERATION-SKIPPED: depth=off]` and runs the current (pre-5.8.0) brainstorm unchanged.
  An operator may override depth at invocation. The resolved depth is recorded in `deliberation.md` §Investigation Summary (or in the `[DELIBERATION-SKIPPED]` marker for `off`).
  Independent Test: `ls plugins/spec-flow/reference/deliberation-depth.md` exits 0 and defines the `full`/`lite`/`off` profiles + per-skill defaults; `grep -n 'lite' plugins/spec-flow/skills/small-change/SKILL.md` shows small-change's default-lite resolution; `grep -n 'DELIBERATION-SKIPPED' plugins/spec-flow/reference/deliberation-depth.md` returns the off-path marker contract.

AC-20: Given question grounding must be artifact-verifiable (not merely instructed), When deliberation succeeds, Then `deliberation.md` §Validated Open Questions assigns a stable `VOQ-N` ID to each entry, and `qa-spec` carries a grounding-provenance criterion: it confirms the spec skill's Phase 2 instructions require every brainstorm question to cite a `VOQ-N` ID or a named deliberation section (per AC-8), and that §Validated Open Questions entries are VOQ-ID-tagged (per AC-13). qa-spec treats absence of these as a must-fix when `deliberation.md` is present; it adds no finding on the UNAVAILABLE/SKIPPED path.
  Independent Test: `grep -n 'VOQ' plugins/spec-flow/reference/deliberation-artifact.md` shows the VOQ-N ID requirement in the §Validated Open Questions contract; `grep -n 'VOQ\|grounding' plugins/spec-flow/agents/qa-spec.md` returns the provenance criterion.

## Technical Approach

### Deliberation protocol architecture

The deliberation protocol is a 5-phase multi-agent orchestration dispatched by the calling skill. CR-008 governs: the calling skill orchestrates (dispatches, sequences, commits state); each deliberation agent executes one narrow task. No deliberation agent dispatches sub-agents.

**Five agent files (each a structural clone of `agents/research.md` in frontmatter shape):**
All have: `name: deliberation-<role>`, `description:` (trigger criteria + dispatch contract), `model: opus`, `STATUS: OK | BLOCKED` return, ≤2K digest return to calling skill.

---

**Phase A — Coordinator (`agents/deliberation-coordinator.md`, single dispatch):**
Reads all injected inputs: PRD sections, research.md digest (if STATUS: OK), charter constraints, piece description, manifest entry. Identifies genuine unknowns — questions not answerable from injected inputs. For each genuine unknown: fires WebSearch/WebFetch to find prior art, methodology, comparable implementations. If no genuine unknowns: explicitly states "no unknowns requiring web research found" and completes without web calls. Returns investigation seed (structured summary of inputs + web findings) to calling skill.

---

**Phase B — Decision-unit-cluster viability (`agents/deliberation-viability.md`, parallel dispatch, one per cluster):**
The calling skill identifies **decision-unit clusters** (group by functional similarity or dependency — units are FRs for `spec`, candidate pieces for `prd`, domain rules for `charter`, the change for `small-change`). It dispatches one `deliberation-viability` agent per cluster in parallel. Each agent receives: the Phase A investigation seed, its assigned cluster, charter constraints. It enumerates ALL viable paths for its cluster (no pre-set cap) — **including reuse/extend-existing-code paths surfaced from research.md, not only greenfield** — evaluates each against charter constraints, codebase conventions, and PRD goals, and assigns VIABLE or NON-VIABLE with explicit reasoning. A path is NON-VIABLE only if a concrete blocker is identified (EARS-style: not a bare "seems hard"). Returns per-cluster viability findings. Calling skill applies a barrier: dispatches Phase C only after all Phase B agents complete.

---

**Phase C — Synthesis (`agents/deliberation-synthesis.md`, single dispatch):**
Receives all Phase B per-cluster viability findings from the calling skill. Checks cross-cluster integration: for each pair of decision-unit clusters with VIABLE paths, checks whether the paths compose. Conflicts documented explicitly. Narrows the VIABLE set to composable paths. Produces an integrated recommendation. Unresolvable cross-cluster conflicts are flagged as validated open questions. Returns integrated recommendation to calling skill.

---

**Phase D — Multi-lens adversarial review board (`agents/deliberation-lens.md`, parallel dispatch, 5 instances at `full` depth):**
The calling skill dispatches `deliberation-lens` agents in parallel — all on Opus — each receiving the Phase C recommendation and a single lens label injected into the prompt. This is a **single-model, multi-lens** board (dimension diversity), deliberately NOT a multi-model council (model diversity); see Out of Scope and `design-basis.md` §D-1. The five lenses:
1. **Architecture integrity** — does the recommendation follow the project's charter architectural principles?
2. **Scope/simplicity** — is this the simplest solution? any scope creep or under-scope?
3. **User-intent alignment** — does the recommendation serve the PRD user story?
4. **Backward-compat** — does the recommendation break any existing behavior or contract?
5. **Risk** — what are the key failure modes, hidden assumptions, and external dependencies?

At `full` depth all five run; at `lite` depth only the configured subset runs (default: scope/simplicity + risk). Each agent returns HOLDS or CONTESTED with specific reasoning per lens. Calling skill applies a barrier: dispatches Phase E only after all dispatched Phase D agents complete. Verdict-folding is Phase E's job (FR-009-E).

---

**Phase E — Convergence (`agents/deliberation-convergence.md`, single dispatch):**
Receives Phase C recommendation + all Phase D adversarial verdicts from the calling skill. Synthesizes: finalizes the recommendation (or revises if adversarial verdicts require), generates the validated-open-questions list — **each entry tagged with a stable `VOQ-N` ID** (only questions that survived adversarial review without resolution), generates the answered-by-investigation list, records the resolved depth in §Investigation Summary, writes `deliberation.md`. Returns ≤2K digest to calling skill. The calling skill commits `deliberation.md` and proceeds to brainstorm.

### Skill wiring (same pattern for all four call sites)

In each calling skill's pre-brainstorm setup (after any research dispatch+commit):

```
0. Resolve depth: read .spec-flow.yaml deliberation.depth, else per-skill default
   (full for spec/prd/charter, lite for small-change); apply any operator override.
   On depth=off → emit [DELIBERATION-SKIPPED: depth=off], run current brainstorm, STOP here.

1. Dispatch Phase A (coordinator): inject PRD sections, piece description,
   research.md digest (if STATUS: OK), charter constraints.
   On STATUS: BLOCKED → emit [DELIBERATION-UNAVAILABLE: phase-A-blocked], fall back.

2. Identify decision-unit clusters (group by functional similarity/dependency).
   Decision unit = FR (spec) / candidate piece (prd) / domain rule (charter) / the change (small-change).
   At lite depth: treat the whole piece as a single cluster.

3. Dispatch Phase B (parallel viability, one agent per cluster): inject Phase A
   investigation seed + per-cluster unit assignment + charter constraints.
   Each agent must enumerate reuse/extend-existing paths from research.md, not only greenfield.
   Barrier: wait for all Phase B agents to complete.
   On any Phase B STATUS: BLOCKED → log the blocked cluster; proceed with
   remaining cluster outputs (partial is acceptable for Phase C).

4. Dispatch Phase C (synthesis): inject all Phase B findings.
   (Skip when ≤1 cluster — single-cluster output is already integrated.)
   On STATUS: BLOCKED → emit [DELIBERATION-UNAVAILABLE: phase-C-blocked], fall back.

5. Dispatch Phase D (parallel adversarial): inject Phase C recommendation + lens label
   per agent. full=5 lenses, lite=configured subset (default scope/simplicity + risk).
   Barrier: wait for all dispatched Phase D agents.
   On any/all Phase D STATUS: BLOCKED → log the blocked lens(es); proceed to Phase E
   with available verdicts. Phase D all-BLOCKED is non-fatal (same pattern as Phase B
   partial failure); Phase E notes "adversarial review unavailable" in §Adversarial Review.

6. Dispatch Phase E (convergence): inject Phase C recommendation + all Phase D verdicts
   (may be empty if Phase D all-BLOCKED). Phase E tags each validated open question VOQ-N
   and records resolved depth in §Investigation Summary.
   On STATUS: OK and deliberation.md present + non-empty: commit deliberation.md.
   On STATUS: BLOCKED or deliberation.md missing/empty:
     emit [DELIBERATION-UNAVAILABLE: phase-E-blocked], fall back.

7. Brainstorm first message: present Investigation Summary + Recommendation +
   "I have N validated questions for you."
8. Questions: draw from §Validated Open Questions in order; each question cites its
   VOQ-N ID (or a named deliberation section for an emergent follow-up).
```

The `reference/deliberation-artifact.md` contract defines the exact path, 7-section structure, VOQ-N ID requirement, marker triggers, and STATUS line contract (parallel to `reference/research-artifact.md`). The `reference/deliberation-depth.md` contract defines the full/lite/off profiles, per-skill defaults, and override behavior.

### Depth policy (complexity gate)

The operator concern is that the full protocol — 8+ Opus dispatches (coordinator + N viability + synthesis + 5 lens + convergence) plus web research — is rational for spec/prd/charter but disproportionate for a one-line small-change. `reference/deliberation-depth.md` defines three profiles:

| Depth | Phases run | Lenses | Default for | Cost |
|---|---|---|---|---|
| `full` | A → B(parallel) → C → D(parallel) → E | 5 | spec, prd, charter | highest (deep investigation where it belongs) |
| `lite` | A → B(single pass) → [C skipped if ≤1 cluster] → D(subset) → E | 2 (scope/simplicity + risk) | small-change | ~3–4 dispatches |
| `off` | none — `[DELIBERATION-SKIPPED: depth=off]` + current brainstorm | 0 | (operator opt-out only) | zero |

Resolution order: explicit operator override → `.spec-flow.yaml` `deliberation.depth` (+ optional `deliberation.lenses`) → per-skill default. The key is optional; absence applies the per-skill default, so existing configs are unbroken (NN-C-003). The chosen depth is recorded in `deliberation.md` §Investigation Summary (or the SKIPPED marker) so a reviewer can see what depth produced the artifact. This directly honors "spec/prd time is where deep investigation is rational — but not at full depth every time."

### Plan skill consumption

In `skills/plan/SKILL.md` Phase 1 context load (after research.md read and `[RESEARCH-CONSUMED]` emit):

```
Read deliberation.md §Recommendation and §Viability Analysis from the piece branch.
On file present and non-empty:
  Emit [DELIBERATION-CONSUMED: <recommendation-one-liner>]
  Plan agent prompt includes: "Deliberation recommendation: <recommendation>"
On file absent or zero-length:
  Emit [DELIBERATION-ABSENT: no deliberation artifact]
  Plan proceeds with current behavior (research.md as primary context)
```

The `[DELIBERATION-CONSUMED]` / `[DELIBERATION-ABSENT]` pattern mirrors `[RESEARCH-CONSUMED]` / `[RESEARCH-ABSENT]` — same marker contract, additive consumption, non-blocking on absence. The plan agent does not re-derive the approach; it decomposes the recommended path into phases.

### Mandatory-block skip logic

The calling skill reads `deliberation.md` §Answered by Investigation before each mandatory block. If the block's dimension (security / NFRs / migration / assumptions) appears in §Answered by Investigation with an N/A rationale: skip the block, emit a one-line note to the user ("Security: auto-skipped — deliberation concluded N/A: [reason]"). If the dimension does NOT appear in §Answered by Investigation: run the block starting from deliberation's partial answer as the seed, not from scratch.

**Amendment to C-2 "never silently skip" rule (brainstorm-procedure.md):** This piece amends the C-2 Security Sub-Block's "never silently skip it" instruction in `reference/brainstorm-procedure.md`. Under the investigation-first protocol, the C-2 block (and other mandatory blocks) may be auto-skipped ONLY when (a) deliberation explicitly concludes N/A with reasoning logged in §Answered by Investigation AND (b) the auto-skip rationale is surfaced to the user as a one-line note. "Auto-skip" is not "silent skip" — the user sees the block name and N/A rationale. `reference/brainstorm-procedure.md` must be updated in Phase implementation to reflect this amendment.

### deliberation.md structure (7 H2 sections, fixed order)

```markdown
## Investigation Summary
## Viability Analysis
## Integration Check
## Adversarial Review
## Recommendation
## Validated Open Questions
## Answered by Investigation
```

`reference/deliberation-artifact.md` specifies the exact subsection format for Viability Analysis (one entry per **decision unit**, markdown table of paths + verdicts, with reuse/extend-existing paths flagged) and the exact marker contract. The seven section names are stable across all four calling skills; only the unit each Viability Analysis entry represents differs by skill: an FR for `spec`, a candidate piece / decomposition boundary for `prd`, a domain rule or principle for `charter`, the change itself for `small-change`. §Validated Open Questions entries each carry a stable `VOQ-N` ID so brainstorm questions and qa-spec can cite them.

### FR-009 content to write into prd.md (AC-14)

The implementer writes exactly the following content as the FR-009 section in `docs/prds/exec-ready/prd.md`:

- **Statement:** One-paragraph summary of the investigation-first protocol covering: (1) the 5-phase multi-agent deliberation protocol (coordinator, parallel per-decision-unit-cluster viability agents, synthesis, parallel single-model multi-lens adversarial board, convergence); (2) four calling skills (spec, prd, small-change, charter) with a configurable depth policy (full/lite/off); (3) plan skill consumption of deliberation.md as the approach anchor; (4) the deliberation.md artifact structure with artifact-verifiable question grounding (VOQ IDs). The summary must convey: (a) the protocol runs before any user-facing question; (b) it executes five phases, two of which are parallel with barriers (Phase B and Phase D); (c) the output is a structured deliberation.md; (d) calling skills present the investigation summary first and only ask questions the protocol could not resolve, each traceable to a finding; (e) the plan skill consumes the recommendation so design decisions survive into implementation.
- **Priority:** P0
- **User Story:** "As a pipeline operator, I want the spec/prd/charter/small-change skills to investigate the problem space before asking any questions, and for the plan skill to build on that investigation, so that every question I'm asked is grounded in actual findings and implementation follows the approved design approach without re-deriving it."
- **Acceptance Criteria:** Cross-reference ACs from this spec (AC-1 through AC-20) as the full AC set for FR-009.

## Testing Strategy

This is a doc-as-code piece (markdown + YAML changes). No test runner (charter-tools: markdown/JSON/YAML/bash only). Verification:
- Structural lint: grep for required H2 sections in new `.md` files
- qa-spec adversarial review of this spec itself
- qa-plan adversarial review of the resulting plan
- Review-board (8-agent) before merge
- Manual smoke: run `/spec-flow:spec` on a scratch piece, verify deliberation protocol runs (all 5 phases), check `deliberation.md` has all 7 H2 sections, verify brainstorm starts with investigation summary

Branch-enumeration ACs for skill-wiring conditionals:
- AC-12 enumerates all 5 fatal UNAVAILABLE triggers + 2 partial (Phase B and Phase D) failure branches (each branch verified)
- AC-11 enumerates N/A vs confirmation branch (both verified)
- AC-4 enumerates web-fires vs web-skips branch (both verified)
- AC-19 enumerates the full / lite / off depth branches (each verified; off-path SKIPPED marker + small-change lite default)

## Integration Coverage

- `agents/deliberation-coordinator.md` + `agents/deliberation-viability.md` + `agents/deliberation-synthesis.md` + `agents/deliberation-lens.md` + `agents/deliberation-convergence.md` → `skills/spec/SKILL.md` (5-phase protocol dispatched from Phase 2 pre-brainstorm setup); inside: all 5 deliberation agents + spec skill; doubled externals: WebSearch/WebFetch (invoked by coordinator agent on genuine-unknown path; contract: returns relevant search results), git commit (writing deliberation.md to piece branch after Phase E; contract: file written successfully); AC-1, AC-2, AC-8, AC-17, AC-18
- same 5-agent protocol → `skills/prd/SKILL.md` (dispatched before piece-decomposition brainstorm); inside: all 5 deliberation agents + prd skill; doubled externals: WebSearch/WebFetch, git commit (same contract); AC-9
- same 5-agent protocol → `skills/small-change/SKILL.md` (dispatched before focused brainstorm); inside: all 5 deliberation agents + small-change skill; doubled externals: WebSearch/WebFetch, git commit (same contract); AC-10
- same 5-agent protocol → `skills/charter/SKILL.md` (dispatched before each charter-domain brainstorm); inside: all 5 deliberation agents + charter skill; doubled externals: WebSearch/WebFetch, git commit (same contract); AC-10b
- `deliberation.md` artifact → `skills/plan/SKILL.md` (consumed during Phase 1 context load, after research.md read); inside: plan skill + deliberation artifact reader; doubled externals: git read (reading deliberation.md from piece branch; contract: file present → [DELIBERATION-CONSUMED] emitted, file absent → [DELIBERATION-ABSENT] emitted); AC-16
- `.spec-flow.yaml` `deliberation.depth` + `reference/deliberation-depth.md` → all four calling skills (depth resolved at step 0 of pre-brainstorm setup); inside: depth-resolution logic + the four skills; doubled externals: config read (`.spec-flow.yaml`; contract: key present → resolved depth, key absent → per-skill default); AC-19

## Explicitly Out of Scope / Deferred

- **Cross-piece deliberation caching:** reusing a prior deliberation if the same decision unit appears in a later piece — each piece's deliberation is independent and fresh.
- **Per-unit (individual) agent dispatch:** Phase B dispatches one agent per decision-unit CLUSTER, not one per individual unit; single-unit granularity is a future performance optimization when piece unit counts grow large.
- **True multi-model council:** different model architectures cross-reviewing (Karpathy's design) — rejected per NN-P-005; see Out of Scope / Non-Goals and `design-basis.md` §D-1.

## Open Questions

- OQ-1: Should `deliberation.md` carry a `deliberation_snapshot:` front-matter (like `charter_snapshot:` in spec.md) recording when it was written? (Default: no — deliberation is consumed in the same session it is written; snapshot staleness isn't a concern as it is for charter drift)
- OQ-2: ~~Should the protocol emit `[DELIBERATION-PARTIAL]` for partial phase failures?~~ RESOLVED in AC-12: Phase B and Phase D partial/all-BLOCKED are non-fatal (proceed with available outputs); only Phase A, C, E failures emit `[DELIBERATION-UNAVAILABLE]`. No `[DELIBERATION-PARTIAL]` marker is introduced.
