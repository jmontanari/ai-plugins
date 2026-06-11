# Deliberation — exec-ready/exec-guardrails (FR-011)

## Investigation Summary

**Resolved depth:** `full`.

This piece implements FR-011: **test immutability** (a Build phase must not be able to silently edit, weaken, or delete the Red phase's failing tests to make the gate pass) plus an **amendment hard-cap** (a per-piece amendment ceiling that, unlike today's soft-checkpoint, can actually halt under-scoped pieces). It serves US-011's acceptance-boundary success condition: the operator wants the green signal at piece acceptance to be trustworthy — that a passing result means the production code satisfies the authored tests, not that the tests were quietly rewritten to pass.

Four decision-unit clusters were evaluated in Phase B (C1 immutability detection mechanism; C2 declared-authored-test exemption; C3 amendment-budget home/threshold; C4 reject→discovery provenance), composed in Phase C into a single integrated recommendation, then stress-tested by six adversarial lenses in Phase D. The investigation confirmed the central design — a **single seam eval order at the post-commit re-hash gate** with the existing 2-attempt budget governing rejects — but four adversarial lenses returned CONTESTED, three of them resolvable by concrete fold and four genuinely-unresolved tensions that survive as validated open questions for the operator.

The decisive structural finding (architecture lens): the C3 "FORK" — placing the amendment cap in a different canonical home than the existing soft-checkpoint — is a definitional contradiction, because the cap and the soft-checkpoint are the **same counter**. This was confirmed against source: `plugins/spec-flow/skills/execute/SKILL.md` L1211–1263 maintains `piece_amendment_count` / `piece_spec_amendment_count`, recovers them via `git log --grep '^chore(plan): amend'` / `'^chore(spec): amend'`, uses the 5-total / 1-spec thresholds, and at L1263 cites `reference/spike-agent.md` `## Soft-checkpoint budget` as the canonical definition while L1253/L1263 assert the count "never hard-blocks." A hard-cap and a never-hard-blocks soft-checkpoint cannot both be canonical for one counter.

## Viability Analysis

### C1 — Immutability detection mechanism

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| 1A-1: hash Red-manifest test files (sha256) and re-check at post-commit gate | VIABLE | Reuses the existing post-commit re-hash gate (flat Step 3.7a / deferred Step G9b) and Red manifest. Byte-level immutability of enumerated files. | Yes — reuses re-hash gate + Red manifest | — |
| 1B-1: Red-manifest immutability as a distinct rejection class in the seam | VIABLE | Slots into existing seam eval order; reuses the 2-attempt reject budget. | Yes | — |
| 1C-1: smuggling guard — path in BOTH immutable-set AND exemption-set = hard reject | VIABLE | Closes the obvious bypass (declare a Red test as "authored" to gain edit rights). Lower precedence for exemption. | Yes | — |
| 1D-1: 2nd immutability rejection → Step 6c missing-prerequisite-shaped discovery row | VIABLE | Reuses the existing Step 6c discovery + `.discovery-log.md` machinery; `default_triage: amend`. | Yes — reuses Step 6c | — |
| Pre-commit `git diff --cached` interception (flat path) | NON-VIABLE | On the flat path the implementer commits autonomously and owns the commit primitive; the orchestrator never holds a staged-but-uncommitted index to inspect. AC-1 "before any commit" is unachievable as literal pre-commit on flat. | n/a | Orchestrator has no pre-commit hook point on the flat (autonomous-implementer) path; the only enforceable boundary is post-commit acceptance (revert-before-acceptance). |

### C2 — Declared-authored-test exemption

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| 2a-2: dedicated `**Authored-tests:**` field listing exempt paths | VIABLE | Unambiguous machine-parseable exemption set; classification is explicit, not inferred. | Partial — new field | — |
| 2b-2: exemption is lower-precedence than immutability (path in both = reject) | VIABLE | Preserves the smuggling guard from 1C-1. | Yes | — |
| 2c-1: reconciliation folds declared paths into `expected` | VIABLE | Reuses gate-(b) reconciliation; declared authored tests don't trip the "unexpected test file" check. | Yes — reuses reconciliation | — |
| Reuse existing `In scope:` / `Scope:` literal-path list as the exemption source | NON-VIABLE | The orchestrator cannot unambiguously classify an arbitrary scope-listed path as test-vs-prod without a heuristic; CR-006 parser-ambiguity. A prod path mis-classified as exempt would silently widen the immutable-set hole. | n/a (reuse) | No unambiguous test-vs-prod classifier over free-form scope paths (CR-006); reuse re-introduces the ambiguity the dedicated field eliminates. |

