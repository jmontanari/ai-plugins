---
charter_snapshot:
  non-negotiables: 2026-06-05
  architecture: 2026-06-10
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: exec-guardrails

**PRD Sections:** FR-011, SC-002, G-2, G-6
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** none

## Goal

Make execute's integrity guardrails **mechanical, not advisory**. Two coupled changes:

1. **Test immutability** — a Build phase must not be able to silently edit, weaken, or delete the Red phase's failing tests to make the gate pass. The SHA-256 manifest that `tdd-red` already produces (pi-020 anti-cheat anchoring) is upgraded from *detect-later / warn* to *reject-mechanically*: a Build-step diff touching any manifest file is rejected and the implementer re-dispatched with the violating paths named — no warn-and-proceed path. Phase exit re-verifies the hashes as a blocking finding. Implement-track phases that legitimately author tests declare those paths so they are exempt.
2. **Amendment hard-cap** — the per-piece amendment budget becomes a configurable hard ceiling that actually halts, replacing today's soft-checkpoint that never blocks. Reaching it is a **"why are we here?" review gate**: execute halts and escalates with the amendment history so the operator can judge whether the plan/spec under-scoped something structural, rather than letting an unattended run grind amendments forever.

Both serve US-011's acceptance-boundary success condition: a green result means the planned tests passed, not that the tests were bent to the code. This is a precondition for safe loop-driven / unattended execute.

## In Scope

- Mechanical test-immutability reject on **both** commit paths — the flat / `deferred_commit: off` HEAD path (execute Step 3 gate (a)) and the deferred-Phase-Group barrier path (Step G9b) — tightening the existing re-hash gates from warn/no-op to hard reject + named-path re-dispatch.
- **`tdd-red` manifest enrichment**: fold the fixture/helper files a staged test *directly imports* — plus `conftest.py` in the staged test's directory tree — into the SHA-256 manifest, so the common fixture-tampering vector is byte-covered without a fragile closure-derivation pass.
- **Phase-exit re-verification** (Step 4 / Verify): a manifest-hash mismatch at phase exit is a blocking finding attributed to the phase, never a silent no-op (catches Refactor-step drift after the entry gate).
- **Declared-authored-test exemption**: a new conditional `**Authored-tests:**` plan phase-header field; only declared paths are exempt from the immutability reject; `qa-plan` verifies the declaration; a path that is both Red-immutable and declared-authored is a hard reject (smuggling guard).
- **Amendment hard-cap**: a configurable `amendment_budget` integer in `.spec-flow.yaml` (documented default 5); reaching it halts execute with a diagnostic escalation; the operator may raise the integer and resume as an attended decision; no per-event soft continuation; no off/unlimited sentinel.
- **Unify the amendment counter** (architecture correction): model the soft-checkpoint and the hard-cap as thresholds on the *single* existing `piece_amendment_count` counter in one canonical home; edit the `reference/spike-agent.md` `## Soft-checkpoint budget` "never hard-blocks" assertion (and the matching `execute/SKILL.md` text) so the single-source-of-truth no longer contradicts the new hard-halt.
- **Repeated-rejection routing**: the 2nd immutability rejection on a phase emits a Step 6c missing-prerequisite-shaped discovery row (`source_agent: orchestrator`, `default_triage: amend`) — plan-incompleteness, never an auto-exemption.
- Dual-file edits to every touched agent (`<name>.md` + `<name>.agent.md`), plugin version bump (`plugin.json` + `marketplace.json`), and a CHANGELOG `### Changed` entry with a migration note for the `(c) continue` removal.

## Out of Scope / Non-Goals

- **Full transitive import/fixture closure-hashing.** This piece covers *directly-imported* fixtures + same-tree `conftest.py` only. Catching deep transitive chains or fixtures injected *by name with no import* would require deriving a full closure (fragile in POSIX bash, NN-C-002 tension; the existing M3 closure-hashing only works because integration paths are *plan-declared*). The residual is documented as a known limitation and tracked as a candidate follow-up piece (see Deferred).
- **New-trivial-test-file detection** beyond existing reconciliation. A Build phase adding a *new* trivially-passing test games coverage optics, not the pass/fail oracle (the failing Red test must still go green), so it is a lower-severity vector left to the existing reconciliation + review board.
- **Spec sub-cap configurability.** The 1-spec-amendment sub-limit stays a fixed documented constant; only the *total* budget is operator-configurable (AC-4 names the total).
- **Off / unlimited amendment sentinel.** A value that disables the hard halt is explicitly excluded — it reopens the unattended-runaway failure mode FR-011 exists to prevent. "More headroom" is expressed by a higher finite integer.
- **New flywheel / monitoring infrastructure.** The diagnostic escalation reuses the existing `.discovery-log.md` rows and the already-shipped self-hardening flywheel (FR-006) as its substrate; this piece builds no new recording surface.
- **Changing the flat-vs-deferred commit-timing asymmetry.** On the flat path the implementer commits autonomously, so the reject is revert-before-acceptance; on the deferred path the orchestrator owns the commit, so the re-hash is genuinely pre-commit. This asymmetry is structural and accepted (both converge on "no tampered state is accepted").

