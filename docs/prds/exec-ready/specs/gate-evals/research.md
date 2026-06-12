# research.md — exec-ready / gate-evals (FR-017)

## Brainstorm Inference Digest

**Piece purpose.** Build a committed fixture corpus (~60–80) plus a pure-bash eval-runner that measures every merge-blocking QA gate's catch rate, false-positive (clean-fixture flag) rate, verdict-flip rate over 3 runs, severity-assignment accuracy, and per-seat unique-catch — across three gate classes: (1) defective + known-clean spec/plan fixtures → `qa-spec`/`qa-plan`; (2) planted-defect + clean phase diffs → per-phase QA (`qa-phase`/`qa-phase-lite`/`qa-tdd-red`); (3) whole-piece fixtures with one defect mapped to the owning board seat → per-reviewer recall. Plus a **cheater track** that red-teams the FR-011 execute-integrity guardrails: ≥10 scripted cheat scenarios + ≥5 legitimate test-refactor fixtures the gate must ALLOW. Sub-100% cheat detection = guardrail bug + permanent regression. QA prompts/rubrics get version-frozen; any edit triggers a gold-set re-run before release. Living corpus: escaped defects add fixtures; saturated fixtures (3 consecutive full-catch runs) retire to a regression tier. Consuming contract: FR-016 board-composition changes must cite these catch-rates + ablation.

**The central architectural tension (the spike-worthy unknown).** A bash harness can deterministically test the **mechanical** FR-011 hash guardrails exactly like the existing `gate-ac{4,5,6}` fixtures (re-hash, compare, expect reject) — those are bash-checkable today. But measuring the **LLM gates'** catch rate is non-deterministic and *requires a model in the loop*. The charter (NN-C-002) mandates bash-only / no-runtime-deps, and the e2e harness's whole identity (README: "never invokes a model") is *no model dispatch*. So the eval-runner cannot itself dispatch the QA agents. This forces a split design the spec author must resolve.