### C3 — Amendment-budget home / threshold

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| A1: hard-cap modeled as a threshold on the existing `piece_amendment_count` | VIABLE | One counter, one recovery path (`git log --grep`), one canonical home. The cap is a second threshold above the soft-checkpoint, not a second budget. | Yes — reuses existing counter + recovery | — |
| B1: single canonical home (execute SKILL.md amendment-budget section + cited spike-agent SSOT) | VIABLE | Avoids the two-homes contradiction; the soft-checkpoint and hard-cap are co-located. | Yes | — |
| C1-fork: relocate the cap into a *separate* canonical home from the soft-checkpoint | NON-VIABLE | The cap governs the same `piece_amendment_count` the soft-checkpoint governs (same `--grep` recovery, same 5/1 thresholds). Two canonical homes asserting opposite at-threshold behavior ("never hard-blocks" vs "hard-halt") is a contradiction the SSOT cannot hold. | n/a | One counter cannot have two canonical homes with contradictory at-threshold semantics; `execute/SKILL.md:1253/1263` "never hard-blocks" directly contradicts a forked hard-halt home. |
| D2 ∪ D1: hard-halt path = block-piece behavior, reusing the existing `(b) block` Step semantics | VIABLE | The hard-cap reuses the existing block-piece halt (status→`blocked`, manifest commit) rather than inventing a new terminal state. | Yes — reuses `(b) block` flow | — |

### C4 — Reject → discovery provenance

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| 4a-1: 2nd immutability reject emits a Step 6c discovery row | VIABLE | Reuses the Step 6c missing-prerequisite discovery shape. | Yes | — |
| 4b-1: `default_triage: amend`, unchanged `.discovery-log.md` format | VIABLE | No schema change to the discovery log; the new row is format-compatible. | Yes | — |
| 4c-1: discovery routed through existing triage | VIABLE | Reuses existing triage routing. | Yes | — |
| `source_agent` value (orchestrator vs implementer) | VIABLE (both) | Both are mechanically valid; this is a provenance-semantics choice, not a viability blocker. Surfaced as VOQ-4. | Yes | — |

## Integration Check

Phase C composed the four clusters into one coherent path with **no unresolvable cross-cluster conflict** at the structural level. The composed recommendation:

- **Single seam, single eval order** at the post-commit re-hash gate (flat Step 3.7a / deferred Step G9b): **M3 registry window → Red-manifest immutability → declared-authored-test exemption (lower precedence) → reconciliation.** A path appearing in BOTH the immutable-set and the exemption-set is a hard reject (smuggling guard) — the exemption never overrides immutability.
- **The existing 2-attempt reject budget** governs immutability rejects; the **2nd** immutability rejection emits a Step 6c missing-prerequisite-shaped discovery row (`default_triage: amend`) with no `.discovery-log.md` format change.
- **One amendment counter** (`piece_amendment_count`) carries both the soft-checkpoint threshold and the new hard-cap threshold; they are co-located in one canonical home (C3 fork rejected by both Phase B viability and the architecture lens).

**Flat-vs-deferred asymmetry (held, not a conflict):** AC-1 "before any commit" resolves differently per path and this is intentional, not a defect. On the **deferred/barrier** path the orchestrator owns the commit, so enforcement is literal pre-commit. On the **flat** path the implementer commits autonomously, so enforcement is "before any tampered commit is accepted / survives" — revert-before-acceptance at the acceptance boundary. Genuine `git diff --cached` interception on the flat path was ruled NON-VIABLE (no orchestrator pre-commit hook point). The two readings compose into one seam because both converge on the same post-commit re-hash gate.

## Adversarial Review

| Lens | Verdict | What was challenged | Disposition |
|------|---------|---------------------|-------------|
| architecture-integrity | CONTESTED | The C3 FORK puts one counter (`piece_amendment_count`) in two canonical homes with contradictory at-threshold semantics. | **Folded.** Do not fork. One counter, one home; soft-checkpoint and hard-cap are two thresholds on the same counter, defined in one place; spike-agent SSOT reduced to a cite and its "never hard-blocks" assertion edited so it no longer contradicts the hard-halt. Seam eval-order + flat/deferred asymmetry HOLD. |
| scope/simplicity | CONTESTED | (a) dedicated `**Authored-tests:**` field may be gold-plating; (b) two config keys when AC-4 only needs the total configurable; (c) precedence-ordered exemption framework heavier than needed. | **Partially folded.** (a) is a genuine simplicity-vs-parse-ambiguity tension → **VOQ-2** (scope-reuse was ruled NON-VIABLE in C2). (b) → **VOQ-3** (merged with backward-compat config tension). (c) folded toward the simpler reconciliation-`expected` + one-line tie-break framing, *retaining* the smuggling guard. (d) FORK relocation already removed by the architecture fold. |
| risk | CONTESTED (highest severity) | Byte-identical hashing of manifest-listed test files misses semantic tampering via un-enumerated files (a new trivially-true test; a rewritten shared `conftest.py`/fixture the Red test consumes). M3 closure-hashing exists only for `integration_registry` rows; ordinary unit Red tests get no closure hashing. Hidden assumption: "the Red manifest enumerates the complete behavioral surface." | **Surfaced as scope decision → VOQ-1.** Secondary items folded as documented assumptions: git-log `--grep` count fragility under squash/rebase/coincidental-prefix (anchor: piece-internal commits not rebased mid-piece — now more consequential because the cap hard-halts); escalation summary degrades to `git log --oneline` if `.discovery-log.md` absent on resume. |
| backward-compat | CONTESTED (agent emitted BLOCKED but produced a complete verdict — treated as CONTESTED with content) | New declared-test mechanism and new amendment keys could break in-flight plans and pre-existing `.spec-flow.yaml` configs; the `(c) continue` removal is a behavioral break. | **Folded as hard constraints** (see §Recommendation a–d). The configurability-vs-AC4 tension (e) is genuinely open → **VOQ-3**. |
| user-intent | HOLDS | Does the design serve US-011's acceptance-boundary success condition? | Holds. Residual recorded in §Answered by Investigation: "mechanically unable" is guaranteed at the *acceptance* boundary on the flat path, at the *commit* primitive on the deferred path. |

