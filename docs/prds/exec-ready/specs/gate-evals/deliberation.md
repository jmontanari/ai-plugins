# Deliberation — exec-ready/gate-evals (FR-017)

## Investigation Summary

**Resolved depth:** full.

FR-017 commits a fixture corpus plus a bash eval-runner that measures the catch-rate of spec-flow's merge-blocking QA gates, and adds a cheater track that red-teams the FR-011 execute-integrity guardrails. The full-depth investigation evaluated five decision units (DU-1 corpus, DU-2 LLM runner, DU-3 cheater track, DU-4 rubric-freeze/release gate, DU-5 lifecycle) against the constraint spine: bash-only (NN-C-002), the `tests/e2e/` harness identity ("never invokes a model"), no CI, and human-driven release.

The corpus + two-runner + cheater-track shape is sound and was confirmed structurally viable by Phase D's architecture lens (HOLDS). Four lenses (scope/simplicity, user-intent, backward-compat, risk) returned CONTESTED, none of them attacking the shape — they attacked over-build, integrity gaps, migration-hostility, and a set of ship-red contradictions between the design and the PRD's success criteria. All four were folded into the Recommendation below via concrete revisions (label-correctness lint, single collapsed ledger, content-marker baseline anchor, opt-out scalar, results-file integrity binding, narrow drift trigger, separate documented-residual tier, README scoping amendment, sha256sum shim, temp-repo trap, and dropping kappa/index/provenance-manifest gold-plating). Five genuine operator-only decisions survived to Validated Open Questions, the load-bearing one being the three-way oracle-vs-replay-vs-live-gate question for the cheater track.

## Viability Analysis

### DU-1 — Fixture corpus

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Hybrid builder + inline `# Scenario:`/`# Expected gate behavior:` labels + generated index | VIABLE | grep-scored ground truth; inline labels keep scorer simple; index is derived not authoritative | Extends `tests/e2e/` fixture conventions | — |
| Inline taxonomy fields (class/severity/owning-seat) | VIABLE | Per-seat attribution becomes intrinsic to one-defect-per-seat fixtures; no metrics-artifact change needed | New convention | — |
| Known-clean control tier | VIABLE | Supplies the false-positive denominator the catch-rate needs | New | — |
| Seat-weighted split (≥8 whole-piece, one-defect-per-board-seat) | VIABLE | Guarantees per-seat coverage for the unique-catch metric | New | — |
| Extend the closed `VALID_BREAKS` enum | NON-VIABLE | Enum is one-repo-per-run; cannot host a 60–80 multi-fixture corpus | — | `VALID_BREAKS` is a single-repo-per-run construct |
| Labels only in YAML | NON-VIABLE | Strands the grep-based scorer; forces a YAML parser into bash | — | grep scorer cannot read YAML labels |
| Derive owning-seat from metrics artifact | NON-VIABLE | metrics-artifact.md has no `findings[].seat` leaf to derive from | — | No `seat` field exists in metrics schema |
| Defective-only split (no clean tier) | NON-VIABLE | Removes the false-positive denominator; flag-rate becomes uncomputable | — | No clean-fixture denominator |

### DU-2 — LLM (judge) runner

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Operator-driven dispatch + pure-bash scorer (mirrors `--verify-live`/L3) | VIABLE | Operator is the dispatcher; scorer stays model-free, preserving harness identity | Mirrors existing `--verify-live` idiom | — |
| Block-style YAML verdict capture, bash computes 5 metrics | VIABLE | catch-rate / clean-flag-rate / verdict-flip / severity-accuracy / per-seat unique-catch all bash-computable from structured capture | New | — |
| Intrinsic per-seat attribution (one-defect-per-seat) | VIABLE | Seat is known from the fixture, not scraped from output | New | — |
| Operator-gated 3-run flip subset | VIABLE | Bounds dispatch cost; flip computed only on selected subset | New | — |
| Model-invoked from bash | NON-VIABLE | Violates NN-C-002 and the harness "never invokes a model" identity | — | NN-C-002 bash-only / harness identity |
| Free-text scrape of judge output | NON-VIABLE | Silent mis-scoring on format drift | — | Unstructured output is not reliably parseable in bash |
| Attribution via metrics provenance | NON-VIABLE | The `seat` field is absent | — | No `seat` leaf in metrics |
| Mandatory 3-run-all | NON-VIABLE | 180–240 dispatches per pass; unaffordable for a human-driven release | — | Dispatch budget blows human-release cadence |
| Fold LLM track into the default run | NON-VIABLE | Breaks the harness "never invokes a model" identity | — | Harness identity invariant |