**Open ambiguities (surface these in brainstorm):**
- (a) **How the LLM gates actually run.** Operator-driven skill/agent dispatch (operator runs `/spec-flow:execute`-style dispatches against each fixture, harness only scores the recorded verdicts — mirrors the existing `--verify-live` operator-driven pattern) vs a scripted model invocation (violates the harness's no-model identity + NN-C-002). The mechanical cheater-track scenarios are pure bash; the LLM catch-rate scenarios need a verdict-capture handoff. The bash/agent split line is the core design decision.
- (b) **Extend `build-fixture.sh` vs a parallel corpus builder.** `build-fixture.sh` builds ONE 12-commit replay repo with a closed `VALID_BREAKS` enum (6 cases). A 60–80 fixture corpus across 3 classes + a cheater track is a different shape (many small labeled fixtures, not one repo). Likely a new builder/loader, but the gate-ac inline-comment labeling convention should be reused verbatim.
- (c) **Where labels live.** The existing convention is **inline per-fixture**: a `# Scenario:` / `# Expected gate behavior:` comment header + `## Scenario` / `## Expected gate (X) outcome` body, scored by `grep -qF` keyword matches in `contract.sh`. Scaling to 60–80 fixtures with class/severity/owning-seat taxonomy may want a central label manifest (yaml) — but that breaks the grep-keyword scoring pattern. Resolve: inline labels + a generated index, or a central `labels.yaml`.
- (d) **Rubric-freeze release-gate enforcement with NO CI.** No CI exists today (charter-processes "CI gates: None currently configured"; PI-002 backlog only). The release protocol is a manual 5-step checklist in `charter-processes/SKILL.md`. FR-017 AC says version bump on prompt/rubric edit triggers a gold-set re-run "enforced as a release-process check." With no CI, enforcement is a documented release-checklist step + a bash drift-detector (hash the QA agent files, compare to a frozen `rubric_version` → version manifest). The QA agents carry **NO `version:`/`rubric_version:` field today** — FR-017 must ADD one (additive, NN-C-003).
- (e) **Non-determinism cost.** Verdict-flip over 3 runs means 3× model dispatches per LLM fixture × 60–80 fixtures — expensive. Likely operator-gated / on-demand (like the live procedure), with bash scoring of recorded verdict transcripts. Budget which fixtures get the 3-run treatment.
- (f) **Flat-path transient-commit window (backlog EG-4).** ADR-1 accepts that on `deferred_commit: off`/flat path a tampered commit transiently exists on HEAD before the orchestrator's gate (a) revert. The cheater track must include a scenario reading tampered content from HEAD in that window — else the accepted asymmetry goes untested.

**Design constraints (binding).** NN-C-002 eval runner MUST be POSIX bash 4+, no runtime deps (python3 only as optional fast-path with a mandatory awk/bash fallback, per `metrics-aggregate`). NN-C-008 any new/edited agent stays self-contained with bare `name:`. NN-C-003 additive/backward-compat (corpus + runner are new files; `rubric_version:` is an additive frontmatter key). NN-C-009 version bump + plugin.json/marketplace.json sync. CR-008 thin-orchestrator skills / narrow-executor agents. FR-017 failure mode: capability-absent → per-stage `SKIPPED: <capability>`, never false green (mirrors the existing `skip_cap` mechanism). Deps both MERGED: pipeline-e2e (shared fixture infra under `tests/e2e/`), metrics (per-reviewer finding provenance the per-seat unique-catch consumes).

## Codebase Conventions

- **e2e harness lives at** `plugins/spec-flow/tests/e2e/`: `run-e2e.sh` (152 LOC CLI dispatcher, `MODE` switch), `build-fixture.sh` (256 LOC, builds the replay repo), `lib/*.sh` (sourced modules: `assert.sh`, `contract.sh`, `golden.sh`, `live.sh`, `metrics.sh`, `static.sh`), `self/test-core.sh` (unit-tests the assert primitives), `setup-live.sh`, `fixtures/`, `golden/`.
- **Result vocabulary (assert.sh):** `PASS` / `FAIL` / `SKIPPED: <capability>` / `ERROR` / `EXCLUDED` (informational, uncounted). Counters `PASSES/FAILS/SKIPS/ERRORS`; `summary()` exits 0 iff `FAILS==0 && ERRORS==0`. A `SKIPPED` line is inert (never contributes to pass count) — the never-false-green rule.
- **Capability gating:** single-flip probe functions (`have_golden`, `have_transcript`, `have_metrics_artifact`); when the pre-condition is absent the check emits `skip_cap <id> <reason>` instead of failing. Capability IDs ∈ `live-run | transcript | metrics-artifact`.
- **Assertion primitives:** `assert_exit`, `assert_grep`/`assert_no_grep` (ERE), `assert_file` (exists+non-empty), `assert_count`, `assert_subject_order` (commit-order). Fixtures scored by `grep -qF "<keyword>"` against expected-outcome keywords.
- **Module-missing guard:** `run_mode` ERRORs if a `lib/` function is absent (defensive against partial source).
- **Destructive-op confinement (NN-C-006):** all `rm -rf` routes through `e2e_mktemp`/`e2e_cleanup`, which refuses any path outside `/tmp|/private|/var/folders`.
- **Agent dual-file convention:** each agent ships as BOTH `<name>.md` and `<name>.agent.md`, byte-identical (verified: `qa-spec.md` == `qa-spec.agent.md`). Frontmatter is bare `name:` + `description:` (+ optional `model:`). No `version:`/`rubric_version:` field exists on any QA agent today.
- **python3 fast-path pattern (`scripts/metrics-aggregate`):** optional python3 exec with a mandatory awk/bash fallback (`METRICS_AGG_NO_PY=1` forces fallback); NN-C-002 makes the bash path the guaranteed one.
- **Fixture labeling convention (the reusable one):** inline comment header `# Scenario: …` + `# Expected gate behavior: …`, body `## Scenario` (bulleted manifest/inputs) + `## Expected gate (X) outcome` (the asserted verdict + named violating path). Scored by keyword `grep -qF` in `contract.sh`.
- **No CI:** charter-processes "CI gates: None currently configured" (PI-002 backlog). Release = a manual checklist + a `master` commit bumping plugin.json + marketplace.json + CHANGELOG.

## Cluster: E2E Harness Infrastructure (reuse target)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/tests/e2e/run-e2e.sh` (152) — CLI dispatcher; modes `default | --audit | --verify-live | --record-golden | --break | --help`; sources `lib/assert.sh` first then all other `lib/*.sh`.
- `plugins/spec-flow/tests/e2e/lib/assert.sh` (76) — result vocabulary, counters, capability probes, `e2e_mktemp`/`e2e_cleanup`.
- `plugins/spec-flow/tests/e2e/lib/static.sh` (237) — L1 static contract checks against `skills/execute/SKILL.md` (ordered dispatch-sequence tokens at line-start, strictly increasing; greps for `exempt_authored`, smuggling HARD REJECT, auto-exempt prohibition).
- `plugins/spec-flow/tests/e2e/lib/contract.sh` (462) — L2 fixture-replay; `check_gate_fixtures` (the gate-ac scorer), `check_authored_tests_criterion`.
- `plugins/spec-flow/tests/e2e/lib/golden.sh` (295), `lib/live.sh` (300), `lib/metrics.sh` (28).
- `plugins/spec-flow/tests/e2e/build-fixture.sh` (256) — builds the 12-commit replay repo; closed `VALID_BREAKS` enum (6 cases).
- `plugins/spec-flow/tests/e2e/README.md` (123) — capability/SKIPPED semantics, live procedure, re-record policy, "What is NOT asserted" (note: "CI wiring deferred to pi-022-vsync-ci").
- `plugins/spec-flow/tests/e2e/self/test-core.sh`, `setup-live.sh`.
- Existing planted-defect fixtures: `fixtures/replay/gate-ac4-trip.md`, `gate-ac5-exempt.md`, `gate-ac6-smuggling.md`, `plan-clean.md`, `plan-no-test-data.md`, `plan-authored-tests-{clean,collision,no-authored-tests}.md`, `tdd-red-manifest-with-conftest.md`, `spec.md`, `plan-*.md`, `research.md`, `learnings.md`, `discovery-log.md`, `manifest.yaml`.

### Dependency Map
**Dependency Map:** `run-e2e.sh` sources `lib/assert.sh` then every other `lib/*.sh`, then calls `run_mode <fn>` per mode (ERRORs if fn missing). `build-fixture.sh` reads `fixtures/replay/*` and sources `lib/assert.sh` only for `e2e_mktemp`. `lib/static.sh` reads `skills/execute/SKILL.md` (couples the L1 checks to the FR-011 guardrail text). `lib/contract.sh check_gate_fixtures` reads `fixtures/replay/gate-ac*.md` and `check_authored_tests_criterion` reads `agents/qa-plan.md` + `agents/qa-plan.agent.md`. `lib/metrics.sh metrics_check` probes `<piece-dir>/metrics.yaml` via `have_metrics_artifact` → SKIPPED today. gate-evals adds a new corpus + a new runner/loader that reuses `assert.sh` primitives; it likely does NOT extend the closed `VALID_BREAKS` enum but adds parallel infra.

### Test Landscape
**Test Landscape:** Self-test at `self/test-core.sh` unit-tests `pass/fail/skip_cap/summary` + golden logic. `--break <case>` builds a single-defect fixture and asserts the harness detects it (the deterministic-defect-injection pattern gate-evals generalizes). Default run = L1 static + L2 replay + live selftest + golden + metrics, all model-free. The cheater track is the natural heir to `--break`: scripted single-defect injection, deterministic bash assertion. The LLM-gate catch-rate track has no model-free analog — it is the genuinely new capability.

### Pattern Catalog
**Pattern Catalog:**
```bash
# assert.sh — never-false-green: SKIPPED is inert, summary gates on FAILS+ERRORS only
skip_cap() { printf 'SKIPPED: %s — %s\n' "$1" "$2"; SKIPS=$((SKIPS + 1)); }
summary() {
  printf '== summary: %s passed, %s failed, %s skipped, %s errors ==\n' "$PASSES" "$FAILS" "$SKIPS" "$ERRORS"
  [ "$FAILS" -eq 0 ] && [ "$ERRORS" -eq 0 ] && return 0; return 1
}
have_metrics_artifact() { [ -s "${1:-}/metrics.yaml" ]; }   # single capability flip-point
```
```bash
# contract.sh — fixture scored by grep -qF on the expected-outcome keyword (the labeling contract)
if grep -qF "integrity fail" "$f4" 2>/dev/null; then
  pass "L2(i) AC-4 trip fixture asserts 'integrity fail' outcome"
else
  fail "L2(i) AC-4 trip fixture missing 'integrity fail' outcome"
fi
```
```text
# gate-ac4-trip.md — inline fixture-label convention (reuse verbatim for the corpus)
# Scenario: Build commit edits a manifest-listed conftest.py.
# Expected gate behavior: integrity fail — conftest.py named in reject.
#   [body H2] Scenario:
#     - phase_N_red_stage_manifest: {tests/unit/test_foo.py, tests/unit/conftest.py, ...}
#   [body H2] Expected gate (a) outcome:
#     integrity fail: tests/unit/conftest.py → reject (hard stop)
```

## Cluster: FR-011 Execute-Integrity Guardrails (cheater-track target)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/skills/execute/SKILL.md` (2121) — the guardrail source. Key loci: Step 2.6 capture stage manifest (`phase_N_red_stage_manifest`, path→sha256, ~line 502) + defensive re-hash at capture (~507); Step 3.7 item 7 post-commit integrity+reconciliation gates (~620); **gate (a)** content-hash integrity, HARD-stop, names violating paths, smuggling guard (~624–704), incl. `git show HEAD:"$path" | sha256sum` compare and `exempt_authored` precedence (M3 registry → Red-manifest immutability → exempt_authored; overlap = HARD REJECT smuggling); M3 single-shot edit window `skeleton_sha256`→`completed_sha256` (~636–702, closure hashes in orchestrator state not plan columns); **gate (b)** reconciliation `expected = Red manifest ∪ Build Files ∪ exempt_authored` (~714); Step 4 item 5 phase-exit test-integrity re-hash (~795, catches Refactor drift); Step 4.5 completing-phase M3 re-check (~808–825); `amendment_budget` resolve (~278, default 5); amendment hard-cap escalation (~1279–1304, raise/fork/defer/block — never auto-exempt).

### Dependency Map
**Dependency Map:** Guardrails are MECHANICAL (orchestrator bash: `sha256sum`, `git show HEAD:`, `git cat-file -e`, set reconciliation, path normalization for CWE-706). `lib/static.sh` already asserts the guardrail TEXT exists in `SKILL.md` (greps `exempt_authored`, `HARD REJECT.*smuggling`, `NEVER auto-exempt`). The cheater track must exercise the guardrail BEHAVIOR, not just text presence — i.e. construct a tampered HEAD state and assert the orchestrator's re-hash logic rejects it. Pure-bash testable: edit-assertions / skip-or-delete-failing-tests / hardcode-outputs-in-except-handlers / stub-function-under-test / weaken-tolerances → all manifest as a HEAD content-hash drift or a reconciliation stray/missing → mechanically detectable. AC-done-with-no-diff and the flat-path transient-commit window (backlog EG-4) are also bash-constructible. Scenarios that need a *judgment* call (is this a legit refactor or a cheat?) are the ≥5 legitimate test-refactor fixtures the gate must ALLOW — these test the *boundary* of the mechanical rule (a refactor that touches a non-Red-manifest file passes; one that drifts a Red-manifest hash fails).

### Test Landscape
**Test Landscape:** Existing `gate-ac4-trip` (conftest in manifest → integrity fail), `gate-ac5-exempt` (Authored-tests declared test passes reconciliation), `gate-ac6-smuggling` (Authored-tests lists Red-manifest path → HARD REJECT) are the seed of the cheater track — they already encode the tamper→reject pattern as static fixtures scored by keyword. The cheater track extends this from 3 to ≥10 + ≥5 allow-fixtures, and (the harder part) from static-keyword-assertion to actually-running-the-orchestrator-bash against a constructed tampered repo state. `tdd-red-manifest-with-conftest.md` covers Phase-2 fixture enrichment (Rule 10) — relevant to the smuggling-guard-applies-to-enriched-entries clause.

### Pattern Catalog
**Pattern Catalog:**
```bash
# execute/SKILL.md Step 3.7a gate (a) — the mechanical anti-cheat the cheater track red-teams
commit_hash=$(git show HEAD:"$path" | sha256sum | cut -d' ' -f1)
[ "$commit_hash" = "$manifest_hash" ] || echo "integrity fail: $path"
# Any mismatch for a path NOT in exempt_authored = implementer modified Red's tests → HARD STOP, no warn branch
```
```bash
# execute/SKILL.md — defensive re-hash at capture (Step 2.6), trust nothing self-reported
actual=$(sha256sum -- "$path" | cut -d' ' -f1)
# compare against Red's self-reported manifest hash before trusting it
```
```text
# gate (a) precedence (smuggling guard): M3 registry → Red-manifest immutability → exempt_authored (lowest)
# A path in BOTH phase_N_red_stage_manifest AND exempt_authored = HARD REJECT (exemption ignored)
# Applies to ALL Red-manifest entries incl. Phase-2-enriched conftest/fixture/helper paths.
```

## Cluster: QA Gate Agents (catch-rate subjects + rubric-freeze)

### File Inventory
**File Inventory:** Spec/plan-gate: `agents/qa-spec.md` (+`.agent.md`), `qa-plan.md` (largest, 24K — criterion-numbered, incl. the smuggling/Authored-tests criterion `contract.sh` asserts). Per-phase: `qa-phase.md`, `qa-phase-lite.md`, `qa-tdd-red.md` (theater-pattern catalog). Board seats: `review-board-{blind,edge-case,security,ground-truth,architecture,integration,spec-compliance,prd-alignment,triage}.md`. Each ships as a byte-identical `<name>.md` + `<name>.agent.md` pair. Supporting refs: `reference/qa-iteration-loop.md`, `reference/gate-scaling.md` (FR-016 consuming contract), `reference/deliberation-depth.md`.

### Dependency Map
**Dependency Map:** Frontmatter today = bare `name:` + `description:` (+ `model: opus` on some board seats, e.g. `review-board-integration`). **NO `version:`/`rubric_version:` field on any QA agent** — FR-017 must add it (additive frontmatter key, NN-C-003/NN-C-008 self-contained, NN-C-009 version bump). These are LLM dispatches: measuring catch rate requires model-in-the-loop verdicts, which conflicts with the harness's model-free identity and NN-C-002 — the operator-driven-dispatch + bash-score-the-transcript split is the likely reconciliation. `review-board-*` seats map to the class-3 whole-piece fixtures (one defect per fixture → the seat that should own it → per-seat unique-catch). The rubric-freeze gate hashes these files → compares to a frozen version → forces a gold-set re-run on drift (bash drift-detector since no CI).

### Test Landscape
**Test Landscape:** No behavioral test of these agents' catch rate exists today — only `static.sh`/`contract.sh` assert that specific *criterion text* is present in `qa-plan.md`/`execute/SKILL.md`. gate-evals is the first piece to measure their *recall*. The clean-fixture flag rate (FP control) and verdict-flip-over-3-runs are net-new measurement capabilities with no model-free precedent. Severity-assignment accuracy needs the agents' severity vocabulary captured per fixture.

### Pattern Catalog
**Pattern Catalog:**
```yaml
# Current QA agent frontmatter (qa-spec.md) — NO version field; FR-017 adds rubric_version
---
name: qa-spec
description: "Internal agent — dispatched by spec-flow:spec. ... Read-only — never modifies files."
---
```
```yaml
# Some board seats carry an explicit model tier (review-board-integration.md)
---
name: review-board-integration
description: "... Read-only — never modifies code."
model: opus
---
```

## Cluster: Metrics + Release Process (provenance source + freeze-gate wiring)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/reference/metrics-artifact.md` (17.5K) — `metrics.yaml` schema; `final_review.iterations`, `final_review.must_fix` (deduped), `gate_scaling.<gate>.{offered_summary_confirm,fell_back,reason}`, write procedure (upsert own block, serial-checkpoint-only ADR-4), no-secrets clause.
- `plugins/spec-flow/scripts/metrics-aggregate` (+`.py`) — python3 fast-path + mandatory awk/bash fallback; the NN-C-002 pattern gate-evals' runner should mirror.
- `.claude/skills/charter-processes/SKILL.md` — release protocol (5-step manual checklist; CI gates "None currently configured", PI-002 backlog).
- `.claude/skills/charter-non-negotiables/SKILL.md` — NN-C-002/003/006/008/009.
- `docs/prds/exec-ready/backlog.md` (EG-4: flat-path transient-commit cheater scenario, to fold into this spec).

### Dependency Map
**Dependency Map:** The merged `metrics` piece records `final_review.{iterations,must_fix}` but the current schema shown does NOT yet expose a per-reviewer/per-seat finding-provenance leaf — gate-evals' per-seat unique-catch needs to know WHICH seat produced WHICH finding. Confirm during spec whether `metrics` added a `final_review.findings[].seat` provenance field or whether gate-evals must derive per-seat attribution from its own fixtures (one-defect-per-seat fixtures make attribution intrinsic to the fixture label, sidestepping a metrics dependency). The rubric-freeze release-gate wires into `charter-processes` release protocol step (a new pre-release check: "if any `agents/qa-*.md` or `review-board-*.md` hash changed since the frozen `rubric_version`, a gold-set re-run is required before bump"). No CI → enforcement is a documented checklist step + a runnable bash drift-detector.

### Test Landscape
**Test Landscape:** `lib/metrics.sh metrics_check` probes `<piece-dir>/metrics.yaml` → SKIPPED until present. No release-gate test exists today. gate-evals adds (1) the corpus eval-runner (bash, model-free for the mechanical/cheater track; operator-driven for LLM catch-rate), (2) a rubric-version drift detector, (3) the saturated-fixture→regression-tier retirement bookkeeping.

### Pattern Catalog
**Pattern Catalog:**
```bash
# metrics-aggregate — NN-C-002 python-fast-path + mandatory bash fallback (mirror for the eval runner)
# If python3 is available (and not suppressed), exec into the Python implementation...
# NN-C-002: the awk path below is the mandatory fallback when python3 is absent.
# Set METRICS_AGG_NO_PY=1 to force the awk/bash path.
```
```text
# charter-processes release protocol — where the rubric-freeze gate wires in (no CI today)
1. Bump plugins/<plugin>/.claude-plugin/plugin.json version
2. Update .claude-plugin/marketplace.json to match
3. Add ## [X.Y.Z] — YYYY-MM-DD to CHANGELOG.md
# FR-017 inserts: "if any qa-*/review-board-* rubric changed → gold-set re-run required"
```