## Recommendation

Adopt the Phase C integrated recommendation with the following folds applied:

**Seam (C1+C2+C4 core, unchanged):** one seam, one eval order at the post-commit re-hash gate (flat Step 3.7a / deferred Step G9b): **M3 registry window → Red-manifest immutability → declared-authored-test exemption (lower precedence) → reconciliation.** Path in BOTH immutable-set and exemption-set = hard reject (smuggling guard, retained). The existing 2-attempt reject budget governs immutability rejects; the 2nd immutability rejection emits a Step 6c missing-prerequisite-shaped discovery row, `default_triage: amend`, with no `.discovery-log.md` format change.

**Amendment cap — unify the counter (architecture fold, mandatory):** Do **not** fork. Model the hard-cap and the soft-checkpoint as **two thresholds on the single `piece_amendment_count` counter**, with one canonical home. Reduce `reference/spike-agent.md` `## Soft-checkpoint budget` to a cite of that home **and edit its "never hard-blocks" assertion** (and the matching `execute/SKILL.md:1253/1263` text) so the SSOT no longer contradicts the new hard-halt. The hard-halt reuses the existing `(b) block`-piece flow (status→`blocked`, manifest commit), not a new terminal state.

**Declared-authored-test mechanism — conditional (backward-compat fold, mandatory):** The mechanism MUST be conditional. **Absent field/declaration ⇒ empty exemption set, no parse error, no warning.** The new qa-plan / reconciliation criterion is "verify IFF present" — never "MUST be present" — so in-flight pre-piece plans don't break at their next phase-exit. Reconciliation simply folds any declared authored paths into `expected`; the precedence-ordered framing collapses to: declared paths join `expected`, with a one-line tie-break that a declared path also in the immutable-set is a hard reject (smuggling guard retained).

**Config defaults — clean fallback (backward-compat fold, mandatory):** `.spec-flow.yaml` without amendment keys (absent OR malformed, per NN-C-003) defaults cleanly to the documented default. No error, no warning.

**In-flight resume preserved (backward-compat fold, mandatory):** Hard-reject applies to **fresh dispatches only**; in-flight old-format (≤5.1.0) journal resume preserves the existing escape and is not hard-rejected mid-stream.

**Versioning (backward-compat fold, mandatory):** The `(c) continue` removal is a behavioral break — record it in CHANGELOG under `### Changed` with a migration note, **not** `### Added`.

The four genuinely-unresolved tensions below (VOQ-1..VOQ-4) are NOT resolved by this recommendation; the brainstorm walks them with the operator before the spec is authored.

## Validated Open Questions

**VOQ-1 — Semantic-tampering scope (X vs Y).** Byte-identical hashing of manifest-listed test files does not catch (1) a Build phase adding a NEW trivially-true test file that it correctly declares in `## Files Created/Modified` (passes reconciliation), or (2) a Build rewrite of a shared `conftest.py`/fixture/helper the Red test consumes — changing asserted behavior while the listed test bytes (and sha256) stay identical. M3 fixture/closure hashing today covers only `integration_registry` rows. **Decide:** (X) extend the per-phase Red manifest to capture+hash an import/fixture closure like M3 does (broader scope, stronger guarantee), OR (Y) explicitly scope FR-011 to "listed-file byte immutability only" and document the semantic-tampering + new-trivial-test residual as an accepted/known limitation so the guarantee isn't oversold.