### DU-3 — Cheater track

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Reconstructed bash oracle re-implements the FR-011 predicate + inline labels | VIABLE | `git show HEAD:$path \| sha256sum` vs recorded manifest; `--name-only` reconciliation; smuggling = manifest∩exempt; M3-window; cap = count-vs-budget — all bash-expressible against a tampered HEAD in `e2e_mktemp` | New lib/ module; reuses e2e tmp builder | — |
| Live-extraction of the SKILL.md gate bash | NON-VIABLE | The gate is LLM-bound placeholder prose (~lines 502–520); nothing callable/sourceable | — | No sourced lib/ fn exists; predicate is prose |
| Greenfield-only cheats | NON-VIABLE | Ignores the reuse path; redundant with existing labeled fixtures | — | Discards reusable FR-011 predicate logic |
| Detection-only, no allow-set | NON-VIABLE | Cannot measure false-positive rate against legitimately-exempt authored files | — | No allow-set denominator |
| Auto-refresh cheat corpus | NON-VIABLE | Requires a model to synthesize new cheats | — | Generation needs an LLM (NN-C-002) |

### DU-4 — Rubric-freeze / release gate

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| `rubric_version` frontmatter + frozen-hash baseline + bash drift-detector in `releasing.md` + any-byte trigger with attestation override | VIABLE | CR-001 optional keys make the field safe; bash hashes the frozen region; degraded path = manual attestation | Reuses releasing.md gate slot | — |
| Git hooks | NON-VIABLE | No install path in a no-CI, human-driven repo | — | No hook install mechanism exists |
| Pure-doc convention | NON-VIABLE | No verifier; drift is undetectable | — | No mechanical enforcement |
| CI-based check | NON-VIABLE | No CI exists | — | No CI in the project |
| Semantic-only trigger | NON-VIABLE | Bash cannot classify rubric-relevant vs irrelevant edits semantically | — | Bash cannot do semantic diff classification |
| Gate placed inside the release skill | NON-VIABLE | Fires post-version-bump, violating CR-008 ordering | — | CR-008 ordering |

### DU-5 — Lifecycle

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Convention + provenance manifest + append-only run-history ledger (derived saturation) + two-state active↔regression tier + citation in `gate-scaling.md` | VIABLE | Saturation is a derived 3-row read; two-state tier reuses `EXCLUDED`; citation gives SC-009 a stable interface | Reuses `EXCLUDED` state | — |
| Auto-scaffold new fixtures | NON-VIABLE | Violates NN-P-004 (no auto-generation of committed artifacts) | — | NN-P-004 |
| Per-fixture mutable counter | NON-VIABLE | Mutates committed fixtures on every run | — | Committed fixtures must stay immutable |
| Full lifecycle state machine | NON-VIABLE | YAGNI; two states cover the actual transitions | — | Unjustified complexity |
| Ad-hoc citation | NON-VIABLE | SC-009 needs a stable cited interface, not a free-floating reference | — | SC-009 requires a stable interface |

## Integration Check

Phase C ran across five decision-unit clusters and confirmed they compose into one coherent piece. The load-bearing seam is **two runners, one published vocabulary** (`PASS|FAIL|SKIPPED:<cap>|ERROR|EXCLUDED`): the DEFAULT model-free runner scores the corpus and the reconstructed-oracle cheater track deterministically and appends to a run-history ledger; the OPERATOR-GATED LLM runner records judge verdicts to block-style YAML which a pure-bash scorer reads. `SKIPPED:llm-verdicts` is emitted when the judge results file is absent, keeping the two tracks cleanly separable and preserving the harness "never invokes a model" identity for the default path.