## Requirements

### Functional Requirements

- **FR-EG-1 (flat-path mechanical reject):** On the flat / `deferred_commit: off` path, when the Build-step diff (Step 3 gate (a)) adds, modifies, or deletes any file in Red's SHA-256 manifest that is not in the declared-exemption set, the orchestrator rejects the phase before the tampered commit is accepted (revert + retry), names the violating paths, and re-dispatches the implementer. There is no warn-and-proceed branch.
- **FR-EG-2 (deferred-path mechanical reject):** On the deferred-Phase-Group barrier (Step G9b), the working-tree re-hash against the journal `red_manifest_hashes` (git-blob anchor) rejects any manifest-file mismatch before the orchestrator's barrier commit, names the violating paths, and re-dispatches the offending sub-phase.
- **FR-EG-3 (manifest enrichment):** `tdd-red` extends its `## Staged test manifest` to additionally include — by a bounded, declared rule — the fixture/helper files each staged test *directly imports* and any `conftest.py` in the staged test's directory tree, hashing them the same way as the test files. The enriched set is what the gates in FR-EG-1/FR-EG-2 protect.
- **FR-EG-4 (phase-exit re-verification):** At phase exit (Step 4 / Verify), the orchestrator re-hashes the manifest set; a mismatch is a blocking finding attributed to the phase (reject + re-dispatch the offending agent with paths named), never a silent no-op. This covers post-gate drift introduced by the Refactor step.
- **FR-EG-5 (declared-authored-test exemption):** A plan phase block may carry an optional `**Authored-tests:**` field listing literal test paths the phase legitimately authors. Only listed paths are exempt from the immutability reject. The field is conditional: its absence yields an empty exemption set (no parse error, no warning). A path that appears in *both* the immutable manifest set and an `**Authored-tests:**` declaration is a hard reject (smuggling guard), never an exemption.
- **FR-EG-6 (qa-plan verification):** `qa-plan` verifies `**Authored-tests:**` declarations when present (verify-iff-present): each declared path is a real test path cited in that phase's body, and no declared path collides with any Red-manifest or integration-registry path. A collision or phantom declaration is a must-fix finding. Absence of the field is never a finding.
- **FR-EG-7 (amendment-budget config):** `.spec-flow.yaml` gains an `amendment_budget` integer key (documented default 5). It is read with the existing config idiom — default when absent, one-line warning + default when malformed (NN-C-003), documented inline in `templates/pipeline-config.yaml` (CR-007). The 1-spec sub-cap remains a fixed documented constant. The budget is enforced against the *single existing* `piece_amendment_count` counter — no second counter, no second canonical home.
- **FR-EG-8 (diagnostic hard-cap halt):** Reaching `amendment_budget` halts execute with an operator escalation that frames the situation as a possible process failure ("this many amendments signals the plan/spec may have under-scoped — is a larger change needed?") and summarizes the amendment history. There is no per-event soft-continuation option. The operator's attended escapes are to raise `amendment_budget` and resume, or to route to the existing `fork` / `block` triage. The `reference/spike-agent.md` `## Soft-checkpoint budget` "never hard-blocks" assertion and the matching `execute/SKILL.md` text are edited so the single-source-of-truth is consistent with the hard-halt.
- **FR-EG-9 (repeated-rejection routing):** The 2nd immutability rejection on the same phase (the implementer cannot complete within the existing 2-attempt budget without touching tests) routes to Step 6c as a plan-incompleteness discovery row — `source_agent: orchestrator`, `default_triage: amend`, using the unchanged `.discovery-log.md` format. The routing never auto-exempts the touched test; mutability is reachable only via a plan amendment that is re-reviewed by `qa-plan` and re-gated by per-phase QA.
- **FR-EG-10 (packaging):** Every touched agent is edited in both its `<name>.md` and `<name>.agent.md` mirror. The plugin version is bumped in `plugin.json` and `marketplace.json` (NN-C-001/NN-C-009). The CHANGELOG records the `(c) continue` removal under `### Changed` with a migration note (CR-006) — it is a behavioral break, not an addition.

### Non-Functional Requirements

