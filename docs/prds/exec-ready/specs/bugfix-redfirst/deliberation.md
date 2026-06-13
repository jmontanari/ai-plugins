# Deliberation — exec-ready/bugfix-redfirst

## Investigation Summary

**Resolved depth:** lite.

This piece implements the already-authored non-negotiable **NN-P-006** (red-first obligation for bug-fix / regression work) and **FR-022** into the spec-flow pipeline surfaces. NN-P-006 and FR-022 are *not* being decided here — they exist in the PRD. The decision space is purely *how to wire the rule into every surface that must honor it* and *how to make it mechanically runnable* end-to-end.

A single whole-piece cluster (**DU-1**: "Wire NN-P-006 red-first into all surfaces") was evaluated, decomposed into seven constituent decision units (i)–(vii). Phase C was a no-op (one cluster). Phase B chose a VIABLE path for each of the seven units. Phase D ran two lenses: **scope/simplicity = HOLDS**, **risk = CONTESTED** with three source-confirmed findings.

The investigation surfaced no genuine web-research unknowns — the question is entirely about in-repo pipeline mechanics, and the repo itself is sufficient ground truth. NN-P-006 is justified on the **integrity axis** — "the test was observed red against unfixed code" is an *evidence* artifact, not an output-quality claim. That framing is load-bearing for several downstream decisions (notably the DECLARATION-vs-observation split and the false-positive posture).

The risk lens forced two material expansions to the Phase B recommendation and a re-framing of the execute reconciliation as the central open design fork. These are folded into §Recommendation below; the residual design forks are carried as VOQ-1 through VOQ-4.

## Viability Analysis

Decision unit **DU-1** — "Wire NN-P-006 red-first into all surfaces" — decomposes into seven constituent units. One table per unit.

### (i) Phase-tag mechanism — how a plan phase declares it is bug-fix/regression work

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| (i-A) NEW `**Phase type:**` bold-label field in the plan-template phase header, beside `**ACs Covered:**`, under the CR-009 H3/H4 anchors; values `bug-fix`/`regression`; absent ⇒ feature work | VIABLE | Does NOT touch the counted `### Phase N:` heading the Scheduler parses; reuses the existing bold-label header convention; three-state (present-bugfix / present-regression / absent) is legacy-safe | Yes — reuses CR-009 bold-label header pattern | — |
| (i-B) Encode the tag as a token in the `### Phase N:` heading | NON-VIABLE | Breaks the Scheduler, which parses the counted heading by position/format | No | Scheduler heading parser would mis-count phases on any tagged heading |
| (i-C) Reuse the spec-level `piece_class` field | NON-VIABLE | No per-phase granularity — a piece can mix bug-fix and feature phases | Partial | `piece_class` is piece-scoped; cannot classify an individual phase |
| (i-D) New `[Bug-Fix]` checkbox marker | NON-VIABLE | Forces an execute Step 1a rewrite and breaks the "both-markers ⇒ malformed" invariant | No | Execute Step 1a marker grammar treats two track markers as malformed |

### (ii) Static gate — where the red-first declaration is enforced at plan/spec time

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| (ii-A) Append a next-integer criterion to BOTH qa-plan (→34) AND qa-spec (→18): a bug-fix/regression phase proposing tests-after OR omitting the red-first declaration is must-fix; DECLARATION-only; three-state legacy-safe predicate | VIABLE | Covers both non-overlapping documents (plan surface + spec surface), each required by AC-3; gates the *declaration* (a static artifact), not observed-red (a runtime artifact) | Yes — extends existing qa-plan / qa-spec criterion lists | — |
| (ii-B) Gate observed-red at gate time | NON-VIABLE | observed-red is a runtime/execute artifact; not present at static-gate time | No | No red-evidence exists at plan/spec gate time — runtime-only artifact |
| (ii-C) qa-plan only | NON-VIABLE | Misses the spec surface, which AC-3 also requires | Partial | Spec-surface declarations would pass un-gated |