Composability confirmed across units:
- **DU-3 ↔ DU-4** consolidate: the same bash hash-detector serves both the gate-freeze release gate and the oracle parity-pin (one mechanism, two consumers). Architecture-integrity confirmed this is sound consolidation, not coincidental coupling.
- **DU-1 ↔ DU-2** compose: per-seat attribution is intrinsic to the one-defect-per-seat fixtures, so the LLM scorer reads seat from the fixture, never from a (nonexistent) metrics `seat` leaf.
- **DU-5 ↔ DU-1** compose: the append-only ledger derives saturation without mutating committed fixtures (NN-P-004 honored).

One cross-cutting conflict surfaced and is carried to VOQ-3: the cheater track's reconstructed-oracle path tests a copy of the predicate, while FR-016's downstream need (leave-one-out ablation) and the operator's stated fear (live-gate bypass) may demand exercising the live execute reconciliation path instead. This is a genuine cross-unit tension between DU-3's structural viability and the consumer's intent, resolved only by an operator decision.

## Adversarial Review

| Lens | Verdict | Challenge | Disposition |
|------|---------|-----------|-------------|
| architecture-integrity | HOLDS | Reconstructed oracle is the only viable structural path (no sourceable production fn); parity-pin sound; two-runner/one-vocab seam clean; CR-008 not violated (operator = dispatcher, scorer pure-bash); folding gate-freeze + parity-pin into one detector is sound consolidation. | Recommendation survives. Two non-blocking residuals folded: (R-A) README "harness never invokes a model" amended to scope to the DEFAULT runner; (R-B) drift baseline anchors on a content marker/region delimiter, not raw line numbers. |
| scope/simplicity | CONTESTED | Over-build vs AC floor: (1) reconstructed behavioral oracle exceeds AC-4 (existing `gate-ac{4,5,6}` are static labeled-assertion fixtures); (2) Cohen's kappa, generated index, provenance manifest are gold-plating; (3) two ledgers are one append-only record with a `kind` column; (4) the 60–80 corpus × cheater × release × lifecycle scope risks the qa-prd ≤7-AC/artifact budget. | Folded: kappa/index/provenance-manifest dropped (operator may re-add); two ledgers collapsed to one `kind`-column ledger. ELEVATED: the reconstruction-vs-replay scope cut → VOQ-1; corpus-size budget → VOQ-4. Held by AC force: two runners (AC SKIPPED:llm-verdicts), two-state tier (AC-5), clean-control + seat-weighting (AC-1/AC-2). |
| user-intent | CONTESTED | (1) SC-009 "100% of gates have a PUBLISHED catch rate" vs a SKIPPED-by-default LLM runner — default model-free runner scores LABELS not the JUDGE, so 0% of gates have a published judge catch-rate until someone pays for a run. (2) FR-016 cites "leave-one-out ablation"; per-seat unique-catch ≠ leave-one-out; the comparative re-aggregation is UNBUILT → FR-017 closes green while its sole consumer stays blocked. (3) Cheater track tests the operator's COPY (green-by-construction), not the live ~200-line stateful gate. | ELEVATED, all three are genuine operator decisions: SC-009 scope → VOQ-2; leave-one-out ownership → VOQ-3 (this also subsumes the live-gate-grader flip path); the live-vs-copy concern → VOQ-1. |
| backward-compat | CONTESTED | (1) `rubric_version` frontmatter is SAFE (CR-001 optional keys). (2) drift-detector is a NEW mandatory release gate — PRD-sanctioned by AC-3 only if it triggers narrowly on rubric-bearing edits. (3) hash-pin over the execute/SKILL.md predicate region is migration-hostile (highest-churn file; byte-hash trips on any edit). (4) the new release-blocking gate names no opt-out key, violating NFR-003 + the pipeline-config opt-out-scalar idiom. | Folded: drift trigger narrowed to QA-agent files + rubric content only, SKILL.md region dropped from the baseline (resolves R-B and migration-hostility together); `evals: on|off` opt-out scalar added to `.spec-flow.yaml` for clean rollback. |
| risk | CONTESTED | (1) SC-009 "100% detection" vs EG-1/EG-2 shipped as KNOWN-RESIDUAL probes the guardrail is designed NOT to catch → a residual probe reports <100% and files a false guardrail bug. (2) LLM results file has no integrity control — operator could copy one verdict across 3 runs; flip can't distinguish gate non-determinism from procedure variance. (3) oracle re-baseline is an unguarded escape hatch that launders drift. (4) 60–80 hand-labeled fixtures have no label-correctness control. (5) `sha256sum` vs BSD `shasum -a 256`; `e2e_mktemp` needs `trap … EXIT` cleanup. | Folded: EG-1/EG-2 moved to a SEPARATE documented-residual/expected-fail tier scored independently (SC-009 100% set scoped to the mechanically-detectable taxonomy); each LLM verdict bound to a content-hash of (fixture+gate-agent-file)+per-run session marker, rejecting flips where the 3 rows share a marker or are byte-identical; baseline-bump requires a co-committed oracle re-derivation note (blocking coupling); structural label-correctness lint added (owning-seat ∈ valid set; defective ⇒ expected reject/flag; clean ⇒ pass; label grammar) + human-review-at-add-time; single `sha256sum` shim matching the live gate; `trap … EXIT` cleanup on the tampered-repo builder. |