- **NFR-EG-1 (no runtime dependency):** All new checks use POSIX bash and git only (`sha256sum`, `git show`, `git cat-file`, `git hash-object`, `git diff`, `git log`). No interpreter, parser library, or runtime dependency is introduced (NN-C-002).
- **NFR-EG-2 (determinism / idempotence):** The immutability verdict is deterministic and idempotent — re-running the re-hash on an unchanged tree yields the same verdict; the gate has no time- or order-dependent state.
- **NFR-EG-3 (backward compatibility):** A plan authored before this piece (no `**Authored-tests:**` field) executes unchanged (empty exemption set). A `.spec-flow.yaml` without `amendment_budget` defaults cleanly to 5 (absent or malformed). An in-flight piece resuming from a ≤5.1.0 journal format preserves the existing format escape — the hard-reject applies to fresh dispatches, not mid-stream old-format resume (NN-C-003).
- **NFR-EG-4 (observability):** The operator-facing surface of both guardrails is on disk and re-derivable — the named violating paths in the re-dispatch, the Step 6c discovery row in `.discovery-log.md`, and the amendment-history escalation summary (git-log `--grep` canonical count, enriched by `.discovery-log.md` amend rows when present).

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-002 (markdown + config only — no runtime deps): every guardrail is orchestration/agent prose + POSIX bash + git; no compiled tool, no closure-derivation library (this is the reason full transitive closure-hashing is out of scope).
- NN-C-003 (backward compatibility within a major version): conditional `**Authored-tests:**` field, default-when-absent `amendment_budget`, and the preserved in-flight ≤5.1.0 journal escape all keep pre-piece artifacts working without migration.
- NN-C-001 / NN-C-009 (version sync + always bump): `plugin.json` + `marketplace.json` bumped together; CHANGELOG updated.

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-001 (human approval gate never removed): the hard-cap halt and the Step 6c routing are operator gates requiring a keystroke; nothing auto-advances. The operator's "raise and resume" is an attended decision, not an automatic continuation.
- NN-P-002 (no silent or mid-stream execute-time change): repeated rejections route to synchronous Step 6c operator triage (never a silent backlog write or auto-exemption); the immutability gate tightens, never creating a QA/review bypass.
- NN-P-005 (thinking on Opus, mechanics on Sonnet — no silent upgrade): the immutability check is mechanical orchestrator work (hash compare); it adds no thinking step and triggers no model upgrade.

### Coding Rules Honored

- CR-007 (config keys documented inline): `amendment_budget` is documented in `templates/pipeline-config.yaml` with purpose, value enumeration, default, and version-introduced note.
- CR-006 (CHANGELOG — Keep a Changelog): the `(c) continue` removal is a `### Changed` entry with a migration note.
- CR-008 (separation of concerns — thin-orchestrator skills, narrow-executor agents): the orchestrator owns the gate/halt logic; `tdd-red` owns manifest production; `qa-plan` owns declaration verification; the canonical budget definition lives in one home and is cited, not restated.
- CR-001 (agent frontmatter schema): preserved on every edited agent file and its `.agent.md` mirror.
- CR-004 (conventional-commits with plugin scope): all commits use the `feat(...)` / `chore(...)` plugin-scoped format.

## Acceptance Criteria

AC-1: Given a TDD phase on the flat / `deferred_commit: off` path whose Build-step diff modifies, adds, or deletes a file in Red's (enriched) manifest that is not declared-exempt, When Step 3 gate (a) runs, Then the phase is rejected before the tampered commit is accepted, the violating paths are named back to the implementer, and the implementer is re-dispatched — with no warn-and-proceed branch reachable. *(machine-checkable)*
  Independent Test: e2e fixture scenario (pipeline-e2e harness) drives a Build agent that edits a manifest test file; assert the run rejects + re-dispatches + the rejected commit is not accepted; structural assert that no warn/continue branch exists at gate (a) in `execute/SKILL.md`.

AC-2: Given a deferred Phase Group whose sub-phase tampers with a manifest file, When the Step G9b barrier working-tree re-hash runs, Then the mismatch is rejected before the barrier commit and the offending sub-phase is re-dispatched with the violating paths named. *(machine-checkable)*
  Independent Test: e2e deferred-group fixture with a tampering sub-phase; assert reject-before-barrier-commit + named paths.

AC-3: Given a phase has passed gate (a), When the Refactor step (Step 5) modifies a manifest file and the phase-exit re-hash (Step 4 / Verify) runs, Then the mismatch is surfaced as a blocking finding attributed to the phase (reject + re-dispatch), never recorded as a no-op. *(machine-checkable)*
  Independent Test: fixture where Refactor edits a Red test; assert phase-exit emits a blocking finding; structural assert the Step 4 prose says "blocking finding," not "already passed / no-op."