**VOQ-2 — Declared-authored-test mechanism (dedicated field vs scope-reuse).** A dedicated `**Authored-tests:**` field is unambiguous but is new surface that the simplicity lens flags as possible gold-plating; the simpler alternative (reuse the existing `In scope:`/`Scope:` literal-path list + extend qa-plan to flag any test file an Implement phase touches outside its declared scope) was ruled **NON-VIABLE in C2** because the orchestrator cannot unambiguously classify a free-form scope path as test-vs-prod (CR-006). **The genuine tension: simplicity vs parse-unambiguity.** Decide whether the unambiguity is worth the new field, or whether a constrained heuristic / different reuse shape can recover simplicity without re-opening the classification hole.

**VOQ-3 — Amendment config: key count + cap-configurability vs AC-4 "no soft continuation."** Two sub-questions, merged because they touch the same keys. (a) AC-4 only requires the *total* be configurable; the spec sub-cap could stay a fixed documented constant — one key vs two. (b) If `amendment_budget` is a configurable int, setting it high IS an escape hatch, which sits in tension with AC-4's "no soft continuation." **Decide:** is the hard-cap "no per-EVENT soft continue (an up-front config raise is a legitimate operator decision)" or a truly fixed wall? Should an `off`/unlimited sentinel exist, and if so does it violate AC-4's intent?

**VOQ-4 — Reject→discovery provenance (`source_agent`).** The 2nd-immutability-rejection Step 6c discovery row needs a `source_agent`: `orchestrator` (it is the orchestrator that detects the reject at the re-hash gate) vs `implementer` (it is the implementer that failed to complete cleanly; the existing Step-6c missing-prerequisite precedent at ~L1004 uses `implementer`). **Decide** which provenance the row records — consistency with the L1004 precedent vs accuracy of who detected the violation.

## Answered by Investigation

| Dimension | Status | Rationale |
|-----------|--------|-----------|
| Amendment-counter home (C3 FORK) | RESOLVED | Architecture lens confirmed `piece_amendment_count` is a single counter (one `git log --grep` recovery, one 5/1 threshold set, `execute/SKILL.md:1211–1263`). Fork rejected; cap and soft-checkpoint are two thresholds on one counter in one canonical home. |
| Seam eval order | RESOLVED | M3 registry → immutability → exemption (lower precedence) → reconciliation; held by every lens (only the architecture lens's HOLD explicitly preserves it). |
| Flat-vs-deferred AC-1 asymmetry | RESOLVED | Intentional, not a defect: literal pre-commit on deferred (orchestrator owns commit); revert-before-acceptance on flat (autonomous implementer). Genuine `git diff --cached` on flat ruled NON-VIABLE — no orchestrator pre-commit hook point. |
| Smuggling guard (path in both sets) | RESOLVED | Hard reject retained; exemption is strictly lower precedence than immutability. Survives the simplicity fold. |
| Scope-reuse of `In scope:`/`Scope:` for exemption | RESOLVED (N/A as a path) | NON-VIABLE in C2 (CR-006 parse-ambiguity). The residual simplicity tension is carried as VOQ-2; the reuse path itself is closed. |
| Reject-budget reuse | RESOLVED | The existing 2-attempt reject budget governs immutability rejects; no new budget. |
| Step 6c discovery shape + `.discovery-log.md` format | RESOLVED | 2nd reject reuses the missing-prerequisite Step 6c row, `default_triage: amend`, no format change. (Only the `source_agent` value remains open — VOQ-4.) |
| Hard-halt terminal state | RESOLVED | Reuses the existing `(b) block`-piece flow (status→`blocked`, manifest commit); no new terminal state invented. |
| Backward-compat: conditional declared-test mechanism | RESOLVED (folded as hard constraint) | Absent declaration ⇒ empty exemption set, no error/warning; qa-plan criterion verifies IFF present. |
| Backward-compat: config defaults | RESOLVED (folded) | `.spec-flow.yaml` without amendment keys (absent or malformed, NN-C-003) defaults cleanly. |
| Backward-compat: in-flight resume | RESOLVED (folded) | Hard-reject applies to fresh dispatches only; old-format (≤5.1.0) journal resume escape preserved. |
| Backward-compat: `(c) continue` removal | RESOLVED (folded) | Recorded in CHANGELOG `### Changed` with migration note (behavioral break), not `### Added`. |
| git-log `--grep` count fragility | RESOLVED (documented assumption) | Anchored on "piece-internal commits not rebased mid-piece"; more consequential now the cap hard-halts. Escalation summary degrades to `git log --oneline` if `.discovery-log.md` absent on resume. |
| user-intent / US-011 fit | CONFIRMED (HOLDS) | Serves the acceptance-boundary success condition. **Residual:** "mechanically unable [to tamper]" is guaranteed at the ACCEPTANCE boundary (not the commit primitive) on the flat path; the stronger no-tampered-object-ever reading is met only on the deferred/barrier path — acceptable because US-011 is signal-integrity-at-result. |