## Recommendation

The Phase C shape **survives** — a single committed 60–80 fixture corpus, two runners over one published vocabulary, and a reconstructed-oracle cheater track — with the four CONTESTED lenses folded as concrete revisions:

**Corpus (DU-1).** Single committed corpus with inline `# Scenario:`/`# Expected gate behavior:` grep-scored labels; taxonomy (class/severity/owning-seat) as inline fields; known-clean control tier; seat-weighted split (≥8 whole-piece, one-defect-per-board-seat). Add a **structural label-correctness lint** run at fixture-add time: owning-seat ∈ valid seat set; defective ⇒ expected reject/flag; clean-control ⇒ pass; label grammar well-formed. Drop the **generated aggregation index** as authoritative (AC-1 needs labels, not an index) unless the operator wants it. EG-1/EG-2 residual probes live in a **separate documented-residual / expected-fail tier**, scored independently and excluded from the SC-009 100% set.

**Default runner (DU-2/DU-3).** Model-free runner scores the corpus and the reconstructed-oracle cheater track deterministically and appends to a **single append-only run-record ledger with a `kind` column** (collapsing the former run-history + eval-attestation ledgers into one). Vocabulary: `PASS|FAIL|SKIPPED:<cap>|ERROR|EXCLUDED`. Use **one `sha256sum` shim** that matches whatever the live gate hardcodes (normalize BSD `shasum -a 256` at that single shim). The `e2e_mktemp` tampered-repo builder gets a `trap … EXIT` cleanup so tampered repos do not leak into `$TMPDIR`.

**LLM (judge) runner (DU-2).** Operator-gated dispatch (mirrors `--verify-live`/L3); judge verdicts captured to block-style YAML; pure-bash scorer computes catch-rate / clean-fixture flag-rate / verdict-flip-over-3-runs / severity accuracy / per-seat unique-catch. `SKIPPED:llm-verdicts` when the results file is absent. 3-run flip only on an operator-selected subset. Per-seat attribution is **intrinsic** to the one-defect-per-seat fixtures (no `findings[].seat` leaf added to metrics-artifact.md). **Integrity binding:** each verdict row is bound to a content-hash of (fixture + gate-agent-file) plus a per-run session marker/nonce; the scorer **rejects** any flip computation where the 3 rows share a session marker or are byte-identical, so operator-procedure variance cannot masquerade as gate non-determinism. Kappa is dropped from the build (research basis only, not in AC-2) unless the operator opts in.