### (iii) Routing — bug-signal → red-first obligation at intake/small-change

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| (iii-A) small-change Step 9 bug-signal → red-first branch CITING `triage-contract.md` `## Red-first obligation` keyword set; intake hotfix path (Q4→Q6 "Work directly") gains a red-first obligation line | VIABLE | Cites the canonical keyword set rather than re-listing it (honors NN-C-008); covers both small-change and the intake hotfix shortcut | Yes — cites existing triage-contract keyword set | — |
| (iii-B) ALSO add a Step 6 brainstorm routing branch | VIABLE (optional) | Satisfiable but not required — Step 9 alone satisfies AC-4 | Yes | — (droppable; see §Adversarial Review note a) |
| (iii-C) Re-list the keyword set inline at the routing site | NON-VIABLE | Duplicates the canonical keyword set | No | Violates NN-C-008 (single source of truth for the keyword set) |
| (iii-D) New dedicated hotfix skill | NON-VIABLE | No consumer demand; speculative | No | YAGNI — no requirement justifies a new skill surface |

### (iv) Carve-out — exclude bug-fix/regression phases from the `tdd:false` efficient default

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| (iv-A) Document the Non-TDD-mode override (plan/SKILL.md L267–274) + doctrine + BOTH FR-021/FR-022 so that `tdd:false` (efficient default) EXCLUDES bug-fix/regression phases | VIABLE | Makes the exclusion explicit at every place the efficient default is described | Yes — extends existing override doc + doctrine | — |
| (iv-B) Defer the exclusion to the implement-oracle at runtime | NON-VIABLE | The oracle cannot retroactively re-impose red-first once a phase has been emitted without the marker | No | Oracle runs after phase emission; cannot back-fill a missing red-first track |

> **Note:** (iv-A) only *documents* the exclusion. It does NOT put the *structural plan-emission override* in scope — that gap is CONTESTED-2 and is folded as required scope in §Recommendation.

### (v) PIVOTAL — execute reconciliation (make NN-P-006 mechanically runnable)

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| (v-A) Full re-key of execute's tdd-mode dispatch | VIABLE (rejected as over-engineering) | Correct but pulls far more surface than needed; scope lens flags as over-engineering vs the predicate approach | Partial | — (rejected for scope, not viability) |
| (v-C) Minimal predicate-narrowing at the tdd:false-keyed skip/no-op sites | VIABLE (chosen, but enumeration was incomplete) | Minimal-correct *direction* — but the originally named 4 sites are NOT the complete keyed set; see CONTESTED-1 | Yes — narrows existing predicates | — |
| (v-B) execute-OUT / doc-only | NON-VIABLE | Ships NN-P-006 mechanically un-runnable — a bug-fix red-first phase could never actually run red under `tdd:false` | No | Ships a non-negotiable that cannot execute — un-runnable rule |

> execute is **IN scope** (resolves the execute-IN/OUT question). The live design fork between (v-C) predicate-narrowing and a dedicated lightweight red-first path is carried as **VOQ-1** (see §Recommendation / §Validated Open Questions).

### (vi) Out-of-band entry points — non-pipeline surfaces that must honor NN-P-006

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| (vi-A) small-change / plan-amend / new-piece / hotfix HONOR triage's existing forward-record NN-P-006 stamp; non-reproducible ⇒ existing `[SPIKE]` marker or explicit no-repro rationale at triage; campaign (FR-020) reaches the forward-record only | VIABLE | Reuses the existing triage forward-record and `[SPIKE]` marker; campaign only writes the forward-record because the campaign skill does not exist yet | Yes — reuses forward-record + `[SPIKE]` | — |
| (vi-B) Active-campaign honoring (a campaign consumer that enforces NN-P-006) | NON-VIABLE | The campaign skill does not exist | No | No campaign-consumer skill exists to carry the enforcement |
| (vi-C) New no-repro marker | NON-VIABLE | `[SPIKE]` already covers the non-reproducible case | No | Duplicates existing `[SPIKE]` marker semantics |

