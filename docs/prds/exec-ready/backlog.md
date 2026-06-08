# exec-ready PRD Backlog

Deferred work items scoped to this PRD. Cross-PRD learnings live at `docs/improvement-backlog.md`.
Items here are surfaced during spec brainstorm for each piece and either incorporated, deferred with rationale, or marked obsolete.

---

## Open Questions deferred to piece spec brainstorm (2026-06-06)

These are the PRD's Open Questions; resolve each during the relevant piece's spec:

- **Plugin-registry path** — `~/.claude/spec-flow/patterns.yaml` is the proposal; confirm path and update-stability (must survive plugin reinstall, must not collide) during `flywheel` spec.
- **Pattern occurrence granularity** — one occurrence per piece where the pattern appeared, or one per reflection finding? Resolve during `flywheel` spec.
- **`.spec-flow.yaml` keys** — finalize `flywheel_threshold` shape during `flywheel` spec. (`model_policy` and the doc-as-code circuit-breaker were resolved in the `sonnet-coord` spec, 2026-06-07: `model_policy: auto|off`; `qa_max_iterations: auto` = 5 doc-as-code / 3 TDD.)

---

## Deferred from the 2026-06-06 re-evaluation (cut/deferred from the prior exec-loop PRD)

The original `exec-loop` PRD was re-scoped after a capability audit + fresh Boris research. These items were dropped from scope and parked here:

- **Sonnet context-budget / oversized-file routing / summarizer (old FR-006)** — DEFERRED. The original justification ("Sonnet's small window") was superseded by the Opus-1M driver, and the real goal became file-based statelessness (now FR-004/NFR-002). Revisit only if dense plans strain context at the *plan* stage, or if a token ceiling proves necessary in practice. Not a piece today.
- **Execute self-resolve + `decisions.md` (old FR-004)** — CUT. Conflicts with the synchronous-discovery doctrine; an execute-time ambiguity is a plan-incompleteness signal routed to Step 6c or a `[SPIKE]`, not a silent in-execute decision log. Captured as NN-P-002.
- **`loop-driver.md` multi-piece driver + DONE/BLOCKED vocabulary (old FR-005 scraps)** — DROPPED. The execute loop, manifest→merged, and journal resume already ship; only the configurable circuit-breaker survived (folded into `sonnet-coord`). Autonomous multi-piece queue is an explicit non-goal.
- **Cross-machine plugin-pattern correlation** — NON-GOAL. The `~/` plugin registry is per-machine; cross-machine correlation needs a shared remote backend (auth/privacy/weight). Revisit only if multi-machine plugin learning becomes a real need.

---

## Recent findings

### [Deferred via /spec-flow:defer] qa-spec + spec/SKILL.md + templates/spec.md lack branch-enumeration AC coverage — 2026-06-07

**Source:** `exec-ready/plan-concrete` phase `step-4.5-reflection` (agent: `reflection-future-opportunities`)
**Finding (verbatim):** plan-concrete shipped branch-enumeration AC enforcement at the plan layer (qa-plan criterion #30, plan/SKILL.md §2f sub-rule 3, §9d, templates/plan.md slot). The upstream spec layer is untouched — a spec can ship with implicit conditional branches that no AC covers, and the plan author must retrofit ACs later (or qa-plan must-fixes the resulting plan). The pi-011 retro in improvement-backlog.md also called for qa-spec branch-enumeration. Candidate piece: add qa-spec criterion (#19) for doc-as-code phases, extend spec/SKILL.md with a parallel authoring note, add branch-AC slot to templates/spec.md — all citing reference/plan-concreteness.md §3. Deps: plan-concrete (merged ✓).
**Why this does not block plan-concrete's goals:** plan-concrete's scope is the plan layer only; the spec-layer gap is a follow-on improvement. qa-plan's criterion #30 provides a backstop even when the spec layer is silent.
**Captured:** 2026-06-07

### [Deferred via /spec-flow:defer] flywheel-repo spec should include unmarked-execute-time-discovery as a first-class metric — 2026-06-07

**Source:** `exec-ready/plan-concrete` phase `step-4.5-reflection` (agent: `reflection-future-opportunities`)
**Finding (verbatim):** plan-concrete's stated outcome goal ("a passing plan yields zero unmarked execute-time discoveries") has no measurement surface. The flywheel-repo piece (FR-006, status: open) is the natural recording surface. During flywheel-repo spec brainstorm, propose adding "unmarked execute-time discovery" as a first-class flywheel pattern-type: each Step 6c discovery event that was NOT a [SPIKE]-routed resolution increments a per-plan-quality counter in docs/patterns.yaml. This is a scope amendment for flywheel-repo, not a new piece. Deps: spike-agent (FR-005) must land first (Step 6c plan amendments must exist).
**Why this does not block plan-concrete's goals:** The measurement surface is downstream of multiple open pieces; plan-concrete's enforcement layer is complete and correct without it.
**Captured:** 2026-06-07

---

### spike-agent future opportunities (2026-06-07)

**Source:** `exec-ready/spike-agent` step-4.5-reflection (agent: `reflection-future-opportunities`)

**FO-1: Configurable `spike_threshold` key (fold into flywheel-repo spec)**
The 0.5 diff-ratio threshold is hardcoded in `reference/spike-agent.md` `## Threshold reuse`. Once the flywheel accumulates per-piece amendment data (FR-006), operators will have a basis for tuning. The spec's Open Questions (spec.md line 172) already flagged `spike_threshold` as a future `.spec-flow.yaml` key. Candidate: during `flywheel-repo` spec brainstorm, propose adding `spike_threshold` as an optional config scalar (default 0.5) read at the threshold computation site in `execute/SKILL.md`. When present it overrides the hardcoded value; when absent behavior is identical (NN-C-003). `reference/spike-agent.md` `## Threshold reuse` is updated to cite `.spec-flow.yaml` as the source of truth.
**Deps:** spike-agent merged (this piece); flywheel-repo spec brainstorm.

**FO-2: Confirm-then-n recording for admission-heuristic calibration (fold into flywheel-repo spec)**
The detect-and-confirm gate (Step 6c `#### Operator-initiated change admission`) treats a `n` response as a silent no-op (comment). Once flywheel-repo has a recording surface, `n` events could be recorded as `admission-false-positive` pattern-type in `docs/patterns.yaml`. At threshold, the flywheel proposes a heuristic-tuning amendment to the admission trigger list. This keeps the detection heuristic improvable without NLU infrastructure.
**Deps:** spike-agent merged; flywheel-repo spec brainstorm.

**FO-3: Cross-piece resolved-spike index (fold into flywheel-repo spec or follow-on piece)**
The no-re-spike guard (Step 1c) is piece-scoped: `spikes/<phase-id>.md` lookup is local. A later piece in the same PRD resolving the same unknown would re-spike from scratch. The flywheel already walks `docs/prds/<prd-slug>/` during pattern recording; it could index spike `Trigger:` fields into `docs/patterns.yaml` as a queryable resolution cache. The spike agent's resolve mode could receive "prior resolutions for similar trigger" pre-context. This bounds Opus spend as PRD unknowns accumulate.
**Deps:** spike-agent merged (canonical artifact schema/location); flywheel-repo (the indexing surface).

**Non-blocking on spike-agent goals:** all three items are flywheel-downstream. This piece's goals are complete without them.