**Cheater track (DU-3).** New lib/ module re-implements the FR-011 predicate (`git show HEAD:$path | sha256sum` vs recorded manifest; `--name-only` reconciliation; smuggling = manifest∩exempt; M3-window; cap = count-vs-budget) as a bash oracle against a tampered HEAD in `e2e_mktemp`; ≥10 cheats + ≥5 allow-set; EG-1/EG-2 as known-residual probes (in the residual tier). Live-extraction stays NON-VIABLE (the SKILL.md gate is LLM-bound prose). **Open caveat (VOQ-1/VOQ-3):** because this tests a reconstructed copy, it is green-by-construction against itself and cannot surface a live-gate bypass; whether to keep reconstruction, fall back to labeled-assertion replay, or drive scripted cheats through the LIVE execute reconciliation path with the oracle as GRADER-only is the load-bearing operator decision.

**Release gate (DU-4).** `rubric_version` frontmatter (CR-001-safe optional key) + a frozen-hash baseline + a bash drift-detector in `releasing.md`. The trigger is **narrowed to QA-agent `.md`/`.agent.md` pairs + rubric content only**; the execute/SKILL.md predicate region is **dropped from the baseline** (it is the highest-churn file and byte-hashing it is migration-hostile). The baseline anchors on a **content marker / region delimiter, not raw line numbers**. Drift + no-rerun ⇒ blocked; degraded ⇒ manual attestation. The same mechanism serves as the oracle parity-pin. Add an **`evals: on|off` (or equivalent) opt-out scalar** in `.spec-flow.yaml` (NFR-003 + pipeline-config idiom) for clean rollback if the suite is buggy. A **baseline re-bump requires a co-committed oracle re-derivation note** (blocking coupling — the two halves cannot be bumped independently).

**Lifecycle (DU-5).** Convention/checklist + provenance manifest; the single append-only ledger above (saturation = derived 3-row read); two-state active↔regression tier (reusing `EXCLUDED`); AC-6 citation obligation lands in `reference/gate-scaling.md#board-swap-rule`. The provenance manifest is folded into the ledger/inline-labels rather than maintained as a separate artifact unless the operator wants it standalone.

**README amendment (R-A).** Amend the `tests/e2e/` README "harness never invokes a model" line to scope that invariant to the DEFAULT runner; the operator-gated LLM runner is the documented exception, so the invariant stays true rather than becoming false on this piece.

## Validated Open Questions