### (vii) Back-compat + version-sync

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| (vii-A) Absent tag ⇒ feature work, no retro-fail (three-state idiom); NN-C-009 version bump across ALL version-bearing files + CHANGELOG + the hard-coded static.sh L209–214 `5.18.0` assertions in lockstep + new `assert_grep` tokens | VIABLE | The three-state idiom means existing untagged plans never retro-fail; version-sync stays lockstep per NN-C-009 | Yes — extends version-sync process | — |
| (vii-B) Skip the static.sh update | NON-VIABLE | static.sh asserts the version literals; a bump without updating them fails CI | No | static.sh literal assertions would fail on the next version bump |
| (vii-C) Edit the `.agent.md` symlink twins | NON-VIABLE | Byte-identity test enforces symlink twins are identical to their source | No | Byte-identity test forbids editing the twin separately from source |

> **Folded (CONTESTED-3):** there are TWO `plugin.json` files — `plugins/spec-flow/plugin.json` (L4) AND `plugins/spec-flow/.claude-plugin/plugin.json`. The version bumper must name BOTH separately, plus `marketplace.json`, CHANGELOG, and the static.sh literals (static.sh L209–214 asserts 3 sites). See §Recommendation clause (vii).

## Integration Check

Phase C was a **no-op**: a single whole-piece cluster (DU-1) was evaluated, so there is no cross-cluster composition to analyze.

**Single-cluster coherence:** the seven constituent decision units compose into one coherent surface-wiring of NN-P-006 with no internal contradictions. Each unit maps to exactly one acceptance criterion (i→AC-1, ii→AC-3, iii→AC-4, iv→AC-6, v→AC-2, vi→AC-5, vii→AC-7), giving complete AC coverage with no orphaned units and no AC served by two competing units. The phase-tag field (i) is the GATE INPUT that the static gate (ii) and the execute reconciliation (v) both consume; the carve-out (iv) and the plan-emission override (the CONTESTED-2 addition) are the producer side that emits the tagged phase the gate and execute then honor. The chain producer→tag→gate→execute is internally consistent once the CONTESTED-2 plan-emission override is added (without it the chain is broken at the producer — see §Adversarial Review).

## Adversarial Review

Two Phase D lenses returned `STATUS: OK`. Both are recorded below.

### Lens: scope/simplicity — HOLDS

Every surface maps to exactly one AC (i→AC-1, ii→AC-3, iii→AC-4, iv→AC-6, v→AC-2, vi→AC-5, vii→AC-7) — no orphan scope, no missing AC. Specific HOLDS reasoning:

- **(v-C) is minimal-correct**; (v-A) full re-key would be over-engineering.
- **Dual-gate (qa-plan + qa-spec) is NOT redundant** — it covers two non-overlapping documents, both required by AC-3.
- **The `**Phase type:**` field is NOT duplicative of the `[TDD-Red]` checkbox.** The field is the GATE INPUT (classification); the checkbox is the ENFORCED CONSEQUENCE (track). Without the field, an absent checkbox is ambiguous between "feature Implement phase (fine)" and "bug-fix phase missing red-first (must-fix)". The two carry different information and both are required.

Two **non-blocking narrowing notes** (folded into §Answered by Investigation):

- **(a)** small-change Step 6 brainstorm routing is **DROPPABLE** — Step 9 alone satisfies AC-4. (iii-B) is optional, not required.
- **(b)** The campaign forward-record-only scope is **correct** — do NOT expand it into a campaign consumer (a campaign skill does not exist).

### Lens: risk — CONTESTED (3 source-confirmed findings + lower-severity notes)