AC-4: Given `tdd-red` stages a test that directly imports a fixture/helper file and/or has a `conftest.py` in its directory tree, When it emits the staged manifest, Then those fixture/helper/conftest files appear in the manifest with their SHA-256 and are protected by the gates in AC-1/AC-2. *(machine-checkable)*
  Independent Test: fixture test with a `conftest.py` + an imported helper; assert both appear in the emitted manifest; assert a Build edit to the `conftest.py` trips the reject.

AC-5: Given an Implement-track phase that legitimately authors a test, When the phase declares the path in `**Authored-tests:**`, Then a Build-step write to exactly that declared path is exempt from the immutability reject; and Given the field is absent, Then the exemption set is empty and the phase parses without error or warning. *(machine-checkable)*
  Independent Test: two fixtures — (a) Implement phase with `**Authored-tests:**` listing the path it writes → no reject; (b) pre-piece plan with no field → executes unchanged, empty exemption.

AC-6: Given an `**Authored-tests:**` declaration that lists a path also present in Red's manifest, When the immutability gate evaluates it, Then it is a hard reject (smuggling guard), not an exemption; and When `qa-plan` reviews such a plan, Then it raises a must-fix finding. *(machine-checkable)*
  Independent Test: fixture plan declaring a Red-manifest path as authored → assert runtime hard reject AND qa-plan must-fix.

AC-7: Given `.spec-flow.yaml` sets `amendment_budget: N`, When the piece reaches its Nth amendment, Then execute halts with a diagnostic escalation summarizing the amendment history and offering no per-event soft-continuation; and Given the key is absent or malformed, Then it defaults to 5 (malformed also emits a one-line warning). *(machine-checkable)*
  Independent Test: fixture driving N amendments with `amendment_budget` set low → assert hard halt + escalation summary + no `(c) continue` affordance; config tests for absent/malformed → default 5 (+warning on malformed).

AC-8: Given execute halts at the amendment cap, When the operator raises `amendment_budget` and resumes, Then execution continues from the journal state; and there is no `off`/unlimited value that disables the halt. *(machine-checkable)*
  Independent Test: resume fixture after raising the integer → continues; structural assert no off/unlimited sentinel is accepted by the config read.

AC-9: Given the implementer hits a 2nd immutability rejection on the same phase within the 2-attempt budget, When the budget is exhausted, Then a Step 6c discovery row is emitted with `source_agent: orchestrator` and `default_triage: amend` in the unchanged `.discovery-log.md` format, and the touched test is never auto-exempted. *(machine-checkable)*
  Independent Test: fixture with a persistently-tampering Build agent → assert a single Step 6c row with the stated fields after the 2nd rejection; assert the exemption set is unchanged by the routing.

AC-10: Given the amendment counter is referenced for the soft-checkpoint and the hard-cap, When the implementation lands, Then there is exactly one counter (`piece_amendment_count`) with one canonical home, and `reference/spike-agent.md` `## Soft-checkpoint budget` no longer asserts "never hard-blocks" in contradiction with the hard-cap. *(judgment-required)*
  Independent Test: structural review — grep that no second counter/home is introduced; read spike-agent.md + execute text for SSOT consistency (architecture reviewer / qa-spec).

AC-11: Given this piece ships, When the package is inspected, Then every edited agent has matching `<name>.md` and `<name>.agent.md` changes, `plugin.json` and `marketplace.json` versions match, and the CHANGELOG records the `(c) continue` removal under `### Changed` with a migration note. *(machine-checkable)*
  Independent Test: diff inspection — assert paired mirror edits, version sync, and a `### Changed` CHANGELOG entry naming the behavioral break.

## Technical Approach

**One seam, one evaluation order.** Both the flat gate (Step 3 gate (a)) and the deferred barrier (Step G9b) evaluate the same ordered set: **M3 integration-registry window → Red-manifest immutability (enriched) → declared-authored-test exemption (lower precedence) → reconciliation.** A path that is both immutable and declared-authored resolves deterministically to *reject* because exemption is strictly lower precedence. This is a tightening of the existing gate prose, not a new mechanism — the re-hash loop, the 2-attempt budget, and the M3 window already exist (research.md §Test-immutability anti-cheat).