- **VOQ-1 — Cheater-track strategy (load-bearing).** Three viable-but-divergent paths exist for what the cheater track actually exercises: (a) **reconstructed bash oracle with parity-pin** (architecture-integrity's recommendation — structurally the only sourceable path, but green-by-construction against its own copy); (b) **labeled-assertion replay** (scope/simplicity's recommendation — reserve reconstruction for the un-pre-labelable cheat sub-class only; note that cutting reconstruction also evaporates the parity-pin machinery in DU-4); (c) **drive scripted cheats through the LIVE execute reconciliation path** with the bash oracle as ground-truth GRADER only, not the gate-under-test (user-intent's flip-to-HOLDS path — the only one that can surface the live-gate bypass the operator most fears). Only the operator can settle this three-way trade between structural simplicity, build cost, and fidelity to the live gate.

- **VOQ-2 — SC-009 published-catch-rate scope.** SC-009 requires "100% of gates have a PUBLISHED catch rate," but the default runner scores LABELS, not the JUDGE, and the judge runner is SKIPPED by default. Resolve one of two ways: (a) **re-scope SC-009** to state explicitly that model-free metrics ≠ judge catch rate (the published number is a label-detection metric, not a judge metric); or (b) make **AC-3's rubric-change release check FORCE an LLM gold-set run** (not merely flag it), so a judge catch-rate is published on every rubric change. Operator owns the SC-009 wording-vs-mechanism choice.

- **VOQ-3 — leave-one-out ablation ownership.** FR-016 (downstream, open) cites "verdict-overlap / leave-one-out ablation" as a prerequisite before any board-seat cut. Per-seat unique-catch (in this design) ≠ leave-one-out (re-score the corpus with seat X's verdicts removed, compare aggregate recall). Settle ownership: is the comparative re-aggregation **in scope for FR-017** (build it here, so FR-016 unblocks), or **explicitly FR-016's job** (FR-017 ships per-seat metrics only and the manifest/PRD records that FR-016 owns the ablation)? As written, FR-017 closes green while its sole consumer stays blocked unless this is settled. Note: choosing the live-gate path in VOQ-1(c) interacts with this — a live-grader run is also the cleanest substrate for a true leave-one-out.

- **VOQ-4 — corpus initial size (spec-amend territory).** AC-1 states "initial size 60–80." Building, hand-labeling, and lint-clearing 60–80 fixtures plus the cheater track plus the release gate plus lifecycle in one piece risks the qa-prd ≤7-AC / artifact budget. Either the **operator confirms 60–80 is realistic for one piece**, or the size is **renegotiated down via spec-amend** with the living-corpus growth path documented as the route to eventually reach 60–80. This is a scope/spec-amend decision the operator must ratify; trimming the committed initial corpus cannot be done silently against an AC.

- **VOQ-5 — Seam-2 (LLM-report) freshness cadence.** The operator-gated LLM judge report can go stale between runs (nobody pays for a run, the published number ages). Decide whether release tolerates an **on-demand / best-effort freshness** (the number is whatever the last run produced, however old) or enforces a **minimum-freshness release window** (a release is blocked if the judge report is older than N releases / N days). This interacts with VOQ-2(b): forcing an LLM run on rubric change is one freshness mechanism but does not cover non-rubric staleness.

## Answered by Investigation

| Dimension | Status | Rationale |
|-----------|--------|-----------|
| Live-extraction of the SKILL.md gate bash | Resolved (NON-VIABLE) | The gate is LLM-bound placeholder prose (~lines 502–520); nothing is sourceable/callable. The reconstructed-oracle path is the only structural option — confirmed by architecture-integrity HOLDS. |
| Per-seat attribution source | Resolved → intrinsic | metrics-artifact.md has no `findings[].seat` leaf; attribution is made intrinsic to the one-defect-per-seat fixtures rather than derived from metrics. No metrics-schema change. |
| bash-only (NN-C-002) | Confirmed | The default runner and both scorers are pure bash; the operator (a human) is the only model-dispatcher. Model-from-bash paths were ruled NON-VIABLE across DU-2/DU-3. |
| No CI | Confirmed | Git hooks and CI-based drift detection ruled NON-VIABLE in DU-4; the drift-detector lives in `releasing.md` as a bash check on a human-driven release. |
| Harness "never invokes a model" identity | Confirmed (with scoped amendment) | The DEFAULT runner preserves the invariant; the LLM runner is folded as a documented operator-gated exception and the README line is amended to scope the invariant to the default runner (R-A). Folding the LLM track into the default run was ruled NON-VIABLE. |
| CR-008 ordering (gate placement) | Confirmed honored | The release gate sits in `releasing.md`, not inside the release skill (which would fire post-bump). Operator = dispatcher, scorer = pure bash, so CR-008 is not violated. |
| CR-001 optional-key safety (`rubric_version`) | Confirmed safe | Loader ignores unknown frontmatter keys; the new field is backward-compatible (backward-compat lens, point 1). |
| Two ledgers (run-history + eval-attestation) | Resolved → collapsed | Folded into one append-only run-record ledger with a `kind` column (scope/simplicity point 3). |
| Cohen's kappa / generated index / provenance manifest | Resolved → dropped as gold-plating | Not required by AC-2/AC-1/AC-5; dropped from the build, operator may re-add. Ledger + inline labels already satisfy AC-5. |
| Drift-trigger scope + baseline anchor | Resolved | Narrowed to QA-agent files + rubric content only; SKILL.md region dropped; anchored on a content marker, not line numbers (backward-compat points 2–3, architecture R-B). |
| Opt-out for the new release gate | Resolved → `evals: on\|off` scalar | NFR-003 + pipeline-config opt-out-scalar idiom; clean rollback if the suite is buggy (backward-compat point 4). |
| LLM results-file integrity | Resolved | Per-verdict content-hash binding + per-run session marker; scorer rejects shared-marker / byte-identical flip rows (risk point 2). |
| EG-1/EG-2 residual-probe contradiction with SC-009 100% | Resolved | EG-1/EG-2 moved to a separate documented-residual / expected-fail tier scored independently; SC-009 100% set scoped to the mechanically-detectable taxonomy (risk point 1). |
| Oracle re-baseline laundering drift | Resolved | Baseline-bump requires a co-committed oracle re-derivation note (blocking coupling); the two halves cannot be bumped independently (risk point 3). |
| Label-correctness control | Resolved | Structural label lint at add-time (owning-seat ∈ valid set; defective ⇒ reject/flag; clean ⇒ pass; grammar) + human-review-at-add-time (risk point 4). |
| `sha256sum` vs BSD `shasum` + temp-repo leak | Resolved | Single `sha256sum` shim matching the live gate; `trap … EXIT` cleanup on the `e2e_mktemp` tampered-repo builder (risk point 5). |

## Re-alignment Addendum (2026-06-12) — substrate pivot

The original investigation above evaluated a **fabricated labeled fixture corpus** as the gate-effectiveness substrate. At plan stage, a data check changed the design: the operator's real spec-flow session transcripts (`~/.claude/projects/<project>/*.jsonl`) are plentiful (prop-firm-repo 1.5 GB / 195 sessions, ai-plugins 270 MB / 57, + pool) and already contain per-seat gate dispatches + results. The piece pivoted to **mining real sessions** instead of fabricating fixtures. Decisions taken in the plan-stage conversation (now the resolved design in `spec.md`):

- **Substrate:** mine real session transcripts (precision/overlap/leave-one-out/activity from real usage), not a hand-authored corpus. The fabricated-corpus design (old DU-1/DU-2/DU-4/DU-5 and their runner/rubric-freeze machinery) is **superseded** — only the DU-3 cheater track survives intact (+ EG-1 residual, EG-2 fix).
- **Fundamental limit (carried forward honestly):** mining gives PRECISION, not true RECALL — you cannot see defects nobody flagged. Recall is sourced only from the cheater track / constructed tampers. The "story" must never claim a catch rate (SF-8/SC-009 re-scope).
- **Tooling / charter:** the miner is an internal maintainer tool (python + pip) at **repo-root `tools/transcript-eval/`** — outside `plugins/<plugin>/` and not shipped — so NN-C-002 (consumer zero-install) does not govern it; no charter amendment needed. The consumer surface (cheater track, EG-2, `rubric_version`) stays bash-only under `plugins/spec-flow/`.
- **Durability + privacy:** accrued insights live in a repo-peer store **outside repo scope** (default `/Volumes/joeData/spec-flow-insights/`) so git ops can't wipe them; nothing mined is ever committed; cross-repo (prop-firm) content never enters the ai-plugins tree.
- **Shared lib:** the parse/scrub/aggregate core is reusable — gate-evals first-consumes it; `flywheel-global` (FR-007) reuses it later for cross-install correlation.
- **Extraction risk → spike-gated:** the `.jsonl` schema is undocumented and a naive jq extraction came back empty, so an extraction-validation spike (SF-7) gates the downstream build on real coverage/agreement thresholds.
- **LLM-inference layer (re-run a gate against a past artifact for flip/consistency):** explicitly deferred to a later piece.

The new design was operator-driven (not re-run through the 5-phase board); this addendum records the pivot so `spec.md`'s rationale references stay coherent. The pre-pivot investigation is retained above for provenance.