- **CONTESTED-1 — execute skip-site under-enumeration.** The 4 originally named `tdd:false`-keyed sites (Step 2 L467, Step 2.5 L518, qa-tdd-red, qa_max_iterations L276) are NOT the complete set of front-matter-`tdd:false`-keyed skip/no-op sites in execute/SKILL.md. At minimum, three more would still skip/no-op and silently suppress Red evidence for a `[TDD-Red]` phase under `tdd:false`: **L737** (Step 3.6 AC-Coverage-Matrix reconciliation, skipped in non-TDD mode), **L795** (Step 4 "Test integrity — Mode: TDD only; non-TDD: no-op" — the content-hash anti-tampering re-check; Red's tests are authored + staged but NEVER hash-verified at phase exit), and **L817** (Step 3.7+ non-TDD-mode dispatch path). **Failure mode:** the phase runs Red, but Step 4 integrity re-hash + Step 3.6 reconciliation treat it as Implement. Incomplete predicate-narrowing is THE dangerous failure mode. **Resolution:** folded into §Recommendation clause (v) as a complete enumeration requirement, and the predicate-vs-dedicated-path fork is surfaced as **VOQ-1**.

- **CONTESTED-2 — inert pivotal clause / missing plan-emission precondition.** A `tdd:false` plan NEVER emits a `[TDD-Red]` phase today. plan/SKILL.md L267–269 (Non-TDD override) explicitly states: under `tdd:false`, "Generate ALL phases with non-TDD structure… No `[TDD-Red]`, no `[QA-Red]`, no `[Build]` markers." The per-phase override at L61 is ONE-DIRECTIONAL (`[Implement]` even when `tdd:true`) — there is NO per-phase `[TDD-Red]` override when `tdd:false`. So clause (v) guards an input plan cannot produce — a dead mitigation UNLESS plan/SKILL.md L267–269 is amended to permit a per-phase `[TDD-Red]`/red-first carve-out for bug-fix/regression phases. Clause (iv) only DOCUMENTS the exclusion; it does NOT put the structural plan-emission override in scope. **Resolution:** the plan-emission override is folded as NEW REQUIRED scope into §Recommendation clause (iv′). The marker-reuse-vs-own-phase-type question is surfaced as **VOQ-2**.

- **CONTESTED-3 — version-sync half-specified.** There are TWO `plugin.json` files — `plugins/spec-flow/plugin.json` (L4) AND `plugins/spec-flow/.claude-plugin/plugin.json`. static.sh L209–214 asserts 3 sites. The bumper must name BOTH `plugin.json` files separately + `marketplace.json` + CHANGELOG + the static.sh literals. **Resolution:** folded into §Recommendation clause (vii).

**Lower-severity risk notes:**

- observed-red evidence recording rides entirely on the CONTESTED-2 plan override being added — until then it is unverifiable for `tdd:false` bug-fix phases. (The concrete evidence-artifact question is **VOQ-3**.)
- The detection-heuristic false-positive posture on bug-signal keyword routing (e.g. "fix typo in docs" → red-first on a non-behavioral change) is **FRAGILE, not BROKEN**, under the DECLARATION-only framing — but the failure posture should be STATED, not silent. (Surfaced as **VOQ-4**.)
- Backward-compat risk is **forward** (a future `[TDD-Red]`-carrying `tdd:false` plan hits the L795/L737 incoherence), not retro — acceptable once CONTESTED-1 is closed.

## Recommendation

Implement DU-1 by wiring NN-P-006 into all seven surfaces using the Phase B VIABLE paths, **with two CONTESTED-driven scope expansions** and the execute reconciliation re-framed around a genuine design fork. Concretely:

- **(i) Phase-tag mechanism** — add a NEW `**Phase type:**` bold-label field in the plan-template phase header, beside `**ACs Covered:**`, under the CR-009 H3/H4 anchors. Values `bug-fix` / `regression`; absent ⇒ feature work. Does not touch the counted `### Phase N:` heading. This field is the GATE INPUT that (ii) and (v) consume.

- **(ii) Static gate** — append a next-integer criterion to BOTH qa-plan (→34) AND qa-spec (→18): a bug-fix/regression phase proposing tests-after OR omitting the red-first declaration is must-fix. DECLARATION-only (observed-red is an execute artifact). Three-state legacy-safe predicate. Both gates are required (non-overlapping documents).

- **(iii) Routing** — add the small-change Step 9 bug-signal → red-first branch, CITING the `triage-contract.md` `## Red-first obligation` keyword set (do not re-list it — NN-C-008). The intake hotfix path (Q4→Q6 "Work directly") gains a red-first obligation line. The Step 6 brainstorm routing branch is **dropped** (Step 9 alone satisfies AC-4).

- **(iv) Carve-out (documentation)** — document the Non-TDD-mode override (plan/SKILL.md L267–274) + doctrine + BOTH FR-021/FR-022 so that `tdd:false` EXCLUDES bug-fix/regression phases from the efficient default.

- **(iv′) Plan-emission override — NEW REQUIRED scope (folds CONTESTED-2).** Amend plan/SKILL.md L267–269 so the Non-TDD override permits a *per-phase* `[TDD-Red]`/red-first carve-out for bug-fix/regression phases under `tdd:false`. Without this structural override the plan can never emit the very phase clause (v) guards — clause (v) would be a dead mitigation. This is the producer-side precondition that makes the producer→tag→gate→execute chain coherent.

- **(v) execute reconciliation — re-framed (folds CONTESTED-1).** execute is **IN scope**. The reconciliation must address the COMPLETE set of front-matter-`tdd:false`-keyed skip/no-op sites — at minimum Step 2 L467, Step 2.5 L518, qa-tdd-red, qa_max_iterations L276, **Step 3.6 L737, Step 4 L795, Step 3.7+ L817** — so that a `[TDD-Red]` phase under `tdd:false` is never silently treated as Implement (no suppressed Red evidence, no skipped integrity re-hash, no skipped AC-matrix reconciliation). The *how* is a genuine design fork carried as **VOQ-1**: (Option α) narrow the predicate at every enumerated site so a `[TDD-Red]` phase always runs full Red + integrity even under `tdd:false`, vs (Option β) define a dedicated lightweight red-first regression-phase execution path that records observed-red evidence WITHOUT pulling the full TDD scaffolding (AC matrix, hash-lock) through `tdd:false`. This fork is the central brainstorm question; the full-enumeration requirement holds under either option.

- **(vi) Out-of-band** — small-change / plan-amend / new-piece / hotfix HONOR triage's existing forward-record NN-P-006 stamp; non-reproducible ⇒ existing `[SPIKE]` marker or explicit no-repro rationale at triage. Campaign (FR-020) reaches the forward-record ONLY — do NOT build a campaign consumer (the campaign skill does not exist).

- **(vii) Back-compat + version-sync (folds CONTESTED-3)** — absent tag ⇒ feature work, no retro-fail (three-state idiom). Per NN-C-009, bump version-bearing files in lockstep: **BOTH** `plugins/spec-flow/plugin.json` AND `plugins/spec-flow/.claude-plugin/plugin.json` (named separately), `marketplace.json`, CHANGELOG, and the hard-coded static.sh L209–214 `5.18.0` literal assertions, plus new `assert_grep` tokens for the added surfaces.

Four design forks survive adversarial review unresolved and are carried into the brainstorm as VOQ-1 through VOQ-4.

## Validated Open Questions

- **VOQ-1 — execute reconciliation approach.** Given the complete enumerated set of `tdd:false`-keyed skip/no-op sites (Step 2 L467, Step 2.5 L518, qa-tdd-red, qa_max_iterations L276, Step 3.6 L737, Step 4 L795, Step 3.7+ L817), which approach: **(α)** narrow the predicate at every enumerated site so a `[TDD-Red]` phase always runs full Red + integrity even under `tdd:false`, or **(β)** define a dedicated lightweight red-first regression-phase execution path that records observed-red evidence WITHOUT pulling the full TDD scaffolding (AC matrix, hash-lock) through `tdd:false`? (From §Adversarial Review CONTESTED-1; the central brainstorm question.)

- **VOQ-2 — marker for the bug-fix red-first phase.** Does the bug-fix/regression red-first phase REUSE the existing `[TDD-Red]` marker, or does it get its own phase-type-driven execution marker? This determines the exact shape of the plan-emission override (clause iv′) and interacts with the VOQ-1 fork. (From §Adversarial Review CONTESTED-2.)

- **VOQ-3 — observed-red evidence artifact.** What concrete field/artifact records "test seen red against unfixed code" as phase evidence at execute time, and WHERE is it written — the journal, the discovery-log, or a dedicated phase-evidence line? (Evidence recording is unverifiable for `tdd:false` bug-fix phases until this and VOQ-1/VOQ-2 are resolved.) (From §Adversarial Review lower-severity risk note.)

- **VOQ-4 — bug-signal detection false-positive posture.** When the bug-signal keyword routing fires on a non-behavioral change (e.g. "fix typo in docs"), what is the intended posture — a behavioral-vs-non-behavioral filter, an operator-confirm step, or a must-fix-nudge-only (advisory) treatment? The DECLARATION-only framing makes this FRAGILE, not BROKEN, but the chosen posture must be STATED, not silent. (From §Adversarial Review lower-severity risk note.)

## Answered by Investigation

- **execute IN-or-OUT of scope** — RESOLVED: execute is **IN scope**. The execute-OUT/doc-only path (v-B) is NON-VIABLE because it ships NN-P-006 mechanically un-runnable.
- **execute reconciliation breadth — full re-key vs predicate** — RESOLVED in direction: (v-A) full re-key REJECTED as over-engineering relative to the predicate/targeted approach (scope lens HOLDS). The residual α-vs-β fork *within* the predicate direction is the open VOQ-1, not this resolved breadth question.
- **Phase-tag mechanism** — RESOLVED: a NEW `**Phase type:**` bold-label field (i-A). Heading-token (i-B), `piece_class` reuse (i-C), and the `[Bug-Fix]` checkbox (i-D) are all NON-VIABLE for the recorded blockers.
- **Static-gate placement** — RESOLVED: dual-gate qa-plan + qa-spec (ii-A); the two cover non-overlapping documents and are NOT redundant. qa-plan-only (ii-C) misses the spec surface.
- **Gate target — declaration vs observed-red** — RESOLVED: the static gate enforces the DECLARATION only; observed-red is a runtime/execute artifact and cannot be gated at static time (ii-B NON-VIABLE).
- **Keyword set handling** — RESOLVED: CITE the `triage-contract.md` `## Red-first obligation` keyword set; do NOT re-list it (re-listing is NON-VIABLE under NN-C-008).
- **small-change Step 6 brainstorm routing** — RESOLVED (scope-lens note a): DROPPABLE — Step 9 alone satisfies AC-4. Step 6 routing is optional and is dropped from scope.
- **Campaign (FR-020) scope** — RESOLVED (scope-lens note b): forward-record-ONLY is correct. Do NOT build a campaign consumer — the campaign skill does not exist (vi-B NON-VIABLE).
- **Out-of-band non-reproducible case** — RESOLVED: reuse the existing `[SPIKE]` marker or an explicit no-repro rationale at triage; a new no-repro marker (vi-C) is NON-VIABLE (duplicates `[SPIKE]`).
- **Back-compat for untagged plans** — RESOLVED: the three-state idiom (present-bugfix / present-regression / absent) means absent ⇒ feature work with NO retro-fail. Backward-compat risk is forward-only, acceptable once CONTESTED-1 is closed.
- **Symlink twins** — RESOLVED: do NOT edit the `.agent.md` symlink twins directly (vii-C NON-VIABLE — byte-identity test).
- **NN-P-006 justification axis** — CONFIRMED: NN-P-006 is justified on the **INTEGRITY axis** — "observed-red against unfixed code" is an evidence artifact — NOT an output-quality claim. This framing underpins the DECLARATION-vs-observation split and the VOQ-4 false-positive posture.
- **Web research** — N/A: no external unknowns. The question is entirely in-repo pipeline mechanics; the repo is sufficient ground truth.