**Flat vs deferred asymmetry (accepted).** On the flat path the implementer commits autonomously (implementer Rule 8), so the orchestrator cannot hold a staged-but-uncommitted tree — the reject is revert-before-acceptance (no tampered commit ever survives into accepted history). On the deferred path the orchestrator owns the barrier commit, so the working-tree re-hash is genuinely pre-commit. Both converge on the invariant "no tampered state is accepted." AC-1 "before any commit" is read as literal pre-commit on the deferred path and as "before any tampered commit is accepted" on the flat path.

**Manifest enrichment (bounded rule).** `tdd-red` already holds the staged test source. The enrichment scans each staged test for direct import statements and resolves them to repo-relative files, and includes any `conftest.py` in the staged test's directory tree. This is best-effort and intentionally shallow (no transitive walk) to avoid the false-positive risk that fragile closure-derivation would create — over-protecting unrelated files would cause spurious rejects that erode trust in the gate.

**Amendment cap — unify, don't fork.** The soft-checkpoint and the hard-cap are two thresholds on the *single* `piece_amendment_count` counter (recovered via `git log --grep '^chore(plan): amend'`). The hard-halt reuses the existing `(b) block`-piece flow (status → blocked, manifest commit). The `(c) continue` per-event affordance is removed. The canonical budget definition stays in one home; `reference/spike-agent.md` is reduced to a cite and its "never hard-blocks" text is edited to match.

**Diagnostic framing.** The cap escalation is a "why are we here?" review gate: it surfaces the amendment history (git-log canonical, `.discovery-log.md`-enriched) and frames the count as a signal that the plan/spec may need a structural re-scope — leaning on the already-shipped flywheel substrate rather than new monitoring infrastructure.

## Testing Strategy

- **No unit harness in this repo** — validation is the e2e fixture harness (pipeline-e2e L1/L2/L3 fixtures + scripted scenario), structural assertions over the orchestration/agent prose (grep for the presence/absence of specific branches and fields), and adversarial review (qa-spec, qa-plan, the end-of-piece review board including architecture + ground-truth + integration reviewers).
- **Integration boundaries** (file-contract seams, exercised end-to-end by the pipeline-e2e harness): orchestrator ↔ `tdd-red` enriched manifest; orchestrator ↔ plan `**Authored-tests:**` field (via `qa-plan`); orchestrator ↔ Step 6c `.discovery-log.md` row; orchestrator ↔ journal `red_manifest_hashes` on the deferred path.
- **Edge cases to cover:** absent `**Authored-tests:**` (empty exemption, no warning); absent/malformed `amendment_budget` (default 5, warning on malformed); smuggling (Red path declared authored → reject); Refactor-step drift (phase-exit blocking finding); deferred-group tampering sub-phase; 2nd-rejection → single Step 6c row; in-flight ≤5.1.0 journal resume not hard-rejected; byte-identical fixture regeneration (no false reject).

## Integration Coverage

- Integration: `tdd-red` → orchestrator gate — inside: tdd-red manifest producer + execute Step 3/G9b consumer; doubled externals: none (in-plugin file contract — the enriched manifest); AC-1, AC-4; completes in the immutability-gate phase, exercised by the pipeline-e2e harness.
- Integration: plan `**Authored-tests:**` → `qa-plan` → orchestrator exemption set — inside: plan template field, qa-plan verifier, execute gate; doubled externals: none (in-plugin file contract); AC-5, AC-6; exercised by the pipeline-e2e harness.
- Integration: orchestrator → Step 6c `.discovery-log.md` row — inside: gate reject path + discovery-log writer; doubled externals: none; AC-9; exercised by the pipeline-e2e harness.

## Open Questions

- OQ-1: The exact direct-import scan rule for manifest enrichment (which import forms `tdd-red` resolves, and how `conftest.py` directory-tree scope is bounded). (Default: resolve `from X import` / `import X` direct statements in each staged test to repo-relative files, plus any `conftest.py` from the staged test's directory up to the test root; no transitive walk; non-resolving imports are skipped, not errored — this is a plan-time mechanical detail.)
- OQ-2: Whether the amendment-cap escalation reuses the existing `fork` / `block` triage menu verbatim or adds a distinct "raise budget and resume" line item. (Default: reuse the existing menu plus a one-line "raise `amendment_budget` and resume" instruction in the escalation text — no new triage option code path.)

## Explicitly Out of Scope / Deferred

- **Full transitive / by-name fixture-closure hashing** — DEFERRED. This piece covers directly-imported fixtures + same-tree `conftest.py`. Deep transitive chains and fixtures injected by name (no import) remain a documented residual. Candidate follow-up piece: evaluate whether the residual is exploited in practice before building plan-declared closure hashing (the only NN-C-002-clean shape, modeled on the existing M3 integration closure). Owner: a future exec-ready piece, TBD — resolved at that piece's brainstorm with real evidence.
